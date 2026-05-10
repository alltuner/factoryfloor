// ABOUTME: Builds environment variables injected into workstream terminals.
// ABOUTME: Centralizes FF_* vars and agent settings for claude and workspace shells.

import Foundation

enum WorkstreamEnvironment {
    /// Build the environment variables for a workstream's terminal sessions.
    static func variables(
        workstreamID: UUID,
        projectName: String,
        workstreamName: String,
        projectDirectory: String,
        workingDirectory: String,
        port: Int,
        codingCLI: CodingCLI,
        agentTeams: Bool
    ) -> [String: String] {
        var vars = [
            "FF_WORKSTREAM_ID": workstreamID.uuidString.lowercased(),
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
            "FF_PROJECT_DIR": projectDirectory,
            "FF_WORKTREE_DIR": workingDirectory,
            "FF_PORT": "\(port)",
        ]
        
        if codingCLI == .claude, agentTeams {
            vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
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
