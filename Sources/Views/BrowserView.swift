// ABOUTME: Embedded WKWebView for previewing local dev servers.
// ABOUTME: Simple browser with navigation bar, back/forward, reload, home.

import SwiftUI
import WebKit

extension Notification.Name {
    static let focusAddressBar = Notification.Name("factoryfloor.focusAddressBar")
    static let browserTitleChanged = Notification.Name("factoryfloor.browserTitleChanged")
}

func shouldRetargetBrowser(currentURL: String?, displayedURL: String, previousDefaultURL: String, nextDefaultURL: String, connectionError: Bool) -> Bool {
    guard normalizedBrowserURL(previousDefaultURL) != normalizedBrowserURL(nextDefaultURL) else {
        return false
    }

    if connectionError {
        return normalizedBrowserURL(displayedURL) == normalizedBrowserURL(previousDefaultURL)
    }

    guard let currentURL else { return false }
    return normalizedBrowserURL(currentURL) == normalizedBrowserURL(previousDefaultURL)
}

private func normalizedBrowserURL(_ urlString: String) -> String {
    var resolved = urlString
    if !resolved.contains("://") {
        resolved = "http://\(resolved)"
    }
    guard let components = URLComponents(string: resolved) else {
        return resolved
    }

    var normalized = components
    if normalized.path.isEmpty {
        normalized.path = "/"
    }
    return normalized.string ?? resolved
}

struct BrowserView: View {
    let defaultURL: String
    var tabID: UUID?
    let webView: WKWebView

    @State private var urlText: String = ""
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
                .buttonStyle(.borderless)
                .disabled(!canGoBack)
                .foregroundStyle(canGoBack ? .primary : .quaternary)
                .accessibilityLabel("Back")

                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .disabled(!canGoForward)
                .foregroundStyle(canGoForward ? .primary : .quaternary)
                .accessibilityLabel("Forward")

                Button(action: {
                    if isLoading { webView.stopLoading() } else { retry() }
                }) {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isLoading ? "Stop loading" : "Reload")

                Button(action: { navigateTo(defaultURL) }) {
                    Image(systemName: "house")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Home")

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
            if webView.url == nil {
                urlText = defaultURL
                navigateTo(defaultURL)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    urlFieldFocused = true
                }
            } else {
                urlText = webView.url?.absoluteString ?? defaultURL
                canGoBack = webView.canGoBack
                canGoForward = webView.canGoForward
                isLoading = webView.isLoading
                pageTitle = webView.title
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAddressBar)) { _ in
            urlFieldFocused = true
        }
        .onChange(of: defaultURL) { oldURL, newURL in
            guard shouldRetargetBrowser(
                currentURL: webView.url?.absoluteString,
                displayedURL: urlText,
                previousDefaultURL: oldURL,
                nextDefaultURL: newURL,
                connectionError: connectionError
            ) else { return }
            urlText = newURL
            navigateTo(newURL)
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
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        // MARK: - WKUIDelegate (JavaScript dialogs)

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame _: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void)
        {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            if let window = webView.window {
                alert.beginSheetModal(for: window) { _ in completionHandler() }
            } else {
                alert.runModal()
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame _: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void)
        {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    completionHandler(response == .alertFirstButtonReturn)
                }
            } else {
                let response = alert.runModal()
                completionHandler(response == .alertFirstButtonReturn)
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame _: WKFrameInfo,
                     completionHandler: @escaping @MainActor @Sendable (String?) -> Void)
        {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField
            if let window = webView.window {
                alert.beginSheetModal(for: window) { response in
                    completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
                }
            } else {
                let response = alert.runModal()
                completionHandler(response == .alertFirstButtonReturn ? textField.stringValue : nil)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.isLoading = true
            parent.connectionError = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            parent.isLoading = false
            parent.connectionError = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            let nsError = error as NSError
            // Connection refused, host not found, network issues
            if nsError.domain == NSURLErrorDomain,
               [NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost,
                NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet,
                NSURLErrorTimedOut].contains(nsError.code)
            {
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
