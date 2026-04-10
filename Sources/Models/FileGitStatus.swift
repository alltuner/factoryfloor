// ABOUTME: Git file status types and a provider that resolves status for files and directories.
// ABOUTME: Directories inherit status from their children; ignored ancestors propagate to descendants.

import Foundation

enum FileGitStatus {
    case modified // M, A, D, R, C in either index or worktree
    case untracked // ??
    case ignored // !!
}

struct GitFileStatusProvider {
    let fileStatuses: [String: FileGitStatus]
    /// Directory paths that are ignored (from `!! dir/` entries).
    let ignoredDirectories: Set<String>

    init(fileStatuses: [String: FileGitStatus] = [:]) {
        self.fileStatuses = fileStatuses
        var dirs = Set<String>()
        for (path, status) in fileStatuses where status == .ignored {
            // Heuristic: if the path itself isn't a file status entry with a different type,
            // and it appears as a directory prefix for other entries, treat it as a directory.
            // We also store all ignored entries as potential directory prefixes — the ancestor
            // check in isIgnored will handle both files and directories correctly.
            dirs.insert(path)
        }
        ignoredDirectories = dirs
    }

    /// Status for a file or directory. Directories derive status from children.
    func status(for relativePath: String, isDirectory: Bool) -> FileGitStatus? {
        if !isDirectory {
            return fileStatuses[relativePath]
        }
        // Directory: scan for children with status
        let prefix = relativePath + "/"
        var hasModified = false
        var hasUntracked = false
        for (path, status) in fileStatuses {
            guard path.hasPrefix(prefix) else { continue }
            switch status {
            case .modified: hasModified = true
            case .untracked: hasUntracked = true
            case .ignored: continue
            }
        }
        if hasModified { return .modified }
        if hasUntracked { return .untracked }
        return nil
    }

    /// Whether a path is gitignored (exact match or inside an ignored ancestor directory).
    func isIgnored(_ relativePath: String) -> Bool {
        if fileStatuses[relativePath] == .ignored { return true }
        // Check if any ancestor directory is ignored
        var current = relativePath
        while let slashIndex = current.lastIndex(of: "/") {
            current = String(current[current.startIndex ..< slashIndex])
            if ignoredDirectories.contains(current) { return true }
        }
        return false
    }
}
