// ABOUTME: Runs the .dockyard.json `setup` script as a background Process.
// ABOUTME: Captures a tail of stdout/stderr, exposes state for the UI to observe.

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "dockyard", category: "setup-runner")

@MainActor
final class SetupRunner: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case succeeded
        case failed(exitCode: Int32)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var logTail: String = ""

    private let workstreamID: UUID
    private var process: Process?
    private var outputBuffer = Data()
    private static let maxLogBytes = 4096

    init(workstreamID: UUID) {
        self.workstreamID = workstreamID
    }

    /// Starts the script. No-op if already running or already succeeded.
    func start(script: String, workingDirectory: String, environmentVars: [String: String] = [:], shell: String = CommandBuilder.userShell) {
        if state == .running || state == .succeeded {
            return
        }

        outputBuffer = Data()
        logTail = ""
        state = .running

        let process = Process()
        self.process = process

        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lic", script]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        var env = ProcessInfo.processInfo.environment
        for (k, v) in environmentVars {
            env[k] = v
        }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let workstreamID = self.workstreamID

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.outputBuffer.append(data)

                if self.outputBuffer.count > Self.maxLogBytes {
                    let overage = self.outputBuffer.count - Self.maxLogBytes
                    self.outputBuffer.removeFirst(overage)
                }

                self.logTail = String(decoding: self.outputBuffer, as: UTF8.self)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            let exitCode = terminatedProcess.terminationStatus
            
            if let outputPipe = terminatedProcess.standardOutput as? Pipe {
                outputPipe.fileHandleForReading.readabilityHandler = nil
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if exitCode == 0 {
                    self.state = .succeeded
                    SetupStateStore.markCompleted(for: workstreamID)
                } else {
                    self.state = .failed(exitCode: exitCode)
                }
                self.process = nil
            }
        }

        do {
            try process.run()
        } catch {
            state = .failed(exitCode: -1)
            logTail = error.localizedDescription
            self.process = nil
        }
    }

    /// Terminates the running process if any. State becomes .idle.
    func cancel() {
        guard let process = process else { return }

        if let pipe = process.standardOutput as? Pipe {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        if process.isRunning {
            process.terminate()
        }

        state = .idle
        self.process = nil
    }
}
