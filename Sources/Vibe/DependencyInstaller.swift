// ABOUTME: Runs the appropriate package manager install command in a worktree.
// ABOUTME: Only installs if package.json exists and node_modules is not symlinked.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.deps")

enum DependencyInstaller {
    struct InstallResult: Sendable {
        let success: Bool
        let output: String
        let errorOutput: String
    }

    /// Check whether dependency installation is needed in the worktree.
    /// Returns false if no package.json exists or if node_modules is already symlinked.
    static func needsInstall(in worktreeDir: String) -> Bool {
        let fm = FileManager.default
        let packageJson = URL(fileURLWithPath: worktreeDir).appendingPathComponent("package.json").path
        let nodeModules = URL(fileURLWithPath: worktreeDir).appendingPathComponent("node_modules").path

        guard fm.fileExists(atPath: packageJson) else { return false }

        // If node_modules is a symlink, deps are shared — no install needed
        if let attrs = try? fm.attributesOfItem(atPath: nodeModules),
           let fileType = attrs[.type] as? FileAttributeType,
           fileType == .typeSymbolicLink
        {
            return false
        }

        return true
    }

    /// Run the install command for the detected package manager.
    /// Returns nil if no install is needed, otherwise returns the result.
    static func install(
        in worktreeDir: String,
        config: VibeConfig? = nil
    ) -> InstallResult? {
        guard needsInstall(in: worktreeDir) else {
            logger.info("No dependency install needed in \(worktreeDir, privacy: .public)")
            return nil
        }

        guard let detected = PackageManagerDetector.detect(in: worktreeDir, config: config) else {
            logger.info("No package manager detected in \(worktreeDir, privacy: .public)")
            return nil
        }

        let command = detected.installCommand
        logger.info("Running \(command.joined(separator: " "), privacy: .public) in \(worktreeDir, privacy: .public)")

        guard let toolPath = CommandLineTools.path(for: command[0]) else {
            logger.warning("Could not find \(command[0], privacy: .public) in PATH")
            return InstallResult(
                success: false,
                output: "",
                errorOutput: "Could not find \(command[0]) in PATH"
            )
        }

        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = Array(command.dropFirst())
        process.currentDirectoryURL = URL(fileURLWithPath: worktreeDir)
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errData, encoding: .utf8) ?? ""

            let success = process.terminationStatus == 0
            if success {
                logger.info("Dependency install completed successfully")
            } else {
                logger.warning("Dependency install failed (exit \(process.terminationStatus, privacy: .public)): \(errorOutput, privacy: .public)")
            }

            return InstallResult(success: success, output: output, errorOutput: errorOutput)
        } catch {
            logger.warning("Failed to run \(command[0], privacy: .public): \(error, privacy: .public)")
            return InstallResult(success: false, output: "", errorOutput: error.localizedDescription)
        }
    }
}
