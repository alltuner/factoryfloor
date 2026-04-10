// ABOUTME: Shared WKWebView wrapper for Monaco editor with multi-model support.
// ABOUTME: One WKWebView per workstream; models (one per open file) swap via editor.setModel().

import Cocoa
import SwiftUI
import WebKit

// MARK: - MonacoResourceSchemeHandler

/// Serves Monaco editor resources from the app bundle via a custom URL scheme.
/// WKWebView's `loadFileURL` uses `file://` which breaks `fetch()` in JS
/// (WebKit's fetch only supports http/https/blob/data). By serving everything
/// through a custom scheme, all requests — JS modules, CSS, JSON, WASM, worker
/// fetches — go through this handler and work reliably.
final class MonacoResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func webView(_: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        // Strip leading slash from path to get relative path within MonacoEditor/
        let relativePath = String(url.path.dropFirst())
        let fileURL = baseURL.appendingPathComponent(relativePath)

        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mimeType = Self.mimeType(for: fileURL.pathExtension)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(data.count)",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_: WKWebView, stop _: any WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "wasm": return "application/wasm"
        case "ttf": return "font/ttf"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - EditorWebView

/// WKWebView subclass that lets app-level keyboard shortcuts pass through to the
/// macOS menu system instead of being consumed by the web content.
class EditorWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        let chars = event.charactersIgnoringModifiers ?? ""

        // Shortcuts that must reach the app menu
        switch chars {
        case "s", "w", "t", "b", "e":
            return false
        case "[", "]":
            return false
        case "\r":
            return false
        case "0":
            return false
        default:
            if let c = chars.first, c.isNumber {
                return false
            }
        }

        if event.modifierFlags.contains(.option) {
            return false
        }

        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - MonacoEditorBridge

/// Manages a single shared WKWebView and multiple Monaco models (one per editor tab).
/// Queues operations until Monaco posts "ready". All calls must be on @MainActor.
@MainActor
final class MonacoEditorBridge {
    private(set) var webView: EditorWebView?
    private(set) var isReady = false
    private var pendingOps: [() -> Void] = []
    private var coordinator: Coordinator?

    /// Called when any model's dirty state changes. Parameters: (modelId, isDirty).
    var onContentChanged: ((String, Bool) -> Void)?

    // MARK: - WebView lifecycle

    /// Lazily creates the WKWebView and starts loading Monaco.
    func ensureWebView() -> EditorWebView {
        if let webView { return webView }

        let coord = Coordinator(bridge: self)
        coordinator = coord

        let contentController = WKUserContentController()
        contentController.add(coord, name: "editor")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        // Serve Monaco resources via custom scheme so fetch() works for all
        // resource types (JS, CSS, JSON, WASM). WKWebView's file:// breaks
        // fetch() which the VS Code extension system depends on.
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

        if let url = URL(string: "ff-resource://monaco/index.html") {
            wv.load(URLRequest(url: url))
        }

        webView = wv
        return wv
    }

    // MARK: - Model API

    func openFile(modelId: String, text: String, languageId: String, filePath: String? = nil) {
        enqueue {
            guard let webView = self.webView else { return }
            let filePathArg = filePath.map { self.jsLiteral($0) } ?? "undefined"
            let js = "window.editorAPI.openFile(\(self.jsLiteral(modelId)), \(self.jsLiteral(text)), \(self.jsLiteral(languageId)), \(filePathArg))"
            webView.evaluateJavaScript(js)
        }
    }

    func switchModel(modelId: String) {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.editorAPI.switchModel(\(self.jsLiteral(modelId)))")
        }
    }

    func getContent(modelId: String) async -> String? {
        guard let webView, isReady else { return nil }
        return try? await webView.evaluateJavaScript(
            "window.editorAPI.getContent(\(jsLiteral(modelId)))"
        ) as? String
    }

    func markClean(modelId: String) {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.editorAPI.markClean(\(self.jsLiteral(modelId)))")
        }
    }

    func closeModel(modelId: String) {
        enqueue {
            guard let webView = self.webView else { return }
            webView.evaluateJavaScript("window.editorAPI.closeModel(\(self.jsLiteral(modelId)))")
        }
    }

    // MARK: - Ready state

    fileprivate func markReady() {
        isReady = true
        for op in pendingOps {
            op()
        }
        pendingOps.removeAll()
    }

    // MARK: - Private

    private func enqueue(_ op: @escaping @MainActor () -> Void) {
        if isReady {
            op()
        } else {
            pendingOps.append(op)
        }
    }

    /// Encode a Swift String as a JavaScript string literal (with quotes).
    /// Uses JSONEncoder which handles all escaping (quotes, newlines, unicode, etc.).
    private func jsLiteral(_ string: String) -> String {
        guard let data = try? JSONEncoder().encode(string),
              let json = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }
        return json
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, @unchecked Sendable {
        private let bridge: MonacoEditorBridge

        init(bridge: MonacoEditorBridge) {
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
                case "contentChanged":
                    if let modelId = body["modelId"] as? String,
                       let dirty = body["dirty"] as? Bool
                    {
                        self.bridge.onContentChanged?(modelId, dirty)
                    }
                case "error":
                    if let msg = body["message"] as? String {
                        print("[MonacoEditor] JS error: \(msg)")
                    }
                default:
                    break
                }
            }
        }
    }
}

// MARK: - MonacoEditorView

/// NSViewRepresentable that reparents the shared WKWebView into its container.
/// Only one editor tab is visible at a time, so the WKWebView physically moves
/// between containers when switching tabs.
struct MonacoEditorView: NSViewRepresentable {
    let bridge: MonacoEditorBridge

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
        }
    }
}
