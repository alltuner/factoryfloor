// ABOUTME: Detects which Node.js package manager a project uses by checking lock files.
// ABOUTME: Returns the detected package manager and its install command for worktree setup.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.packagemanager")

enum PackageManagerDetector {
    struct Result: Sendable {
        let packageManager: VibeConfig.PackageManager
        let installCommand: [String]
    }

    /// Detect the package manager used in the given project directory.
    /// Checks lock files first, falls back to VibeConfig override, then defaults to npm if package.json exists.
    static func detect(in directory: String, config: VibeConfig? = nil) -> Result? {
        let fm = FileManager.default

        // If config explicitly specifies a package manager, use it
        if let pm = config?.packageManager {
            logger.info("Using package manager from config: \(pm.rawValue, privacy: .public)")
            return Result(packageManager: pm, installCommand: pm.installCommand)
        }

        let lockFiles: [(String, VibeConfig.PackageManager)] = [
            ("bun.lockb", .bun),
            ("pnpm-lock.yaml", .pnpm),
            ("yarn.lock", .yarn),
            ("package-lock.json", .npm),
        ]

        for (lockFile, pm) in lockFiles {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(lockFile).path
            if fm.fileExists(atPath: path) {
                logger.info("Detected \(pm.rawValue, privacy: .public) from \(lockFile, privacy: .public)")
                return Result(packageManager: pm, installCommand: pm.installCommand)
            }
        }

        // Fallback: if package.json exists but no lock file, default to npm
        let packageJsonPath = URL(fileURLWithPath: directory).appendingPathComponent("package.json").path
        if fm.fileExists(atPath: packageJsonPath) {
            logger.info("No lock file found but package.json exists, defaulting to npm")
            return Result(packageManager: .npm, installCommand: VibeConfig.PackageManager.npm.installCommand)
        }

        return nil
    }
}
