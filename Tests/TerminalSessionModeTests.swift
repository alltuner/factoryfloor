// ABOUTME: Tests for startup terminal mode resolution.
// ABOUTME: Verifies tmux-enabled sessions wait for tool detection before launching terminals.

import XCTest
@testable import FactoryFloor

final class TerminalSessionModeTests: XCTestCase {
    func testTmuxModeWaitsForToolDetection() {
        let mode = TerminalSessionMode.resolve(
            tmuxModeEnabled: true,
            isDetectingTools: true,
            tmuxInstalled: false
        )

        XCTAssertEqual(mode, .waitingForTools)
    }

    func testTmuxModeUsesTmuxAfterDetection() {
        let mode = TerminalSessionMode.resolve(
            tmuxModeEnabled: true,
            isDetectingTools: false,
            tmuxInstalled: true
        )

        XCTAssertEqual(mode, .tmux)
    }

    func testStandardModeWhenTmuxDisabled() {
        let mode = TerminalSessionMode.resolve(
            tmuxModeEnabled: false,
            isDetectingTools: true,
            tmuxInstalled: true
        )

        XCTAssertEqual(mode, .standard)
    }
}
