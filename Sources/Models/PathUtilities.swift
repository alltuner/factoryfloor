// ABOUTME: Shared path and UUID utilities used across the app.
// ABOUTME: Provides path abbreviation and deterministic UUID derivation.

import Foundation

/// Deterministic UUID derived from a base UUID and a salt string.
/// Uses simple byte-folding to produce fully deterministic output (no random bytes).
func derivedUUID(from base: UUID, salt: String) -> UUID {
    // Build a deterministic byte sequence from the base UUID and salt
    let input = "\(base.uuidString)-\(salt)"
    // Simple deterministic hash using all characters
    var bytes: [UInt8] = Array(repeating: 0, count: 16)
    for (i, byte) in input.utf8.enumerated() {
        bytes[i % 16] = bytes[i % 16] &+ byte &+ UInt8(i & 0xFF)
    }
    // Set version 4 and variant bits for valid UUID format
    bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant 1
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                       bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11],
                       bytes[12], bytes[13], bytes[14], bytes[15]))
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

extension String {
    /// Replaces the home directory prefix with ~ for compact display.
    var abbreviatedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if hasPrefix(home) {
            return "~" + dropFirst(home.count)
        }
        return self
    }
}
