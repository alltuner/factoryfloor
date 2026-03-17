// ABOUTME: Embedded WKWebView for previewing local dev servers.
// ABOUTME: Simple browser with navigation bar, back/forward, reload, home.

import SwiftUI
import WebKit

extension Notification.Name {
    static let focusAddressBar = Notification.Name("factoryfloor.focusAddressBar")
    static let browserTitleChanged = Notification.Name("factoryfloor.browserTitleChanged")
}

struct BrowserView: View {
    let defaultURL: String
    var tabID: UUID?

    @State private var urlText: String = ""
    @State private var webView = WKWebView()
    @State private var isLoading = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var connectionError = false
    @State private var pageTitle: String?
    @FocusState private var urlFieldFocused: Bool

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
                    if isLoading { webView.stopLoading() } else { retry() }
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
                    .focused($urlFieldFocused)
                    .onSubmit { navigateTo(urlText) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)

            // Loading indicator
            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 2)
            } else {
                Divider()
            }

            // Content
            ZStack {
                WebViewRepresentable(
                    webView: webView,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    urlText: $urlText,
                    connectionError: $connectionError,
                    pageTitle: $pageTitle
                )
                .opacity(connectionError ? 0 : 1)

                if connectionError {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Server not responding")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text(urlText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Button("Retry") { retry() }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            urlText = defaultURL
            navigateTo(defaultURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                urlFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAddressBar)) { _ in
            urlFieldFocused = true
        }
        .onChange(of: pageTitle) { _, newTitle in
            guard let tabID else { return }
            NotificationCenter.default.post(
                name: .browserTitleChanged,
                object: tabID,
                userInfo: newTitle.map { ["title": $0] }
            )
        }
    }

    private func navigateTo(_ urlString: String) {
        connectionError = false
        var resolved = urlString
        if !resolved.contains("://") {
            resolved = "http://\(resolved)"
        }
        guard let url = URL(string: resolved),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme) else { return }
        webView.load(URLRequest(url: url))
    }

    private func retry() {
        connectionError = false
        if let url = webView.url {
            webView.load(URLRequest(url: url))
        } else {
            navigateTo(defaultURL)
        }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var urlText: String
    @Binding var connectionError: Bool
    @Binding var pageTitle: String?

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
            parent.connectionError = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.connectionError = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            let nsError = error as NSError
            // Connection refused, host not found, network issues
            if nsError.domain == NSURLErrorDomain &&
               [NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
                NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut].contains(nsError.code) {
                parent.connectionError = true
            }
            updateState(webView)
        }

        private func updateState(_ webView: WKWebView) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            if let url = webView.url?.absoluteString {
                parent.urlText = url
            }
            parent.pageTitle = webView.title
        }
    }
}
