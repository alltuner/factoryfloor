// ABOUTME: Shared shell command runner used by worktree setup paths.
// ABOUTME: Provides a Sendable-compatible static method to run arbitrary shell commands in a directory.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.shell")

enum ShellCommand {
    /// Run a shell command in a given directory, returning true on success.
    ///
    /// Uses `zsh` if available, falling back to `bash`. Standard output is
    /// discarded; standard error is logged on failure.
    static func run(_ command: String, in directory: String) -> Bool {
        guard let shellPath = CommandLineTools.path(for: "zsh")
            ?? CommandLineTools.path(for: "bash")
        else {
            logger.warning("No shell found for post-setup command")
            return false
        }

        let process = Process()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                logger.warning("Post-setup command '\(command, privacy: .public)' failed: \(errStr, privacy: .public)")
                return false
            }
            return true
        } catch {
            logger.warning("Failed to run post-setup command '\(command, privacy: .public)': \(error, privacy: .public)")
            return false
        }
    }
}
