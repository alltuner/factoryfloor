// ABOUTME: Tests for resolving absolute paths to app-launched command line tools.
// ABOUTME: Guards against debug and release builds using different command lookup behavior.

import XCTest
@testable import FactoryFloor

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
            isExecutable: { path in
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
}
