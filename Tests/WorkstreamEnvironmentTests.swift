// ABOUTME: Tests for WorkstreamEnvironment env var construction.
// ABOUTME: Validates FF_* vars, default branch, and compatibility aliases for external tools.

@testable import FactoryFloor
import XCTest

final class WorkstreamEnvironmentTests: XCTestCase {
    private let baseParams: (UUID, String, String, String, String, Int, Bool) = (
        UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
        "my-project",
        "coral-reef",
        "/Users/test/my-project",
        "/Users/test/.factoryfloor/worktrees/my-project/coral-reef",
        42847,
        false
    )

    // MARK: - Core FF_* variables

    func testCoreVariables() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "main",
            scriptSource: nil
        )
        XCTAssertEqual(vars["FF_WORKSTREAM_ID"], "12345678-1234-1234-1234-123456789abc")
        XCTAssertEqual(vars["FF_PROJECT"], "my-project")
        XCTAssertEqual(vars["FF_WORKSTREAM"], "coral-reef")
        XCTAssertEqual(vars["FF_PROJECT_DIR"], "/Users/test/my-project")
        XCTAssertEqual(vars["FF_WORKTREE_DIR"], "/Users/test/.factoryfloor/worktrees/my-project/coral-reef")
        XCTAssertEqual(vars["FF_PORT"], "42847")
        XCTAssertEqual(vars["FF_DEFAULT_BRANCH"], "main")
        XCTAssertNil(vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"])
    }

    func testAgentTeamsFlag() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: true,
            defaultBranch: "main",
            scriptSource: nil
        )
        XCTAssertEqual(vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"], "1")
    }

    // MARK: - Conductor aliases

    func testConductorAliases() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "main",
            scriptSource: "conductor.json"
        )
        XCTAssertEqual(vars["CONDUCTOR_WORKSPACE_NAME"], "coral-reef")
        XCTAssertEqual(vars["CONDUCTOR_ROOT_PATH"], "/Users/test/my-project")
        XCTAssertEqual(vars["CONDUCTOR_WORKSPACE_PATH"], "/Users/test/.factoryfloor/worktrees/my-project/coral-reef")
        XCTAssertEqual(vars["CONDUCTOR_PORT"], "42847")
        XCTAssertEqual(vars["CONDUCTOR_DEFAULT_BRANCH"], "main")
    }

    // MARK: - Emdash aliases

    func testEmdashAliases() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "develop",
            scriptSource: ".emdash.json"
        )
        XCTAssertEqual(vars["EMDASH_TASK_ID"], "12345678-1234-1234-1234-123456789abc")
        XCTAssertEqual(vars["EMDASH_TASK_NAME"], "coral-reef")
        XCTAssertEqual(vars["EMDASH_TASK_PATH"], "/Users/test/.factoryfloor/worktrees/my-project/coral-reef")
        XCTAssertEqual(vars["EMDASH_ROOT_PATH"], "/Users/test/my-project")
        XCTAssertEqual(vars["EMDASH_PORT"], "42847")
        XCTAssertEqual(vars["EMDASH_DEFAULT_BRANCH"], "develop")
    }

    // MARK: - Superset aliases

    func testSupersetAliases() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "main",
            scriptSource: ".superset/config.json"
        )
        XCTAssertEqual(vars["SUPERSET_WORKSPACE_NAME"], "coral-reef")
        XCTAssertEqual(vars["SUPERSET_ROOT_PATH"], "/Users/test/my-project")
        XCTAssertEqual(vars["SUPERSET_PORT_BASE"], "42847")
    }

    // MARK: - No aliases for native config

    func testNoAliasesForFactoryFloorConfig() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "main",
            scriptSource: ".factoryfloor.json"
        )
        XCTAssertNil(vars["CONDUCTOR_WORKSPACE_NAME"])
        XCTAssertNil(vars["EMDASH_TASK_NAME"])
        XCTAssertNil(vars["SUPERSET_WORKSPACE_NAME"])
    }

    func testNoAliasesForNilSource() {
        let vars = WorkstreamEnvironment.variables(
            workstreamID: baseParams.0,
            projectName: baseParams.1,
            workstreamName: baseParams.2,
            projectDirectory: baseParams.3,
            workingDirectory: baseParams.4,
            port: baseParams.5,
            agentTeams: baseParams.6,
            defaultBranch: "main",
            scriptSource: nil
        )
        XCTAssertNil(vars["CONDUCTOR_WORKSPACE_NAME"])
        XCTAssertNil(vars["EMDASH_TASK_NAME"])
        XCTAssertNil(vars["SUPERSET_WORKSPACE_NAME"])
    }
}
