// ABOUTME: Generates unique workstream names using operation-adjective-component format.
// ABOUTME: Inspired by Docker's container naming, but with a geeky CS twist.

import Foundation

enum NameGenerator {
    private static let operations = [
        "build", "check", "clean", "clone", "fetch", "fixup", "flush", "merge",
        "parse", "patch", "probe", "prune", "pull", "push", "queue", "route",
        "scan", "serve", "spawn", "split", "start", "stop", "sync", "trace",
        "watch", "debug", "drain", "count", "boot", "bind", "exec", "fork",
        "load", "store", "send", "recv", "emit", "alloc", "free", "map",
        "unmap", "pack", "unzip", "zip", "hash",
    ]

    private static let adjectives = [
        "slow", "fast", "laggy", "busy", "idle", "noisy", "stale", "fresh",
        "clean", "valid", "buggy", "broke", "loose", "tight", "quick", "sharp",
        "solid", "hot", "warm", "cold", "light", "heavy", "clear", "dense",
        "short", "deep", "smart", "dumb", "prime", "eager", "lazy", "async",
        "syncd", "local", "steep", "spiky",
    ]

    private static let components = [
        "alu", "core", "simd", "mmu", "fpu", "reg", "pc", "gpu", "cpu",
        "ram", "rom", "bios", "uefi", "bus", "dma", "tty", "fd", "pipe",
        "fifo", "pty", "inode", "proc", "task", "thr", "lock", "mmap", "epoll",
        "kq", "dns", "tcp", "udp", "http", "https", "tls", "arp", "icmp", "ip",
        "mac", "mtu", "ast", "ssa", "cfg", "dfa", "nfa", "byte", "word",
        "page", "heap", "stack", "cache", "node", "edge", "tree", "graph",
        "table", "index", "key", "val", "blob", "log", "shard", "queue",
        "chan", "topic", "codec", "frame", "model",
    ]

    /// Generate a unique name that doesn't collide with existing names.
    static func generate(avoiding existing: Set<String>) -> String {
        // Total combinations: 45 * 40 * 70 = 126,000
        for _ in 0 ..< 100 {
            let name = [
                operations.randomElement()!,
                adjectives.randomElement()!,
                components.randomElement()!,
            ].joined(separator: "-")

            if !existing.contains(name) {
                return name
            }
        }

        // Extremely unlikely fallback: append a number
        let base = [
            operations.randomElement()!,
            adjectives.randomElement()!,
            components.randomElement()!,
        ].joined(separator: "-")
        var suffix = 2
        while existing.contains("\(base)-\(suffix)") {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }
}
