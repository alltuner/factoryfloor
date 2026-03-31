// ABOUTME: Resolves full paths for command line tools the app launches directly.
// ABOUTME: Keeps tool detection and process execution consistent across app builds.

import Foundation

enum CommandLineTools {
    static func path(
        for name: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        resolveFromPath: (String, [String: String]) -> String? = { name, environment in
            pathFromEnvironment(named: name, environment: environment)
        },
        resolveFromShellPath: (String) -> String? = { shell in
            loginShellPath(shell: shell)
        }
    ) -> String? {
        let knownLocations = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
        ]

        for location in knownLocations where isExecutable(location) {
            return location
        }

        if let found = resolveFromPath(name, environment) {
            return found
        }

        // GUI apps inherit a minimal PATH from launchd. Resolve the user's
        // login shell PATH to find tools in non-standard locations.
        guard let shell = environment["SHELL"], !shell.isEmpty else { return nil }
        guard let shellPath = resolveFromShellPath(shell) else { return nil }

        for directory in shellPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if isExecutable(candidate) {
                return candidate
            }
        }

        return nil
    }

    private static let shellPathCache = ShellPathCache()

    static func loginShellPath(shell: String) -> String? {
        shellPathCache.resolve(shell: shell)
    }

    private final class ShellPathCache: Sendable {
        private let lock = NSLock()
        private let storage = MutableBox()

        /// Mutable state isolated behind NSLock
        private final class MutableBox: @unchecked Sendable {
            var resolved = false
            var path: String?
        }

        func resolve(shell: String) -> String? {
            lock.lock()
            defer { lock.unlock() }

            if storage.resolved { return storage.path }
            storage.resolved = true

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-lic", "echo $PATH"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                storage.path = result
                return result
            } catch {
                return nil
            }
        }
    }

    private static func pathFromEnvironment(named name: String, environment: [String: String]) -> String? {
        guard let rawPath = environment["PATH"], !rawPath.isEmpty else { return nil }

        for directory in rawPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }
}
