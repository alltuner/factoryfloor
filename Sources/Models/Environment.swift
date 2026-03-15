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

    func refresh() {
        isDetecting = true
        Task.detached {
            let tools = await ToolStatus.detect()
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
}
