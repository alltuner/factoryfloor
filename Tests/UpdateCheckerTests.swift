// ABOUTME: Tests for parsing the latest version from a Sparkle appcast XML feed.
// ABOUTME: Covers valid appcast, missing version, and malformed XML scenarios.

@testable import FactoryFloor
import XCTest

final class UpdateCheckerTests: XCTestCase {
    func testParsesVersionFromAppcast() {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 0.2.0</title>
              <enclosure url="https://example.com/app.dmg"
                         sparkle:version="0.2.0"
                         sparkle:shortVersionString="0.2.0"
                         length="1000"
                         type="application/octet-stream" />
            </item>
          </channel>
        </rss>
        """
        let version = UpdateChecker.parseVersion(from: Data(xml.utf8))
        XCTAssertEqual(version, "0.2.0")
    }

    func testReturnsNilForMissingVersion() {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
          </channel>
        </rss>
        """
        let version = UpdateChecker.parseVersion(from: Data(xml.utf8))
        XCTAssertNil(version)
    }

    func testReturnsNilForMalformedXML() {
        let version = UpdateChecker.parseVersion(from: Data("not xml".utf8))
        XCTAssertNil(version)
    }

    func testIsNewerComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "0.1.37"))
        XCTAssertTrue(UpdateChecker.isNewer("0.1.38", than: "0.1.37"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.37", than: "0.1.37"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.36", than: "0.1.37"))
    }
}
