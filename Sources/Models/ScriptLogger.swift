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

    /// Wraps a command with `script -a -q` to append raw terminal output to a log file.
    /// A header with the role and timestamp is written before the command runs.
    /// The pseudo-TTY preserves colors and formatting in both the terminal and the log.
    static func wrapCommand(_ command: String, logPath: String, role: String) -> String {
        let quotedLog = CommandBuilder.shellQuote(logPath)
        let quotedCommand = CommandBuilder.shellQuote(command)
        let header = "printf '\\n--- %s %s ---\\n' \(CommandBuilder.shellQuote(role)) \"$(date '+%Y-%m-%d %H:%M:%S')\" >> \(quotedLog)"
        return "\(header) && script -a -q \(quotedLog) sh -c \(quotedCommand)"
    }

    /// Appends a header and process output to the log file for the given role.
    /// Returns the FileHandle for the caller to assign to process stdout/stderr.
    static func openLogForAppend(workstreamID: UUID, role: String) -> FileHandle? {
        let logURL = logPath(workstreamID: workstreamID, role: role)
        let fm = FileManager.default
        if !fm.fileExists(atPath: logURL.path) {
            fm.createFile(atPath: logURL.path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: logURL.path) else { return nil }
        handle.seekToEndOfFile()
        let header = "\n--- \(role) \(ISO8601DateFormatter().string(from: Date())) ---\n"
        if let data = header.data(using: .utf8) {
            handle.write(data)
        }
        return handle
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
