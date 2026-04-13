// ABOUTME: Tests for parsing versions and release notes from a Sparkle appcast XML feed.
// ABOUTME: Covers single-item, multi-item, version filtering, and malformed XML scenarios.

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

    func testParsesReleaseNotesURLFromAppcast() {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 0.2.0</title>
              <link>https://factory-floor.com/changelog/0.2.0</link>
              <enclosure url="https://example.com/app.dmg"
                         sparkle:version="0.2.0"
                         sparkle:shortVersionString="0.2.0"
                         length="1000"
                         type="application/octet-stream" />
            </item>
          </channel>
        </rss>
        """
        let releases = UpdateChecker.parseAppcast(from: Data(xml.utf8))
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases[0].version, "0.2.0")
        XCTAssertEqual(releases[0].releaseNotesURL, URL(string: "https://factory-floor.com/changelog/0.2.0"))
    }

    func testParsesAppcastWithoutReleaseNotesURL() {
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
        let releases = UpdateChecker.parseAppcast(from: Data(xml.utf8))
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases[0].version, "0.2.0")
        XCTAssertNil(releases[0].releaseNotesURL)
    }

    func testParsesMultipleItemsFromAppcast() {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 0.3.0</title>
              <link>https://github.com/alltuner/factoryfloor/releases/tag/v0.3.0</link>
              <description>&lt;p&gt;Added feature X&lt;/p&gt;</description>
              <enclosure url="https://example.com/app-0.3.0.dmg"
                         sparkle:version="0.3.0"
                         sparkle:shortVersionString="0.3.0"
                         length="2000"
                         type="application/octet-stream" />
            </item>
            <item>
              <title>Version 0.2.0</title>
              <link>https://github.com/alltuner/factoryfloor/releases/tag/v0.2.0</link>
              <description>&lt;p&gt;Fixed bug Y&lt;/p&gt;</description>
              <enclosure url="https://example.com/app-0.2.0.dmg"
                         sparkle:version="0.2.0"
                         sparkle:shortVersionString="0.2.0"
                         length="1500"
                         type="application/octet-stream" />
            </item>
            <item>
              <title>Version 0.1.0</title>
              <enclosure url="https://example.com/app-0.1.0.dmg"
                         sparkle:version="0.1.0"
                         sparkle:shortVersionString="0.1.0"
                         length="1000"
                         type="application/octet-stream" />
            </item>
          </channel>
        </rss>
        """
        let releases = UpdateChecker.parseAppcast(from: Data(xml.utf8))
        XCTAssertEqual(releases.count, 3)

        XCTAssertEqual(releases[0].version, "0.3.0")
        XCTAssertEqual(releases[0].releaseNotes, "<p>Added feature X</p>")
        XCTAssertEqual(
            releases[0].releaseNotesURL,
            URL(string: "https://github.com/alltuner/factoryfloor/releases/tag/v0.3.0")
        )

        XCTAssertEqual(releases[1].version, "0.2.0")
        XCTAssertEqual(releases[1].releaseNotes, "<p>Fixed bug Y</p>")

        XCTAssertEqual(releases[2].version, "0.1.0")
        XCTAssertNil(releases[2].releaseNotes)
        XCTAssertNil(releases[2].releaseNotesURL)
    }

    func testParsesDescriptionAsReleaseNotes() {
        let xml = """
        <?xml version='1.0' encoding='utf-8'?>
        <rss version="2.0" xmlns:sparkle="https://www.andymatuschak.org/xml-namespaces/sparkle">
          <channel>
            <item>
              <title>Version 0.2.0</title>
              <description>&lt;h3&gt;Bug Fixes&lt;/h3&gt;&lt;ul&gt;&lt;li&gt;Fixed crash&lt;/li&gt;&lt;/ul&gt;</description>
              <enclosure url="https://example.com/app.dmg"
                         sparkle:version="0.2.0"
                         sparkle:shortVersionString="0.2.0"
                         length="1000"
                         type="application/octet-stream" />
            </item>
          </channel>
        </rss>
        """
        let releases = UpdateChecker.parseAppcast(from: Data(xml.utf8))
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases[0].releaseNotes, "<h3>Bug Fixes</h3><ul><li>Fixed crash</li></ul>")
    }

    func testReleasesNewerThanFiltersCorrectly() {
        let releases = [
            AppcastRelease(version: "0.3.0", releaseNotesURL: nil, releaseNotes: "Three"),
            AppcastRelease(version: "0.2.0", releaseNotesURL: nil, releaseNotes: "Two"),
            AppcastRelease(version: "0.1.5", releaseNotesURL: nil, releaseNotes: "One-five"),
            AppcastRelease(version: "0.1.0", releaseNotesURL: nil, releaseNotes: "One"),
        ]
        let pending = UpdateChecker.releasesNewer(than: "0.1.5", in: releases)
        XCTAssertEqual(pending.count, 2)
        XCTAssertEqual(pending[0].version, "0.3.0")
        XCTAssertEqual(pending[1].version, "0.2.0")
    }

    func testReleasesNewerThanReturnsEmptyWhenUpToDate() {
        let releases = [
            AppcastRelease(version: "0.2.0", releaseNotesURL: nil, releaseNotes: nil),
        ]
        let pending = UpdateChecker.releasesNewer(than: "0.2.0", in: releases)
        XCTAssertTrue(pending.isEmpty)
    }

    func testIsNewerComparison() {
        XCTAssertTrue(UpdateChecker.isNewer("0.2.0", than: "0.1.37"))
        XCTAssertTrue(UpdateChecker.isNewer("0.1.38", than: "0.1.37"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.37", than: "0.1.37"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.36", than: "0.1.37"))
    }
}
