// ABOUTME: Loads setup/run/teardown script configuration from project config files.
// ABOUTME: Resolves from .factoryfloor.json, .emdash.json, conductor.json, or .superset/config.json.

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
    /// Checks .factoryfloor.json first, then .emdash.json, conductor.json, then .superset/config.json.
    static func load(from directory: String) -> ScriptConfig {
        let dir = URL(fileURLWithPath: directory)

        let candidates: [(path: String, source: String, loader: (String) throws -> ScriptConfig)] = [
            (dir.appendingPathComponent(".factoryfloor.json").path, ".factoryfloor.json", loadFF2),
            (dir.appendingPathComponent(".emdash.json").path, ".emdash.json", loadEmdash),
            (dir.appendingPathComponent("conductor.json").path, "conductor.json", loadConductor),
            (dir.appendingPathComponent(".superset/config.json").path, ".superset/config.json", loadSuperset),
        ]

        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            do {
                return try candidate.loader(candidate.path)
            } catch {
                logger.error("Failed to load \(candidate.path): \(error.localizedDescription)")
                return ScriptConfig(setup: nil, run: nil, teardown: nil, source: candidate.source, loadError: error.localizedDescription)
            }
        }

        return .empty
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

    /// .emdash.json: { "scripts": { "setup": "cmd", "run": "cmd", "teardown": "cmd" } }
    private static func loadEmdash(_ path: String) throws -> ScriptConfig {
        let dict = try loadJSON(path)
        guard let scripts = dict["scripts"] as? [String: Any] else { return .empty }
        let setup = scripts["setup"] as? String
        let run = scripts["run"] as? String
        let teardown = scripts["teardown"] as? String
        guard setup != nil || run != nil || teardown != nil else { return .empty }
        return ScriptConfig(setup: nonEmpty(setup), run: nonEmpty(run), teardown: nonEmpty(teardown), source: ".emdash.json", loadError: nil)
    }

    /// conductor.json: { "scripts": { "setup": "cmd", "run": "cmd", "archive": "cmd" } }
    private static func loadConductor(_ path: String) throws -> ScriptConfig {
        let dict = try loadJSON(path)
        guard let scripts = dict["scripts"] as? [String: Any] else { return .empty }
        let setup = scripts["setup"] as? String
        let run = scripts["run"] as? String
        let teardown = scripts["archive"] as? String
        guard setup != nil || run != nil || teardown != nil else { return .empty }
        return ScriptConfig(setup: nonEmpty(setup), run: nonEmpty(run), teardown: nonEmpty(teardown), source: "conductor.json", loadError: nil)
    }

    /// .superset/config.json: { "setup": ["cmd1", "cmd2"], "run": ["cmd"], "teardown": ["cmd"] }
    private static func loadSuperset(_ path: String) throws -> ScriptConfig {
        let dict = try loadJSON(path)
        let setup = joinCommands(dict["setup"])
        let run = joinCommands(dict["run"])
        let teardown = joinCommands(dict["teardown"])
        guard setup != nil || run != nil || teardown != nil else { return .empty }
        return ScriptConfig(setup: setup, run: run, teardown: teardown, source: ".superset/config.json", loadError: nil)
    }

    // MARK: - Helpers

    /// Join a string array into a single command with &&, or return a plain string.
    private static func joinCommands(_ value: Any?) -> String? {
        if let array = value as? [String] {
            let joined = array.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " && ")
            return nonEmpty(joined)
        }
        if let str = value as? String {
            return nonEmpty(str)
        }
        return nil
    }

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
