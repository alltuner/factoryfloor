// ABOUTME: Handles archiving a workstream: teardown script, worktree removal, tmux cleanup, surface cache eviction.
// ABOUTME: Shared by ContentView and ProjectSidebar to avoid duplicated archive logic.

import Foundation

enum WorkstreamArchiver {
    /// Paths currently being archived (background removal in progress).
    @MainActor static var archivingPaths: Set<String> = []

    /// Posted on MainActor when a background worktree removal finishes.
    static let archivingDidComplete = Notification.Name("FFWorktreeArchivingComplete")

    /// Archives a workstream by running teardown, removing the git worktree, killing tmux sessions,
    /// and evicting terminal surfaces and pixel agents from their caches.
    /// Removes the workstream from the project in place.
    ///
    /// - Parameters:
    ///   - workstreamID: The UUID of the workstream to archive.
    ///   - project: The project containing the workstream (mutated in place to remove it).
    ///   - surfaceCache: The terminal surface cache to evict surfaces from.
    ///   - pixelAgentsCache: The pixel agents cache to evict the WKWebView entry from.
    ///   - tmuxPath: Path to the tmux binary, if available.
    @MainActor
    static func archive(
        _ workstreamID: UUID,
        in project: inout Project,
        surfaceCache: TerminalSurfaceCache,
        pixelAgentsCache: PixelAgentsPanelCache? = nil,
        tmuxPath: String?
    ) {
        if let ws = project.workstreams.first(where: { $0.id == workstreamID }) {
            let projectDir = project.directory
            let worktreeDir = ws.worktreePath ?? projectDir
            let standardizedPath = URL(fileURLWithPath: worktreeDir).standardizedFileURL.path
            let wsName = ws.name
            let projName = project.name
            // Evict pixel agents cache entry for this workstream's working directory
            pixelAgentsCache?.removeEntry(for: worktreeDir)
            archivingPaths.insert(standardizedPath)
            Task.detached {
                ScriptConfig.runTeardown(in: worktreeDir, projectDirectory: projectDir)
                GitOperations.removeWorktree(projectPath: projectDir, workstreamName: wsName, projectName: projName)
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
        project.workstreams.removeAll { $0.id == workstreamID }
    }
}
