// ABOUTME: Builds environment variables injected into workstream terminals.
// ABOUTME: Centralizes DY_* vars, default branch, and compatibility aliases for external tools.

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
        codingCLI: CodingCLI,
        agentTeams: Bool,
        defaultBranch: String = "main",
        scriptSource: String? = nil,
        inferredPort: Int? = nil,
        inferredVenv: String? = nil
    ) -> [String: String] {
        let id = workstreamID.uuidString.lowercased()
        let finalPort = inferredPort ?? port
        let portString = "\(finalPort)"

        var vars = [
            "DY_WORKSTREAM_ID": id,
            "DY_PROJECT": projectName,
            "DY_WORKSTREAM": workstreamName,
            "DY_PROJECT_DIR": projectDirectory,
            "DY_WORKTREE_DIR": workingDirectory,
            "DY_PORT": portString,
            "DY_DEFAULT_BRANCH": defaultBranch,
        ]

        if let inferredVenv {
            vars["DY_VENV_DIR"] = inferredVenv
        }
        
        if codingCLI == .claude, agentTeams {
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

        
        var pathsToPrepend: [String] = []
        let fileManager = FileManager.default
        let projectURL = URL(fileURLWithPath: projectDirectory)
        
        let venvBin = projectURL.appendingPathComponent("venv/bin").path
        let dotVenvBin = projectURL.appendingPathComponent(".venv/bin").path
        let nodeBin = projectURL.appendingPathComponent("node_modules/.bin").path
        
        if fileManager.fileExists(atPath: venvBin + "/activate") {
            pathsToPrepend.append(venvBin)
        } else if fileManager.fileExists(atPath: dotVenvBin + "/activate") {
            pathsToPrepend.append(dotVenvBin)
        }
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: nodeBin, isDirectory: &isDir), isDir.boolValue {
            pathsToPrepend.append(nodeBin)
        }
        
        if !pathsToPrepend.isEmpty {
            let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
            vars["PATH"] = (pathsToPrepend + [currentPath]).filter { !$0.isEmpty }.joined(separator: ":")
        }
        
        return vars
    }
}
