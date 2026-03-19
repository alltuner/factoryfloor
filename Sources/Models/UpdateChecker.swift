// ABOUTME: Checks factory-floor.com/versions.json for available updates.
// ABOUTME: Sidebar badge fallback for Homebrew users; Sparkle handles DMG auto-updates.

import Foundation
import os

@MainActor
class UpdateChecker: ObservableObject {
    @Published var availableVersion: String?

    private let currentVersion: String
    private let logger = Logger(subsystem: AppConstants.appID, category: "UpdateChecker")
    private static let versionsURL = URL(string: "https://factory-floor.com/versions.json")!

    init() {
        currentVersion = AppConstants.version
    }

    func check() {
        Task.detached { [currentVersion, logger] in
            do {
                let (data, _) = try await URLSession.shared.data(from: Self.versionsURL)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
                      let stable = json["stable"] else { return }
                if Self.isNewer(stable, than: currentVersion) {
                    await MainActor.run { [weak self] in
                        self?.availableVersion = stable
                    }
                }
            } catch {
                logger.debug("Update check failed: \(error.localizedDescription)")
            }
        }
    }

    /// Simple semver comparison: returns true if `remote` is newer than `local`.
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0 ..< max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}
