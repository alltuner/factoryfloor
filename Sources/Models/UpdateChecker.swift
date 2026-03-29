// ABOUTME: Checks factory-floor.com/appcast.xml for available updates.
// ABOUTME: Sidebar badge for Homebrew users; Sparkle handles DMG auto-updates.

import Foundation
import os

@MainActor
class UpdateChecker: ObservableObject {
    @Published var availableVersion: String?

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
                    guard let version = Self.parseVersion(from: data) else { return }
                    if Self.isNewer(version, than: currentVersion) {
                        await MainActor.run { [weak self] in
                            self?.availableVersion = version
                        }
                    }
                } catch {
                    logger.debug("Update check failed: \(error.localizedDescription)")
                }
            }
        #endif
    }

    /// Extracts the sparkle:shortVersionString from the first enclosure in an appcast feed.
    nonisolated static func parseVersion(from data: Data) -> String? {
        let parser = AppcastParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else { return nil }
        return parser.version
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

    func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "enclosure", version == nil {
            version = attributeDict["sparkle:shortVersionString"]
        }
    }
}
