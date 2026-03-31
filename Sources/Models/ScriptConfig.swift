// ABOUTME: Loads setup/run/teardown script configuration from project config files.
// ABOUTME: Resolves from .factoryfloor.json or .factoryfloor/config.json.

import Foundation
import os

private let logger = Logger(subsystem: "factoryfloor", category: "script-config")

struct ScriptConfig {
    let setup: String?
    let run: String?
    let teardown: String?
    let source: String?
    let loadError: String?

    static let empty = ScriptConfig(setup: nil, run: nil, teardown: nil, source: nil, loadError: nil)

    /// Load script config for a project directory.
    static func load(from directory: String) -> ScriptConfig {
        let path = URL(fileURLWithPath: directory).appendingPathComponent(".factoryfloor.json").path
        guard FileManager.default.fileExists(atPath: path) else { return .empty }
        do {
            return try loadFF2(path)
        } catch {
            logger.error("Failed to load \(path): \(error.localizedDescription)")
            return ScriptConfig(setup: nil, run: nil, teardown: nil, source: URL(fileURLWithPath: path).lastPathComponent, loadError: error.localizedDescription)
        }
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
        process.arguments = ["-lic", teardown]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Loader

    enum LoadError: LocalizedError {
        case unreadable(String)
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case let .unreadable(path): return "Cannot read \(path)"
            case let .invalidJSON(detail): return "Invalid JSON: \(detail)"
            }
        }
    }

    /// { "setup": "cmd", "run": "cmd", "teardown": "cmd" }
    private static func loadFF2(_ path: String) throws -> ScriptConfig {
        let dict = try loadJSON(path)
        let setup = dict["setup"] as? String
        let run = dict["run"] as? String
        let teardown = dict["teardown"] as? String
        guard setup != nil || run != nil || teardown != nil else {
            return .empty
        }
        return ScriptConfig(setup: nonEmpty(setup), run: nonEmpty(run), teardown: nonEmpty(teardown), source: URL(fileURLWithPath: path).lastPathComponent, loadError: nil)
    }

    // MARK: - Helpers

    private static func loadJSON(_ path: String) throws -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw LoadError.unreadable(path)
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw LoadError.invalidJSON("expected object, got \(type(of: obj))")
        }
        return dict
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }
}
