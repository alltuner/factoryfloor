// ABOUTME: Tests for config-directory resolution across app, debug, and test contexts.
// ABOUTME: Keeps XCTest persistence isolated from the app's real project roster.

@testable import FactoryFloor
import XCTest

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

    func testDetectsXCTestEnvironment() {
        XCTAssertTrue(isRunningXCTest(environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]))
        XCTAssertFalse(isRunningXCTest(environment: [:]))
    }
}
