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
    static func withFallback(_ primary: String, _ fallback: String, message: String? = nil, shell: String = userShell) -> String {
        let fallbackCmd: String
        if let message {
            let escapedMessage = shellQuote(message)
            fallbackCmd = "(echo \(escapedMessage); \(fallback))"
        } else {
            fallbackCmd = fallback
        }
        let posixCmd = "\(primary) || \(fallbackCmd)"
        let shArgQuote = isFish(shell) ? fishQuote(posixCmd) : shellQuote(posixCmd)
        let shCmd = "exec sh -c \(shArgQuote)"
        return "\(shell) -lic \(shellQuote(shCmd, forShell: shell))"
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

    /// Quote a string for the given shell. Fish 4.0 can't parse POSIX '\'' escaping,
    /// so we use double quotes when Fish is the outer shell.
    static func shellQuote(_ s: String, forShell shell: String) -> String {
        let simple = !s.isEmpty && s.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == "/" || $0 == ":" || $0 == "~" || $0 == "@" || $0 == "+" || $0 == "="
        }
        if simple { return s }
        if isFish(shell) {
            return fishQuote(s)
        }
        return shellQuote(s)
    }

    static func isFish(_ shell: String) -> Bool {
        shell.hasSuffix("/fish") || shell == "fish"
    }

    private static func fishQuote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
        return "\"\(escaped)\""
    }
}
