// ABOUTME: Resolves the bundled ff-run helper and builds wrapped run-script commands.
// ABOUTME: Keeps Environment tab command assembly small and consistent across tmux modes.

import Foundation

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

        return nil
    }
}

func runScriptCommand(script: String, workstreamID: UUID, launcherPath: String, shell: String = CommandBuilder.userShell) -> String {
    let workstream = workstreamID.uuidString.lowercased()
    let quotedLauncher = CommandBuilder.shellQuote(launcherPath)
    let quotedScript = CommandBuilder.shellQuote(script)
    return "\(quotedLauncher) --workstream-id \(workstream) -- \(shell) -lic \(quotedScript)"
}
