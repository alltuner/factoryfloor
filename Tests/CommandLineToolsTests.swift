// ABOUTME: Tests for resolving absolute paths to app-launched command line tools.
// ABOUTME: Guards against debug and release builds using different command lookup behavior.

@testable import FactoryFloor
import XCTest

final class CommandLineToolsTests: XCTestCase {
    func testPrefersLoginShellPath() {
        // The login shell PATH should take priority over known locations
        // so we find the same binary the user's terminal would.
        var knownLocationChecked = false
        let resolved = CommandLineTools.path(
            for: "claude",
            environment: ["SHELL": "/bin/zsh"],
            isExecutable: { path in
                if path == "/opt/homebrew/bin/claude" { knownLocationChecked = true }
                return path == "/Users/me/.nvm/versions/node/v22/bin/claude"
            },
            resolveFromPath: { _, _ in nil },
            resolveFromShellPath: { shell in
                XCTAssertEqual(shell, "/bin/zsh")
                return "/Users/me/.nvm/versions/node/v22/bin:/opt/homebrew/bin:/usr/bin"
            }
        )

        XCTAssertEqual(resolved, "/Users/me/.nvm/versions/node/v22/bin/claude")
        XCTAssertFalse(knownLocationChecked, "Known locations should not be checked when shell PATH matches")
    }

    func testFallsBackToProcessPathWhenShellPathMisses() {
        let resolved = CommandLineTools.path(
            for: "mytool",
            environment: ["PATH": "/custom/bin", "SHELL": "/bin/zsh"],
            isExecutable: { $0 == "/custom/bin/mytool" },
            resolveFromPath: { name, env in
                let rawPath = env["PATH"] ?? ""
                for dir in rawPath.split(separator: ":") {
                    let candidate = "\(dir)/\(name)"
                    if candidate == "/custom/bin/mytool" { return candidate }
                }
                return nil
            },
            resolveFromShellPath: { _ in
                // Shell PATH doesn't contain the tool
                "/usr/bin:/bin"
            }
        )

        XCTAssertEqual(resolved, "/custom/bin/mytool")
    }

    func testFallsBackToKnownLocationsAsLastResort() {
        let resolved = CommandLineTools.path(
            for: "git",
            environment: ["PATH": "", "SHELL": "/bin/zsh"],
            isExecutable: { $0 == "/opt/homebrew/bin/git" },
            resolveFromPath: { _, _ in nil },
            resolveFromShellPath: { _ in
                // Shell PATH doesn't contain the tool either
                "/usr/bin:/bin"
            }
        )

        XCTAssertEqual(resolved, "/opt/homebrew/bin/git")
    }

    func testReturnsNilWhenNothingFound() {
        let resolved = CommandLineTools.path(
            for: "nonexistent",
            environment: ["PATH": "", "SHELL": "/bin/zsh"],
            isExecutable: { _ in false },
            resolveFromPath: { _, _ in nil },
            resolveFromShellPath: { _ in "/usr/bin:/bin" }
        )

        XCTAssertNil(resolved)
    }

    func testSkipsShellPathWhenShellNotSet() {
        // No SHELL in environment, should skip shell PATH and fall through
        let resolved = CommandLineTools.path(
            for: "git",
            environment: ["PATH": ""],
            isExecutable: { $0 == "/usr/local/bin/git" },
            resolveFromPath: { _, _ in nil },
            resolveFromShellPath: { _ in
                XCTFail("Shell PATH should not be queried when SHELL is not set")
                return nil
            }
        )

        XCTAssertEqual(resolved, "/usr/local/bin/git")
    }
}
