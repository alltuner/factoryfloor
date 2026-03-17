// ABOUTME: Tests for terminal input coordinate conversion.
// ABOUTME: Verifies AppKit mouse positions are translated to Ghostty's top-left Y axis.

import Cocoa
import XCTest
@testable import FactoryFloor

@MainActor
final class TerminalViewTests: XCTestCase {
    func testGhosttyMousePointFlipsYAxis() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 120))

        let point = TerminalView.ghosttyMousePoint(from: NSPoint(x: 25, y: 30), in: view)

        XCTAssertEqual(point.x, 25)
        XCTAssertEqual(point.y, 90)
    }
}
