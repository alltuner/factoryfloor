// ABOUTME: Checks factory-floor.com/appcast.xml for available updates.
// ABOUTME: Sidebar badge for Homebrew users; Sparkle handles DMG auto-updates.

import Foundation
import os

struct AppcastRelease {
    let version: String
    let releaseNotesURL: URL?
    let releaseNotes: String?
}

@MainActor
class UpdateChecker: ObservableObject {
    @Published var pendingReleases: [AppcastRelease] = []

    var availableVersion: String? {
        pendingReleases.first?.version
    }

    var releaseNotesURL: URL? {
        pendingReleases.first?.releaseNotesURL
    }

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
                    let releases = Self.parseAppcast(from: data)
                    let pending = Self.releasesNewer(than: currentVersion, in: releases)
                    guard !pending.isEmpty else { return }
                    await MainActor.run { [weak self] in
                        self?.pendingReleases = pending
                    }
                } catch {
                    logger.debug("Update check failed: \(error.localizedDescription)")
                }
            }
        #endif
    }

    /// Parses all release items from an appcast feed, ordered newest first.
    nonisolated static func parseAppcast(from data: Data) -> [AppcastRelease] {
        let parser = AppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else { return [] }
        return parser.releases
    }

    /// Extracts the sparkle:shortVersionString from the first enclosure in an appcast feed.
    nonisolated static func parseVersion(from data: Data) -> String? {
        parseAppcast(from: data).first?.version
    }

    /// Filters releases to those newer than the given version.
    nonisolated static func releasesNewer(than version: String, in releases: [AppcastRelease]) -> [AppcastRelease] {
        releases.filter { isNewer($0.version, than: version) }
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
    var releases: [AppcastRelease] = []

    private var insideItem = false
    private var currentElement: String?
    private var currentText = ""

    private var itemVersion: String?
    private var itemLink: URL?
    private var itemDescription: String?

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" {
            insideItem = true
            itemVersion = nil
            itemLink = nil
            itemDescription = nil
        } else if elementName == "enclosure", insideItem, itemVersion == nil {
            itemVersion = attributeDict["sparkle:shortVersionString"]
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
        if insideItem {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if elementName == "link" {
                itemLink = URL(string: trimmed)
            } else if elementName == "description" {
                if !trimmed.isEmpty {
                    itemDescription = trimmed
                }
            } else if elementName == "item" {
                if let version = itemVersion {
                    releases.append(AppcastRelease(
                        version: version,
                        releaseNotesURL: itemLink,
                        releaseNotes: itemDescription
                    ))
                }
                insideItem = false
            }
        }
        currentElement = nil
    }
}
