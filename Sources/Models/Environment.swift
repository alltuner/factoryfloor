// ABOUTME: Detects installed tools, apps, and git repo status.
// ABOUTME: Shared across the app as an environment object with async background updates.

import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var toolStatus = ToolStatus()
    @Published var installedTerminals: [AppInfo] = []
    @Published var installedBrowsers: [AppInfo] = []
    @Published var isDetecting = false

    // Cached repo info per directory, refreshed asynchronously
    @Published private var repoInfoCache: [String: GitRepoInfo] = [:]
    private var repoInfoTimestamps: [String: Date] = [:]

    // Worktree path validity cache
    @Published private var pathValidityCache: [String: Bool] = [:]

    // Branch name cache per worktree path
    @Published private var branchNameCache: [String: String] = [:]

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
           Date().timeIntervalSince(lastRefresh) < 5 {
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
               now.timeIntervalSince(lastRefresh) < minInterval {
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

    /// Returns IDs of projects whose directories no longer exist.
    @Published var missingProjectIDs: Set<UUID> = []

    func refreshPathValidity(projects: [Project]) {
        Task.detached {
            var results: [String: Bool] = [:]
            var missing: Set<UUID> = []
            var branches: [String: String] = [:]

            for project in projects {
                // Check project directory
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: project.directory, isDirectory: &isDir) && isDir.boolValue
                if !exists {
                    missing.insert(project.id)
                }

                // Check worktree paths and branch names
                for ws in project.workstreams {
                    guard let path = ws.worktreePath else { continue }
                    var wsIsDir: ObjCBool = false
                    let valid = FileManager.default.fileExists(atPath: path, isDirectory: &wsIsDir) && wsIsDir.boolValue
                    results[path] = valid
                    if valid {
                        let info = GitOperations.repoInfo(at: path)
                        if let branch = info.branch {
                            branches[path] = branch
                        }
                    }
                }
            }
            await MainActor.run {
                self.pathValidityCache.merge(results) { _, new in new }
                self.branchNameCache.merge(branches) { _, new in new }
                self.missingProjectIDs = missing
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
}
