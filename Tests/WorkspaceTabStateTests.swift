// ABOUTME: Tests for workspace tab restoration and custom tab reordering.
// ABOUTME: Verifies only fixed tabs are restored and custom tabs reorder deterministically.

@testable import FactoryFloor
import XCTest

final class WorkspaceTabSnapshotTests: XCTestCase {
    func testSaveAndRestore() {
        let workstreamID = UUID()
        let terminalID = derivedUUID(from: workstreamID, salt: "terminal-1")
        let browserID = derivedUUID(from: workstreamID, salt: "browser-1")
        let tabs: [WorkspaceTab] = [.info, .agent, .terminal(terminalID), .browser(browserID)]

        let snapshot = WorkspaceTabSnapshot(
            tabs: tabs,
            terminalCount: 1,
            browserCount: 1,
            activeTab: .terminal(terminalID),
            browserTitles: [browserID: "localhost"],
            terminalTitles: [terminalID: "zsh"]
        )

        XCTAssertEqual(snapshot.tabs, tabs)
        XCTAssertEqual(snapshot.terminalCount, 1)
        XCTAssertEqual(snapshot.browserCount, 1)
        XCTAssertEqual(snapshot.activeTab, .terminal(terminalID))
        XCTAssertEqual(snapshot.browserTitles[browserID], "localhost")
        XCTAssertEqual(snapshot.terminalTitles[terminalID], "zsh")
    }

    func testReconcileFiltersDeadTerminals() {
        let workstreamID = UUID()
        let liveTerminalID = derivedUUID(from: workstreamID, salt: "terminal-1")
        let deadTerminalID = derivedUUID(from: workstreamID, salt: "terminal-2")
        let browserID = derivedUUID(from: workstreamID, salt: "browser-1")

        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent, .terminal(liveTerminalID), .terminal(deadTerminalID), .browser(browserID)],
            terminalCount: 2,
            browserCount: 1,
            activeTab: .terminal(deadTerminalID),
            browserTitles: [:],
            terminalTitles: [:]
        )

        let reconciled = snapshot.reconciled(liveSurfaceIDs: [liveTerminalID])

        XCTAssertEqual(reconciled.tabs, [.info, .agent, .terminal(liveTerminalID), .browser(browserID)])
        XCTAssertEqual(reconciled.terminalCount, 2) // count preserved for ID generation
        XCTAssertEqual(reconciled.activeTab, .agent) // fell back since dead terminal was active
    }

    func testReconcilePreservesActiveTabWhenAlive() {
        let workstreamID = UUID()
        let terminalID = derivedUUID(from: workstreamID, salt: "terminal-1")

        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent, .terminal(terminalID)],
            terminalCount: 1,
            browserCount: 0,
            activeTab: .terminal(terminalID),
            browserTitles: [:],
            terminalTitles: [:]
        )

        let reconciled = snapshot.reconciled(liveSurfaceIDs: [terminalID])

        XCTAssertEqual(reconciled.tabs, [.info, .agent, .terminal(terminalID)])
        XCTAssertEqual(reconciled.activeTab, .terminal(terminalID))
    }

    func testReconcileKeepsBrowserTabsRegardlessOfSurfaces() {
        let browserID = UUID()

        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent, .browser(browserID)],
            terminalCount: 0,
            browserCount: 1,
            activeTab: .browser(browserID),
            browserTitles: [:],
            terminalTitles: [:]
        )

        // Empty live surfaces - browser should still survive
        let reconciled = snapshot.reconciled(liveSurfaceIDs: [])

        XCTAssertEqual(reconciled.tabs, [.info, .agent, .browser(browserID)])
        XCTAssertEqual(reconciled.activeTab, .browser(browserID))
    }
}

final class WorkspaceTabStateTests: XCTestCase {
    func testCustomTabsPersistAsInfo() {
        XCTAssertEqual(RestorableWorkspaceTab(activeTab: .terminal(UUID())), .info)
        XCTAssertEqual(RestorableWorkspaceTab(activeTab: .browser(UUID())), .info)
    }

    func testEnvironmentRestoresToInfoWhenUnavailable() {
        XCTAssertEqual(RestorableWorkspaceTab.environment.workspaceTab(hasEnvironmentTab: false), .info)
        XCTAssertEqual(RestorableWorkspaceTab.environment.workspaceTab(hasEnvironmentTab: true), .environment)
    }

    func testReorderedCustomTabsKeepsFixedTabsInPlace() throws {
        let terminalA = try WorkspaceTab.terminal(XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")))
        let browserB = try WorkspaceTab.browser(XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")))
        let terminalC = try WorkspaceTab.terminal(XCTUnwrap(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")))
        let tabs: [WorkspaceTab] = [.info, .agent, .environment, terminalA, browserB, terminalC]

        let reordered = reorderedCustomTabs(tabs, dragging: terminalC, to: terminalA)

        XCTAssertEqual(reordered, [.info, .agent, .environment, terminalC, terminalA, browserB])
    }
}
