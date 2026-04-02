// ABOUTME: Spawns one-shot claude -p subprocesses for quick actions.
// ABOUTME: Forks from the active session for context-aware tasks like PR creation.

import Foundation
import os

private let logger = Logger(subsystem: "factoryfloor", category: "quick-action")

enum QuickAction: String, CaseIterable, Identifiable {
    case createPR
    case commitAndPush

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .createPR: return NSLocalizedString("Create PR", comment: "")
        case .commitAndPush: return NSLocalizedString("Commit & Push", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .createPR: return "arrow.triangle.pull"
        case .commitAndPush: return "arrow.up.circle"
        }
    }

    var requiresGitHubRemote: Bool {
        switch self {
        case .createPR: return true
        case .commitAndPush: return false
        }
    }

    var prompt: String {
        switch self {
        case .createPR:
            return "Create a pull request for the current changes. Write a clear title and description based on what we've been working on."
        case .commitAndPush:
            return "Commit all current changes with a good commit message based on what we've been working on, then push to the remote."
        }
    }
}

enum QuickActionState: Equatable {
    case idle
    case running(QuickAction)
    case succeeded(QuickAction)
    case failed(QuickAction)
}

struct QuickActionLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let action: QuickAction
    let command: String
    var output: String
    var exitCode: Int32?
}

@MainActor
final class QuickActionRunner: ObservableObject {
    @Published var state: QuickActionState = .idle
    @Published var log: [QuickActionLogEntry] = []
    var onSuccess: ((QuickAction) -> Void)?
    private var runningProcess: Process?
    private var dismissWork: DispatchWorkItem?

    func run(
        action: QuickAction,
        claudePath: String,
        workingDirectory: String
    ) {
        guard case .idle = state else { return }

        state = .running(action)
        dismissWork?.cancel()

        var args: [String] = []
        args.append(claudePath)
        args.append("-p")
        args.append(CommandBuilder.shellQuote(action.prompt))
        args.append("--output-format")
        args.append("json")
        args.append("--continue")
        args.append("--fork-session")
        args.append("--no-session-persistence")
        args.append("--dangerously-skip-permissions")

        let innerCommand = args.joined(separator: " ")
        let shell = CommandBuilder.userShell
        let dir = workingDirectory
        let actionRaw = action.rawValue
        let fullCommand = "\(shell) -lic \(innerCommand)"

        let entry = QuickActionLogEntry(
            timestamp: Date(),
            action: action,
            command: fullCommand,
            output: ""
        )
        log.append(entry)
        let entryID = entry.id

        logger.info("Quick action \(actionRaw) starting in \(dir)")
        logger.info("Command: \(fullCommand)")

        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-lic", innerCommand]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
            process.standardOutput = pipe
            process.standardError = pipe

            let success: Bool
            let output: String
            do {
                try process.run()
                await MainActor.run { self.runningProcess = process }
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: data, encoding: .utf8) ?? ""
                success = Self.parseSuccess(output: output, exitCode: process.terminationStatus)
                if success {
                    logger.info("Quick action \(actionRaw) succeeded")
                } else {
                    logger.error("Quick action \(actionRaw) failed (status \(process.terminationStatus)): \(output)")
                }
            } catch {
                logger.error("Quick action \(actionRaw) failed to launch: \(error)")
                output = "Failed to launch: \(error.localizedDescription)"
                success = false
            }

            let exitCode = process.terminationStatus
            await MainActor.run {
                if let idx = self.log.firstIndex(where: { $0.id == entryID }) {
                    self.log[idx].output = output
                    self.log[idx].exitCode = exitCode
                }
                self.runningProcess = nil
                self.state = success ? .succeeded(action) : .failed(action)
                if success {
                    self.onSuccess?(action)
                }
                self.scheduleDismiss()
            }
        }
    }

    func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
        state = .idle
    }

    func clearLog() {
        log.removeAll()
    }

    private nonisolated static func parseSuccess(output: String, exitCode: Int32) -> Bool {
        guard exitCode == 0 else { return false }
        // Parse the JSON output from claude --output-format json
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // If we can't parse JSON, fall back to exit code
            return true
        }
        let isError = json["is_error"] as? Bool ?? false
        return !isError
    }

    private func scheduleDismiss() {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.state = .idle
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
}
