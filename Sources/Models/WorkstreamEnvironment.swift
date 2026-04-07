// ABOUTME: Builds environment variables injected into workstream terminals.
// ABOUTME: Centralizes FF_* vars, default branch, and compatibility aliases for external tools.

import Foundation

enum WorkstreamEnvironment {
    /// Build the environment variables for a workstream's terminal sessions.
    /// When `scriptSource` matches an external tool's config file, compatibility
    /// aliases are added so scripts written for that tool work without modification.
    static func variables(
        workstreamID: UUID,
        projectName: String,
        workstreamName: String,
        projectDirectory: String,
        workingDirectory: String,
        port: Int,
        agentTeams: Bool,
        defaultBranch: String = "main",
        scriptSource: String? = nil
    ) -> [String: String] {
        let id = workstreamID.uuidString.lowercased()
        let portString = "\(port)"

        var vars = [
            "FF_WORKSTREAM_ID": id,
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
            "FF_PROJECT_DIR": projectDirectory,
            "FF_WORKTREE_DIR": workingDirectory,
            "FF_PORT": portString,
            "FF_DEFAULT_BRANCH": defaultBranch,
        ]
        if agentTeams {
            vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        }

        switch scriptSource {
        case "conductor.json":
            vars["CONDUCTOR_WORKSPACE_NAME"] = workstreamName
            vars["CONDUCTOR_ROOT_PATH"] = projectDirectory
            vars["CONDUCTOR_WORKSPACE_PATH"] = workingDirectory
            vars["CONDUCTOR_PORT"] = portString
            vars["CONDUCTOR_DEFAULT_BRANCH"] = defaultBranch
        case ".emdash.json":
            vars["EMDASH_TASK_ID"] = id
            vars["EMDASH_TASK_NAME"] = workstreamName
            vars["EMDASH_TASK_PATH"] = workingDirectory
            vars["EMDASH_ROOT_PATH"] = projectDirectory
            vars["EMDASH_PORT"] = portString
            vars["EMDASH_DEFAULT_BRANCH"] = defaultBranch
        case ".superset/config.json":
            vars["SUPERSET_WORKSPACE_NAME"] = workstreamName
            vars["SUPERSET_ROOT_PATH"] = projectDirectory
            vars["SUPERSET_PORT_BASE"] = portString
        default:
            break
        }

        return vars
    }
}
