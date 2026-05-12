// ABOUTME: Central place for app-wide constants.
// ABOUTME: Debug builds use separate IDs so they can run alongside release builds.

import Foundation

func resolvedConfigDirectory(
    configDirectoryName: String,
    environment: [String: String],
    defaultConfigBase: URL,
    isRunningTests: Bool
) -> URL {
    let configBase: URL
    if let xdg = environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
        configBase = URL(fileURLWithPath: xdg)
    } else {
        configBase = defaultConfigBase
    }

    if isRunningTests {
        return configBase.appendingPathComponent("\(configDirectoryName)-tests")
    }

    return configBase.appendingPathComponent(configDirectoryName)
}

func isRunningXCTest(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
    environment["XCTestConfigurationFilePath"] != nil
}

enum AppConstants {
    static let appID: String = {
        #if DEBUG
            "dockyard-debug"
        #else
            "dockyard"
        #endif
    }()

    static let appName: String = {
        #if DEBUG
            "Dockyard Debug"
        #else
            "Dockyard"
        #endif
    }()

    static let urlScheme: String = {
        #if DEBUG
            "dockyard-debug"
        #else
            "dockyard"
        #endif
    }()

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var displayVersion: String {
        return "\(version) (\(AppCommit.hash))"
    }

    /// Config directory: ~/.config/dockyard/ (respects XDG_CONFIG_HOME).
    /// XCTest uses ~/.config/dockyard-tests/ to keep test data isolated.
    static var configDirectory: URL {
        resolvedConfigDirectory(
            configDirectoryName: "dockyard",
            environment: ProcessInfo.processInfo.environment,
            defaultConfigBase: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config"),
            isRunningTests: isRunningXCTest()
        )
    }

    /// Cache directory: ~/Library/Caches/dockyard/.
    /// Used for transient files like run-state and tmux config.
    static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dirName = isRunningXCTest()
            ? "dockyard-tests"
            : "dockyard"
        return base.appendingPathComponent(dirName)
    }

    /// Worktrees are always shared between debug and release builds.
    static var worktreesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dockyard")
            .appendingPathComponent("worktrees")
    }
}
