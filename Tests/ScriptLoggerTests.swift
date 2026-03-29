// ABOUTME: Tests for file-based script logging utility.
// ABOUTME: Verifies log path construction, command wrapping, and directory management.

@testable import FactoryFloor
import XCTest

final class ScriptLoggerTests: XCTestCase {
    func testLogDirectoryIsUnderCacheDirectory() {
        let logDir = ScriptLogger.logDirectory
        XCTAssertTrue(logDir.path.contains("factoryfloor"))
        XCTAssertTrue(logDir.path.hasSuffix("/logs"))
    }

    func testLogPathIncludesWorkstreamIDAndRole() throws {
        let id = try XCTUnwrap(UUID(uuidString: "12345678-1234-1234-1234-123456789ABC"))
        let path = ScriptLogger.logPath(workstreamID: id, role: "setup")

        XCTAssertTrue(path.lastPathComponent == "12345678-1234-1234-1234-123456789abc-setup.log")
        XCTAssertTrue(path.path.contains("/logs/"))
    }

    func testLogPathForTeardown() throws {
        let id = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let path = ScriptLogger.logPath(workstreamID: id, role: "teardown")

        XCTAssertEqual(path.lastPathComponent, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee-teardown.log")
    }

    func testWrapCommandUsesScriptForRawCapture() {
        let wrapped = ScriptLogger.wrapCommand("npm run dev", logPath: "/tmp/test.log", role: "run")

        XCTAssertTrue(wrapped.contains("script -a -q"))
        XCTAssertTrue(wrapped.contains("/tmp/test.log"))
        XCTAssertTrue(wrapped.contains("npm run dev"))
    }

    func testWrapCommandWritesHeaderBeforeScript() {
        let wrapped = ScriptLogger.wrapCommand("echo hello", logPath: "/tmp/test.log", role: "setup")

        XCTAssertTrue(wrapped.contains("printf"))
        XCTAssertTrue(wrapped.contains("setup"))
        XCTAssertTrue(wrapped.contains(">> /tmp/test.log"))
    }

    func testWrapCommandPassesOriginalToShell() {
        let wrapped = ScriptLogger.wrapCommand("echo hello", logPath: "/tmp/test.log", role: "run")

        XCTAssertTrue(wrapped.contains("sh -c"))
        XCTAssertTrue(wrapped.contains("echo hello"))
    }

    func testWrapCommandQuotesLogPathWithSpaces() {
        let wrapped = ScriptLogger.wrapCommand("echo hi", logPath: "/tmp/my logs/test.log", role: "run")

        XCTAssertTrue(wrapped.contains("'/tmp/my logs/test.log'"))
    }

    func testEnsureDirectoryCreatesLogDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scriptlogger-test-\(UUID().uuidString)")
            .appendingPathComponent("logs")

        defer { try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent()) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))

        try ScriptLogger.ensureLogDirectory(at: tempDir)

        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testIsEnabledReadsSetting() {
        let defaults = UserDefaults.standard
        let key = "factoryfloor.detailedLogging"

        defaults.set(false, forKey: key)
        XCTAssertFalse(ScriptLogger.isEnabled)

        defaults.set(true, forKey: key)
        XCTAssertTrue(ScriptLogger.isEnabled)

        // Clean up - restore default (off)
        defaults.removeObject(forKey: key)
    }

    func testIsEnabledDefaultsToFalse() {
        let defaults = UserDefaults.standard
        let key = "factoryfloor.detailedLogging"
        defaults.removeObject(forKey: key)

        XCTAssertFalse(ScriptLogger.isEnabled)
    }
}
