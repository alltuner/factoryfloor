// ABOUTME: Tests for tmux session configuration and command composition.
// ABOUTME: Verifies the generated config preserves finished panes instead of respawning them.

import XCTest
@testable import FactoryFloor

final class TmuxSessionTests: XCTestCase {
    func testConfigDoesNotRespawnDeadPanes() {
        XCTAssertFalse(TmuxSession.configContents.contains("pane-died"))
        XCTAssertFalse(TmuxSession.configContents.contains("respawn-pane"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit on"))
        XCTAssertTrue(TmuxSession.configContents.contains("set -g remain-on-exit-format \"\""))
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
