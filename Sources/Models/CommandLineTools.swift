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

        return resolveFromPath(name, environment)
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
