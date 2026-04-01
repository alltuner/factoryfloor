// ABOUTME: Detects installed tools, apps, and git repo status.
// ABOUTME: Shared across the app as an environment object with async background updates.

import OSLog
import SwiftUI

private let logger = Logger(subsystem: "factoryfloor", category: "environment")

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

    /// Active port cache per workstream ID
    @Published private var activePortCache: Set<UUID> = []

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

            await MainActor.run {
                self.pathValidityCache.merge(results) { _, new in new }
                self.branchNameCache.merge(branches) { _, new in new }
                self.missingProjectIDs = missing
                self.gitRepoCache.merge(gitRepoResults) { _, new in new }
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

    func refreshGitHubInfo(for directory: String, branch: String? = nil) {
        guard ghAvailable, let ghPath = toolStatus.gh.path else { return }
        guard GitHubOperations.hasGitHubRemote(at: directory) else { return }

        Task.detached {
            let repo = GitHubOperations.repoInfo(ghPath: ghPath, at: directory)
            let prs = GitHubOperations.openPRs(ghPath: ghPath, at: directory)
            var branchPR: GitHubPR?
            if let branch {
                branchPR = GitHubOperations.prForBranch(ghPath: ghPath, at: directory, branch: branch)
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

    /// Refresh PRs for all workstream branches. Throttled to run at most every 30 seconds.
    func refreshAllBranchPRs(projects: [Project]) {
        let now = Date()
        guard now.timeIntervalSince(lastBranchPRRefresh) >= 30 else { return }
        lastBranchPRRefresh = now

        guard ghAvailable, let ghPath = toolStatus.gh.path else { return }

        // Collect (projectDir, branch) pairs from cached branch names
        var lookups: [(projectDir: String, branch: String)] = []
        for project in projects {
            for ws in project.workstreams {
                guard let path = ws.worktreePath,
                      let branch = branchNameCache[path] else { continue }
                lookups.append((project.directory, branch))
            }
        }

        guard !lookups.isEmpty else { return }

        // Deduplicate by key to avoid redundant gh calls
        var seen: Set<String> = []
        let unique = lookups.filter { seen.insert("\($0.projectDir)|\($0.branch)").inserted }

        Task.detached {
            await withTaskGroup(of: (String, GitHubPR?).self) { group in
                for lookup in unique {
                    let dir = lookup.projectDir
                    let branch = lookup.branch
                    let key = "\(dir)|\(branch)"
                    group.addTask {
                        let pr = GitHubOperations.prForBranch(ghPath: ghPath, at: dir, branch: branch)
                        return (key, pr)
                    }
                }
                for await (key, pr) in group {
                    let capturedKey = key
                    let capturedPR = pr
                    await MainActor.run {
                        if let pr = capturedPR {
                            self.githubBranchPRCache[capturedKey] = pr
                        } else {
                            self.githubBranchPRCache.removeValue(forKey: capturedKey)
                        }
                    }
                }
            }
        }
    }
}
