// ABOUTME: Loads setup/run/teardown script configuration from project config files.
// ABOUTME: Resolves from .factoryfloor.json or .factoryfloor/config.json.

import Foundation

struct ScriptConfig {
    let setup: String?
    let run: String?
    let teardown: String?
    let source: String?

    static let empty = ScriptConfig(setup: nil, run: nil, teardown: nil, source: nil)

    /// Load script config for a project directory.
    static func load(from directory: String) -> ScriptConfig {
        let path = URL(fileURLWithPath: directory).appendingPathComponent(".factoryfloor.json").path
        guard FileManager.default.fileExists(atPath: path) else { return .empty }
        return loadFF2(path) ?? .empty
    }

    var hasAnyScript: Bool {
        setup != nil || run != nil || teardown != nil
    }

    /// Run the teardown script synchronously in the given directory.
    static func runTeardown(in directory: String, projectDirectory: String) {
        let config = load(from: projectDirectory)
        guard let teardown = config.teardown else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandBuilder.userShell)
        process.arguments = ["-lc", teardown]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Loader

    /// { "setup": "cmd", "run": "cmd", "teardown": "cmd" }
    private static func loadFF2(_ path: String) -> ScriptConfig? {
        guard let dict = loadJSON(path) else { return nil }
        let setup = dict["setup"] as? String
        let run = dict["run"] as? String
        let teardown = dict["teardown"] as? String
        guard setup != nil || run != nil || teardown != nil else { return nil }
        return ScriptConfig(setup: nonEmpty(setup), run: nonEmpty(run), teardown: nonEmpty(teardown), source: URL(fileURLWithPath: path).lastPathComponent)
    }

    // MARK: - Helpers

    private static func loadJSON(_ path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }
}
