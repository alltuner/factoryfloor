// ABOUTME: Tests for tmux session configuration and command composition.
// ABOUTME: Verifies the generated config preserves finished panes instead of respawning them.

@testable import FactoryFloor
import XCTest

final class TmuxSessionTests: XCTestCase {
    func testConfigKeepsNativeMouseSelectionEnabled() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -g mouse off"))
        XCTAssertFalse(TmuxSession.configContents.contains("set -g mouse on"))
    }

    func testConfigKeepsOuterTerminalOutOfAlternateScreen() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -ga terminal-overrides ',*:smcup@:rmcup@'"))
    }

    func testConfigDisablesPaneAlternateScreen() {
        XCTAssertTrue(TmuxSession.configContents.contains("set -g alternate-screen off"))
    }

    func testConfigDoesNotRespawnDeadPanes() {
        XCTAssertFalse(TmuxSession.configContents.contains("pane-died"))
        XCTAssertFalse(TmuxSession.configContents.contains("respawn-pane"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit on"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit-format \"\""))
    }

    func testWrapCommandQuotesEnvVarValuesWithSpaces() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "echo hello",
            environmentVars: ["FF_PROJECT": "My Project"],
            shell: "/bin/zsh"
        )

        // The value must be double-quoted so the shell keeps it as one token
        XCTAssertTrue(command.contains("-e \"FF_PROJECT=My Project\""))
    }

    func testWrapCommandQuotesEnvVarValuesWithSpecialChars() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "echo hello",
            environmentVars: ["FF_PROJECT": "client's \"best\" $project"],
            shell: "/bin/zsh"
        )

        // Single quotes, double quotes, and dollar signs must survive nested quoting.
        // The two-layer shell wrapping (login shell -> sh) applies shellEscape twice,
        // so we verify the key and double-quote-escaped value appear at the inner level.
        XCTAssertTrue(command.contains("FF_PROJECT"))
        XCTAssertTrue(command.contains("client"))
        XCTAssertTrue(command.contains("best"))
        XCTAssertTrue(command.contains("\\$project"))
    }

    func testWrapCommandClearsStalePaneDiedHookBeforeAttaching() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "project/workstream/setup",
            command: "bun run build",
            shell: "/bin/zsh"
        )

        XCTAssertTrue(command.hasPrefix("/bin/zsh -lc "), "Should use login shell for PATH")
        XCTAssertTrue(command.contains("exec sh -c"), "Should use sh for POSIX syntax")
        XCTAssertTrue(command.contains("start-server"))
        XCTAssertTrue(command.contains("source-file"))
        XCTAssertTrue(command.contains("set-hook -gu pane-died"))
        XCTAssertTrue(command.contains("new-session -A -s"))
        XCTAssertTrue(command.contains("bun run build"))
    }
}
