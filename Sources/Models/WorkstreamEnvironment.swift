// ABOUTME: Builds environment variables injected into workstream terminals.
// ABOUTME: Centralizes FF_* vars and agent settings for claude and workspace shells.

import Foundation

enum WorkstreamEnvironment {
    /// Build the environment variables for a workstream's terminal sessions.
    static func variables(
        projectName: String,
        workstreamName: String,
        projectDirectory: String,
        workingDirectory: String,
        port: Int,
        agentTeams: Bool
    ) -> [String: String] {
        var vars = [
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
            "FF_PROJECT_DIR": projectDirectory,
            "FF_WORKTREE_DIR": workingDirectory,
            "FF_PORT": "\(port)",
        ]
        if agentTeams {
            vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        }
        return vars
    }
}
