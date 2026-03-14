// ABOUTME: Embedded WKWebView for previewing local dev servers.
// ABOUTME: Simple browser with navigation bar, back/forward, reload.

import SwiftUI
import WebKit

struct BrowserView: View {
    let defaultURL: String

    @State private var urlText: String = ""
    @State private var webView = WKWebView()
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack(spacing: 6) {
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canGoBack)
                .foregroundStyle(canGoBack ? .primary : .quaternary)

                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .foregroundStyle(canGoForward ? .primary : .quaternary)

                Button(action: {
                    if isLoading { webView.stopLoading() } else { webView.reload() }
                }) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Button(action: { navigateTo(defaultURL) }) {
                    Image(systemName: "house")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                TextField("URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { navigateTo(urlText) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            // Web content
            WebViewRepresentable(
                webView: webView,
                isLoading: $isLoading,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                urlText: $urlText
            )
        }
        .onAppear {
            urlText = defaultURL
            navigateTo(defaultURL)
        }
    }

    private func navigateTo(_ urlString: String) {
        var resolved = urlString
        if !resolved.contains("://") {
            resolved = "http://\(resolved)"
        }
        guard let url = URL(string: resolved) else { return }
        webView.load(URLRequest(url: url))
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var urlText: String

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        private func updateState(_ webView: WKWebView) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            if let url = webView.url?.absoluteString {
                parent.urlText = url
            }
        }
    }
}
