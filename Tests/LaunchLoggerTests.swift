// ABOUTME: Tests for LaunchLogger per-workstream debug log file writing.
// ABOUTME: Validates log entry serialization, gating on detailedLogging, append behavior, and cleanup.

@testable import FactoryFloor
import XCTest

final class LaunchLoggerTests: XCTestCase {
    private var testLogsDir: URL!
    private let testWorkstreamID = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!

    override func setUp() {
        super.setUp()
        testLogsDir = LaunchLogger.logsDirectoryURL
        // Ensure clean state
        try? FileManager.default.removeItem(at: testLogsDir)
        // Enable detailed logging for tests
        UserDefaults.standard.set(true, forKey: "factoryfloor.detailedLogging")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testLogsDir)
        UserDefaults.standard.removeObject(forKey: "factoryfloor.detailedLogging")
        super.tearDown()
    }

    // MARK: - Log entry encoding

    func testLogEntryRoundTrips() throws {
        let entry = LaunchLogEntry(
            workstreamID: testWorkstreamID,
            event: "agent-start",
            finalCommand: "/bin/zsh -lic 'claude --resume abc'",
            intermediateCommands: ["claude --resume abc", "tmux new-session -A -s test claude --resume abc"],
            environmentVariables: ["FF_PROJECT": "myproject"],
            workingDirectory: "/tmp/test",
            toolPaths: LaunchLogEntry.ToolPaths(claude: "/usr/local/bin/claude", tmux: "/usr/bin/tmux", ffRun: nil),
            settings: LaunchLogEntry.Settings(tmuxMode: true, bypassPermissions: false, agentTeams: false, autoRenameBranch: true, allowOutsideWorktree: false),
            shell: "/bin/zsh"
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(LaunchLogEntry.self, from: data)

        XCTAssertEqual(decoded.workstreamID, testWorkstreamID)
        XCTAssertEqual(decoded.event, "agent-start")
        XCTAssertEqual(decoded.finalCommand, entry.finalCommand)
        XCTAssertEqual(decoded.intermediateCommands, entry.intermediateCommands)
        XCTAssertEqual(decoded.environmentVariables, entry.environmentVariables)
        XCTAssertEqual(decoded.workingDirectory, "/tmp/test")
        XCTAssertEqual(decoded.toolPaths.claude, "/usr/local/bin/claude")
        XCTAssertEqual(decoded.toolPaths.tmux, "/usr/bin/tmux")
        XCTAssertNil(decoded.toolPaths.ffRun)
        XCTAssertTrue(decoded.settings.tmuxMode)
        XCTAssertFalse(decoded.settings.bypassPermissions)
        XCTAssertTrue(decoded.settings.autoRenameBranch)
        XCTAssertEqual(decoded.shell, "/bin/zsh")
    }

    func testLogEntryTimestampIsISO8601() throws {
        let entry = makeEntry(event: "agent-start")
        let data = try JSONEncoder().encode(entry)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let timestamp = try XCTUnwrap(json["timestamp"] as? String)

        // ISO 8601 format: contains date separator and time separator
        XCTAssertTrue(timestamp.contains("T"), "Timestamp should be ISO 8601 format")
        XCTAssertTrue(timestamp.contains("Z") || timestamp.contains("+") || timestamp.contains("-"),
                      "Timestamp should have timezone indicator")
    }

    // MARK: - Logging gated on setting

    func testLogWritesFileWhenEnabled() {
        let entry = makeEntry(event: "agent-start")
        LaunchLogger.log(entry)

        let logFile = LaunchLogger.logFileURL(for: testWorkstreamID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path), "Log file should exist when detailed logging is enabled")
    }

    func testLogSkipsWhenDisabled() {
        UserDefaults.standard.set(false, forKey: "factoryfloor.detailedLogging")

        let entry = makeEntry(event: "agent-start")
        LaunchLogger.log(entry)

        let logFile = LaunchLogger.logFileURL(for: testWorkstreamID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: logFile.path), "Log file should not exist when detailed logging is disabled")
    }

    // MARK: - Append behavior

    func testLogAppendsMultipleEntries() throws {
        let entry1 = makeEntry(event: "agent-start")
        let entry2 = makeEntry(event: "run-start")
        let entry3 = makeEntry(event: "setup-start")

        LaunchLogger.log(entry1)
        LaunchLogger.log(entry2)
        LaunchLogger.log(entry3)

        let logFile = LaunchLogger.logFileURL(for: testWorkstreamID)
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)

        XCTAssertEqual(lines.count, 3, "Should have 3 JSON lines")

        // Each line should be valid JSON with the correct event type
        let decoder = JSONDecoder()
        for (i, line) in lines.enumerated() {
            let data = Data(line.utf8)
            let decoded = try decoder.decode(LaunchLogEntry.self, from: data)
            let expectedEvent = ["agent-start", "run-start", "setup-start"][i]
            XCTAssertEqual(decoded.event, expectedEvent)
        }
    }

    // MARK: - Separate files per workstream

    func testSeparateFilesPerWorkstream() throws {
        let otherID = try XCTUnwrap(UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
        let entry1 = makeEntry(event: "agent-start")
        let entry2 = LaunchLogEntry(
            workstreamID: otherID,
            event: "run-start",
            finalCommand: "npm start",
            intermediateCommands: [],
            environmentVariables: [:],
            workingDirectory: "/tmp",
            toolPaths: LaunchLogEntry.ToolPaths(claude: nil, tmux: nil, ffRun: nil),
            settings: LaunchLogEntry.Settings(tmuxMode: false, bypassPermissions: false, agentTeams: false, autoRenameBranch: false, allowOutsideWorktree: false),
            shell: "/bin/zsh"
        )

        LaunchLogger.log(entry1)
        LaunchLogger.log(entry2)

        XCTAssertTrue(FileManager.default.fileExists(atPath: LaunchLogger.logFileURL(for: testWorkstreamID).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: LaunchLogger.logFileURL(for: otherID).path))

        // Clean up the other file
        try? FileManager.default.removeItem(at: LaunchLogger.logFileURL(for: otherID))
    }

    // MARK: - Cleanup

    func testRemoveLogDeletesFile() {
        let entry = makeEntry(event: "agent-start")
        LaunchLogger.log(entry)

        let logFile = LaunchLogger.logFileURL(for: testWorkstreamID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path))

        LaunchLogger.removeLog(for: testWorkstreamID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: logFile.path), "Log file should be deleted after removeLog")
    }

    func testRemoveLogNoopsForMissingFile() {
        // Should not throw or crash
        LaunchLogger.removeLog(for: testWorkstreamID)
    }

    // MARK: - Directory

    func testLogsDirectoryIsUnderCacheDirectory() {
        let logsDir = LaunchLogger.logsDirectoryURL
        let cacheDir = AppConstants.cacheDirectory
        XCTAssertTrue(logsDir.path.hasPrefix(cacheDir.path), "Logs directory should be under cache directory")
        XCTAssertTrue(logsDir.path.hasSuffix("/logs"), "Logs directory should end with /logs")
    }

    // MARK: - Helpers

    private func makeEntry(event: String) -> LaunchLogEntry {
        LaunchLogEntry(
            workstreamID: testWorkstreamID,
            event: event,
            finalCommand: "/bin/zsh -lic 'claude --resume abc'",
            intermediateCommands: ["claude --resume abc"],
            environmentVariables: ["FF_PROJECT": "test"],
            workingDirectory: "/tmp/test",
            toolPaths: LaunchLogEntry.ToolPaths(claude: "/usr/local/bin/claude", tmux: nil, ffRun: nil),
            settings: LaunchLogEntry.Settings(tmuxMode: false, bypassPermissions: false, agentTeams: false, autoRenameBranch: false, allowOutsideWorktree: false),
            shell: "/bin/zsh"
        )
    }
}
