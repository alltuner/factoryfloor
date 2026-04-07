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
        resolvedUserShell()
    }

    static func resolvedUserShell(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> String {
        if let shell = environment["SHELL"], !shell.isEmpty, isExecutable(shell) {
            return shell
        }

        for fallback in ["/bin/zsh", "/bin/bash", "/bin/sh"] where isExecutable(fallback) {
            return fallback
        }

        return "/bin/sh"
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

enum CodingCLI: String, CaseIterable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }

    var commandName: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .claude:
            return NSLocalizedString("Claude Code", comment: "")
        case .codex:
            return NSLocalizedString("Codex", comment: "")
        }
    }

    var installURL: URL {
        switch self {
        case .claude:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!
        case .codex:
            return URL(string: "https://developers.openai.com/codex")!
        }
    }

    var missingTitle: String {
        switch self {
        case .claude:
            return NSLocalizedString("Claude Code not found", comment: "")
        case .codex:
            return NSLocalizedString("Codex not found", comment: "")
        }
    }

    var missingDescription: String {
        switch self {
        case .claude:
            return NSLocalizedString("Install Claude Code to use the Coding Agent.", comment: "")
        case .codex:
            return NSLocalizedString("Install Codex to use the Coding Agent.", comment: "")
        }
    }

    var installLabel: String {
        switch self {
        case .claude:
            return NSLocalizedString("Install Claude Code", comment: "")
        case .codex:
            return NSLocalizedString("Install Codex", comment: "")
        }
    }

    var quickActionNotInstalledMessage: String {
        switch self {
        case .claude:
            return NSLocalizedString("Claude Code is not installed.", comment: "")
        case .codex:
            return NSLocalizedString("Codex is not installed.", comment: "")
        }
    }

    var supportsAgentTeams: Bool {
        self == .claude
    }

    var supportsAutoRenameBranch: Bool {
        self == .claude
    }
}

extension ToolStatus {
    func status(for cli: CodingCLI) -> BinaryStatus {
        switch cli {
        case .claude:
            return claude
        case .codex:
            return codex
        }
    }

    func version(for cli: CodingCLI) -> String? {
        switch cli {
        case .claude:
            return claudeVersion
        case .codex:
            return codexVersion
        }
    }

    func path(for cli: CodingCLI) -> String? {
        status(for: cli).path
    }

    func supportsSessionName(for cli: CodingCLI) -> Bool {
        switch cli {
        case .claude:
            return claudeSupportsSessionName
        case .codex:
            return false
        }
    }

    func resolvedCodingCLI(storedValue: String) -> CodingCLI {
        if let selected = CodingCLI(rawValue: storedValue), !storedValue.isEmpty {
            return selected
        }
        if claude.isInstalled {
            return .claude
        }
        if codex.isInstalled {
            return .codex
        }
        return .claude
    }
}

struct AgentLaunchCommand {
    let finalCommand: String
    let intermediateCommands: [String]
}

struct CLIQuickActionCommand {
    let shell: String
    let arguments: [String]
    let command: String
    let parseJSON: Bool
}

enum CodingCLICommandBuilder {
    static func buildAgentCommand(
        cli: CodingCLI,
        cliPath: String,
        workingDirectory: String,
        projectName: String,
        workstreamName: String,
        workstreamID: UUID,
        tmuxPath: String?,
        useTmux: Bool,
        bypassPermissions: Bool,
        allowOutsideWorktree: Bool,
        autoRenameBranch: Bool,
        envVars: [String: String],
        supportsSessionName: Bool
    ) -> AgentLaunchCommand {
        let command: AgentLaunchCommand
        switch cli {
        case .claude:
            command = buildClaudeAgentCommand(
                cliPath: cliPath,
                workingDirectory: workingDirectory,
                workstreamName: workstreamName,
                workstreamID: workstreamID,
                useTmux: useTmux,
                bypassPermissions: bypassPermissions,
                allowOutsideWorktree: allowOutsideWorktree,
                autoRenameBranch: autoRenameBranch,
                supportsSessionName: supportsSessionName
            )
        case .codex:
            command = buildCodexAgentCommand(
                cliPath: cliPath,
                workingDirectory: workingDirectory,
                bypassPermissions: bypassPermissions,
                allowOutsideWorktree: allowOutsideWorktree
            )
        }

        if useTmux, let tmuxPath {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "agent")
            let wrapped = TmuxSession.wrapCommand(
                tmuxPath: tmuxPath,
                sessionName: session,
                command: command.finalCommand,
                environmentVars: envVars,
                respawnOnExit: true
            )
            return AgentLaunchCommand(
                finalCommand: wrapped,
                intermediateCommands: command.intermediateCommands + [wrapped]
            )
        }

        return command
    }

    static func buildQuickActionCommand(
        cli: CodingCLI,
        cliPath: String,
        prompt: String,
        workingDirectory: String
    ) -> CLIQuickActionCommand {
        let innerCommand: String
        let parseJSON: Bool

        switch cli {
        case .claude:
            var command = CommandBuilder(cliPath)
            command.flag("-p")
            command.arg(CommandBuilder.shellQuote(prompt))
            command.option("--output-format", "json")
            command.flag("--continue")
            command.flag("--fork-session")
            command.flag("--no-session-persistence")
            command.flag("--dangerously-skip-permissions")
            innerCommand = command.command
            parseJSON = true
        case .codex:
            var command = CommandBuilder(cliPath)
            command.arg("exec")
            command.flag("--json")
            command.flag("--dangerously-bypass-approvals-and-sandbox")
            command.option("-C", workingDirectory)
            command.arg(CommandBuilder.shellQuote(prompt))
            innerCommand = command.command
            parseJSON = false
        }

        let shell = CommandBuilder.userShell
        let arguments = ["-lic", innerCommand]
        return CLIQuickActionCommand(
            shell: shell,
            arguments: arguments,
            command: "\(shell) \(arguments.joined(separator: " "))",
            parseJSON: parseJSON
        )
    }

    private static func buildClaudeAgentCommand(
        cliPath: String,
        workingDirectory: String,
        workstreamName: String,
        workstreamID: UUID,
        useTmux: Bool,
        bypassPermissions: Bool,
        allowOutsideWorktree: Bool,
        autoRenameBranch: Bool,
        supportsSessionName: Bool
    ) -> AgentLaunchCommand {
        let sessionID = workstreamID.uuidString.lowercased()

        var systemPromptParts: [String] = []
        if !allowOutsideWorktree {
            systemPromptParts.append(SystemPrompts.restrictToWorktreePrompt(worktreePath: workingDirectory))
        }
        if autoRenameBranch {
            systemPromptParts.append(SystemPrompts.autoRenameBranchPrompt)
        }
        let combinedSystemPrompt = systemPromptParts.isEmpty ? nil : systemPromptParts.joined(separator: "\n\n")

        var resume = CommandBuilder(cliPath)
        resume.option("--resume", sessionID)
        if supportsSessionName {
            resume.option("--name", workstreamName)
        }
        if useTmux {
            resume.flag("--teammate-mode")
            resume.arg("tmux")
        }
        if bypassPermissions {
            resume.flag("--dangerously-skip-permissions")
        }
        if let combinedSystemPrompt {
            resume.option("--append-system-prompt", combinedSystemPrompt)
        }

        var fresh = CommandBuilder(cliPath)
        fresh.option("--session-id", sessionID)
        if supportsSessionName {
            fresh.option("--name", workstreamName)
        }
        if useTmux {
            fresh.flag("--teammate-mode")
            fresh.arg("tmux")
        }
        if bypassPermissions {
            fresh.flag("--dangerously-skip-permissions")
        }
        if let combinedSystemPrompt {
            fresh.option("--append-system-prompt", combinedSystemPrompt)
        }

        let finalCommand = CommandBuilder.withFallback(
            resume.command,
            fresh.command,
            message: "Starting new session..."
        )
        return AgentLaunchCommand(
            finalCommand: finalCommand,
            intermediateCommands: [resume.command, fresh.command, finalCommand]
        )
    }

    private static func buildCodexAgentCommand(
        cliPath: String,
        workingDirectory: String,
        bypassPermissions: Bool,
        allowOutsideWorktree: Bool
    ) -> AgentLaunchCommand {
        var resume = CommandBuilder(cliPath)
        resume.arg("resume")
        resume.flag("--last")
        applyCodexInteractiveOptions(
            to: &resume,
            workingDirectory: workingDirectory,
            bypassPermissions: bypassPermissions,
            allowOutsideWorktree: allowOutsideWorktree
        )

        var fresh = CommandBuilder(cliPath)
        applyCodexInteractiveOptions(
            to: &fresh,
            workingDirectory: workingDirectory,
            bypassPermissions: bypassPermissions,
            allowOutsideWorktree: allowOutsideWorktree
        )

        let finalCommand = CommandBuilder.withFallback(
            resume.command,
            fresh.command,
            message: "Starting new session..."
        )
        return AgentLaunchCommand(
            finalCommand: finalCommand,
            intermediateCommands: [resume.command, fresh.command, finalCommand]
        )
    }

    private static func applyCodexInteractiveOptions(
        to command: inout CommandBuilder,
        workingDirectory: String,
        bypassPermissions: Bool,
        allowOutsideWorktree: Bool
    ) {
        command.option("-C", workingDirectory)
        command.option("--sandbox", allowOutsideWorktree ? "danger-full-access" : "workspace-write")
        command.option("--ask-for-approval", bypassPermissions ? "never" : "on-request")
    }
}
