// ABOUTME: Tests for the NSAppearance isDark extension.
// ABOUTME: Verifies dark appearance detection across standard AppKit appearance names.

import Cocoa
@testable import FactoryFloor
import XCTest

final class NSAppearanceTests: XCTestCase {
    func testDarkAppearanceDetected() throws {
        let dark = try XCTUnwrap(NSAppearance(named: .darkAqua))
        XCTAssertTrue(dark.isDark)
    }

    func testLightAppearanceNotDark() throws {
        let light = try XCTUnwrap(NSAppearance(named: .aqua))
        XCTAssertFalse(light.isDark)
    }

    func testVibrantDarkDetected() throws {
        let vibrantDark = try XCTUnwrap(NSAppearance(named: .vibrantDark))
        XCTAssertTrue(vibrantDark.isDark)
    }

    func testVibrantLightNotDark() throws {
        let vibrantLight = try XCTUnwrap(NSAppearance(named: .vibrantLight))
        XCTAssertFalse(vibrantLight.isDark)
    }
}
