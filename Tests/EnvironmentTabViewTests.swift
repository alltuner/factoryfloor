// ABOUTME: Tests for environment tab session restoration decisions.
// ABOUTME: Verifies run panes reappear when tmux already has a persisted run session.

@testable import FactoryFloor
import XCTest

final class EnvironmentTabViewTests: XCTestCase {
    func testRunSessionRestoresOnlyWhenTmuxSessionExists() {
        XCTAssertTrue(shouldRestoreRunSession(useTmux: true, hasRunScript: true, hasExistingRunSession: true, wasStoppedManually: false))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: false, hasRunScript: true, hasExistingRunSession: true, wasStoppedManually: false))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: true, hasRunScript: false, hasExistingRunSession: true, wasStoppedManually: false))
        XCTAssertFalse(shouldRestoreRunSession(useTmux: true, hasRunScript: true, hasExistingRunSession: false, wasStoppedManually: false))
    }

    func testRunSessionDoesNotRestoreAfterManualStop() {
        XCTAssertFalse(shouldRestoreRunSession(useTmux: true, hasRunScript: true, hasExistingRunSession: true, wasStoppedManually: true))
    }

    func testSetupScriptAppendsCompletionMessage() {
        let command = scriptCommand(script: "./.hooks/factoryfloor-setup.sh", role: "setup", shell: "/bin/zsh")

        XCTAssertTrue(command.contains("./.hooks/factoryfloor-setup.sh"))
        XCTAssertTrue(command.contains("Setup completed in this terminal."))
    }

    func testRunScriptDoesNotAppendCompletionMessage() {
        let command = scriptCommand(script: "just local", role: "run", shell: "/bin/zsh")

        XCTAssertFalse(command.contains("Setup completed"))
    }

    func testSetupScriptWrapsInLoginShell() {
        let command = scriptCommand(script: "setup.sh", role: "setup", shell: "/bin/zsh")

        XCTAssertTrue(command.hasPrefix("/bin/zsh -lic "))
    }

    func testRunScriptWrapsInLoginShell() {
        let command = scriptCommand(script: "just local", role: "run", shell: "/bin/zsh")

        XCTAssertTrue(command.hasPrefix("/bin/zsh -lic "))
        XCTAssertTrue(command.contains("just local"))
    }

    func testRunScriptCommandUsesLoginShell() {
        let command = runScriptCommand(script: "bun dev", workstreamID: UUID(), launcherPath: "/path/to/ff-run", shell: "/bin/zsh")

        XCTAssertTrue(command.contains("/bin/zsh -lic"))
        XCTAssertFalse(command.contains("/bin/sh"))
    }
}
