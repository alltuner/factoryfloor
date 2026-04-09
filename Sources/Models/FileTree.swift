// ABOUTME: FileNode tree model built from FileManager directory enumeration.
// ABOUTME: DirectoryWatcher uses FSEventStream for real-time recursive file system monitoring.

import Foundation

// MARK: - FileNode

struct FileNode: Identifiable {
    let id: String // relative path from worktree root (empty string for root)
    let name: String // last path component
    let isDirectory: Bool
    var children: [FileNode]

    /// Build a file tree by recursively enumerating a directory.
    /// Skips `.git`. Sorts directories first, then files, alphabetical case-insensitive.
    static func buildTree(rootPath: String) -> [FileNode] {
        buildChildren(at: rootPath, relativeTo: rootPath)
    }

    private static func buildChildren(at directoryPath: String, relativeTo rootPath: String) -> [FileNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: directoryPath) else {
            return []
        }

        var dirs: [FileNode] = []
        var files: [FileNode] = []

        for entry in entries {
            if entry == ".git" { continue }

            let fullPath = (directoryPath as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

            let relativePath: String
            if rootPath.hasSuffix("/") {
                relativePath = String(fullPath.dropFirst(rootPath.count))
            } else {
                relativePath = String(fullPath.dropFirst(rootPath.count + 1))
            }

            if isDir.boolValue {
                let children = buildChildren(at: fullPath, relativeTo: rootPath)
                dirs.append(FileNode(id: relativePath, name: entry, isDirectory: true, children: children))
            } else {
                files.append(FileNode(id: relativePath, name: entry, isDirectory: false, children: []))
            }
        }

        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return dirs + files
    }
}

// MARK: - DirectoryWatcher

/// Watches a directory tree for changes using macOS FSEventStream.
/// Calls `onChange` on the main thread when files are created, deleted, or renamed.
final class DirectoryWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(path: String, onChange: @escaping () -> Void) {
        self.onChange = onChange

        let pathsToWatch = [path] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            DirectoryWatcher.callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // 1 second coalescing latency
            FSEventStreamCreateFlags(flags)
        ) else { return }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }

    private static let callback: FSEventStreamCallback = {
        _, clientCallBackInfo, _, _, _, _ in
        guard let info = clientCallBackInfo else { return }
        let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
        DispatchQueue.main.async {
            watcher.onChange()
        }
    }
}
