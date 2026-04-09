// ABOUTME: Tests for workspace tab restoration and custom tab reordering.
// ABOUTME: Verifies only fixed tabs are restored and custom tabs reorder deterministically.

import AppKit
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
            editorCount: 0,
            activeTab: .terminal(terminalID),
            browserTitles: [browserID: "localhost"],
            terminalTitles: [terminalID: "zsh"],
            editorFilePaths: [:],
            runStarted: false,
            runStoppedManually: false
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
            editorCount: 0,
            activeTab: .terminal(deadTerminalID),
            browserTitles: [:],
            terminalTitles: [:],
            editorFilePaths: [:],
            runStarted: false,
            runStoppedManually: false
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
            editorCount: 0,
            activeTab: .terminal(terminalID),
            browserTitles: [:],
            terminalTitles: [:],
            editorFilePaths: [:],
            runStarted: false,
            runStoppedManually: false
        )

        let reconciled = snapshot.reconciled(liveSurfaceIDs: [terminalID])

        XCTAssertEqual(reconciled.tabs, [.info, .agent, .terminal(terminalID)])
        XCTAssertEqual(reconciled.activeTab, .terminal(terminalID))
    }

    func testReconciledPreservesRunState() {
        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent],
            terminalCount: 0,
            browserCount: 0,
            editorCount: 0,
            activeTab: .agent,
            browserTitles: [:],
            terminalTitles: [:],
            editorFilePaths: [:],
            runStarted: true,
            runStoppedManually: false
        )

        let reconciled = snapshot.reconciled(liveSurfaceIDs: [])

        XCTAssertTrue(reconciled.runStarted)
        XCTAssertFalse(reconciled.runStoppedManually)
    }

    func testReconcileKeepsBrowserTabsRegardlessOfSurfaces() {
        let browserID = UUID()

        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent, .browser(browserID)],
            terminalCount: 0,
            browserCount: 1,
            editorCount: 0,
            activeTab: .browser(browserID),
            browserTitles: [:],
            terminalTitles: [:],
            editorFilePaths: [:],
            runStarted: false,
            runStoppedManually: false
        )

        // Empty live surfaces - browser should still survive
        let reconciled = snapshot.reconciled(liveSurfaceIDs: [])

        XCTAssertEqual(reconciled.tabs, [.info, .agent, .browser(browserID)])
        XCTAssertEqual(reconciled.activeTab, .browser(browserID))
    }

    func testStartupStatePreservesRestoredSnapshot() {
        let snapshot = WorkspaceTabSnapshot(
            tabs: [.info, .agent],
            terminalCount: 0,
            browserCount: 0,
            editorCount: 0,
            activeTab: .agent,
            browserTitles: [:],
            terminalTitles: [:],
            editorFilePaths: [:],
            runStarted: true,
            runStoppedManually: false
        )

        let state = startupWorkspaceTabState(
            snapshot: snapshot,
            savedTab: nil
        )

        XCTAssertEqual(state.tabs, [.info, .agent])
        XCTAssertEqual(state.activeTab, .agent)
        XCTAssertTrue(state.runStarted)
    }

    func testStartupStateUsesSavedFixedTabWithoutSnapshot() {
        let state = startupWorkspaceTabState(
            snapshot: nil,
            savedTab: .agent
        )

        XCTAssertEqual(state.tabs, [.info, .agent])
        XCTAssertEqual(state.activeTab, .agent)
    }

    func testWorkspaceEnvironmentUsesSuppliedDefaultBranch() throws {
        let workstreamID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))

        let vars = workspaceEnvironmentVariables(
            workstreamID: workstreamID,
            projectName: "app",
            workstreamName: "task",
            projectDirectory: "/app",
            workingDirectory: "/app/task",
            port: 3000,
            agentTeams: false,
            defaultBranch: "develop",
            scriptSource: "conductor.json"
        )

        XCTAssertEqual(vars["FF_DEFAULT_BRANCH"], "develop")
        XCTAssertEqual(vars["CONDUCTOR_DEFAULT_BRANCH"], "develop")
    }
}

final class WorkspaceTabStateTests: XCTestCase {
    func testCommandBracketShortcutsAreHandledBeforeTerminalInput() {
        XCTAssertEqual(
            commandKeyNotification(charactersIgnoringModifiers: "[", modifierFlags: [.command]),
            .prevWorkstream
        )
        XCTAssertEqual(
            commandKeyNotification(charactersIgnoringModifiers: "]", modifierFlags: [.command]),
            .nextWorkstream
        )
        XCTAssertEqual(
            commandKeyNotification(charactersIgnoringModifiers: "[", modifierFlags: [.command, .shift]),
            .prevTab
        )
        XCTAssertEqual(
            commandKeyNotification(charactersIgnoringModifiers: "]", modifierFlags: [.command, .shift]),
            .nextTab
        )
        XCTAssertEqual(
            commandKeyNotification(charactersIgnoringModifiers: "w", modifierFlags: [.command]),
            .closeTerminal
        )
    }

    func testCommandBracketShortcutsIgnoreOptionAndControlChords() {
        XCTAssertNil(commandKeyNotification(charactersIgnoringModifiers: "[", modifierFlags: [.command, .option]))
        XCTAssertNil(commandKeyNotification(charactersIgnoringModifiers: "[", modifierFlags: [.command, .control]))
        XCTAssertNil(commandKeyNotification(charactersIgnoringModifiers: "x", modifierFlags: [.command]))
    }

    func testCustomTabsPersistAsInfo() {
        XCTAssertEqual(RestorableWorkspaceTab(activeTab: .terminal(UUID())), .info)
        XCTAssertEqual(RestorableWorkspaceTab(activeTab: .browser(UUID())), .info)
    }

    func testEnvironmentRestoresToInfo() {
        XCTAssertEqual(RestorableWorkspaceTab.environment.workspaceTab(), .info)
    }

    func testReorderedCustomTabsKeepsFixedTabsInPlace() throws {
        let terminalA = try WorkspaceTab.terminal(XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")))
        let browserB = try WorkspaceTab.browser(XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")))
        let terminalC = try WorkspaceTab.terminal(XCTUnwrap(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")))
        let tabs: [WorkspaceTab] = [.info, .agent, terminalA, browserB, terminalC]

        let reordered = reorderedCustomTabs(tabs, dragging: terminalC, to: terminalA)

        XCTAssertEqual(reordered, [.info, .agent, terminalC, terminalA, browserB])
    }

    func testRenderableWorkstreamIDKeepsOnlySelectedReadyWorkstream() throws {
        let selectedID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        let previousID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let nextID = try XCTUnwrap(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))
        let unreadyID = try XCTUnwrap(UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"))
        let project = Project(
            name: "app",
            directory: "/app",
            workstreams: [
                Workstream(name: "selected", worktreePath: "/app/selected", id: selectedID, lastAccessedAt: Date(timeIntervalSince1970: 40)),
                Workstream(name: "previous", worktreePath: "/app/previous", id: previousID, lastAccessedAt: Date(timeIntervalSince1970: 50)),
                Workstream(name: "next", worktreePath: "/app/next", id: nextID, lastAccessedAt: Date(timeIntervalSince1970: 30)),
                Workstream(name: "unready", id: unreadyID, lastAccessedAt: Date(timeIntervalSince1970: 20)),
            ]
        )

        let id = renderableWorkstreamID(
            in: project,
            selectedWorkstreamID: selectedID,
            pathExists: { _ in true }
        )

        XCTAssertEqual(id, selectedID)
    }

    func testRenderableWorkstreamIDSkipsUnreadySelection() throws {
        let selectedID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let project = Project(
            name: "app",
            directory: "/app",
            workstreams: [
                Workstream(name: "selected", id: selectedID),
            ]
        )

        let id = renderableWorkstreamID(in: project, selectedWorkstreamID: selectedID)

        XCTAssertNil(id)
    }

    func testRenderableWorkstreamIDSkipsMissingWorktreePath() throws {
        let selectedID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let project = Project(
            name: "app",
            directory: "/app",
            workstreams: [
                Workstream(name: "selected", worktreePath: "/app/missing", id: selectedID),
            ]
        )

        let id = renderableWorkstreamID(
            in: project,
            selectedWorkstreamID: selectedID,
            pathExists: { _ in false }
        )

        XCTAssertNil(id)
    }

    func testCycleWorkstreamWrapsToPreviousExistingWorktree() throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let missingID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        let previousID = try XCTUnwrap(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))
        let project = Project(
            name: "app",
            directory: "/app",
            workstreams: [
                Workstream(name: "first", worktreePath: "/app/first", id: firstID, lastAccessedAt: Date(timeIntervalSince1970: 30)),
                Workstream(name: "missing", worktreePath: "/app/missing", id: missingID, lastAccessedAt: Date(timeIntervalSince1970: 20)),
                Workstream(name: "previous", worktreePath: "/app/previous", id: previousID, lastAccessedAt: Date(timeIntervalSince1970: 10)),
            ]
        )

        let id = cycledWorkstreamID(
            in: project,
            selectedWorkstreamID: firstID,
            direction: -1,
            pathExists: { $0 != "/app/missing" }
        )

        XCTAssertEqual(id, previousID)
    }
}

final class SidebarExpansionTests: XCTestCase {
    func testSelectionExpansionAddsSelectedProject() throws {
        let selectedProjectID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let existingProjectID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))

        let expanded = expandedProjectIDs(
            afterSelecting: .project(selectedProjectID),
            current: [existingProjectID],
            projectIDByWorkstreamID: [:]
        )

        XCTAssertEqual(expanded, [existingProjectID, selectedProjectID])
    }

    func testSelectionExpansionAddsParentProjectForWorkstream() throws {
        let workstreamID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let projectID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))

        let expanded = expandedProjectIDs(
            afterSelecting: .workstream(workstreamID),
            current: [],
            projectIDByWorkstreamID: [workstreamID: projectID]
        )

        XCTAssertEqual(expanded, [projectID])
    }

    func testSelectionExpansionIgnoresMissingWorkstreamParent() throws {
        let workstreamID = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))

        let expanded = expandedProjectIDs(
            afterSelecting: .workstream(workstreamID),
            current: [],
            projectIDByWorkstreamID: [:]
        )

        XCTAssertEqual(expanded, [])
    }
}
