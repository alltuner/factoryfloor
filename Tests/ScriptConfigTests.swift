// ABOUTME: Tests for ScriptConfig loading from multiple config file formats.
// ABOUTME: Validates priority order and parsing of factoryfloor, conductor, and superset configs.

@testable import FactoryFloor
import XCTest

final class ScriptConfigTests: XCTestCase {
    private var tmpDir: URL!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - Empty directory

    func testEmptyDirectoryReturnsEmpty() {
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertNil(config.setup)
        XCTAssertNil(config.run)
        XCTAssertNil(config.teardown)
        XCTAssertNil(config.source)
        XCTAssertFalse(config.hasAnyScript)
    }

    // MARK: - .factoryfloor.json (primary)

    func testFactoryFloorJSON() {
        writeJSON(".factoryfloor.json", ["setup": "npm install", "run": "npm start"])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.setup, "npm install")
        XCTAssertEqual(config.run, "npm start")
        XCTAssertNil(config.teardown)
        XCTAssertEqual(config.source, ".factoryfloor.json")
    }

    func testFactoryFloorTakesPriorityOverConductor() {
        writeJSON(".factoryfloor.json", ["run": "ff-run"])
        writeJSON("conductor.json", ["scripts": ["run": "conductor-run"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.run, "ff-run")
        XCTAssertEqual(config.source, ".factoryfloor.json")
    }

    func testFactoryFloorTakesPriorityOverSuperset() throws {
        writeJSON(".factoryfloor.json", ["run": "ff-run"])
        let supersetDir = tmpDir.appendingPathComponent(".superset")
        try FileManager.default.createDirectory(at: supersetDir, withIntermediateDirectories: true)
        writeJSON(".superset/config.json", ["run": ["superset-run"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.run, "ff-run")
        XCTAssertEqual(config.source, ".factoryfloor.json")
    }

    // MARK: - conductor.json (fallback)

    func testConductorJSON() {
        writeJSON("conductor.json", ["scripts": ["setup": "make build", "run": "make serve", "archive": "make clean"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.setup, "make build")
        XCTAssertEqual(config.run, "make serve")
        XCTAssertEqual(config.teardown, "make clean")
        XCTAssertEqual(config.source, "conductor.json")
    }

    func testConductorMapsArchiveToTeardown() {
        writeJSON("conductor.json", ["scripts": ["archive": "rm -rf dist"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.teardown, "rm -rf dist")
        XCTAssertNil(config.setup)
        XCTAssertNil(config.run)
    }

    func testConductorWithoutScriptsKeyReturnsEmpty() {
        writeJSON("conductor.json", ["setup": "npm install"])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertFalse(config.hasAnyScript)
    }

    func testConductorTakesPriorityOverSuperset() throws {
        writeJSON("conductor.json", ["scripts": ["run": "conductor-run"]])
        let supersetDir = tmpDir.appendingPathComponent(".superset")
        try FileManager.default.createDirectory(at: supersetDir, withIntermediateDirectories: true)
        writeJSON(".superset/config.json", ["run": ["superset-run"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.run, "conductor-run")
        XCTAssertEqual(config.source, "conductor.json")
    }

    // MARK: - .superset/config.json (fallback)

    func testSupersetJSON() throws {
        let supersetDir = tmpDir.appendingPathComponent(".superset")
        try FileManager.default.createDirectory(at: supersetDir, withIntermediateDirectories: true)
        writeJSON(".superset/config.json", ["setup": ["npm install", "cp .env.example .env"], "run": ["npm run dev"], "teardown": ["rm -rf node_modules"]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.setup, "npm install && cp .env.example .env")
        XCTAssertEqual(config.run, "npm run dev")
        XCTAssertEqual(config.teardown, "rm -rf node_modules")
        XCTAssertEqual(config.source, ".superset/config.json")
    }

    func testSupersetFiltersEmptyStrings() throws {
        let supersetDir = tmpDir.appendingPathComponent(".superset")
        try FileManager.default.createDirectory(at: supersetDir, withIntermediateDirectories: true)
        writeJSON(".superset/config.json", ["run": ["npm start", "", "  "]])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.run, "npm start")
    }

    func testSupersetAcceptsPlainStrings() throws {
        let supersetDir = tmpDir.appendingPathComponent(".superset")
        try FileManager.default.createDirectory(at: supersetDir, withIntermediateDirectories: true)
        writeJSON(".superset/config.json", ["run": "npm start"])
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertEqual(config.run, "npm start")
    }

    // MARK: - Error handling

    func testInvalidJSONReportsError() {
        let path = tmpDir.appendingPathComponent(".factoryfloor.json").path
        FileManager.default.createFile(atPath: path, contents: "not json".data(using: .utf8))
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertNotNil(config.loadError)
        XCTAssertEqual(config.source, ".factoryfloor.json")
    }

    func testInvalidConductorJSONReportsError() {
        let path = tmpDir.appendingPathComponent("conductor.json").path
        FileManager.default.createFile(atPath: path, contents: "not json".data(using: .utf8))
        let config = ScriptConfig.load(from: tmpDir.path)
        XCTAssertNotNil(config.loadError)
        XCTAssertEqual(config.source, "conductor.json")
    }

    // MARK: - Helpers

    private func writeJSON(_ name: String, _ dict: [String: Any]) {
        let path = tmpDir.appendingPathComponent(name).path
        let data = try! JSONSerialization.data(withJSONObject: dict)
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
