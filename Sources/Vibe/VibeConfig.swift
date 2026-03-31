// ABOUTME: Configuration model for .vibefloor.json per-project config.
// ABOUTME: Extends FactoryFloor with vibe-specific worktree setup options.

import Foundation

struct VibeConfig: Codable, Sendable {
    var baseBranch: String
    var packageManager: PackageManager?
    var symlinks: [String]
    var envPatterns: [String]
    var postSetupCommands: [String]

    enum PackageManager: String, Codable, Sendable {
        case npm, yarn, pnpm, bun

        var installCommand: [String] {
            switch self {
            case .npm: return ["npm", "ci", "--prefer-offline"]
            case .yarn: return ["yarn", "install", "--frozen-lockfile", "--prefer-offline"]
            case .pnpm: return ["pnpm", "install", "--frozen-lockfile"]
            case .bun: return ["bun", "install", "--frozen-lockfile"]
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case baseBranch = "base_branch"
        case packageManager = "package_manager"
        case symlinks
        case envPatterns = "env_patterns"
        case postSetupCommands = "post_setup_commands"
    }

    static let `default` = VibeConfig(
        baseBranch: "development",
        packageManager: nil,
        symlinks: [
            "terraform.tfstate",
            "terraform.tfstate.backup",
            ".terraform",
            "volume",
            "db/prisma-generated-clients",
        ],
        envPatterns: [".env", ".env.*"],
        postSetupCommands: []
    )

    static func load(from projectDirectory: String) -> VibeConfig {
        let url = URL(fileURLWithPath: projectDirectory)
            .appendingPathComponent(".vibefloor.json")
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(VibeConfig.self, from: data)
        else {
            return .default
        }
        return config
    }
}
