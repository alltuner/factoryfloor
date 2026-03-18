// ABOUTME: Moves run-state and tmux.conf from ~/.config/factoryfloor/ to ~/Library/Caches/factoryfloor/.
// ABOUTME: Runs once on launch; removes the old config directory if empty afterward.

import Foundation

enum CacheMigration {
    static func migrateIfNeeded() {
        let fm = FileManager.default
        let oldBase = AppConstants.configDirectory
        let newBase = AppConstants.cacheDirectory

        try? fm.createDirectory(at: newBase, withIntermediateDirectories: true)

        // Migrate run-state directory
        let oldRunState = oldBase.appendingPathComponent("run-state", isDirectory: true)
        let newRunState = newBase.appendingPathComponent("run-state", isDirectory: true)
        moveIfExists(from: oldRunState, to: newRunState)

        // Migrate tmux.conf
        let oldTmux = oldBase.appendingPathComponent("tmux.conf")
        let newTmux = newBase.appendingPathComponent("tmux.conf")
        moveIfExists(from: oldTmux, to: newTmux)

        // Remove old config directory if empty
        removeDirectoryIfEmpty(oldBase)
    }

    private static func moveIfExists(from source: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { return }
        // Remove destination if it already exists so the move doesn't fail
        try? fm.removeItem(at: destination)
        try? fm.moveItem(at: source, to: destination)
    }

    private static func removeDirectoryIfEmpty(_ url: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: url.path) else { return }
        let visible = contents.filter { !$0.hasPrefix(".") }
        if visible.isEmpty {
            try? fm.removeItem(at: url)
        }
    }
}
