// ABOUTME: Tmux session naming and command wrapping for persistent sessions.
// ABOUTME: Sessions survive app restarts but not system restarts.

import Foundation

enum TmuxSession {
    /// Build a deterministic session name from project, workstream, and role.
    static func sessionName(project: String, workstream: String, role: String) -> String {
        "\(AppConstants.appID)/\(sanitize(project))/\(sanitize(workstream))/\(role)"
    }

    static var configContents: String {
        """
        # Managed by \(AppConstants.appID). Do not edit.
        # Makes tmux act as a transparent session persistence wrapper.
        set -g status off
        set -g prefix None
        unbind-key -a
        set -g mouse off
        set -g history-limit 50000
        set -g escape-time 0
        set -g allow-passthrough on
        set -g default-terminal "xterm-256color"
        set -ga terminal-overrides ',*:smcup@:rmcup@'
        set -g alternate-screen off
        set -g aggressive-resize on
        set -g window-size latest
        set -g remain-on-exit on
        set -g remain-on-exit-format ""
        """
    }

    /// Path to the minimal tmux config that makes tmux invisible.
    private static var configPath: String {
        let path = AppConstants.configDirectory.appendingPathComponent("tmux.conf")
        // Write config if missing or outdated
        let fm = FileManager.default
        try? fm.createDirectory(at: AppConstants.configDirectory, withIntermediateDirectories: true)
        if let existing = try? String(contentsOfFile: path.path, encoding: .utf8), existing == configContents {
            return path.path
        }
        try? configContents.write(toFile: path.path, atomically: true, encoding: .utf8)
        return path.path
    }

    /// Wrap a command to run inside a tmux session.
    /// Uses `new-session -A` which creates if missing, attaches if existing.
    /// Tmux is configured to be invisible: no status bar, no prefix key,
    /// mouse passthrough for scrolling.
    /// Dedicated socket name so we don't interfere with the user's tmux.
    private static let socketName = AppConstants.appID

    static func wrapCommand(tmuxPath: String, sessionName: String, command: String?, environmentVars: [String: String] = [:]) -> String {
        let escaped = shellEscape(sessionName)
        let conf = shellEscape(configPath)
        // -L uses a dedicated socket, -f uses our minimal config
        let envFlags = environmentVars.map { "-e \(shellEscape("\($0.key)=\($0.value)"))" }.joined(separator: " ")
        let base = "\(tmuxPath) -L \(socketName) -f \(conf) new-session -A -s \(escaped) \(envFlags)"
        let wrappedCommand: String
        if let command {
            let escapedCommand = shellEscape(command)
            wrappedCommand = "\(base) -- sh -c \(escapedCommand)"
        } else {
            wrappedCommand = base
        }
        return "sh -c \(shellEscape("\(serverSetupCommand(tmuxPath: tmuxPath, configPath: configPath)); exec \(wrappedCommand)"))"
    }

    /// Kill a tmux session by name.
    static func killSession(tmuxPath: String, sessionName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmuxPath)
        process.arguments = ["-L", socketName, "kill-session", "-t", sessionName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    static func sessionExists(tmuxPath: String, sessionName: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tmuxPath)
        process.arguments = ["-L", socketName, "has-session", "-t", sessionName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Kill the agent tmux session for a workstream.
    static func killWorkstreamSessions(tmuxPath: String, project: String, workstream: String) {
        let agentSession = sessionName(project: project, workstream: workstream, role: "agent")
        killSession(tmuxPath: tmuxPath, sessionName: agentSession)
    }

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private static func shellEscape(_ str: String) -> String {
        "'\(str.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func serverSetupCommand(tmuxPath: String, configPath: String) -> String {
        let socket = shellEscape(socketName)
        let conf = shellEscape(configPath)
        let startServer = "\(tmuxPath) -L \(socket) start-server >/dev/null 2>&1 || true"
        let sourceFile = "\(tmuxPath) -L \(socket) source-file \(conf) >/dev/null 2>&1 || true"
        let clearPaneDiedHook = "\(tmuxPath) -L \(socket) set-hook -gu pane-died >/dev/null 2>&1 || true"
        return "\(startServer); \(sourceFile); \(clearPaneDiedHook)"
    }
}
