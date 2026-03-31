// ABOUTME: Sets up Claude Code settings in a worktree by symlinking from the main project.
// ABOUTME: Ensures .claude/settings.local.json is shared across all worktrees.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.claudesettings")

enum ClaudeSettingsSetup {
    /// Symlink .claude/settings.local.json from sourceDir to worktreeDir.
    /// Creates the .claude directory in the worktree if it doesn't exist.
    @discardableResult
    static func setup(from sourceDir: String, to worktreeDir: String) -> Bool {
        let fm = FileManager.default

        let sourceFile = URL(fileURLWithPath: sourceDir)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.local.json")

        guard fm.fileExists(atPath: sourceFile.path) else {
            logger.info("No .claude/settings.local.json in source project, skipping")
            return false
        }

        let destClaudeDir = URL(fileURLWithPath: worktreeDir)
            .appendingPathComponent(".claude")
        let destFile = destClaudeDir
            .appendingPathComponent("settings.local.json")

        // Create .claude directory in worktree
        do {
            try fm.createDirectory(at: destClaudeDir, withIntermediateDirectories: true)
        } catch {
            logger.warning("Failed to create .claude directory: \(error, privacy: .public)")
            return false
        }

        // Skip if already exists
        guard !fm.fileExists(atPath: destFile.path) else {
            logger.info(".claude/settings.local.json already exists in worktree")
            return true
        }

        do {
            try fm.createSymbolicLink(atPath: destFile.path, withDestinationPath: sourceFile.path)
            logger.info("Symlinked .claude/settings.local.json to worktree")
            return true
        } catch {
            logger.warning("Failed to symlink .claude/settings.local.json: \(error, privacy: .public)")
            return false
        }
    }
}
