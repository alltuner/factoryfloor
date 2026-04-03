// ABOUTME: Detects installed tools, apps, and git repo status.
// ABOUTME: Shared across the app as an environment object with async background updates.

import OSLog
import SwiftUI

private let logger = Logger(subsystem: "factoryfloor", category: "environment")

struct WorktreeState {
    var hasUncommittedChanges: Bool = false
    var hasUnpushedCommits: Bool = false
    var hasBranchCommits: Bool = false
    var hasRemote: Bool = false
}

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var toolStatus = ToolStatus()
    @Published var installedTerminals: [AppInfo] = []
    @Published var installedBrowsers: [AppInfo] = []
    @Published var isDetecting = false

    // Cached repo info per directory, refreshed asynchronously
    @Published private var repoInfoCache: [String: GitRepoInfo] = [:]
    private var repoInfoTimestamps: [String: Date] = [:]

    /// Worktree path validity cache
    @Published private var pathValidityCache: [String: Bool] = [:]

    /// Branch name cache per worktree path
    @Published private var branchNameCache: [String: String] = [:]

    /// Git repo detection cache per project directory
    @Published private var gitRepoCache: [String: Bool] = [:]

    /// Working tree state cache per worktree path
    @Published private var worktreeStateCache: [String: WorktreeState] = [:]

    /// Active port cache per workstream ID
    @Published private var activePortCache: Set<UUID> = []

    /// GitHub remote detection cache per project directory (lightweight git check)
    @Published private var githubRemoteCache: [String: Bool] = [:]

    // GitHub info cache
    @Published private var githubRepoCache: [String: GitHubRepoInfo] = [:]
    @Published private var githubPRCache: [String: [GitHubPR]] = [:]
    @Published private var githubBranchPRCache: [String: GitHubPR] = [:] // key: "dir|branch"

    func refresh() {
        isDetecting = true
        Task.detached {
            let tools = ToolStatus.detect()
            let terminals = AppInfo.detectTerminals()
            let browsers = AppInfo.detectBrowsers()
            await MainActor.run {
                self.toolStatus = tools
                self.installedTerminals = terminals
                self.installedBrowsers = browsers
                self.isDetecting = false
            }
        }
    }

    // MARK: - Origin Fetch

    private var lastOriginFetch: [String: Date] = [:]
    private static let originFetchInterval: TimeInterval = 120 // 2 minutes

    /// Fetch the default branch from origin for each project directory.
    /// Throttled to once every 2 minutes per project. Skips repos without
    /// a remote and fails silently on network errors.
    func fetchOrigin(projects: [Project]) {
        let now = Date()
        for project in projects {
            let dir = project.directory
            if let lastFetch = lastOriginFetch[dir],
               now.timeIntervalSince(lastFetch) < Self.originFetchInterval
            {
                continue
            }
            lastOriginFetch[dir] = now
            Task.detached {
                GitOperations.fetchDefaultBranch(at: dir)
            }
        }
    }

    // MARK: - Repo Info

    func repoInfo(for directory: String) -> GitRepoInfo? {
        repoInfoCache[directory]
    }

    func refreshRepoInfo(for directory: String) {
        // Skip if refreshed within the last 5 seconds
        if let lastRefresh = repoInfoTimestamps[directory],
           Date().timeIntervalSince(lastRefresh) < 5
        {
            return
        }
        repoInfoTimestamps[directory] = Date()

        Task.detached {
            let info = GitOperations.repoInfo(at: directory)
            await MainActor.run {
                self.repoInfoCache[directory] = info
            }
        }
    }

    /// Refresh repo info for all tracked projects. Recently active projects
    /// refresh more often than stale ones.
    func refreshAllRepoInfo(projects: [Project]) {
        let now = Date()
        for project in projects {
            let age = now.timeIntervalSince(project.lastAccessedAt)
            let minInterval: TimeInterval = age < 300 ? 10 : 60 // 10s for recent, 60s for stale

            if let lastRefresh = repoInfoTimestamps[project.directory],
               now.timeIntervalSince(lastRefresh) < minInterval
            {
                continue
            }

            repoInfoTimestamps[project.directory] = now
            let dir = project.directory
            Task.detached {
                let info = GitOperations.repoInfo(at: dir)
                await MainActor.run {
                    self.repoInfoCache[dir] = info
                }
            }
        }
    }

    // MARK: - Path Validity

    func isPathValid(_ path: String?) -> Bool {
        guard let path else { return true }
        return pathValidityCache[path] ?? true
    }

    func branchName(for worktreePath: String?) -> String? {
        guard let path = worktreePath else { return nil }
        return branchNameCache[path]
    }

    func isGitRepo(_ directory: String) -> Bool {
        gitRepoCache[directory] ?? false
    }

    func hasGitHubRemote(_ directory: String) -> Bool {
        githubRemoteCache[directory] ?? false
    }

    /// Browser-openable GitHub URL for a project directory.
    /// Prefers the canonical URL from `gh`, falls back to converting the git remote URL.
    func githubURL(for directory: String) -> URL? {
        if let ghURL = githubRepoCache[directory]?.url {
            return URL(string: ghURL)
        }
        if let remoteURL = repoInfoCache[directory]?.remoteURL {
            return GitHubOperations.browserURL(from: remoteURL)
        }
        return nil
    }

    func worktreeState(for path: String) -> WorktreeState {
        worktreeStateCache[path] ?? WorktreeState()
    }

    /// Refresh working tree state for a single worktree path.
    func refreshWorktreeState(for worktreePath: String, projectDirectory: String) {
        let path = worktreePath
        let projectDir = projectDirectory
        Task.detached {
            let state = WorktreeState(
                hasUncommittedChanges: GitOperations.hasUncommittedChanges(at: path),
                hasUnpushedCommits: GitOperations.hasUnpushedCommits(at: path),
                hasBranchCommits: GitOperations.hasBranchCommits(at: path, projectPath: projectDir),
                hasRemote: GitOperations.hasRemote(at: path)
            )
            await MainActor.run {
                self.worktreeStateCache[path] = state
            }
        }
    }

    func hasActivePort(_ workstreamID: UUID) -> Bool {
        activePortCache.contains(workstreamID)
    }

    /// Returns IDs of projects whose directories no longer exist.
    @Published var missingProjectIDs: Set<UUID> = []

    func refreshPathValidity(projects: [Project]) {
        Task.detached {
            var results: [String: Bool] = [:]
            var missing: Set<UUID> = []
            var gitRepoResults: [String: Bool] = [:]
            var githubRemoteResults: [String: Bool] = [:]
            var portResults: Set<UUID> = []

            // Collect valid worktree paths that need git info
            var validPaths: [String] = []

            for project in projects {
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: project.directory, isDirectory: &isDir) && isDir.boolValue
                if !exists {
                    logger.warning("[FF] refreshPathValidity: project \(project.name, privacy: .public) directory MISSING: \(project.directory, privacy: .public)")
                    missing.insert(project.id)
                }

                gitRepoResults[project.directory] = GitOperations.isGitRepo(at: project.directory)
                githubRemoteResults[project.directory] = GitHubOperations.hasGitHubRemote(at: project.directory)

                for ws in project.workstreams {
                    if RunStateStore.loadValidated(for: ws.id)?.detectedPorts.isEmpty == false {
                        portResults.insert(ws.id)
                    }

                    guard let path = ws.worktreePath else { continue }
                    var wsIsDir: ObjCBool = false
                    let valid = FileManager.default.fileExists(atPath: path, isDirectory: &wsIsDir) && wsIsDir.boolValue
                    results[path] = valid
                    if valid {
                        validPaths.append(path)
                    }
                }
            }

            // Map worktree paths to their project directory for state detection
            var worktreeToProject: [String: String] = [:]
            for project in projects {
                for ws in project.workstreams {
                    if let path = ws.worktreePath, validPaths.contains(path) {
                        worktreeToProject[path] = project.directory
                    }
                }
            }

            // Run git info calls in parallel
            let branches: [String: String] = await withTaskGroup(
                of: (String, String?).self
            ) { group in
                for path in validPaths {
                    group.addTask {
                        let info = GitOperations.repoInfo(at: path)
                        return (path, info.branch)
                    }
                }
                var collected: [String: String] = [:]
                for await (path, branch) in group {
                    if let branch {
                        collected[path] = branch
                    }
                }
                return collected
            }

            // Compute worktree state in parallel
            let worktreeStates: [String: WorktreeState] = await withTaskGroup(
                of: (String, WorktreeState).self
            ) { group in
                for (path, projectDir) in worktreeToProject {
                    group.addTask {
                        let state = WorktreeState(
                            hasUncommittedChanges: GitOperations.hasUncommittedChanges(at: path),
                            hasUnpushedCommits: GitOperations.hasUnpushedCommits(at: path),
                            hasBranchCommits: GitOperations.hasBranchCommits(at: path, projectPath: projectDir),
                            hasRemote: GitOperations.hasRemote(at: path)
                        )
                        return (path, state)
                    }
                }
                var collected: [String: WorktreeState] = [:]
                for await (path, state) in group {
                    collected[path] = state
                }
                return collected
            }

            await MainActor.run {
                self.pathValidityCache.merge(results) { _, new in new }
                self.branchNameCache.merge(branches) { _, new in new }
                self.missingProjectIDs = missing
                self.gitRepoCache.merge(gitRepoResults) { _, new in new }
                self.githubRemoteCache.merge(githubRemoteResults) { _, new in new }
                self.worktreeStateCache.merge(worktreeStates) { _, new in new }
                self.activePortCache = portResults
            }
        }
    }

    // MARK: - GitHub

    var ghAvailable: Bool {
        toolStatus.gh.isInstalled && toolStatus.ghAuthDetail != "Not authenticated"
    }

    func githubRepo(for directory: String) -> GitHubRepoInfo? {
        githubRepoCache[directory]
    }

    func githubPRs(for directory: String) -> [GitHubPR] {
        githubPRCache[directory] ?? []
    }

    func githubPR(for directory: String, branch: String) -> GitHubPR? {
        githubBranchPRCache["\(directory)|\(branch)"]
    }

    func clearBranchPR(for directory: String, branch: String) {
        githubBranchPRCache.removeValue(forKey: "\(directory)|\(branch)")
    }

    func refreshGitHubInfo(for directory: String, branch: String? = nil) {
        guard ghAvailable, let ghPath = toolStatus.gh.path else { return }
        guard GitHubOperations.hasGitHubRemote(at: directory) else { return }

        Task.detached {
            let repo = GitHubOperations.repoInfo(ghPath: ghPath, at: directory)
            let prs = GitHubOperations.openPRs(ghPath: ghPath, at: directory)
            var branchPR: GitHubPR?
            if let branch {
                branchPR = GitHubOperations.prForBranch(ghPath: ghPath, at: directory, branch: branch)
                if branchPR == nil {
                    branchPR = GitHubOperations.mergedPRForBranch(ghPath: ghPath, at: directory, branch: branch)
                }
            }

            await MainActor.run {
                if let repo { self.githubRepoCache[directory] = repo }
                self.githubPRCache[directory] = prs
                if let branch, let pr = branchPR {
                    self.githubBranchPRCache["\(directory)|\(branch)"] = pr
                }
            }
        }
    }

    // MARK: - Branch PR Refresh

    private var lastBranchPRRefresh: Date = .distantPast

    /// Refresh PRs for all workstream branches. One gh call per project.
    /// Populate the branch PR cache for a set of branches in a single `gh` call.
    func refreshBranchPRs(for directory: String, branches: Set<String>) {
        guard ghAvailable, let ghPath = toolStatus.gh.path, !branches.isEmpty else { return }
        Task.detached {
            let prs = GitHubOperations.openPRs(ghPath: ghPath, at: directory, limit: 100)
            let prsByBranch = Dictionary(prs.map { ($0.branch, $0) }, uniquingKeysWith: { first, _ in first })
            await MainActor.run {
                for branch in branches {
                    let key = "\(directory)|\(branch)"
                    if let pr = prsByBranch[branch] {
                        self.githubBranchPRCache[key] = pr
                    } else {
                        self.githubBranchPRCache.removeValue(forKey: key)
                    }
                }
            }
        }
    }

    /// Throttled to run at most every 30 seconds.
    func refreshAllBranchPRs(projects: [Project]) {
        let now = Date()
        guard now.timeIntervalSince(lastBranchPRRefresh) >= 30 else { return }
        lastBranchPRRefresh = now

        guard ghAvailable, let ghPath = toolStatus.gh.path else { return }

        // Collect branches per project directory
        var projectBranches: [String: Set<String>] = [:]
        for project in projects {
            var branches: Set<String> = []
            for ws in project.workstreams {
                guard let path = ws.worktreePath,
                      let branch = branchNameCache[path] else { continue }
                branches.insert(branch)
            }
            if !branches.isEmpty {
                projectBranches[project.directory] = branches
            }
        }

        guard !projectBranches.isEmpty else { return }

        // Snapshot currently cached PR states to detect transitions
        var cachedStates: [String: String] = [:]
        for (dir, branches) in projectBranches {
            for branch in branches {
                let key = "\(dir)|\(branch)"
                if let pr = githubBranchPRCache[key] {
                    cachedStates[key] = pr.state
                }
            }
        }

        Task.detached {
            // One gh call per project fetches all open PRs
            var allOpenPRs: [(String, [GitHubPR])] = []
            await withTaskGroup(of: (String, [GitHubPR]).self) { group in
                for (dir, _) in projectBranches {
                    group.addTask {
                        let prs = GitHubOperations.openPRs(ghPath: ghPath, at: dir, limit: 100)
                        return (dir, prs)
                    }
                }
                for await result in group {
                    allOpenPRs.append(result)
                }
            }

            // Update cache with open PRs, collect branches needing merged lookup
            var mergedLookups: [(dir: String, branch: String, key: String)] = []
            for (dir, prs) in allOpenPRs {
                let branches = projectBranches[dir] ?? []
                let prsByBranch = Dictionary(prs.map { ($0.branch, $0) }, uniquingKeysWith: { first, _ in first })

                await MainActor.run {
                    for branch in branches {
                        let key = "\(dir)|\(branch)"
                        if let pr = prsByBranch[branch] {
                            self.githubBranchPRCache[key] = pr
                        } else if cachedStates[key] == "MERGED" {
                            // Already cached as merged, no need to re-fetch
                        } else if cachedStates[key] != nil {
                            // Had an open PR that's no longer open, check if merged
                            mergedLookups.append((dir: dir, branch: branch, key: key))
                            self.githubBranchPRCache.removeValue(forKey: key)
                        } else {
                            // Never had a cached PR, nothing to do
                        }
                    }
                }
            }

            // Targeted merged lookups for branches whose open PR disappeared
            if !mergedLookups.isEmpty {
                await withTaskGroup(of: (String, GitHubPR?).self) { group in
                    for lookup in mergedLookups {
                        group.addTask {
                            let pr = GitHubOperations.mergedPRForBranch(ghPath: ghPath, at: lookup.dir, branch: lookup.branch)
                            return (lookup.key, pr)
                        }
                    }
                    for await (key, pr) in group {
                        if let pr {
                            await MainActor.run {
                                self.githubBranchPRCache[key] = pr
                            }
                        }
                    }
                }
            }
        }
    }
}
