// ABOUTME: Resolves the bundled ff-run helper and builds wrapped run-script commands.
// ABOUTME: Keeps Environment tab command assembly small and consistent across tmux modes.

import Foundation
import os

private let logger = Logger(subsystem: "factoryfloor", category: "run-launcher")

enum RunLauncher {
    static func executableURL(bundle: Bundle = .main) -> URL? {
        let helperURL = bundle.bundleURL.appendingPathComponent("Contents/Helpers/ff-run")
        if FileManager.default.isExecutableFile(atPath: helperURL.path) {
            return helperURL
        }

        if let executableURL = bundle.executableURL {
            let siblingURL = executableURL.deletingLastPathComponent().appendingPathComponent("ff-run")
            if FileManager.default.isExecutableFile(atPath: siblingURL.path) {
                return siblingURL
            }
        }

        logger.warning("ff-run helper not found, port detection will be unavailable")
        return nil
    }
}

func runScriptCommand(script: String, workstreamID: UUID, launcherPath: String, shell: String = CommandBuilder.userShell) -> String {
    let workstream = workstreamID.uuidString.lowercased()
    let quotedLauncher = CommandBuilder.shellQuote(launcherPath)
    let quotedScript = CommandBuilder.shellQuote(script)
    return "\(quotedLauncher) --workstream-id \(workstream) -- \(shell) -lic \(quotedScript)"
}
