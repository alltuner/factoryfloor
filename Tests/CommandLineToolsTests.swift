// ABOUTME: Tests for resolving absolute paths to app-launched command line tools.
// ABOUTME: Guards against debug and release builds using different command lookup behavior.

@testable import FactoryFloor
import XCTest

final class CommandLineToolsTests: XCTestCase {
    func testPathPrefersKnownExecutableLocations() {
        let resolved = CommandLineTools.path(for: "git") { path in
            path == "/opt/homebrew/bin/git"
        } resolveFromPath: { _, _ in
            XCTFail("PATH lookup should not run when a known location exists")
            return nil
        }

        XCTAssertEqual(resolved, "/opt/homebrew/bin/git")
    }

    func testPathFallsBackToEnvironmentPath() {
        let resolved = CommandLineTools.path(
            for: "git",
            environment: ["PATH": "/tmp/custom/bin:/usr/bin"],
            isExecutable: { _ in
                false
            },
            resolveFromPath: { name, environment in
                let rawPath = environment["PATH"] ?? ""
                return rawPath.split(separator: ":").map(String.init)
                    .map { "\($0)/\(name)" }
                    .first
            }
        )

        XCTAssertEqual(resolved, "/tmp/custom/bin/git")
    }

    func testPathFallsBackToShellPath() {
        // Simulates a GUI app where ProcessInfo PATH is minimal (no custom dirs)
        // but the user's login shell has the tool in its PATH
        let resolved = CommandLineTools.path(
            for: "mytool",
            environment: ["PATH": "/usr/bin:/bin", "SHELL": "/bin/zsh"],
            isExecutable: { path in
                // Not in known locations, not in process PATH
                // Only found via shell PATH
                path == "/nix/store/abc123/bin/mytool"
            },
            resolveFromPath: { _, _ in nil },
            resolveFromShellPath: { shell in
                XCTAssertEqual(shell, "/bin/zsh")
                return "/nix/store/abc123/bin:/usr/bin"
            }
        )

        XCTAssertEqual(resolved, "/nix/store/abc123/bin/mytool")
    }

    func testShellPathNotUsedWhenKnownLocationMatches() {
        var shellPathCalled = false
        let resolved = CommandLineTools.path(
            for: "git",
            environment: ["SHELL": "/bin/zsh"],
            isExecutable: { $0 == "/opt/homebrew/bin/git" },
            resolveFromPath: { _, _ in
                XCTFail("Should not reach process PATH")
                return nil
            },
            resolveFromShellPath: { _ in
                shellPathCalled = true
                return "/some/path"
            }
        )

        XCTAssertEqual(resolved, "/opt/homebrew/bin/git")
        XCTAssertFalse(shellPathCalled, "Shell PATH should not be queried when known location matches")
    }

    func testShellPathSkippedWhenProcessPathMatches() {
        var shellPathCalled = false
        let resolved = CommandLineTools.path(
            for: "mytool",
            environment: ["PATH": "/custom/bin", "SHELL": "/bin/zsh"],
            isExecutable: { $0 == "/custom/bin/mytool" },
            resolveFromPath: { name, env in
                let rawPath = env["PATH"] ?? ""
                for dir in rawPath.split(separator: ":") {
                    let candidate = "\(dir)/\(name)"
                    if FileManager.default.isExecutableFile(atPath: candidate) || candidate == "/custom/bin/mytool" {
                        return candidate
                    }
                }
                return nil
            },
            resolveFromShellPath: { _ in
                shellPathCalled = true
                return "/some/path"
            }
        )

        XCTAssertEqual(resolved, "/custom/bin/mytool")
        XCTAssertFalse(shellPathCalled, "Shell PATH should not be queried when process PATH matches")
    }
}
