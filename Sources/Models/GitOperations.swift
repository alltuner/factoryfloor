// ABOUTME: Git operations for project and workstream management.
// ABOUTME: Handles repo detection, init, worktree create/remove, and repo info.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "git")

struct GitRepoInfo {
    let isRepo: Bool
    let branch: String?
    let remoteURL: String?
    let commitCount: Int?
    let isDirty: Bool
}

struct WorktreeInfo: Identifiable {
    let path: String
    let branch: String?
    let isDirty: Bool
    let isMain: Bool

    var id: String {
        path
    }
}

enum GitOperations {
    private static var gitPath: String? {
        CommandLineTools.path(for: "git")
    }

    /// Check if a directory is a git repository.
    static func isGitRepo(at path: String) -> Bool {
        let gitDir = URL(fileURLWithPath: path).appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    /// Initialize a git repo at the given path with an empty initial commit.
    static func initRepo(at path: String) -> Bool {
        guard run(args: ["init"], in: path) != nil else { return false }
        // Create an empty commit so the repo has a HEAD ref, which is
        // required for worktree creation.
        return run(args: ["commit", "--allow-empty", "-m", "Initial commit"], in: path) != nil
    }

    /// Get repo information for display.
    static func repoInfo(at path: String) -> GitRepoInfo {
        guard isGitRepo(at: path) else {
            return GitRepoInfo(isRepo: false, branch: nil, remoteURL: nil, commitCount: nil, isDirty: false)
        }

        let rawBranch = run(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // rev-parse returns literal "HEAD" when in detached state
        let branch = (rawBranch == "HEAD") ? nil : rawBranch

        let remote = run(args: ["remote", "get-url", "origin"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let countStr = run(args: ["rev-list", "--count", "HEAD"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let commitCount = countStr.flatMap(Int.init)

        let status = run(args: ["status", "--porcelain"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let isDirty = status.map { !$0.isEmpty } ?? false

        return GitRepoInfo(
            isRepo: true,
            branch: branch,
            remoteURL: remote,
            commitCount: commitCount,
            isDirty: isDirty
        )
    }

    /// Detect the default branch (origin/main, origin/master, main, master).
    static func defaultBranch(at path: String) -> String {
        // Try remote HEAD first
        if let ref = run(args: ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"], in: path) {
            return ref.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Check if origin/main or origin/master exist
        for branch in ["origin/main", "origin/master"] {
            if run(args: ["rev-parse", "--verify", branch], in: path) != nil {
                return branch
            }
        }
        // Fallback to local main/master
        for branch in ["main", "master"] {
            if run(args: ["rev-parse", "--verify", branch], in: path) != nil {
                return branch
            }
        }
        return "HEAD"
    }

    /// Create a git worktree for a workstream, branching off the default branch.
    /// Returns the worktree path on success, nil on failure.
    static func createWorktree(projectPath: String, projectName: String, workstreamName: String, branchPrefix: String = "ff", symlinkEnv: Bool = true) -> String? {
        let worktreeDir = AppConstants.worktreesDirectory
            .appendingPathComponent(sanitize(projectName))
            .appendingPathComponent(sanitize(workstreamName))

        let branchName = branchPrefix.isEmpty
            ? workstreamName
            : "\(branchPrefix)/\(workstreamName)"

        let baseBranch = defaultBranch(at: projectPath)

        // Create parent directories
        try? FileManager.default.createDirectory(
            at: worktreeDir.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Create worktree with new branch based off the default branch
        let result = run(args: ["worktree", "add", "-b", branchName, worktreeDir.path, baseBranch], in: projectPath)

        if result == nil {
            // Branch might already exist, try without -b
            let fallback = run(args: ["worktree", "add", worktreeDir.path, branchName], in: projectPath)
            guard fallback != nil else { return nil }
        }

        if symlinkEnv {
            symlinkEnvFiles(from: projectPath, to: worktreeDir.path)
        }

        return worktreeDir.path
    }

    /// Symlink .env and .env.local from main repo to worktree if they exist.
    private static func symlinkEnvFiles(from projectPath: String, to worktreePath: String) {
        let envFiles = [".env", ".env.local"]
        let fm = FileManager.default
        for file in envFiles {
            let source = URL(fileURLWithPath: projectPath).appendingPathComponent(file)
            let destination = URL(fileURLWithPath: worktreePath).appendingPathComponent(file)
            guard fm.fileExists(atPath: source.path) else { continue }
            // Skip sources that are themselves symlinks to prevent exposing arbitrary files
            if let attrs = try? fm.attributesOfItem(atPath: source.path),
               let fileType = attrs[.type] as? FileAttributeType,
               fileType != .typeRegular
            {
                continue
            }
            guard !fm.fileExists(atPath: destination.path) else { continue }
            try? fm.createSymbolicLink(at: destination, withDestinationURL: source)
        }
    }

    /// Remove a git worktree.
    static func removeWorktree(projectPath: String, workstreamName: String, projectName: String) {
        let worktreeDir = AppConstants.worktreesDirectory
            .appendingPathComponent(sanitize(projectName))
            .appendingPathComponent(sanitize(workstreamName))

        _ = run(args: ["worktree", "remove", "--force", worktreeDir.path], in: projectPath)

        // Clean up empty directories
        try? FileManager.default.removeItem(at: worktreeDir)
        let projectWorktreeDir = AppConstants.worktreesDirectory.appendingPathComponent(sanitize(projectName))
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: projectWorktreeDir.path), contents.isEmpty {
            try? FileManager.default.removeItem(at: projectWorktreeDir)
        }
    }

    /// Check if a worktree has uncommitted changes (staged, unstaged, or untracked files).
    static func hasUncommittedChanges(at path: String) -> Bool {
        guard let status = run(args: ["status", "--porcelain"], in: path) else { return false }
        return !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// List existing worktrees for a project with branch and dirty status.
    static func listWorktreesWithInfo(at projectPath: String) -> [WorktreeInfo] {
        guard let output = run(args: ["worktree", "list", "--porcelain"], in: projectPath) else {
            return []
        }

        let mainPath = URL(fileURLWithPath: projectPath).standardizedFileURL.path

        var results: [WorktreeInfo] = []
        var currentPath: String?
        var currentBranch: String?

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                // Flush previous entry
                if let path = currentPath {
                    let isMain = URL(fileURLWithPath: path).standardizedFileURL.path == mainPath
                    let dirty = !isMain && hasUncommittedChanges(at: path)
                    results.append(WorktreeInfo(path: path, branch: currentBranch, isDirty: dirty, isMain: isMain))
                }
                currentPath = String(line.dropFirst("worktree ".count))
                currentBranch = nil
            } else if line.hasPrefix("branch refs/heads/") {
                currentBranch = String(line.dropFirst("branch refs/heads/".count))
            }
        }
        // Flush last entry
        if let path = currentPath {
            let isMain = URL(fileURLWithPath: path).standardizedFileURL.path == mainPath
            let dirty = !isMain && hasUncommittedChanges(at: path)
            results.append(WorktreeInfo(path: path, branch: currentBranch, isDirty: dirty, isMain: isMain))
        }

        return results
    }

    /// Remove all worktrees that have no uncommitted changes. Returns count of pruned worktrees.
    @discardableResult
    static func pruneCleanWorktrees(at projectPath: String) -> Int {
        let worktrees = listWorktreesWithInfo(at: projectPath)
        var pruned = 0
        for wt in worktrees where !wt.isMain && !wt.isDirty {
            let result = run(args: ["worktree", "remove", wt.path], in: projectPath)
            if result != nil {
                pruned += 1
            }
        }
        // Clean up stale entries
        _ = run(args: ["worktree", "prune"], in: projectPath)
        return pruned
    }

    /// If the given path is a git worktree (not the main repository), return the main
    /// repository path. Returns nil for non-git directories or main repositories.
    static func mainRepositoryPath(for path: String) -> String? {
        let gitEntry = URL(fileURLWithPath: path).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitEntry.path, isDirectory: &isDir) else {
            return nil
        }
        // .git is a directory in main repos, a file in worktrees
        guard !isDir.boolValue else {
            return nil
        }

        guard let commonDir = run(args: ["rev-parse", "--git-common-dir"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            return nil
        }

        let commonURL: URL
        if commonDir.hasPrefix("/") {
            commonURL = URL(fileURLWithPath: commonDir)
        } else {
            commonURL = URL(fileURLWithPath: path).appendingPathComponent(commonDir).standardized
        }

        return commonURL.deletingLastPathComponent().standardizedFileURL.path
    }

    // MARK: - Private

    private static func sanitize(_ name: String) -> String {
        var result = name.replacingOccurrences(of: "/", with: "--")
            .replacingOccurrences(of: " ", with: "-")
        // Prevent names from being interpreted as git flags
        while result.hasPrefix("-") {
            result = String(result.dropFirst())
        }
        return result.isEmpty ? "unnamed" : result
    }

    private static func run(args: [String], in directory: String) -> String? {
        guard let gitPath else {
            logger.warning("[FF] git run: gitPath is nil")
            return nil
        }
        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                logger.warning("[FF] git \(args.joined(separator: " "), privacy: .public) failed (exit \(process.terminationStatus, privacy: .public)): \(errStr, privacy: .public)")
                return nil
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            logger.warning("[FF] git \(args.joined(separator: " "), privacy: .public) threw: \(error, privacy: .public)")
            return nil
        }
    }
}
