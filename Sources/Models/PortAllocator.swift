// ABOUTME: Derives a deterministic port number from a workstream path.
// ABOUTME: Port range 40001-49999, unique per worktree to avoid collisions.

import Foundation

enum PortAllocator {
    static let rangeStart = 40001
    static let rangeEnd = 49999

    /// Derive a deterministic port from the working directory path.
    static func port(for path: String) -> Int {
        var hasher = Hasher()
        hasher.combine(path)
        let hash = abs(hasher.finalize())
        let range = rangeEnd - rangeStart + 1
        return rangeStart + (hash % range)
    }
}
