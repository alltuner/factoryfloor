// ABOUTME: Monitors Claude Code JSONL transcript files for agent activity.
// ABOUTME: Tails .jsonl files in ~/.claude/projects/ and emits AgentEvent for each tool use.

import Foundation
import os

private let logger = Logger(subsystem: "factoryfloor", category: "transcript-watcher")

/// Watches Claude Code JSONL transcripts and emits pixel agent events.
///
/// Given a project working directory, it resolves the Claude project hash path,
/// finds active session .jsonl files, and tails them for tool_use / tool_result records.
/// Subagent transcripts are discovered automatically from the subagents/ subdirectory.
final class TranscriptWatcher: @unchecked Sendable {

    /// Callback invoked on the main queue whenever an agent event is detected.
    var onEvent: ((AgentEvent) -> Void)?

    private let projectDir: String
    private let claudeProjectPath: URL
    private let queue = DispatchQueue(label: "factoryfloor.transcript-watcher", qos: .utility)

    // MARK: - Thread Safety
    //
    // This class is `@unchecked Sendable` because all mutable state below is
    // accessed exclusively on `self.queue` (a serial DispatchQueue). Public
    // entry points (`start`, `stop`) dispatch onto the queue, and the
    // `onEvent` callback is forwarded to the main queue.
    //
    // DispatchSource cancel handlers (which close file descriptors) fire
    // reliably when sources are deallocated, so `deinit` calling `stop()`
    // with `[weak self]` guards is safe — the sources will still clean up
    // even if the async block finds `self` already nil.

    // Tracking state for each watched file
    private var watchedFiles: [URL: WatchedFile] = [:]
    private var directorySource: DispatchSourceFileSystemObject?
    private var pollTimer: DispatchSourceTimer?

    // Palette assignment for agents
    private var nextPalette = 0
    private var agentPalettes: [String: Int] = [:]

    // Track active tools per agent to emit toolDone
    private var activeTools: [String: String] = [:]

    private struct WatchedFile {
        var offset: UInt64
        var fileSource: DispatchSourceFileSystemObject?
    }

    init(projectDir: String) {
        self.projectDir = projectDir
        self.claudeProjectPath = Self.resolveClaudeProjectPath(for: projectDir)
        logger.info("TranscriptWatcher init for: \(self.claudeProjectPath.path)")
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in
            self?.setupWatching()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.pollTimer?.cancel()
            self.pollTimer = nil
            self.directorySource?.cancel()
            self.directorySource = nil
            for (url, watched) in self.watchedFiles {
                watched.fileSource?.cancel()
                self.watchedFiles[url] = nil
            }
        }
    }

    // MARK: - Claude Project Path Resolution

    /// Converts a working directory path to the Claude project hash directory.
    /// e.g. /Users/foo/Desktop/myproject → ~/.claude/projects/-Users-foo-Desktop-myproject/
    static func resolveClaudeProjectPath(for directory: String) -> URL {
        let sanitized = directory.replacingOccurrences(of: "/", with: "-")
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
            .appendingPathComponent(sanitized)
        return claudeDir
    }

    // MARK: - Watching Setup

    private func setupWatching() {
        // Ensure the claude projects directory exists
        let dirPath = claudeProjectPath.path
        guard FileManager.default.fileExists(atPath: dirPath) else {
            logger.info("Claude project path does not exist yet: \(dirPath). Starting poll timer.")
            startPollTimer()
            return
        }

        attachDirectoryWatcher()
        scanForTranscripts()
        startPollTimer()
    }

    private func attachDirectoryWatcher() {
        let dirPath = claudeProjectPath.path
        let descriptor = open(dirPath, O_EVTONLY)
        guard descriptor >= 0 else {
            logger.warning("Cannot open directory for watching: \(dirPath)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scanForTranscripts()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        directorySource = source
        source.resume()
    }

    /// Poll timer as a fallback — DispatchSource doesn't always fire for nested changes.
    private func startPollTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            self?.scanForTranscripts()
        }
        pollTimer = timer
        timer.resume()
    }

    // MARK: - Transcript Discovery

    private func scanForTranscripts() {
        let fm = FileManager.default
        let dirPath = claudeProjectPath.path
        guard fm.fileExists(atPath: dirPath) else { return }

        // Find session directories (UUIDs) and their .jsonl files
        guard let sessionDirs = try? fm.contentsOfDirectory(atPath: dirPath) else { return }

        for entry in sessionDirs {
            let entryPath = claudeProjectPath.appendingPathComponent(entry)

            // Top-level .jsonl file (the session itself)
            if entry.hasSuffix(".jsonl") {
                watchFileIfNew(entryPath, agentId: "main")
                continue
            }

            // Session directory — check for subagents/
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entryPath.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let subagentsDir = entryPath.appendingPathComponent("subagents")
            guard fm.fileExists(atPath: subagentsDir.path) else { continue }

            guard let subFiles = try? fm.contentsOfDirectory(atPath: subagentsDir.path) else { continue }
            for subFile in subFiles {
                if subFile.hasSuffix(".jsonl") {
                    let agentId = String(subFile.dropLast(6)) // remove .jsonl
                    let subPath = subagentsDir.appendingPathComponent(subFile)
                    watchFileIfNew(subPath, agentId: agentId)

                    // Try to read the meta.json for the agent name
                    let metaPath = subagentsDir.appendingPathComponent(subFile.replacingOccurrences(of: ".jsonl", with: ".meta.json"))
                    emitAgentCreatedIfNew(agentId: agentId, metaPath: metaPath)
                }
            }
        }
    }

    // MARK: - File Watching

    private func watchFileIfNew(_ url: URL, agentId: String) {
        guard watchedFiles[url] == nil else { return }

        // Start from end of file (only watch new activity)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0

        var watched = WatchedFile(offset: fileSize, fileSource: nil)

        // Attach FS event source
        let descriptor = open(url.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.extend, .write],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.readNewLines(from: url, agentId: agentId)
            }
            source.setCancelHandler {
                close(descriptor)
            }
            watched.fileSource = source
            source.resume()
        }

        watchedFiles[url] = watched

        // Emit main agent created for the primary session
        if agentId == "main" {
            emitMainAgentCreated()
        }

        logger.info("Watching transcript: \(url.lastPathComponent) as \(agentId)")
    }

    // MARK: - Reading New Lines

    private func readNewLines(from url: URL, agentId: String) {
        guard var watched = watchedFiles[url] else { return }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        handle.seek(toFileOffset: watched.offset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }

        watched.offset += UInt64(data.count)
        watchedFiles[url] = watched

        guard let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.components(separatedBy: "\n")
        for line in lines where !line.isEmpty {
            parseLine(line, agentId: agentId)
        }
    }

    // MARK: - JSONL Parsing

    private func parseLine(_ line: String, agentId: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        guard let message = json["message"] as? [String: Any],
              let role = message["role"] as? String else { return }

        if role == "assistant" {
            parseAssistantMessage(message, agentId: agentId)
        } else if role == "user" {
            parseUserMessage(message, agentId: agentId)
        }
    }

    private func parseAssistantMessage(_ message: [String: Any], agentId: String) {
        guard let content = message["content"] as? [[String: Any]] else { return }

        for block in content {
            guard let blockType = block["type"] as? String else { continue }

            if blockType == "tool_use" {
                guard let toolName = block["name"] as? String else { continue }
                // Skip internal/meta tools
                guard !toolName.hasPrefix("mcp__") && toolName != "Skill" && toolName != "ToolSearch" else { continue }

                activeTools[agentId] = toolName
                emit(.toolStart(agentId: agentId, tool: toolName))
            }
        }
    }

    private func parseUserMessage(_ message: [String: Any], agentId: String) {
        guard let content = message["content"] as? [[String: Any]] else { return }

        for block in content {
            guard let blockType = block["type"] as? String, blockType == "tool_result" else { continue }
            // A tool_result means the previous tool finished
            if activeTools[agentId] != nil {
                activeTools[agentId] = nil
                emit(.toolDone(agentId: agentId))
            }
        }
    }

    // MARK: - Agent Creation

    private func emitMainAgentCreated() {
        let palette = assignPalette(for: "main")
        emit(.created(agentId: "main", name: "Claude", palette: palette))
    }

    private func emitAgentCreatedIfNew(agentId: String, metaPath: URL) {
        guard agentPalettes[agentId] == nil else { return }

        var name = "Sub-agent"
        if let data = try? Data(contentsOf: metaPath),
           let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let desc = meta["description"] as? String {
            // Use first ~20 chars of description as name
            name = String(desc.prefix(20))
        }

        let palette = assignPalette(for: agentId)
        emit(.created(agentId: agentId, name: name, palette: palette))
    }

    private func assignPalette(for agentId: String) -> Int {
        if let existing = agentPalettes[agentId] { return existing }
        let palette = nextPalette % 6
        nextPalette += 1
        agentPalettes[agentId] = palette
        return palette
    }

    // MARK: - Emit Events

    private func emit(_ event: AgentEvent) {
        logger.debug("Agent event: \(event.type.rawValue) agent=\(event.agentId) tool=\(event.tool ?? "-")")
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
