// ABOUTME: Tests for CommandBuilder shell command composition and quoting.
// ABOUTME: Validates escaping of special characters, spaces, quotes, and nested commands.

@testable import FactoryFloor
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
        XCTAssertEqual(result, "/bin/zsh -lc 'exec sh -c '\\''cmd1 2>/dev/null || cmd2'\\'''")
    }

    func testWithFallbackMessage() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", message: "Retrying...", shell: "/bin/zsh")
        XCTAssertEqual(result, "/bin/zsh -lc 'exec sh -c '\\''cmd1 2>/dev/null || (echo Retrying... && cmd2)'\\'''")
    }

    func testWithFallbackMessageWithSpecialChars() {
        let result = CommandBuilder.withFallback("cmd1", "cmd2", message: "it's failing", shell: "/bin/zsh")
        XCTAssertTrue(result.contains("echo"), "Should contain echo")
        XCTAssertTrue(result.hasPrefix("/bin/zsh -lc "), "Should use login shell")
        XCTAssertTrue(result.contains("exec sh -c"), "Should use sh for POSIX syntax")
    }

    func testWithFallbackNestedQuotes() {
        var cmd1 = CommandBuilder("claude")
        cmd1.option("--name", "my workstream")

        var cmd2 = CommandBuilder("claude")
        cmd2.option("--session-id", "abc-123")

        let result = CommandBuilder.withFallback(cmd1.command, cmd2.command, shell: "/bin/zsh")
        XCTAssertTrue(result.hasPrefix("/bin/zsh -lc '"))
        XCTAssertTrue(result.contains("exec sh -c"))
        XCTAssertTrue(result.contains("--name"))
        XCTAssertTrue(result.contains("--session-id"))
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
}
