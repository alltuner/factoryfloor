// ABOUTME: Builds shell command strings with proper escaping.
// ABOUTME: Replaces ad-hoc string concatenation for claude/tmux commands.

import Foundation

struct CommandBuilder {
    private var parts: [String] = []

    init(_ executable: String) {
        parts.append(executable)
    }

    mutating func arg(_ value: String) {
        parts.append(value)
    }

    mutating func flag(_ name: String) {
        parts.append(name)
    }

    mutating func option(_ name: String, _ value: String) {
        parts.append(name)
        parts.append(Self.shellQuote(value))
    }

    var command: String {
        parts.joined(separator: " ")
    }

    /// Wrap two commands in a fallback using the user's login shell for proper PATH.
    /// Uses two layers: the login shell loads profiles, then exec's sh for POSIX syntax.
    /// This is shell-agnostic (works with zsh, bash, fish) because only sh sees POSIX operators.
    ///
    /// Stderr from the primary command is captured to a temp file. If the fallback fires,
    /// a diagnostic line is printed so the user knows what happened.
    static func withFallback(_ primary: String, _ fallback: String, message: String? = nil, shell: String = userShell) -> String {
        let stderrFile = stderrTempPath
        let fallbackCmd: String
        let diagnostic = "echo '[Factory Floor] Primary command failed. Stderr: '\(stderrFile)"
        if let message {
            let escapedMessage = shellQuote(message)
            fallbackCmd = "(\(diagnostic); echo \(escapedMessage); \(fallback))"
        } else {
            fallbackCmd = "(\(diagnostic); \(fallback))"
        }
        let posixCmd = "\(primary) 2>\(stderrFile) || \(fallbackCmd)"
        let shCmd = "exec sh -c \(shellQuote(posixCmd))"
        return "\(shell) -lic \(shellQuote(shCmd))"
    }

    /// Path for capturing stderr from primary commands in fallback pipelines.
    private static var stderrTempPath: String {
        let dir = AppConstants.cacheDirectory.appendingPathComponent("stderr")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "ff-fallback-\(ProcessInfo.processInfo.processIdentifier).log"
        return dir.appendingPathComponent(name).path
    }

    static var userShell: String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }

    static func shellQuote(_ s: String) -> String {
        let simple = !s.isEmpty && s.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == "/" || $0 == ":" || $0 == "~" || $0 == "@" || $0 == "+" || $0 == "="
        }
        if simple { return s }
        return "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
