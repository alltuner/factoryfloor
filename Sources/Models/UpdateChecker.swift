// ABOUTME: Checks factory-floor.com/appcast.xml for available updates.
// ABOUTME: Sidebar badge for Homebrew users; Sparkle handles DMG auto-updates.

import Foundation
import os

struct AppcastInfo {
    let version: String
    let releaseNotesURL: URL?
}

@MainActor
class UpdateChecker: ObservableObject {
    @Published var availableVersion: String?
    @Published var releaseNotesURL: URL?

    private let currentVersion: String
    private let logger = Logger(subsystem: AppConstants.appID, category: "UpdateChecker")
    private static let appcastURL = URL(string: "https://factory-floor.com/appcast.xml")!

    init() {
        currentVersion = AppConstants.version
    }

    func check() {
        #if DEBUG
            return
        #else
            Task.detached { [currentVersion, logger] in
                do {
                    let (data, _) = try await URLSession.shared.data(from: Self.appcastURL)
                    guard let info = Self.parseAppcast(from: data) else { return }
                    if Self.isNewer(info.version, than: currentVersion) {
                        await MainActor.run { [weak self] in
                            self?.availableVersion = info.version
                            self?.releaseNotesURL = info.releaseNotesURL
                        }
                    }
                } catch {
                    logger.debug("Update check failed: \(error.localizedDescription)")
                }
            }
        #endif
    }

    /// Extracts version and release notes URL from the first item in an appcast feed.
    nonisolated static func parseAppcast(from data: Data) -> AppcastInfo? {
        let parser = AppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse(), let version = parser.version else { return nil }
        return AppcastInfo(version: version, releaseNotesURL: parser.releaseNotesURL)
    }

    /// Extracts the sparkle:shortVersionString from the first enclosure in an appcast feed.
    nonisolated static func parseVersion(from data: Data) -> String? {
        parseAppcast(from: data)?.version
    }

    /// Simple semver comparison: returns true if `remote` is newer than `local`.
    nonisolated static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0 ..< max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}

private class AppcastParser: NSObject, XMLParserDelegate {
    var version: String?
    var releaseNotesURL: URL?

    private var insideItem = false
    private var currentElement: String?
    private var currentText = ""

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            insideItem = true
        } else if elementName == "enclosure", version == nil {
            version = attributeDict["sparkle:shortVersionString"]
        }
        currentElement = elementName
        currentText = ""
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        if elementName == "link", insideItem, releaseNotesURL == nil {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            releaseNotesURL = URL(string: trimmed)
        } else if elementName == "item" {
            insideItem = false
        }
        currentElement = nil
    }
}
