// ABOUTME: Collapsible bottom panel showing pixel art agent visualization.
// ABOUTME: Uses WKWebView with WKScriptMessageHandler for Swift↔JS bridge.

import os
import SwiftUI
import WebKit

private let logger = Logger(subsystem: "factoryfloor", category: "pixel-agents")

extension Notification.Name {
    static let togglePixelAgents = Notification.Name("factoryfloor.togglePixelAgents")
}

struct PixelAgentsPanelView: View {
    let projectDirectory: String
    @State private var isExpanded = true
    @State private var agentCount = 0
    @State private var lastActivity = ""
    @AppStorage("factoryfloor.pixelAgentsPanelHeight") private var panelHeight: Double = 200
    @State private var dragOffset: CGFloat = 0

    private let collapsedHeight: CGFloat = 28
    private let minPanelHeight: CGFloat = 100
    private let maxPanelHeight: CGFloat = 500

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isExpanded {
                resizeHandle
                Divider()
                PixelAgentsWebView(
                    projectDirectory: projectDirectory,
                    agentCount: $agentCount,
                    lastActivity: $lastActivity
                )
                .frame(height: max(minPanelHeight, min(maxPanelHeight, CGFloat(panelHeight) + dragOffset)))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePixelAgents)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isExpanded ? "Collapse pixel agents" : "Expand pixel agents")

            Image(systemName: "person.3.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text("Pixel Agents")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if agentCount > 0 {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("\(agentCount) active")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }

            Spacer()

            if !isExpanded && !lastActivity.isEmpty {
                Text(lastActivity)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: collapsedHeight)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 6)
            .overlay {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 36, height: 3)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        // Dragging up (negative y) increases height since the panel is at the bottom
                        dragOffset = -value.translation.height
                    }
                    .onEnded { value in
                        let newHeight = CGFloat(panelHeight) - value.translation.height
                        panelHeight = Double(max(minPanelHeight, min(maxPanelHeight, newHeight)))
                        dragOffset = 0
                    }
            )
    }
}

// MARK: - WKWebView with bidirectional messaging bridge

struct PixelAgentsWebView: NSViewRepresentable {
    let projectDirectory: String
    @Binding var agentCount: Int
    @Binding var lastActivity: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Register JS→Swift message handler
        let coordinator = context.coordinator
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
            webView.loadHTMLString("<h1 style='color:red;background:#1a1a2e;padding:20px'>PixelAgents resources not found in bundle</h1>", baseURL: nil)
        }
        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(projectDirectory: projectDirectory, agentCount: $agentCount, lastActivity: $lastActivity)
    }

    // MARK: - Coordinator handles JS→Swift messages

    class Coordinator: NSObject, WKScriptMessageHandler {
        var webView: WKWebView?
        private var agentCount: Binding<Int>
        private var lastActivity: Binding<String>
        private var transcriptWatcher: TranscriptWatcher?
        private var webViewReady = false
        private var pendingEvents: [AgentEvent] = []
        private nonisolated(unsafe) var setupObserver: NSObjectProtocol?

        init(projectDirectory: String, agentCount: Binding<Int>, lastActivity: Binding<String>) {
            self.agentCount = agentCount
            self.lastActivity = lastActivity
            super.init()
            setupTranscriptWatcher(projectDirectory: projectDirectory)
            setupObserver = NotificationCenter.default.addObserver(
                forName: .asyncSetupStateChanged,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self,
                      let state = notification.userInfo?["state"] as? AsyncSetupState else { return }
                self.sendSetupProgress(state: state)
            }
        }

        deinit {
            transcriptWatcher?.stop()
            if let setupObserver {
                NotificationCenter.default.removeObserver(setupObserver)
            }
        }

        /// Sends app config to the WebView so JS can adapt to theme, version, etc.
        private func sendConfig() {
            let payload: [String: Any] = [
                "type": "config",
                "theme": "dark",
                "appName": AppConstants.appName,
                "version": AppConstants.version,
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let js = "window.dispatchEvent(new MessageEvent('message', { data: \(jsonString) }));"
            webView?.evaluateJavaScript(js) { _, error in
                if let error {
                    logger.error("Failed to send config to WebView: \(error.localizedDescription)")
                }
            }
        }

        /// Translates an `AsyncSetupState` into a `setupProgress` WebView event.
        private func sendSetupProgress(state: AsyncSetupState) {
            let step: String
            let progress: Double
            let done: Bool

            switch state {
            case .idle:
                return
            case let .inProgress(currentStep, currentProgress):
                step = currentStep
                progress = currentProgress
                done = false
            case .completed:
                step = "Done"
                progress = 1.0
                done = true
            case let .failed(message):
                step = "Setup failed: \(message)"
                progress = 0
                done = true
            }

            let payload: [String: Any] = [
                "type": "setupProgress",
                "step": step,
                "progress": progress,
                "done": done,
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let js = "window.dispatchEvent(new MessageEvent('message', { data: \(jsonString) }));"
            webView?.evaluateJavaScript(js) { _, error in
                if let error {
                    logger.error("Failed to send setupProgress to WebView: \(error.localizedDescription)")
                }
            }
        }

        private func setupTranscriptWatcher(projectDirectory: String) {
            let watcher = TranscriptWatcher(projectDir: projectDirectory)
            watcher.onEvent = { [weak self] event in
                self?.handleAgentEvent(event)
            }
            transcriptWatcher = watcher
        }

        private func handleAgentEvent(_ event: AgentEvent) {
            guard webViewReady else {
                pendingEvents.append(event)
                return
            }
            sendAgentEvent(event)

            // Update header strip info
            if event.type == .agentToolStart, let tool = event.tool {
                lastActivity.wrappedValue = "\(event.agentId): \(tool)"
            }
        }

        private func sendAgentEvent(_ event: AgentEvent) {
            guard let jsonData = try? JSONEncoder().encode(event),
                  let jsonString = String(data: jsonData, encoding: .utf8) else { return }

            let js = "window.dispatchEvent(new MessageEvent('message', { data: \(jsonString) }));"
            webView?.evaluateJavaScript(js) { _, error in
                if let error {
                    logger.error("Failed to send to WebView: \(error.localizedDescription)")
                }
            }
        }

        /// Called when JS sends: window.vibefloor.postMessage({type: "...", ...})
        @MainActor
        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                logger.warning("Invalid message from WebView: \(String(describing: message.body))")
                return
            }

            switch type {
            case "ready":
                logger.info("Pixel Agents WebView ready")
                webViewReady = true
                // Flush any events that arrived before the WebView was ready
                for event in pendingEvents {
                    sendAgentEvent(event)
                }
                pendingEvents.removeAll()
                // Send config so JS knows theme, app name, version
                sendConfig()
                // Start watching transcripts now that JS can receive events
                transcriptWatcher?.start()

            case "requestConfig":
                logger.info("WebView requested config")
                sendConfig()

            case "agentCountUpdate":
                if let count = body["count"] as? Int {
                    agentCount.wrappedValue = count
                }

            case "activityUpdate":
                if let activity = body["activity"] as? String {
                    lastActivity.wrappedValue = activity
                }

            default:
                logger.debug("Unknown message type from WebView: \(type)")
            }
        }
    }

}
