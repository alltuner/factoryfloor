// ABOUTME: Handles archiving a workstream: teardown script, worktree removal, tmux cleanup, surface cache eviction.
// ABOUTME: Shared by ContentView and ProjectSidebar to avoid duplicated archive logic.

import Foundation

enum WorkstreamArchiver {
    /// Archives a workstream by running teardown, removing the git worktree, killing tmux sessions,
    /// and evicting terminal surfaces from the cache. Removes the workstream from the project in place.
    ///
    /// - Parameters:
    ///   - workstreamID: The UUID of the workstream to archive.
    ///   - project: The project containing the workstream (mutated in place to remove it).
    ///   - surfaceCache: The terminal surface cache to evict surfaces from.
    ///   - tmuxPath: Path to the tmux binary, if available.
    @MainActor
    static func archive(
        _ workstreamID: UUID,
        in project: inout Project,
        surfaceCache: TerminalSurfaceCache,
        tmuxPath: String?
    ) {
        if let ws = project.workstreams.first(where: { $0.id == workstreamID }) {
            let projectDir = project.directory
            let worktreeDir = ws.worktreePath ?? projectDir
            let wsName = ws.name
            let projName = project.name
            Task.detached {
                ScriptConfig.runTeardown(in: worktreeDir, projectDirectory: projectDir)
                GitOperations.removeWorktree(projectPath: projectDir, workstreamName: wsName, projectName: projName)
                if let tmuxPath {
                    TmuxSession.killWorkstreamSessions(tmuxPath: tmuxPath, project: projName, workstream: wsName)
                }
            }
        }
        surfaceCache.removeWorkstreamSurfaces(for: workstreamID)
        project.workstreams.removeAll { $0.id == workstreamID }
    }
}
