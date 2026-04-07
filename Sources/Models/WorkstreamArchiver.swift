// ABOUTME: Handles removing and purging workstreams from projects.
// ABOUTME: Shared by ContentView and ProjectSidebar to avoid duplicated workstream cleanup logic.

import Foundation

enum WorkstreamArchiver {
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

    /// Check if purging a workstream would lose work. Returns a warning message
    /// describing what would be lost, or nil if it is safe to purge.
    static func purgeWarning(for workstream: Workstream) -> String? {
        guard let path = workstream.worktreePath else { return nil }
        var warnings: [String] = []
        if GitOperations.hasUncommittedChanges(at: path) {
            warnings.append(NSLocalizedString("uncommitted changes", comment: ""))
        }
        if GitOperations.hasUnpushedCommits(at: path) {
            warnings.append(NSLocalizedString("unpushed commits", comment: ""))
        }
        guard !warnings.isEmpty else { return nil }
        let list = warnings.joined(separator: NSLocalizedString(" and ", comment: ""))
        return String(
            format: NSLocalizedString("This workstream has %@ that will be lost.", comment: ""),
            list
        )
    }

    /// Purges a workstream by running teardown, removing the git worktree from disk,
    /// deleting the local branch, updating the default branch to latest,
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
            let wsName = ws.name
            let projName = project.name
            // Capture the branch name before the worktree is removed
            let branchName = GitOperations.currentBranch(at: worktreePath)
            Task.detached {
                ScriptConfig.runTeardown(in: worktreePath, projectDirectory: projectDir)
                GitOperations.removeWorktree(projectPath: projectDir, worktreePath: worktreePath)
                if let branchName {
                    GitOperations.deleteLocalBranch(at: projectDir, branchName: branchName)
                }
                GitOperations.updateDefaultBranch(at: projectDir)
                if let tmuxPath {
                    TmuxSession.killWorkstreamSessions(tmuxPath: tmuxPath, project: projName, workstream: wsName)
                }
            }
        }
        surfaceCache.removeWorkstreamSurfaces(for: workstreamID)
        LaunchLogger.removeLog(for: workstreamID)
        project.workstreams.removeAll { $0.id == workstreamID }
    }
}
