// ABOUTME: Handles removing and purging workstreams from projects.
// ABOUTME: Shared by ContentView and ProjectSidebar to avoid duplicated workstream cleanup logic.

import Foundation

enum WorkstreamArchiver {
    /// Paths currently being archived (background removal in progress).
    @MainActor static var archivingPaths: Set<String> = []

    /// Posted on MainActor when a background worktree removal finishes.
    static let archivingDidComplete = Notification.Name("FFWorktreeArchivingComplete")

    /// Removes a workstream from the project without deleting the worktree from disk.
    /// Kills running terminals and tmux sessions but leaves files intact.
    @MainActor
    static func remove(
        _ workstreamID: UUID,
        in project: inout Project,
        surfaceCache: TerminalSurfaceCache,
        tmuxPath: String?
    ) {
        if let ws = project.workstreams.first(where: { $0.id == workstreamID }) {
            let projName = project.name
            let wsName = ws.name
            Task.detached {
                if let tmuxPath {
                    TmuxSession.killWorkstreamSessions(tmuxPath: tmuxPath, project: projName, workstream: wsName)
                }
            }
        }
        surfaceCache.removeWorkstreamSurfaces(for: workstreamID)
        LaunchLogger.removeLog(for: workstreamID)
        project.workstreams.removeAll { $0.id == workstreamID }
    }

    /// Purges a workstream by running teardown, removing the git worktree from disk,
    /// killing tmux sessions, and evicting terminal surfaces from the cache.
    @MainActor
    static func purge(
        _ workstreamID: UUID,
        in project: inout Project,
        surfaceCache: TerminalSurfaceCache,
        tmuxPath: String?
    ) {
        if let ws = project.workstreams.first(where: { $0.id == workstreamID }) {
            let projectDir = project.directory
            let worktreePath = ws.worktreePath ?? projectDir
            let standardizedPath = URL(fileURLWithPath: worktreePath).standardizedFileURL.path
            let wsName = ws.name
            let projName = project.name
            archivingPaths.insert(standardizedPath)
            Task.detached {
                ScriptConfig.runTeardown(in: worktreePath, projectDirectory: projectDir)
                GitOperations.removeWorktree(projectPath: projectDir, worktreePath: worktreePath)
                if let tmuxPath {
                    TmuxSession.killWorkstreamSessions(tmuxPath: tmuxPath, project: projName, workstream: wsName)
                }
                await MainActor.run {
                    archivingPaths.remove(standardizedPath)
                    NotificationCenter.default.post(name: archivingDidComplete, object: nil)
                }
            }
        }
        surfaceCache.removeWorkstreamSurfaces(for: workstreamID)
        LaunchLogger.removeLog(for: workstreamID)
        project.workstreams.removeAll { $0.id == workstreamID }
    }
}
