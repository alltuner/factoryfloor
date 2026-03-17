// ABOUTME: Tests for config-directory resolution across app, debug, and test contexts.
// ABOUTME: Keeps XCTest persistence isolated from the app's real project roster.

import XCTest
@testable import FactoryFloor

final class AppConstantsTests: XCTestCase {
    func testDebugBuildUsesReleaseConfigDirectory() {
        let base = URL(fileURLWithPath: "/tmp/factoryfloor-config")

        let resolved = resolvedConfigDirectory(
            configDirectoryName: "factoryfloor",
            environment: [:],
            defaultConfigBase: base,
            isRunningTests: false
        )

        XCTAssertEqual(resolved, base.appendingPathComponent("factoryfloor"))
    }

    func testTestsUseDedicatedConfigDirectoryWithoutFallback() {
        let base = URL(fileURLWithPath: "/tmp/factoryfloor-config")

        let resolved = resolvedConfigDirectory(
            configDirectoryName: "factoryfloor",
            environment: [:],
            defaultConfigBase: base,
            isRunningTests: true
        )

        XCTAssertEqual(resolved, base.appendingPathComponent("factoryfloor-tests"))
    }
}
