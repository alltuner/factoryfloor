// ABOUTME: Tests for environment tab session restoration decisions.
// ABOUTME: Verifies run panes reappear when tmux already has a persisted run session.

import XCTest
@testable import FactoryFloor

final class EnvironmentTabViewTests: XCTestCase {
    func testRunSessionRestoresOnlyWhenTmuxSessionExists() {
        XCTAssertTrue(shouldRestoreRunSession(useTmux: true, hasRunScript: true, hasExistingRunSession: true))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: false, hasRunScript: true, hasExistingRunSession: true))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: true, hasRunScript: false, hasExistingRunSession: true))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: true, hasRunScript: true, hasExistingRunSession: false))
    }

    func testSetupScriptAppendsCompletionMessage() {
        let command = scriptCommand(script: "./.hooks/factoryfloor-setup.sh", role: "setup")

        XCTAssertTrue(command.contains("./.hooks/factoryfloor-setup.sh"))
        XCTAssertTrue(command.contains("Setup completed in this terminal."))
    }

    func testRunScriptDoesNotAppendCompletionMessage() {
        let command = scriptCommand(script: "just local", role: "run")

        XCTAssertEqual(command, "just local")
    }
}
