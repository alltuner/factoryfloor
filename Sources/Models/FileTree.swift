// ABOUTME: FileNode tree model with lazy directory loading (children loaded on expand).
// ABOUTME: DirectoryWatcher uses FSEventStream for real-time recursive file system monitoring.

import Foundation

// MARK: - FileNode

struct FileNode: Identifiable {
    let id: String // relative path from worktree root (empty string for root)
    let name: String // last path component
    let isDirectory: Bool
    var children: [FileNode]? // nil = not yet loaded (lazy), [] = loaded but empty

    /// Whether this directory's children have been loaded.
    var isLoaded: Bool {
        children != nil
    }

    /// Build a shallow tree (root level only). Directory children are nil (lazy).
    static func buildShallowTree(rootPath: String) -> [FileNode] {
        buildShallowChildren(at: rootPath, relativeTo: rootPath)
    }

    /// Load immediate children of a single directory. Directories get children = nil (lazy).
    static func loadChildren(atRelativePath relativePath: String, rootPath: String) -> [FileNode] {
        let dirPath = relativePath.isEmpty
            ? rootPath
            : (rootPath as NSString).appendingPathComponent(relativePath)
        return buildShallowChildren(at: dirPath, relativeTo: rootPath)
    }

    /// Insert loaded children at a specific path in the tree, returning the updated tree.
    static func insertChildren(_ children: [FileNode], atPath path: String, in nodes: [FileNode]) -> [FileNode] {
        nodes.map { node in
            if node.id == path, node.isDirectory {
                return FileNode(id: node.id, name: node.name, isDirectory: true, children: children)
            } else if node.isDirectory, let nodeChildren = node.children, path.hasPrefix(node.id + "/") {
                let updatedChildren = insertChildren(children, atPath: path, in: nodeChildren)
                return FileNode(id: node.id, name: node.name, isDirectory: true, children: updatedChildren)
            }
            return node
        }
    }

    /// Ensure all ancestor directories for a file path are loaded. Returns the updated tree.
    static func ensureAncestorsLoaded(for filePath: String, in nodes: [FileNode], rootPath: String) -> [FileNode] {
        let components = filePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return nodes }

        var result = nodes
        var current = ""
        for component in components.dropLast() {
            current = current.isEmpty ? component : current + "/" + component
            if let node = findNode(atPath: current, in: result), node.isDirectory, !node.isLoaded {
                let children = loadChildren(atRelativePath: current, rootPath: rootPath)
                result = insertChildren(children, atPath: current, in: result)
            }
        }
        return result
    }

    /// Refresh all previously-loaded nodes, preserving lazy structure for unloaded directories.
    static func refreshLoadedNodes(in nodes: [FileNode], rootPath: String) -> [FileNode] {
        let freshRoot = buildShallowChildren(at: rootPath, relativeTo: rootPath)
        return mergeNodes(fresh: freshRoot, existing: nodes, rootPath: rootPath)
    }

    // MARK: - Lookup

    static func findNode(atPath path: String, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.id == path { return node }
            if node.isDirectory, let children = node.children, path.hasPrefix(node.id + "/") {
                if let found = findNode(atPath: path, in: children) { return found }
            }
        }
        return nil
    }

    private static func buildShallowChildren(at directoryPath: String, relativeTo rootPath: String) -> [FileNode] {
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
                dirs.append(FileNode(id: relativePath, name: entry, isDirectory: true, children: nil))
            } else {
                files.append(FileNode(id: relativePath, name: entry, isDirectory: false, children: []))
            }
        }

        dirs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return dirs + files
    }

    /// Merge fresh shallow nodes with existing tree, preserving loaded children.
    private static func mergeNodes(fresh: [FileNode], existing: [FileNode], rootPath: String) -> [FileNode] {
        let existingByID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        return fresh.map { freshNode in
            if freshNode.isDirectory,
               let existingNode = existingByID[freshNode.id],
               existingNode.isLoaded
            {
                // Previously loaded — refresh its children recursively
                let dirPath = (rootPath as NSString).appendingPathComponent(freshNode.id)
                let freshChildren = buildShallowChildren(at: dirPath, relativeTo: rootPath)
                let mergedChildren = mergeNodes(
                    fresh: freshChildren,
                    existing: existingNode.children ?? [],
                    rootPath: rootPath
                )
                return FileNode(id: freshNode.id, name: freshNode.name, isDirectory: true, children: mergedChildren)
            } else {
                return freshNode
            }
        }
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
