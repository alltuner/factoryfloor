// ABOUTME: Shared WKWebView wrapper for the Monaco diff viewer (changes tab).
// ABOUTME: One WKWebView per workstream; shows stacked inline diffs for all changed files.

import Cocoa
import SwiftUI
import WebKit

// MARK: - MonacoDiffBridge

/// Manages a single WKWebView that displays stacked inline diff editors.
/// Queues operations until the JS side posts "ready".
@MainActor
final class MonacoDiffBridge {
    private(set) var webView: EditorWebView?
    private(set) var isReady = false
    private var pendingOps: [() -> Void] = []
    private var coordinator: Coordinator?
    private var appearanceObserver: NSKeyValueObservation?

    /// Called when JS has finished computing all diffs and the view is fully rendered.
    var onContentReady: (() -> Void)?

    /// Git fingerprint from the last successful setFiles() call.
    /// Used by ChangesView to skip reloading when nothing changed.
    var lastFingerprint: String?

    /// The mode (branch/uncommitted) that was active for the last load.
    var lastMode: String?

    /// Number of files from the last setFiles() call.
    /// Stored here (not @State) so it survives view re-creation on tab switch.
    var lastFileCount = 0

    /// Whether setFiles() has been called at least once (cached content exists in the WKWebView).
    private(set) var hasContent = false

    // MARK: - WebView lifecycle

    func ensureWebView() -> EditorWebView {
        if let webView { return webView }

        let coord = Coordinator(bridge: self)
        coordinator = coord

        let contentController = WKUserContentController()
        contentController.add(coord, name: "editor")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        if let resourceURL = Bundle.main.resourceURL {
            let bundleURL = resourceURL.appendingPathComponent("MonacoEditor")
            let handler = MonacoResourceSchemeHandler(baseURL: bundleURL)
            config.setURLSchemeHandler(handler, forURLScheme: "ff-resource")
        }

        let wv = EditorWebView(frame: .zero, configuration: config)
        wv.underPageBackgroundColor = .windowBackgroundColor
        #if DEBUG
            wv.isInspectable = true
        #endif

        if let url = URL(string: "ff-resource://monaco/diff.html") {
            wv.load(URLRequest(url: url))
        }

        webView = wv
        return wv
    }

    // MARK: - Diff API

    /// Set the files to display. Each file has original and modified content,
    /// plus optional review guide annotations and reason.
    func setFiles(_ files: [[String: Any]], reviewGuide: [String: String]? = nil) {
        hasContent = true
        enqueue {
            guard let webView = self.webView else { return }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: files),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }
            if let reviewGuide,
               let guideData = try? JSONSerialization.data(withJSONObject: reviewGuide),
               let guideString = String(data: guideData, encoding: .utf8)
            {
                webView.evaluateJavaScript("window.diffAPI.setFiles(\(jsonString), \(guideString))")
            } else {
                webView.evaluateJavaScript("window.diffAPI.setFiles(\(jsonString))")
            }
        }
    }

    /// Clear all diffs.
    func clear() {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.diffAPI.clear()")
        }
    }

    func setTheme(isDark: Bool) {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.diffAPI.setTheme(\(isDark))")
        }
    }

    func relayout() {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.diffAPI.layout()")
        }
    }

    // MARK: - Ready state

    fileprivate func markReady() {
        isReady = true
        syncThemeWithAppearance()
        startAppearanceObservation()
        for op in pendingOps {
            op()
        }
        pendingOps.removeAll()
    }

    private func syncThemeWithAppearance() {
        let isDark = NSApp?.effectiveAppearance.isDark ?? true
        guard let webView else { return }
        webView.evaluateJavaScript("window.diffAPI.setTheme(\(isDark))")
    }

    private func startAppearanceObservation() {
        guard appearanceObserver == nil else { return }
        appearanceObserver = NSApplication.shared.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.syncThemeWithAppearance()
            }
        }
    }

    // MARK: - Private

    private func enqueue(_ op: @escaping @MainActor () -> Void) {
        if isReady {
            op()
        } else {
            pendingOps.append(op)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, @unchecked Sendable {
        private let bridge: MonacoDiffBridge

        init(bridge: MonacoDiffBridge) {
            self.bridge = bridge
        }

        nonisolated func userContentController(
            _: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            Task { @MainActor in
                guard let body = message.body as? [String: Any],
                      let type = body["type"] as? String else { return }

                switch type {
                case "ready":
                    self.bridge.markReady()
                case "contentReady":
                    self.bridge.onContentReady?()
                case "error":
                    if let msg = body["message"] as? String {
                        print("[MonacoDiff] JS error: \(msg)")
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - MonacoDiffView

/// NSViewRepresentable that hosts the diff WKWebView.
struct MonacoDiffView: NSViewRepresentable {
    let bridge: MonacoDiffBridge

    func makeNSView(context _: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context _: Context) {
        let webView = bridge.ensureWebView()

        if webView.superview !== container {
            webView.removeFromSuperview()
            container.subviews.forEach { $0.removeFromSuperview() }
            container.addSubview(webView)
            webView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: container.topAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
            DispatchQueue.main.async {
                self.bridge.relayout()
            }
        }
    }
}
