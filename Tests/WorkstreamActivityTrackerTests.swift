// ABOUTME: Tests for WorkstreamActivityTracker.
// ABOUTME: Validates activity tracking, expiration, and query behavior.

@testable import FactoryFloor
import XCTest

@MainActor
final class WorkstreamActivityTrackerTests: XCTestCase {
    func testInitiallyNoActiveWorkstreams() {
        let tracker = WorkstreamActivityTracker()
        XCTAssertTrue(tracker.activeWorkstreamIDs.isEmpty)
    }

    func testIsActiveReturnsFalseForUnknownID() {
        let tracker = WorkstreamActivityTracker()
        XCTAssertFalse(tracker.isActive(UUID()))
    }

    func testBecomesActiveOnTitleChange() {
        let tracker = WorkstreamActivityTracker()
        let wsID = UUID()

        NotificationCenter.default.post(
            name: .terminalTitleChanged,
            object: wsID,
            userInfo: ["title": "working..."]
        )

        // Run the main run loop briefly to process the notification
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(tracker.isActive(wsID))
        XCTAssertTrue(tracker.activeWorkstreamIDs.contains(wsID))
    }

    func testMultipleWorkstreamsCanBeActive() {
        let tracker = WorkstreamActivityTracker()
        let ws1 = UUID()
        let ws2 = UUID()

        NotificationCenter.default.post(name: .terminalTitleChanged, object: ws1, userInfo: ["title": "a"])
        NotificationCenter.default.post(name: .terminalTitleChanged, object: ws2, userInfo: ["title": "b"])

        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertTrue(tracker.isActive(ws1))
        XCTAssertTrue(tracker.isActive(ws2))
        XCTAssertEqual(tracker.activeWorkstreamIDs.count, 2)
    }
}
