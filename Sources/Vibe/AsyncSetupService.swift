// ABOUTME: Actor that runs vibe worktree setup steps with async progress reporting.
// ABOUTME: Claude Code launches immediately after worktree creation; deps install in background.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "vibe.asyncsetup")

/// Represents the current state of async worktree setup.
enum AsyncSetupState: Sendable, Equatable {
    case idle
    case inProgress(step: String, progress: Double)
    case completed
    case failed(String)

    static func == (lhs: AsyncSetupState, rhs: AsyncSetupState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.completed, .completed): return true
        case let (.inProgress(ls, lp), .inProgress(rs, rp)): return ls == rs && lp == rp
        case let (.failed(l), .failed(r)): return l == r
        default: return false
        }
    }
}

/// Notification posted on the main thread whenever setup state changes.
/// `userInfo` contains "workstreamID" (UUID) and "state" (AsyncSetupState).
extension Notification.Name {
    static let asyncSetupStateChanged = Notification.Name("factoryfloor.asyncSetupStateChanged")
}

/// Actor that orchestrates vibe worktree setup asynchronously.
/// The key insight: Claude Code can start immediately after `git worktree add` completes.
/// Env copy, symlinks, Claude settings, and dep install run in the background.
actor AsyncSetupService {
    /// Shared singleton for app-wide access.
    static let shared = AsyncSetupService()

    /// Track per-workstream setup state.
    private var states: [UUID: AsyncSetupState] = [:]

    /// Get the current setup state for a workstream.
    func state(for workstreamID: UUID) -> AsyncSetupState {
        states[workstreamID] ?? .idle
    }

    /// Run the full async setup for a new vibe workstream.
    ///
    /// This method:
    /// 1. Creates the git worktree (blocking — must complete before anything else)
    /// 2. Returns the worktree path immediately so the caller can launch Claude Code
    /// 3. Kicks off background setup (env files, symlinks, Claude settings, deps)
    ///
    /// - Parameters:
    ///   - workstreamID: The UUID of the workstream being set up
    ///   - projectPath: Path to the main project/repo root
    ///   - projectName: Name of the project
    ///   - workstreamName: Name for the new workstream/branch
    ///   - branchPrefix: Prefix for the git branch (default: "vibe")
    /// - Returns: The worktree path if worktree creation succeeded, nil otherwise.
    func setup(
        workstreamID: UUID,
        projectPath: String,
        projectName: String,
        workstreamName: String,
        branchPrefix: String = "vibe"
    ) async -> String? {
        // Step 1: Create worktree (must complete first)
        await updateState(for: workstreamID, to: .inProgress(step: "Creating worktree", progress: 0.1))

        let worktreePath: String? = await withCheckedContinuation { continuation in
            // Run git worktree add on a background thread since it's a blocking Process call
            DispatchQueue.global(qos: .userInitiated).async {
                let path = GitOperations.createWorktree(
                    projectPath: projectPath,
                    projectName: projectName,
                    workstreamName: workstreamName,
                    branchPrefix: branchPrefix,
                    symlinkEnv: false // We handle env files ourselves
                )
                continuation.resume(returning: path)
            }
        }

        guard let worktreePath else {
            logger.warning("Failed to create worktree for \(workstreamName, privacy: .public)")
            await updateState(for: workstreamID, to: .failed("Failed to create git worktree"))
            return nil
        }

        logger.info("Worktree created at \(worktreePath, privacy: .public), starting background setup")

        // Step 2: Terminal launch happens in the caller — we just report progress.
        await updateState(for: workstreamID, to: .inProgress(step: "Terminal ready", progress: 0.2))

        // Step 3-6: Background setup — fire and forget from the caller's perspective.
        // The caller gets the worktree path back immediately.
        Task {
            await runBackgroundSetup(
                workstreamID: workstreamID,
                projectPath: projectPath,
                worktreePath: worktreePath
            )
        }

        return worktreePath
    }

    /// Run the background setup steps after worktree creation.
    /// These steps do NOT block Claude Code from launching.
    private func runBackgroundSetup(
        workstreamID: UUID,
        projectPath: String,
        worktreePath: String
    ) async {
        let config = VibeConfig.load(from: projectPath)
        var errors: [String] = []

        // Step 3: Copy env files
        await updateState(for: workstreamID, to: .inProgress(step: "Copying env files", progress: 0.3))
        let envCount: Int = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let count = EnvFileCopier.copyEnvFiles(from: projectPath, to: worktreePath)
                continuation.resume(returning: count)
            }
        }
        logger.info("Copied \(envCount) env file(s)")

        // Step 4: Create symlinks
        await updateState(for: workstreamID, to: .inProgress(step: "Creating symlinks", progress: 0.5))
        let symlinkCount: Int = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let count = SymlinkCreator.createSymlinks(
                    from: projectPath,
                    to: worktreePath,
                    config: config
                )
                continuation.resume(returning: count)
            }
        }
        logger.info("Created \(symlinkCount) symlink(s)")

        // Step 5: Set up Claude settings
        await updateState(for: workstreamID, to: .inProgress(step: "Setting up Claude settings", progress: 0.6))
        let claudeLinked: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let linked = ClaudeSettingsSetup.setup(from: projectPath, to: worktreePath)
                continuation.resume(returning: linked)
            }
        }
        logger.info("Claude settings linked: \(claudeLinked)")

        // Step 6: Install dependencies (longest step)
        await updateState(for: workstreamID, to: .inProgress(step: "Installing dependencies", progress: 0.7))
        logger.warning("[SETUP-DEBUG] About to run DependencyInstaller.install in \(worktreePath, privacy: .public)")
        let installResult: DependencyInstaller.InstallResult? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let result = DependencyInstaller.install(in: worktreePath, config: config)
                continuation.resume(returning: result)
            }
        }
        if let result = installResult {
            logger.warning("[SETUP-DEBUG] Install result: success=\(result.success) output=\(result.output.prefix(200), privacy: .public) error=\(result.errorOutput.prefix(200), privacy: .public)")
        } else {
            logger.warning("[SETUP-DEBUG] Install returned nil (needsInstall=false or no package manager)")
        }
        if let result = installResult, !result.success {
            errors.append("Dependency install failed: \(result.errorOutput)")
            logger.warning("Dependency install failed: \(result.errorOutput, privacy: .public)")
        }

        // Step 7: Post-setup commands
        await updateState(for: workstreamID, to: .inProgress(step: "Running post-setup commands", progress: 0.9))
        for command in config.postSetupCommands {
            let success: Bool = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    let ok = ShellCommand.run(command, in: worktreePath)
                    continuation.resume(returning: ok)
                }
            }
            if !success {
                errors.append("Post-setup command failed: \(command)")
            }
        }

        // Done
        if errors.isEmpty {
            await updateState(for: workstreamID, to: .completed)
            logger.info("Async setup completed successfully for \(worktreePath, privacy: .public)")
        } else {
            let errorMsg = errors.joined(separator: "; ")
            await updateState(for: workstreamID, to: .failed(errorMsg))
            logger.warning("Async setup completed with errors: \(errorMsg, privacy: .public)")
        }
    }

    /// Update state and post notification to main thread.
    private func updateState(for workstreamID: UUID, to newState: AsyncSetupState) async {
        states[workstreamID] = newState
        let state = newState
        await MainActor.run {
            NotificationCenter.default.post(
                name: .asyncSetupStateChanged,
                object: nil,
                userInfo: ["workstreamID": workstreamID, "state": state]
            )
        }
    }

    /// Run background setup on a worktree that was already created externally.
    /// Use this when the worktree was created by upstream GitOperations
    /// and we just need to run the vibe-specific setup steps.
    func setupExistingWorktree(
        workstreamID: UUID,
        projectPath: String,
        worktreePath: String
    ) async {
        await updateState(for: workstreamID, to: .inProgress(step: "Setting up workspace", progress: 0.2))
        await runBackgroundSetup(
            workstreamID: workstreamID,
            projectPath: projectPath,
            worktreePath: worktreePath
        )
    }

    /// Remove tracked state for a workstream (cleanup after archiving).
    func clearState(for workstreamID: UUID) {
        states.removeValue(forKey: workstreamID)
    }

}
