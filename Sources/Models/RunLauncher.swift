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
static func wrapWithVenv(_ script: String, projectDirectory: String) -> String {
    let fm = FileManager.default
    for candidate in ["venv/bin/activate", ".venv/bin/activate"] {
        let path = (projectDirectory as NSString).appendingPathComponent(candidate)
        if fm.fileExists(atPath: path) {
            return "source \(CommandBuilder.shellQuote(path)) && \(script)"
        }
    }
    return script
}

static func inferExpectedPort(runCommand: String, projectDirectory: String) -> Int? {
    let envURL = URL(fileURLWithPath: projectDirectory).appendingPathComponent(".env")
    if let envString = try? String(contentsOf: envURL, encoding: .utf8) {
        let lines = envString.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PORT=") {
                let valStr = trimmed.dropFirst(5).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if let port = Int(valStr) {
                    return port
                }
            }
        }
    }

    let portPattern = "(?:--port\\s+|-p\\s+|--port=)(\\d+)"
    if let regex = try? NSRegularExpression(pattern: portPattern),
       let match = regex.firstMatch(in: runCommand, range: NSRange(runCommand.startIndex..., in: runCommand)) {
        if let range = Range(match.range(at: 1), in: runCommand) {
            return Int(runCommand[range])
        }
    }

    let envVarPattern = "\\bPORT=(\\d+)"
    if let regex = try? NSRegularExpression(pattern: envVarPattern),
       let match = regex.firstMatch(in: runCommand, range: NSRange(runCommand.startIndex..., in: runCommand)) {
        if let range = Range(match.range(at: 1), in: runCommand) {
            return Int(runCommand[range])
        }
    }

    return nil
}
}

func runScriptCommand(script: String, workstreamID: UUID, launcherPath: String, expectedPort: Int? = nil, shell: String = CommandBuilder.userShell) -> String {
let workstream = workstreamID.uuidString.lowercased()
let quotedLauncher = CommandBuilder.shellQuote(launcherPath)
let quotedScript = CommandBuilder.shellQuote(script, forShell: shell)
var cmd = "\(quotedLauncher) --workstream-id \(workstream)"
if let expectedPort {
    cmd += " --expected-port \(expectedPort)"
}
cmd += " -- \(shell) -lic \(quotedScript)"
return cmd
}