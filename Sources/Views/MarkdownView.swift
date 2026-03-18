// ABOUTME: Renders markdown to HTML using cmark-gfm and displays it in a WKWebView.
// ABOUTME: Strips raw HTML from markdown for safe rendering.

import cmark_gfm
import cmark_gfm_extensions
import SwiftUI
import WebKit

struct MarkdownContentView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(false, forKey: "javaScriptCanOpenWindowsAutomatically")
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastMarkdown != markdown else { return }
        context.coordinator.lastMarkdown = markdown
        let html = renderMarkdownToHTML(markdown)
        let page = wrapInHTMLPage(html)
        webView.loadHTMLString(page, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastMarkdown: String?

        func webView(
            _: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                // Only open absolute HTTP(S) links in the external browser.
                // Ignore anchor links, relative paths, and other schemes.
                if url.scheme == "https" || url.scheme == "http" {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - cmark-gfm rendering

private func renderMarkdownToHTML(_ markdown: String) -> String {
    cmark_gfm_core_extensions_ensure_registered()

    guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return escapeHTML(markdown) }
    defer { cmark_parser_free(parser) }

    for name in ["table", "autolink", "strikethrough", "tasklist"] {
        if let ext = cmark_find_syntax_extension(name) {
            cmark_parser_attach_syntax_extension(parser, ext)
        }
    }

    cmark_parser_feed(parser, markdown, markdown.utf8.count)

    guard let doc = cmark_parser_finish(parser) else { return escapeHTML(markdown) }
    defer { cmark_node_free(doc) }

    let options = CMARK_OPT_DEFAULT
    let extensions = cmark_parser_get_syntax_extensions(parser)
    guard let cString = cmark_render_html(doc, options, extensions) else { return escapeHTML(markdown) }
    defer { free(cString) }

    return String(cString: cString)
}

private func escapeHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}

// MARK: - HTML template with GitHub-style CSS

private func wrapInHTMLPage(_ bodyHTML: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
    :root {
        color-scheme: light dark;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
        font-size: 14px;
        line-height: 1.6;
        color: light-dark(#1f2328, #e6edf3);
        background: transparent;
        max-width: 860px;
        margin: 0 auto;
        padding: 16px 32px;
        word-wrap: break-word;
    }
    h1, h2, h3, h4, h5, h6 {
        font-weight: 600;
        line-height: 1.25;
        margin-top: 24px;
        margin-bottom: 16px;
    }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid light-dark(#d1d9e0, #30363d); }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid light-dark(#d1d9e0, #30363d); }
    h3 { font-size: 1.25em; }
    p, ul, ol, blockquote, table, pre { margin-bottom: 16px; }
    a { color: light-dark(#0969da, #4493f8); text-decoration: none; }
    a:hover { text-decoration: underline; }
    code {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
        font-size: 85%;
        padding: 0.2em 0.4em;
        background: light-dark(rgba(175,184,193,0.2), rgba(110,118,129,0.4));
        border-radius: 6px;
    }
    pre {
        padding: 16px;
        overflow: auto;
        background: light-dark(#f6f8fa, #161b22);
        border-radius: 6px;
        line-height: 1.45;
    }
    pre code {
        padding: 0;
        background: transparent;
        font-size: 85%;
    }
    blockquote {
        padding: 0 1em;
        color: light-dark(#636c76, #8b949e);
        border-left: 0.25em solid light-dark(#d1d9e0, #30363d);
        margin-left: 0;
    }
    table {
        border-collapse: collapse;
        width: 100%;
    }
    th, td {
        padding: 6px 13px;
        border: 1px solid light-dark(#d1d9e0, #30363d);
    }
    th { font-weight: 600; background: light-dark(#f6f8fa, #161b22); }
    tr:nth-child(2n) { background: light-dark(#f6f8fa, #161b2200); }
    img { max-width: 100%; height: auto; }
    hr {
        height: 0.25em;
        padding: 0;
        margin: 24px 0;
        background: light-dark(#d1d9e0, #30363d);
        border: 0;
    }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    /* Task list checkboxes */
    li input[type="checkbox"] { margin-right: 0.5em; }
    /* Badge images (inline) */
    p img[src*="shields.io"], p img[src*="badge"] {
        display: inline;
        vertical-align: middle;
        margin: 2px 4px;
    }
    /* Centered paragraphs */
    p[align="center"], h1[align="center"] { text-align: center; }
    </style>
    </head>
    <body>
    \(bodyHTML)
    </body>
    </html>
    """
}
