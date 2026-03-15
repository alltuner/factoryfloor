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
    @State private var activeTab: WorkstreamTab = .claude

    private var claudeID: UUID { workstreamID }
    private var workspaceID: UUID { derivedUUID(from: workstreamID, salt: "workspace") }

    private var useTmux: Bool {
        tmuxMode && appEnv.toolStatus.tmux.isInstalled
    }

    private var claudeCommand: String? {
        let basePath = appEnv.toolStatus.claude.path
        var cmd: String?
        if let basePath {
            cmd = bypassPermissions ? "\(basePath) --dangerously-skip-permissions" : basePath
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
                TabButton(title: "Coding Agent", icon: "sparkle", isActive: activeTab == .claude) {
                    activeTab = .claude
                }
                TabButton(title: "Terminal", icon: "terminal", isActive: activeTab == .workspace) {
                    activeTab = .workspace
                }
                TabButton(title: "Browser", icon: "globe", isActive: activeTab == .browser) {
                    activeTab = .browser
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            Divider()

            // Terminal content
            switch activeTab {
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
            case .claude: activeTab = .workspace
            case .workspace: activeTab = .browser
            case .browser: activeTab = .claude
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            switch activeTab {
            case .claude: activeTab = .browser
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

    private var envVars: [String: String] {
        [
            "FF_PROJECT": projectName,
            "FF_WORKSTREAM": workstreamName,
        ]
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
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

        if terminalView.superview !== container {
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

        DispatchQueue.main.async {
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
