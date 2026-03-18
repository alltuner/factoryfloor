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
            environmentVars: ["FF_PROJECT": "My Project"]
        )

        // The value must be double-quoted so the shell keeps it as one token
        XCTAssertTrue(command.contains("-e \"FF_PROJECT=My Project\""))
    }

    func testWrapCommandQuotesEnvVarValuesWithSpecialChars() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "proj/ws/agent",
            command: "echo hello",
            environmentVars: ["FF_PROJECT": "client's \"best\" $project"]
        )

        // Single quotes, double quotes, and dollar signs must survive
        XCTAssertTrue(command.contains("-e \"FF_PROJECT=client's \\\"best\\\" \\$project\""))
    }

    func testWrapCommandClearsStalePaneDiedHookBeforeAttaching() {
        let command = TmuxSession.wrapCommand(
            tmuxPath: "/opt/homebrew/bin/tmux",
            sessionName: "project/workstream/setup",
            command: "bun run build"
        )

        XCTAssertTrue(command.contains("start-server"))
        XCTAssertTrue(command.contains("source-file"))
        XCTAssertTrue(command.contains("set-hook -gu pane-died"))
        XCTAssertTrue(command.contains("new-session -A -s"))
        XCTAssertTrue(command.contains("-- sh -c"))
        XCTAssertTrue(command.contains("bun run build"))
    }
}
