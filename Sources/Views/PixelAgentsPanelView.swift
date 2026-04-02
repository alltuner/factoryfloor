// ABOUTME: Collapsible bottom panel showing pixel art agent visualization.
// ABOUTME: Uses cached WKWebView from PixelAgentsPanelCache for persistence across workstream switches.

import Combine
import os
import SwiftUI
import WebKit

private let logger = Logger(subsystem: "factoryfloor", category: "pixel-agents")

extension Notification.Name {
    static let togglePixelAgents = Notification.Name("factoryfloor.togglePixelAgents")
}

struct PixelAgentsPanelView: View {
    let projectDirectory: String
    @EnvironmentObject private var pixelAgentsCache: PixelAgentsPanelCache
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
                CachedPixelAgentsWebView(
                    cacheEntry: pixelAgentsCache.entry(for: projectDirectory)
                )
                .frame(height: max(minPanelHeight, min(maxPanelHeight, CGFloat(panelHeight) + dragOffset)))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .togglePixelAgents)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onReceive(pixelAgentsCache.entry(for: projectDirectory).agentCount) { count in
            agentCount = count
        }
        .onReceive(pixelAgentsCache.entry(for: projectDirectory).lastActivity) { activity in
            lastActivity = activity
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

// MARK: - Thin NSViewRepresentable that reparents the cached WKWebView

/// Displays a cached `WKWebView` by adding it as a subview of a plain `NSView` container.
/// When SwiftUI destroys and recreates this representable (due to `.id(workstream.id)`),
/// the cached web view is simply moved from its old container to the new one.
struct CachedPixelAgentsWebView: NSViewRepresentable {
    let cacheEntry: PixelAgentsPanelCache.CacheEntry

    func makeNSView(context _: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        attachWebView(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context _: Context) {
        // If the cached web view is not yet in this container, reparent it
        if cacheEntry.webView.superview !== container {
            attachWebView(to: container)
        }
    }

    private func attachWebView(to container: NSView) {
        let webView = cacheEntry.webView
        // Remove from previous container if reparenting
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}

// MARK: - Coordinator (lives in the cache, not in the NSViewRepresentable)

/// Handles JS->Swift messages and hook events for a pixel agents panel.
/// Created by `PixelAgentsPanelCache` and lives as long as the cache entry.
class PixelAgentsPanelCoordinator: NSObject, WKScriptMessageHandler {
    var webView: WKWebView?
    var agentCountSubject: CurrentValueSubject<Int, Never>
    var lastActivitySubject: CurrentValueSubject<String, Never>
    private let projectDirectory: String
    private var webViewReady = false
    private var pendingEvents: [AgentEvent] = []
    private var pendingSetupState: AsyncSetupState?
    private nonisolated(unsafe) var setupObserver: NSObjectProtocol?

    init(
        projectDirectory: String,
        agentCountSubject: CurrentValueSubject<Int, Never>,
        lastActivitySubject: CurrentValueSubject<String, Never>
    ) {
        self.projectDirectory = projectDirectory
        self.agentCountSubject = agentCountSubject
        self.lastActivitySubject = lastActivitySubject
        super.init()
        // Register with hook router so HTTP hook events reach this coordinator
        HookEventRouter.shared.register(projectDir: projectDirectory) { [weak self] event in
            self?.handleAgentEvent(event)
        }
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
        HookEventRouter.shared.unregister(projectDir: projectDirectory)
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
        guard webViewReady else {
            // Store latest state so it can be flushed when WebView is ready
            pendingSetupState = state
            return
        }

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

    private func handleAgentEvent(_ event: AgentEvent) {
        guard webViewReady else {
            pendingEvents.append(event)
            return
        }
        sendAgentEvent(event)

        // Update header strip info via subject
        if event.type == .agentToolStart, let tool = event.tool {
            lastActivitySubject.send("\(event.agentId): \(tool)")
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
            // Create main agent (palette 0, name "Claude")
            sendAgentEvent(AgentEvent.created(agentId: "main", name: "Claude", palette: 0))
            // Send config so JS knows theme, app name, version
            sendConfig()
            // Flush any events that arrived before the WebView was ready
            for event in pendingEvents {
                sendAgentEvent(event)
            }
            pendingEvents.removeAll()
            // Flush pending setup progress (setup may have started before WebView loaded)
            if let state = pendingSetupState {
                pendingSetupState = nil
                sendSetupProgress(state: state)
            }

        case "requestConfig":
            logger.info("WebView requested config")
            sendConfig()

        case "agentCountUpdate":
            if let count = body["count"] as? Int {
                agentCountSubject.send(count)
            }

        case "activityUpdate":
            if let activity = body["activity"] as? String {
                lastActivitySubject.send(activity)
            }

        default:
            logger.debug("Unknown message type from WebView: \(type)")
        }
    }
}
