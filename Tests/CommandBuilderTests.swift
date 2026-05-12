// ABOUTME: Tests for CommandBuilder shell command composition and quoting.
// ABOUTME: Validates escaping of special characters, spaces, quotes, and nested commands.

@testable import Dockyard
import XCTest

final class CommandBuilderTests: XCTestCase {
    // MARK: - Basic command building

    func testSimpleCommand() {
        var cmd = CommandBuilder("/usr/bin/claude")
        cmd.flag("--verbose")
        cmd.arg("run")
        XCTAssertEqual(cmd.command, "/usr/bin/claude --verbose run")
    }

    func testOptionWithSimpleValue() {
        var cmd = CommandBuilder("claude")
        cmd.option("--name", "my-workstream")
        XCTAssertEqual(cmd.command, "claude --name my-workstream")
    }

    func testOptionWithSpaces() {
        var cmd = CommandBuilder("claude")
        cmd.option("--name", "my workstream")
        XCTAssertEqual(cmd.command, "claude --name 'my workstream'")
    }

    // MARK: - shellQuote edge cases

    func testQuoteEmpty() {
        XCTAssertEqual(CommandBuilder.shellQuote(""), "''")
    }

    func testQuoteSimplePath() {
        XCTAssertEqual(CommandBuilder.shellQuote("/usr/local/bin/claude"), "/usr/local/bin/claude")
    }

    func testQuoteHomePath() {
        XCTAssertEqual(CommandBuilder.shellQuote("~/repos/my-app"), "~/repos/my-app")
    }

    func testQuotePathWithSpaces() {
        XCTAssertEqual(CommandBuilder.shellQuote("/Users/test/my app"), "'/Users/test/my app'")
    }

    func testQuoteSingleQuotes() {
        XCTAssertEqual(CommandBuilder.shellQuote("it's"), "'it'\\''s'")
    }

    func testQuoteDoubleQuotes() {
        XCTAssertEqual(CommandBuilder.shellQuote("say \"hello\""), "'say \"hello\"'")
    }

    func testQuoteBackticks() {
        XCTAssertEqual(CommandBuilder.shellQuote("run `cmd`"), "'run `cmd`'")
    }

    func testQuoteDollarSign() {
        XCTAssertEqual(CommandBuilder.shellQuote("$HOME/bin"), "'$HOME/bin'")
    }

    func testQuoteParentheses() {
        XCTAssertEqual(CommandBuilder.shellQuote("(echo hi)"), "'(echo hi)'")
    }

    func testQuoteSemicolon() {
        XCTAssertEqual(CommandBuilder.shellQuote("cmd1; cmd2"), "'cmd1; cmd2'")
    }

    func testQuotePipe() {
        XCTAssertEqual(CommandBuilder.shellQuote("cmd | grep"), "'cmd | grep'")
    }

    func testQuoteAtSign() {
        XCTAssertEqual(CommandBuilder.shellQuote("user@host"), "user@host")
    }

    func testQuotePlusSign() {
        XCTAssertEqual(CommandBuilder.shellQuote("c++"), "c++")
    }

    func testQuoteEquals() {
        XCTAssertEqual(CommandBuilder.shellQuote("FOO=bar"), "FOO=bar")
    }

    func testQuoteUUID() {
        XCTAssertEqual(CommandBuilder.shellQuote("a1b2c3d4-e5f6-7890-abcd-ef1234567890"), "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
    }

    func testQuoteMultipleSingleQuotes() {
        let input = "it's a 'test'"
        let result = CommandBuilder.shellQuote(input)
        XCTAssertEqual(result, "'it'\\''s a '\\''test'\\'''")
    }

    // MARK: - withFallback

    func testWithFallbackBasic() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", shell: "/bin/zsh")
        XCTAssertTrue(result.hasPrefix("/bin/zsh -lic "), "Should use interactive login shell")
        XCTAssertTrue(result.contains("exec sh -c"), "Should use sh for POSIX syntax")
        XCTAssertFalse(result.contains("2>"), "Stderr should not be redirected")
        XCTAssertTrue(result.contains("cmd1 || cmd2"), "Should have fallback with ||")
    }

    func testWithFallbackMessage() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", message: "Retrying...", shell: "/bin/zsh")
        XCTAssertTrue(result.contains("echo"), "Should contain echo for message")
        XCTAssertTrue(result.contains("Retrying..."), "Should contain user message")
        XCTAssertTrue(result.contains("cmd2"), "Should contain fallback command")
        XCTAssertTrue(result.contains("|| ("), "Should have fallback group with message")
    }

    func testWithFallbackMessageWithSpecialChars() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", message: "it's failing", shell: "/bin/zsh")
        XCTAssertTrue(result.contains("echo"), "Should contain echo")
        XCTAssertTrue(result.hasPrefix("/bin/zsh -lic "), "Should use interactive login shell")
        XCTAssertTrue(result.contains("exec sh -c"), "Should use sh for POSIX syntax")
    }

    func testWithFallbackNestedQuotes() {
        var cmd1 = CommandBuilder("claude")
        cmd1.option("--name", "my workstream")

        var cmd2 = CommandBuilder("claude")
        cmd2.option("--session-id", "abc-123")

        let result = CommandBuilder.withFallback(cmd1.command, cmd2.command, shell: "/bin/zsh")
        XCTAssertTrue(result.hasPrefix("/bin/zsh -lic '"))
        XCTAssertTrue(result.contains("exec sh -c"))
        XCTAssertTrue(result.contains("--name"))
        XCTAssertTrue(result.contains("--session-id"))
    }

    // MARK: - shellQuote forShell (Fish-safe quoting)

    func testShellQuoteForPosixShellUsesSingleQuotes() {
        let result = CommandBuilder.shellQuote("it's a test", forShell: "/bin/zsh")
        XCTAssertEqual(result, "'it'\\''s a test'")
    }

    func testShellQuoteForFishUsesDoubleQuotes() {
        let result = CommandBuilder.shellQuote("it's a test", forShell: "/opt/homebrew/bin/fish")
        XCTAssertTrue(result.hasPrefix("\""), "Fish quoting should use double quotes")
        XCTAssertTrue(result.hasSuffix("\""), "Fish quoting should use double quotes")
        XCTAssertTrue(result.contains("it's a test"), "Single quotes should pass through in double-quoted strings")
    }

    func testShellQuoteForFishEscapesDollarSign() {
        let result = CommandBuilder.shellQuote("echo $HOME", forShell: "/usr/local/bin/fish")
        XCTAssertTrue(result.contains("\\$HOME"), "Dollar signs must be escaped for Fish double quotes")
    }

    func testShellQuoteForFishEscapesBackslash() {
        let result = CommandBuilder.shellQuote("path\\to", forShell: "/opt/homebrew/bin/fish")
        XCTAssertTrue(result.contains("\\\\"), "Backslashes must be escaped for Fish double quotes")
    }

    func testShellQuoteForFishEscapesDoubleQuotes() {
        let result = CommandBuilder.shellQuote("say \"hello\"", forShell: "/opt/homebrew/bin/fish")
        XCTAssertTrue(result.contains("\\\"hello\\\""), "Double quotes must be escaped for Fish")
    }

    func testShellQuoteForFishEscapesBackticks() {
        let result = CommandBuilder.shellQuote("run `cmd`", forShell: "/opt/homebrew/bin/fish")
        XCTAssertTrue(result.contains("\\`cmd\\`"), "Backticks must be escaped for Fish")
    }

    func testShellQuoteForFishSimpleStringStaysUnquoted() {
        let result = CommandBuilder.shellQuote("/usr/bin/test", forShell: "/opt/homebrew/bin/fish")
        XCTAssertEqual(result, "/usr/bin/test", "Simple strings need no quoting even for Fish")
    }

    func testWithFallbackFish() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", shell: "/opt/homebrew/bin/fish")
        XCTAssertTrue(result.hasPrefix("/opt/homebrew/bin/fish -lic \""), "Fish withFallback should use double quotes")
        XCTAssertTrue(result.contains("exec sh -c"), "Should still use sh for POSIX syntax")
        XCTAssertTrue(result.contains("cmd1 || cmd2"))
    }

    func testResolvedUserShellPrefersExecutableEnvironmentShell() {
        let shell = CommandBuilder.resolvedUserShell(
            environment: ["SHELL": "/opt/homebrew/bin/fish"],
            isExecutable: { $0 == "/opt/homebrew/bin/fish" }
        )

        XCTAssertEqual(shell, "/opt/homebrew/bin/fish")
    }

    func testResolvedUserShellFallsBackWhenEnvironmentShellIsInvalid() {
        let shell = CommandBuilder.resolvedUserShell(
            environment: ["SHELL": "/usr/bin/zsh"],
            isExecutable: { $0 == "/bin/zsh" }
        )

        XCTAssertEqual(shell, "/bin/zsh")
    }

    func testResolvedUserShellFallsBackToBashWhenZshUnavailable() {
        let shell = CommandBuilder.resolvedUserShell(
            environment: [:],
            isExecutable: { $0 == "/bin/bash" }
        )

        XCTAssertEqual(shell, "/bin/bash")
    }

    // MARK: - Shell syntax validation (integration tests)

    // These tests invoke real shell binaries to verify generated commands parse correctly.
    // Ghostty passes commands to /bin/sh -c, so that's what we simulate here.

    private func assertShellCanParse(_ command: String, file: StaticString = #filePath, line: UInt = #line) throws {
        // Replace -lic with -nc: keeps -c (command string) but adds -n (no-execute/syntax-only)
        let syntaxCheck = command.replacingOccurrences(of: " -lic ", with: " -nc ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", syntaxCheck]
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "(no stderr)"
            XCTFail("Shell failed to parse command (exit \(process.terminationStatus)): \(errMsg)", file: file, line: line)
        }
    }

    private func fallbackCommand(shell: String) -> String {
        var cmd1 = CommandBuilder("claude")
        cmd1.option("--name", "my workstream")
        var cmd2 = CommandBuilder("claude")
        cmd2.option("--session-id", "abc-123")
        return CommandBuilder.withFallback(
            cmd1.command, cmd2.command,
            message: "it's retrying",
            shell: shell
        )
    }

    func testWithFallbackParsesInZsh() throws {
        try assertShellCanParse(fallbackCommand(shell: "/bin/zsh"))
    }

    func testWithFallbackParsesInBash() throws {
        try assertShellCanParse(fallbackCommand(shell: "/bin/bash"))
    }

    func testWithFallbackParsesInFish() throws {
        let fishPath = "/opt/homebrew/bin/fish"
        guard FileManager.default.fileExists(atPath: fishPath) else {
            throw XCTSkip("Fish not installed at \(fishPath)")
        }
        try assertShellCanParse(fallbackCommand(shell: fishPath))
    }

    // MARK: - Real-world command patterns

    func testClaudeResumeCommand() {
        var cmd = CommandBuilder("/opt/homebrew/bin/claude")
        cmd.option("--resume", "a1b2c3d4")
        cmd.option("--name", "deploy-auth-fix")
        cmd.flag("--dangerously-skip-permissions")
        XCTAssertEqual(cmd.command, "/opt/homebrew/bin/claude --resume a1b2c3d4 --name deploy-auth-fix --dangerously-skip-permissions")
    }

    func testClaudeWithSystemPrompt() {
        var cmd = CommandBuilder("claude")
        cmd.option("--append-system-prompt", "Rename the branch using `git branch -m <name>`.")
        let result = cmd.command
        XCTAssertTrue(result.contains("--append-system-prompt"))
        // Backticks and angle brackets should be quoted
        XCTAssertTrue(result.contains("'"))
    }

    func testResolvedCodingCLIPrefersStoredValue() {
        var status = ToolStatus()
        status.claude = .found("/usr/local/bin/claude")
        status.codex = .found("/usr/local/bin/codex")

        XCTAssertEqual(status.resolvedCodingCLI(storedValue: "codex"), .codex)
    }

    func testResolvedCodingCLIAutoSelectsCodexWhenClaudeMissing() {
        var status = ToolStatus()
        status.codex = .found("/usr/local/bin/codex")

        XCTAssertEqual(status.resolvedCodingCLI(storedValue: ""), .codex)
    }

    func testBuildCodexAgentCommandUsesResumeLastAndSandbox() {
        let workstreamID = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        let command = CodingCLICommandBuilder.buildAgentCommand(
            cli: .codex,
            cliPath: "/usr/local/bin/codex",
            workingDirectory: "/tmp/worktree",
            projectName: "dockyard",
            workstreamName: "switch-cli",
            workstreamID: workstreamID,
            tmuxPath: nil,
            useTmux: false,
            bypassPermissions: true,
            allowOutsideWorktree: false,
            autoRenameBranch: true,
            envVars: [:],
            supportsSessionName: false
        )

        XCTAssertEqual(
            command.intermediateCommands[0],
            "/usr/local/bin/codex resume --last -C /tmp/worktree --sandbox workspace-write --ask-for-approval never"
        )
        XCTAssertEqual(
            command.intermediateCommands[1],
            "/usr/local/bin/codex -C /tmp/worktree --sandbox workspace-write --ask-for-approval never"
        )
        XCTAssertTrue(command.finalCommand.contains("codex resume --last"))
        XCTAssertTrue(command.finalCommand.contains("Starting new session..."))
    }

    func testBuildCodexQuickActionCommandUsesExec() {
        let command = CodingCLICommandBuilder.buildQuickActionCommand(
            cli: .codex,
            cliPath: "/usr/local/bin/codex",
            prompt: "do thing",
            workingDirectory: "/tmp/worktree"
        )

        XCTAssertEqual(command.shell, CommandBuilder.userShell)
        XCTAssertEqual(
            command.arguments,
            ["-lic", "/usr/local/bin/codex exec --json --dangerously-bypass-approvals-and-sandbox -C /tmp/worktree 'do thing'"]
        )
        XCTAssertFalse(command.parseJSON)
    }
}
