// ABOUTME: Creates symlinks in a worktree pointing back to heavy directories in the main repo.
// ABOUTME: Avoids re-downloading dependencies (node_modules, .terraform, vendor) for each worktree.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.symlinks")

enum SymlinkCreator {
    /// Default directories to symlink if they exist in the source project.
    static let defaultSymlinks = [
        ".terraform",
        "terraform.tfstate",
        "terraform.tfstate.backup",
        "vendor",
        "volume",
        "db/prisma-generated-clients",
    ]

    /// Create symlinks in worktreeDir pointing to directories/files in sourceDir.
    /// Uses the config's symlink list if available, otherwise falls back to defaults.
    @discardableResult
    static func createSymlinks(
        from sourceDir: String,
        to worktreeDir: String,
        config: VibeConfig? = nil
    ) -> Int {
        let fm = FileManager.default
        let paths = config?.symlinks ?? defaultSymlinks
        var createdCount = 0

        for relativePath in paths {
            let sourceURL = URL(fileURLWithPath: sourceDir).appendingPathComponent(relativePath)
            let destURL = URL(fileURLWithPath: worktreeDir).appendingPathComponent(relativePath)

            // Only symlink if source exists
            guard fm.fileExists(atPath: sourceURL.path) else { continue }

            // Skip if destination already exists (file, dir, or symlink)
            if fm.fileExists(atPath: destURL.path) || isSymlink(atPath: destURL.path) {
                logger.info("Skipping \(relativePath, privacy: .public): already exists in worktree")
                continue
            }

            // Create parent directory if needed
            let destParent = destURL.deletingLastPathComponent()
            try? fm.createDirectory(at: destParent, withIntermediateDirectories: true)

            do {
                try fm.createSymbolicLink(atPath: destURL.path, withDestinationPath: sourceURL.path)
                createdCount += 1
                logger.info("Symlinked \(relativePath, privacy: .public)")
            } catch {
                logger.warning("Failed to symlink \(relativePath, privacy: .public): \(error, privacy: .public)")
            }
        }

        logger.info("Created \(createdCount) symlink(s) in \(worktreeDir, privacy: .public)")
        return createdCount
    }

    private static func isSymlink(atPath path: String) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let fileType = attrs[.type] as? FileAttributeType
        else { return false }
        return fileType == .typeSymbolicLink
    }
}
