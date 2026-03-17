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

enum AppConstants {
    #if DEBUG
    static let appID = "factoryfloor-debug"
    static let appName = "Factory Floor Debug"
    static let urlScheme = "factoryfloor-debug"
    #else
    static let appID = "factoryfloor"
    static let appName = "Factory Floor"
    static let urlScheme = "factoryfloor"
    #endif

    /// Config directory: ~/.config/factoryfloor/ (respects XDG_CONFIG_HOME).
    /// XCTest uses ~/.config/factoryfloor-tests/ to keep test data isolated.
    static var configDirectory: URL {
        resolvedConfigDirectory(
            configDirectoryName: "factoryfloor",
            environment: ProcessInfo.processInfo.environment,
            defaultConfigBase: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config"),
            isRunningTests: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        )
    }

    /// Worktrees are always shared between debug and release builds.
    static var worktreesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".factoryfloor")
            .appendingPathComponent("worktrees")
    }
}
