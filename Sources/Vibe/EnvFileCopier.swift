// ABOUTME: Recursively finds and copies .env* files from source project to a worktree.
// ABOUTME: Preserves relative paths and skips files inside node_modules, .git, and vendor.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.envcopier")

enum EnvFileCopier {
    private static let excludedDirectories: Set<String> = [
        "node_modules", ".git", "vendor", ".terraform",
    ]

    /// Copy all .env* files from sourceDir to worktreeDir, preserving relative paths.
    /// Skips files inside excluded directories (node_modules, .git, vendor, .terraform).
    @discardableResult
    static func copyEnvFiles(from sourceDir: String, to worktreeDir: String) -> Int {
        let fm = FileManager.default
        let sourceURL = URL(fileURLWithPath: sourceDir)
        var copiedCount = 0

        guard let enumerator = fm.enumerator(
            at: sourceURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.warning("Failed to enumerate directory: \(sourceDir, privacy: .public)")
            return 0
        }

        // We need to manually handle .env files which are hidden (start with dot).
        // The enumerator skips hidden files/dirs by default, but we also want to
        // find .env files at any level. Use a separate approach.
        copyEnvFilesRecursive(
            sourceBase: sourceURL,
            currentDir: sourceURL,
            worktreeBase: URL(fileURLWithPath: worktreeDir),
            fileManager: fm,
            copiedCount: &copiedCount
        )

        logger.info("Copied \(copiedCount) env file(s) from \(sourceDir, privacy: .public) to \(worktreeDir, privacy: .public)")
        return copiedCount
    }

    private static func copyEnvFilesRecursive(
        sourceBase: URL,
        currentDir: URL,
        worktreeBase: URL,
        fileManager fm: FileManager,
        copiedCount: inout Int
    ) {
        guard let contents = try? fm.contentsOfDirectory(
            at: currentDir,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey]
        ) else {
            return
        }

        for item in contents {
            let name = item.lastPathComponent

            // Check if this is a directory
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Skip excluded directories
                if excludedDirectories.contains(name) { continue }
                // Recurse into subdirectories
                copyEnvFilesRecursive(
                    sourceBase: sourceBase,
                    currentDir: item,
                    worktreeBase: worktreeBase,
                    fileManager: fm,
                    copiedCount: &copiedCount
                )
            } else if name.hasPrefix(".env") {
                // This is an env file — copy it
                let relativePath = item.path.dropFirst(sourceBase.path.count)
                let relativeString = String(relativePath).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let destination = worktreeBase.appendingPathComponent(relativeString)

                // Create parent directory if needed
                let destDir = destination.deletingLastPathComponent()
                try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

                // If destination is a symlink (from upstream), replace with a copy
                let attrs = try? fm.attributesOfItem(atPath: destination.path)
                if attrs?[.type] as? FileAttributeType == .typeSymbolicLink {
                    try? fm.removeItem(at: destination)
                } else if fm.fileExists(atPath: destination.path) {
                    continue
                }

                do {
                    try fm.copyItem(at: item, to: destination)
                    copiedCount += 1
                } catch {
                    logger.warning("Failed to copy \(relativeString, privacy: .public): \(error, privacy: .public)")
                }
            }
        }
    }
}
