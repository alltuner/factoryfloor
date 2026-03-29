// ABOUTME: File-based logging for setup, run, and teardown script output.
// ABOUTME: Wraps commands with `script -q` to capture raw terminal output when enabled.

import Foundation

enum ScriptLogger {
    private static let settingsKey = "factoryfloor.detailedLogging"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: settingsKey)
    }

    static var logDirectory: URL {
        AppConstants.cacheDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    static func logPath(workstreamID: UUID, role: String) -> URL {
        let filename = "\(workstreamID.uuidString.lowercased())-\(role).log"
        return logDirectory.appendingPathComponent(filename)
    }

    /// Wraps a command with `script -q` to capture raw terminal output to a log file.
    /// The pseudo-TTY preserves colors and formatting in both the terminal and the log.
    static func wrapCommand(_ command: String, logPath: String) -> String {
        let quotedLog = CommandBuilder.shellQuote(logPath)
        let quotedCommand = CommandBuilder.shellQuote(command)
        return "script -q \(quotedLog) sh -c \(quotedCommand)"
    }

    static func ensureLogDirectory(at directory: URL? = nil) throws {
        let dir = directory ?? logDirectory
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}
