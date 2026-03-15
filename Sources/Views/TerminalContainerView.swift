// ABOUTME: Hosts a workstream's two terminals: claude (main) and workspace (secondary).
// ABOUTME: Manages the lifecycle of terminal surfaces, caching them for fast switching.

import SwiftUI

extension Notification.Name {
    static let terminalSurfaceClosed = Notification.Name("ff2.terminalSurfaceClosed")
}

/// Deterministic UUID derived from a base UUID and a salt string.
func derivedUUID(from base: UUID, salt: String) -> UUID {
    var hasher = Hasher()
    hasher.combine(base)
    hasher.combine(salt)
    let hash = hasher.finalize()
    // Build a deterministic UUID from the hash
    var bytes = UUID().uuid
    withUnsafeMutableBytes(of: &bytes) { buf in
        withUnsafeBytes(of: hash) { hashBuf in
            for i in 0..<min(buf.count, hashBuf.count) {
                buf[i] = hashBuf[i]
            }
        }
    }
    return UUID(uuid: bytes)
}

enum WorkstreamTab: Hashable {
    case info
    case claude
    case workspace
    case browser
}

struct TerminalContainerView: View {
    let workstreamID: UUID
    let workingDirectory: String
    let projectName: String
    let workstreamName: String
    let bypassPermissions: Bool

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache
    @EnvironmentObject var appEnv: AppEnvironment
    @AppStorage("ff2.defaultBrowser") private var defaultBrowser: String = ""
    @AppStorage("ff2.tmuxMode") private var tmuxMode: Bool = false
    @AppStorage("ff2.agentTeams") private var agentTeams: Bool = false
    @State private var activeTab: WorkstreamTab = .info

    private var claudeID: UUID { workstreamID }
    private var workspaceID: UUID { derivedUUID(from: workstreamID, salt: "workspace") }

    private var useTmux: Bool {
        tmuxMode && appEnv.toolStatus.tmux.isInstalled
    }

    private var claudeCommand: String? {
        let basePath = appEnv.toolStatus.claude.path
        var cmd: String?
        if let basePath {
            let sessionID = workstreamID.uuidString.lowercased()
            let wsNameEscaped = workstreamName.replacingOccurrences(of: "\"", with: "\\\"")
            var flags = "--name \"\(wsNameEscaped)\""
            if useTmux {
                flags += " --teammate-mode tmux"
            }
            if bypassPermissions {
                flags += " --dangerously-skip-permissions"
            }
            // Try resuming the workstream's session, fall back to creating one with a fixed ID
            cmd = "sh -c \"\(basePath) --resume \(sessionID) \(flags) 2>/dev/null || (echo 'Starting new session...' && \(basePath) --session-id \(sessionID) \(flags))\""
        }

        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "agent")
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd)
        }
        return cmd
    }

    private var workspaceCommand: String? {
        guard useTmux, let tmuxPath = appEnv.toolStatus.tmux.path else { return nil }
        let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "terminal")
        return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Info", icon: "info.circle", shortcut: "0", isActive: activeTab == .info) {
                    activeTab = .info
                }
                TabButton(title: "Coding Agent", icon: "sparkle", shortcut: "1", isActive: activeTab == .claude) {
                    activeTab = .claude
                }
                TabButton(title: "Terminal", icon: "terminal", shortcut: "2", isActive: activeTab == .workspace) {
                    activeTab = .workspace
                }
                TabButton(title: "Browser", icon: "globe", shortcut: "3", isActive: activeTab == .browser) {
                    activeTab = .browser
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            Divider()

            // Tab content
            switch activeTab {
            case .info:
                WorkstreamInfoView(
                    workstreamName: workstreamName,
                    workingDirectory: workingDirectory,
                    projectName: projectName
                )
            case .claude:
                SingleTerminalView(
                    surfaceID: claudeID,
                    workingDirectory: workingDirectory,
                    command: claudeCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            case .workspace:
                SingleTerminalView(
                    surfaceID: workspaceID,
                    workingDirectory: workingDirectory,
                    command: workspaceCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            case .browser:
                BrowserView(defaultURL: "http://localhost:8000")
            }
        }
        .onAppear { prewarmSurfaces() }
        .onReceive(NotificationCenter.default.publisher(for: .switchToInfo)) { _ in
            activeTab = .info
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAgent)) { _ in
            activeTab = .claude
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTerminal)) { _ in
            activeTab = .workspace
        }
        .onReceive(NotificationCenter.default.publisher(for: .retryBrowser)) { _ in
            activeTab = .browser
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            switch activeTab {
            case .info: activeTab = .claude
            case .claude: activeTab = .workspace
            case .workspace: activeTab = .browser
            case .browser: activeTab = .info
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            switch activeTab {
            case .info: activeTab = .browser
            case .claude: activeTab = .info
            case .workspace: activeTab = .claude
            case .browser: activeTab = .workspace
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExternalBrowser)) { _ in
            guard let url = URL(string: "http://localhost:8000") else { return }
            if defaultBrowser.isEmpty {
                NSWorkspace.shared.open(url)
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: defaultBrowser) {
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Pre-create terminal surfaces so they're ready when tabs are switched.
    private func prewarmSurfaces() {
        guard let app = TerminalApp.shared.app else { return }
        _ = surfaceCache.surface(
            for: claudeID, app: app, workingDirectory: workingDirectory,
            command: claudeCommand, environmentVars: envVars
        )
        _ = surfaceCache.surface(
            for: workspaceID, app: app, workingDirectory: workingDirectory,
            command: workspaceCommand, environmentVars: envVars
        )
    }

    private var envVars: [String: String] {
        var vars = [
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
        ]
        if agentTeams {
            vars["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        }
        return vars
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    var shortcut: String? = nil
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                if let shortcut {
                    Text("\(Image(systemName: "command"))\(shortcut)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(isActive ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// NSViewRepresentable for a single terminal surface.
struct SingleTerminalView: NSViewRepresentable {
    let surfaceID: UUID
    let workingDirectory: String
    var command: String?
    var initialInput: String?
    var isFocused: Bool = true
    var environmentVars: [String: String] = [:]

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let app = TerminalApp.shared.app else { return }

        let terminalView = surfaceCache.surface(
            for: surfaceID,
            app: app,
            workingDirectory: workingDirectory,
            command: command,
            initialInput: initialInput,
            environmentVars: environmentVars
        )

        // Always re-parent: with conditional rendering, the container is
        // recreated each time the tab switches.
        if terminalView.superview !== container {
            terminalView.removeFromSuperview()
            container.subviews.forEach { $0.removeFromSuperview() }
            container.addSubview(terminalView)
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: container.topAnchor),
                terminalView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                terminalView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                terminalView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        // Delay focus slightly to ensure the view is fully in the hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            terminalView.setFocused(isFocused)
        }
    }
}

/// Caches terminal surfaces so switching workstreams doesn't destroy/recreate them.
final class TerminalSurfaceCache: ObservableObject {
    private var surfaces: [UUID: TerminalView] = [:]
    private var surfaceParams: [UUID: SurfaceParams] = [:]

    struct SurfaceParams {
        let workingDirectory: String
        let command: String?
        let initialInput: String?
        let environmentVars: [String: String]
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .terminalSurfaceClosed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let closedView = notification.object as? TerminalView else { return }
            self.handleSurfaceClosed(closedView)
        }
    }

    func surface(for id: UUID, app: ghostty_app_t, workingDirectory: String, command: String? = nil, initialInput: String? = nil, environmentVars: [String: String] = [:]) -> TerminalView {
        if let existing = surfaces[id] {
            existing.workstreamID = id
            return existing
        }
        let view = TerminalView(app: app, workingDirectory: workingDirectory, command: command, initialInput: initialInput, environmentVars: environmentVars)
        view.workstreamID = id
        surfaces[id] = view
        surfaceParams[id] = SurfaceParams(workingDirectory: workingDirectory, command: command, initialInput: initialInput, environmentVars: environmentVars)
        return view
    }

    func removeSurface(for id: UUID) {
        surfaces.removeValue(forKey: id)
        surfaceParams.removeValue(forKey: id)
    }

    /// Remove both claude and workspace surfaces for a workstream.
    func removeWorkstreamSurfaces(for workstreamID: UUID) {
        removeSurface(for: workstreamID)
        removeSurface(for: derivedUUID(from: workstreamID, salt: "workspace"))
    }

    private func handleSurfaceClosed(_ closedView: TerminalView) {
        guard let (id, _) = surfaces.first(where: { $0.value === closedView }) else { return }
        guard let params = surfaceParams[id],
              let app = TerminalApp.shared.app else { return }

        surfaces.removeValue(forKey: id)
        let newView = TerminalView(app: app, workingDirectory: params.workingDirectory, command: params.command, initialInput: params.initialInput, environmentVars: params.environmentVars)
        newView.workstreamID = id
        surfaces[id] = newView

        objectWillChange.send()
    }
}
