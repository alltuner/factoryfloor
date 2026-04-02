// ABOUTME: Caches WKWebView instances and Coordinators for pixel agent panels across workstream switches.
// ABOUTME: Prevents expensive WKWebView recreation when navigating between workstreams.

import Combine
import Foundation
import os
import WebKit

private let logger = Logger(subsystem: "factoryfloor", category: "pixel-agents-cache")

/// Caches `WKWebView` and `Coordinator` instances keyed by normalized working directory.
///
/// When the user switches workstreams, SwiftUI destroys and recreates the
/// `TerminalContainerView` (and its child `PixelAgentsPanelView`) because of `.id(workstream.id)`.
/// Without this cache the `WKWebView` is torn down and rebuilt from scratch on every switch.
///
/// The cache keeps the `WKWebView`, its `Coordinator`, and reactive subjects alive so the
/// panel can reattach the existing web view into a new `NSView` container instantly.
@MainActor
final class PixelAgentsPanelCache: ObservableObject {

    // MARK: - CacheEntry

    /// Holds all state for a single pixel-agents panel instance.
    final class CacheEntry {
        let webView: WKWebView
        let coordinator: PixelAgentsPanelCoordinator
        let agentCount: CurrentValueSubject<Int, Never>
        let lastActivity: CurrentValueSubject<String, Never>

        init(
            webView: WKWebView,
            coordinator: PixelAgentsPanelCoordinator,
            agentCount: CurrentValueSubject<Int, Never>,
            lastActivity: CurrentValueSubject<String, Never>
        ) {
            self.webView = webView
            self.coordinator = coordinator
            self.agentCount = agentCount
            self.lastActivity = lastActivity
        }
    }

    // MARK: - Storage

    private var entries: [String: CacheEntry] = [:]

    // MARK: - Public API

    /// Returns the cached entry for the given working directory, creating one if needed.
    func entry(for workingDirectory: String) -> CacheEntry {
        let key = Self.normalizePath(workingDirectory)
        if let existing = entries[key] {
            logger.debug("Cache hit for: \(key, privacy: .public)")
            return existing
        }

        logger.info("Cache miss — creating entry for: \(key, privacy: .public)")
        let entry = createEntry(for: workingDirectory)
        entries[key] = entry
        return entry
    }

    /// Evicts the entry for the given working directory and breaks retain cycles.
    func removeEntry(for workingDirectory: String) {
        let key = Self.normalizePath(workingDirectory)
        guard let entry = entries.removeValue(forKey: key) else { return }
        teardownEntry(entry, key: key)
    }

    /// Evicts all entries.
    func removeAllEntries() {
        let snapshot = entries
        entries.removeAll()
        for (key, entry) in snapshot {
            teardownEntry(entry, key: key)
        }
    }

    // MARK: - Private Helpers

    private func createEntry(for workingDirectory: String) -> CacheEntry {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Shared subjects between coordinator and cache entry
        let agentCountSubject = CurrentValueSubject<Int, Never>(0)
        let lastActivitySubject = CurrentValueSubject<String, Never>("")

        let coordinator = PixelAgentsPanelCoordinator(
            projectDirectory: workingDirectory,
            agentCountSubject: agentCountSubject,
            lastActivitySubject: lastActivitySubject
        )

        // Register JS->Swift message handler
        config.userContentController.add(coordinator, name: "vibefloor")

        // Inject the bridge API so JS can call window.vibefloor.postMessage(...)
        let bridgeScript = WKUserScript(
            source: """
            window.vibefloor = {
                postMessage: function(msg) {
                    window.webkit.messageHandlers.vibefloor.postMessage(msg);
                }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bridgeScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        coordinator.webView = webView

        // Load index.html from the PixelAgents resource bundle
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "PixelAgents") {
            let accessDir = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: accessDir)
        } else {
            logger.error("PixelAgents index.html not found in bundle")
            webView.loadHTMLString(
                "<h1 style='color:red;background:#1a1a2e;padding:20px'>PixelAgents resources not found in bundle</h1>",
                baseURL: nil
            )
        }

        return CacheEntry(
            webView: webView,
            coordinator: coordinator,
            agentCount: agentCountSubject,
            lastActivity: lastActivitySubject
        )
    }

    private func teardownEntry(_ entry: CacheEntry, key: String) {
        logger.info("Tearing down cache entry for: \(key, privacy: .public)")
        // Break the WKScriptMessageHandler retain cycle
        entry.webView.configuration.userContentController.removeScriptMessageHandler(forName: "vibefloor")
        // Unregister from hook router
        HookEventRouter.shared.unregister(projectDir: key)
        // Remove from any view hierarchy
        entry.webView.removeFromSuperview()
    }

    // MARK: - Path Normalization

    static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardized.path
    }
}
