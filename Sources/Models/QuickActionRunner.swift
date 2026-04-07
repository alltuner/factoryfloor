// ABOUTME: Spawns one-shot coding CLI subprocesses or git/gh commands for quick actions.
// ABOUTME: Uses the selected CLI for context-aware tasks like commit message and PR creation.

import Foundation
import os

private let logger = Logger(subsystem: "factoryfloor", category: "quick-action")

enum QuickAction: String, CaseIterable, Identifiable {
    case commit
    case push
    case createPR
    case abandonPR

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .commit: return NSLocalizedString("Commit", comment: "")
        case .push: return NSLocalizedString("Push", comment: "")
        case .createPR: return NSLocalizedString("Create PR", comment: "")
        case .abandonPR: return NSLocalizedString("Abandon PR", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .commit: return "checkmark.circle"
        case .push: return "arrow.up"
        case .createPR: return "arrow.triangle.pull"
        case .abandonPR: return "xmark.circle"
        }
    }

    /// Whether this action requires the selected coding CLI (vs direct git/gh command).
    var usesLLM: Bool {
        switch self {
        case .commit, .createPR: return true
        case .push, .abandonPR: return false
        }
    }

    var requiresGitHubRemote: Bool {
        switch self {
        case .createPR, .abandonPR: return true
        case .commit, .push: return false
        }
    }

    var prompt: String? {
        switch self {
        case .commit:
            return "Stage and commit all changes in the working tree with a good commit message based on the changes. Do not push."
        case .createPR:
            return "Create a pull request for the current changes. Write a clear title and description based on what we've been working on."
        case .push, .abandonPR:
            return nil
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
        codingCLI: CodingCLI,
        codingCLIPath: String?,
        ghPath: String?,
        workingDirectory: String,
        branchName: String? = nil
    ) {
        guard case .idle = state else { return }

        state = .running(action)
        dismissWork?.cancel()

        switch action {
        case .commit, .createPR:
            guard let codingCLIPath else {
                state = .idle
                return
            }
            runLLMAction(action: action, codingCLI: codingCLI, codingCLIPath: codingCLIPath, workingDirectory: workingDirectory)
        case .push:
            runPush(workingDirectory: workingDirectory)
        case .abandonPR:
            guard let ghPath, let branchName else {
                state = .idle
                return
            }
            runAbandonPR(ghPath: ghPath, branchName: branchName, workingDirectory: workingDirectory)
        }
    }

    private func runLLMAction(action: QuickAction, codingCLI: CodingCLI, codingCLIPath: String, workingDirectory: String) {
        guard let prompt = action.prompt else { return }

        let command = CodingCLICommandBuilder.buildQuickActionCommand(
            cli: codingCLI,
            cliPath: codingCLIPath,
            prompt: prompt,
            workingDirectory: workingDirectory
        )
        runShellCommand(
            action: action,
            shell: command.shell,
            arguments: command.arguments,
            workingDirectory: workingDirectory,
            parseJSON: command.parseJSON
        )
    }

    private func runPush(workingDirectory: String) {
        let dir = workingDirectory
        let actionRaw = QuickAction.push.rawValue
        let command = "git push -u origin HEAD"

        appendLog(action: .push, command: command)
        logger.info("Quick action \(actionRaw) starting in \(dir)")

        Task.detached {
            let result = GitOperations.pushCurrentBranch(at: dir)
            await MainActor.run {
                self.updateLog(output: result.output, exitCode: result.success ? 0 : 1)
                self.runningProcess = nil
                self.state = result.success ? .succeeded(.push) : .failed(.push)
                if result.success {
                    self.onSuccess?(.push)
                }
                self.scheduleDismiss()
            }
        }
    }

    private func runAbandonPR(ghPath: String, branchName: String, workingDirectory: String) {
        let command = "\(ghPath) pr close \(branchName) --comment 'Abandoned from Factory Floor'"

        appendLog(action: .abandonPR, command: command)
        logger.info("Quick action abandonPR starting in \(workingDirectory)")

        let dir = workingDirectory
        let path = ghPath
        let branch = branchName
        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["pr", "close", branch, "--comment", "Abandoned from Factory Floor"]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
            process.standardOutput = pipe
            process.standardError = pipe
            let success: Bool
            let output: String
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: data, encoding: .utf8) ?? ""
                success = process.terminationStatus == 0
            } catch {
                output = "Failed to launch: \(error.localizedDescription)"
                success = false
            }
            await MainActor.run {
                self.updateLog(output: output, exitCode: success ? 0 : 1)
                self.runningProcess = nil
                self.state = success ? .succeeded(.abandonPR) : .failed(.abandonPR)
                if success {
                    self.onSuccess?(.abandonPR)
                }
                self.scheduleDismiss()
            }
        }
    }

    private func runShellCommand(action: QuickAction, shell: String, arguments: [String], workingDirectory: String, parseJSON: Bool) {
        let fullCommand = "\(shell) \(arguments.joined(separator: " "))"
        let entryID = appendLog(action: action, command: fullCommand)
        let actionRaw = action.rawValue
        let dir = workingDirectory

        logger.info("Quick action \(actionRaw) starting in \(dir)")
        logger.info("Command: \(fullCommand)")

        Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = arguments
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
                if parseJSON {
                    success = Self.parseSuccess(output: output, exitCode: process.terminationStatus)
                } else {
                    success = process.terminationStatus == 0
                }
            } catch {
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

    @discardableResult
    private func appendLog(action: QuickAction, command: String) -> UUID {
        let entry = QuickActionLogEntry(
            timestamp: Date(),
            action: action,
            command: command,
            output: ""
        )
        log.append(entry)
        return entry.id
    }

    private func updateLog(output: String, exitCode: Int32) {
        guard let idx = log.indices.last else { return }
        log[idx].output = output
        log[idx].exitCode = exitCode
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
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
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
