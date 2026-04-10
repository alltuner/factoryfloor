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
    let hasUnpushedCommits: Bool
    let hasBranchCommits: Bool

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

        let status = run(args: ["status", "--porcelain", "--ignore-submodules=dirty"], in: path)?
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

        // Fetch the default branch so worktrees start from the latest remote ref
        fetchDefaultBranch(at: projectPath)

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

        addExcludeEntry(at: projectPath, pattern: ".factoryfloor-state/")

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

    /// Append a pattern to .git/info/exclude if not already present.
    private static func addExcludeEntry(at repoPath: String, pattern: String) {
        let excludeURL = URL(fileURLWithPath: repoPath).appendingPathComponent(".git/info/exclude")
        let fm = FileManager.default

        // Ensure the info directory exists
        let infoDir = excludeURL.deletingLastPathComponent()
        try? fm.createDirectory(at: infoDir, withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: excludeURL, encoding: .utf8)) ?? ""
        let lines = existing.components(separatedBy: .newlines)
        if lines.contains(pattern) { return }

        let entry = existing.hasSuffix("\n") || existing.isEmpty ? pattern + "\n" : "\n" + pattern + "\n"
        if let data = entry.data(using: .utf8), let handle = try? FileHandle(forWritingTo: excludeURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            try? (existing + entry).write(to: excludeURL, atomically: true, encoding: .utf8)
        }
    }

    /// Remove a git worktree.
    static func removeWorktree(projectPath: String, worktreePath: String) {
        let worktreeDir = URL(fileURLWithPath: worktreePath)

        _ = run(args: ["worktree", "remove", "--force", worktreePath], in: projectPath)

        // Clean up empty directories
        try? FileManager.default.removeItem(at: worktreeDir)
        let parentDir = worktreeDir.deletingLastPathComponent()
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: parentDir.path), contents.isEmpty {
            try? FileManager.default.removeItem(at: parentDir)
        }
    }

    /// Check if a worktree has uncommitted changes (staged, unstaged, or untracked files).
    static func hasUncommittedChanges(at path: String) -> Bool {
        guard let status = run(args: ["status", "--porcelain", "--ignore-submodules=dirty"], in: path) else { return false }
        return !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if the current branch has commits not yet pushed to its upstream.
    static func hasUnpushedCommits(at path: String) -> Bool {
        guard let output = run(args: ["log", "@{upstream}..HEAD", "--oneline"], in: path) else {
            // No upstream set means everything is unpushed (if there are commits)
            guard let commits = run(args: ["log", "--oneline", "-1"], in: path) else { return false }
            return !commits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if the current branch has commits ahead of the default branch.
    static func hasBranchCommits(at path: String, projectPath: String) -> Bool {
        let base = defaultBranch(at: projectPath)
        guard let output = run(args: ["log", "\(base)..HEAD", "--oneline"], in: path) else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Check if a remote exists for this repository.
    static func hasRemote(at path: String) -> Bool {
        guard let output = run(args: ["remote"], in: path) else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Push the current branch to origin, setting upstream if needed.
    static func pushCurrentBranch(at path: String) -> (success: Bool, output: String) {
        guard let gitPath else { return (false, "git not found") }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = ["-C", path, "push", "-u", "origin", "HEAD"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
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
                    let unpushed = !isMain && hasUnpushedCommits(at: path)
                    let branchCommits = !isMain && hasBranchCommits(at: path, projectPath: projectPath)
                    results.append(WorktreeInfo(path: path, branch: currentBranch, isDirty: dirty, isMain: isMain, hasUnpushedCommits: unpushed, hasBranchCommits: branchCommits))
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
            let unpushed = !isMain && hasUnpushedCommits(at: path)
            let branchCommits = !isMain && hasBranchCommits(at: path, projectPath: projectPath)
            results.append(WorktreeInfo(path: path, branch: currentBranch, isDirty: dirty, isMain: isMain, hasUnpushedCommits: unpushed, hasBranchCommits: branchCommits))
        }

        return results
    }

    /// Remove clean worktrees (no uncommitted changes and no unmerged branch commits).
    /// When `onlyPaths` is provided, only those worktree paths are considered.
    @discardableResult
    static func pruneCleanWorktrees(at projectPath: String, onlyPaths: Set<String>? = nil) -> Int {
        let worktrees = listWorktreesWithInfo(at: projectPath)
        let allowedPaths = onlyPaths.map { paths in
            Set(paths.map { path in
                URL(fileURLWithPath: path).standardizedFileURL.path
            })
        }
        var pruned = 0
        for wt in worktrees where !wt.isMain && !wt.isDirty && !wt.hasBranchCommits {
            let standardizedPath = URL(fileURLWithPath: wt.path).standardizedFileURL.path
            if let allowedPaths, !allowedPaths.contains(standardizedPath) {
                continue
            }
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

    /// Return the current branch name, or nil if detached or not a repo.
    static func currentBranch(at path: String) -> String? {
        guard let raw = run(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: path)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return raw == "HEAD" ? nil : raw
    }

    /// Delete a local branch by name.
    static func deleteLocalBranch(at path: String, branchName: String) {
        _ = run(args: ["branch", "-D", branchName], in: path)
    }

    /// Fetch the default branch from origin, fast-forward the local ref to match,
    /// and reset the working tree if it is clean. Fails silently when there is no
    /// remote, the network is unreachable, or the working tree has local changes.
    static func updateDefaultBranch(at path: String) {
        guard run(args: ["remote", "get-url", "origin"], in: path) != nil else { return }

        let branch: String
        if let ref = run(args: ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"], in: path) {
            branch = ref.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "origin/", with: "")
        } else if run(args: ["rev-parse", "--verify", "refs/heads/main"], in: path) != nil {
            branch = "main"
        } else if run(args: ["rev-parse", "--verify", "refs/heads/master"], in: path) != nil {
            branch = "master"
        } else {
            return
        }

        // Fetch with timeout so we don't block the UI
        guard runWithTimeout(args: ["fetch", "origin", branch, "--no-tags"], in: path, timeout: 5) != nil else {
            return
        }

        // Move the local ref to match origin
        guard run(args: ["update-ref", "refs/heads/\(branch)", "refs/remotes/origin/\(branch)"], in: path) != nil else {
            return
        }

        // Reset the working tree only if it is clean
        if !hasUncommittedChanges(at: path) {
            _ = run(args: ["reset", "--hard", "--quiet"], in: path)
            logger.info("[FF] Updated \(branch, privacy: .public) to latest")
        } else {
            logger.info("[FF] Updated \(branch, privacy: .public) ref but working tree has local changes, skipping reset")
        }
    }

    /// Per-file git status for the file tree (modified, untracked, ignored).
    /// Returns an empty dictionary on failure so the tree degrades gracefully.
    static func fileStatuses(at path: String) -> [String: FileGitStatus] {
        guard let output = runWithTimeout(
            args: ["status", "--porcelain", "--ignored", "--ignore-submodules=dirty"],
            in: path,
            timeout: 3
        ) else {
            return [:]
        }

        var result: [String: FileGitStatus] = [:]
        for line in output.components(separatedBy: "\n") {
            guard line.count >= 4 else { continue }
            let xy = String(line.prefix(2))
            var filePath = String(line.dropFirst(3))

            if xy == "!!" {
                // Ignored — strip trailing slash for directories
                if filePath.hasSuffix("/") { filePath = String(filePath.dropLast()) }
                result[filePath] = .ignored
            } else if xy == "??" {
                result[filePath] = .untracked
            } else {
                // Handle renames/copies: "R  old -> new" or "C  old -> new"
                if let arrowRange = filePath.range(of: " -> ") {
                    let newPath = String(filePath[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    result[newPath] = .modified
                } else {
                    result[filePath] = .modified
                }
            }
        }
        return result
    }

    // MARK: - Private

    /// Fetch the default branch from origin. Fails silently when there is no
    /// remote or the network is unreachable.
    static func fetchDefaultBranch(at path: String) {
        // Check if origin remote exists first (fast, no network)
        guard run(args: ["remote", "get-url", "origin"], in: path) != nil else { return }

        // Determine which branch to fetch
        let branch: String
        if let ref = run(args: ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"], in: path) {
            // e.g. "origin/main" -> "main"
            branch = ref.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "origin/", with: "")
        } else {
            branch = "main"
        }

        // Fetch with timeout — don't block worktree creation
        runWithTimeout(args: ["fetch", "origin", branch, "--no-tags"], in: path, timeout: 5)
    }

    @discardableResult
    private static func runWithTimeout(args: [String], in directory: String, timeout: TimeInterval) -> String? {
        guard let gitPath else { return nil }
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
        } catch {
            return nil
        }

        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }

        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            logger.info("[FF] git \(args.joined(separator: " "), privacy: .public) timed out after \(timeout, privacy: .public)s")
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

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
