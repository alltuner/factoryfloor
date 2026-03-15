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

    /// Wrap two commands in a fallback: `sh -c "cmd1 2>/dev/null || cmd2"`
    static func withFallback(_ primary: String, _ fallback: String, message: String? = nil) -> String {
        let fallbackCmd = message != nil
            ? "(echo '\(message!)' && \(fallback))"
            : fallback
        return "sh -c \(Self.shellQuote("\(primary) 2>/dev/null || \(fallbackCmd)"))"
    }

    private static func shellQuote(_ s: String) -> String {
        // If it's simple (no spaces, quotes, special chars), don't quote
        let simple = s.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == "/" || $0 == ":" }
        if simple && !s.isEmpty { return s }
        return "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private func shellQuote(_ s: String) -> String {
    "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
}
