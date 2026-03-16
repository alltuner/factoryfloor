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

enum WorkstreamTab: Hashable, CaseIterable {
    case info
    case claude
    case workspace
    case browser
    case setup
    case run
}

struct TerminalContainerView: View {
    let workstreamID: UUID
    let workingDirectory: String
    let projectDirectory: String
    let projectName: String
    let workstreamName: String
    let bypassPermissions: Bool

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache
    @EnvironmentObject var appEnv: AppEnvironment
    @AppStorage("ff2.defaultBrowser") private var defaultBrowser: String = ""
    @AppStorage("ff2.tmuxMode") private var tmuxMode: Bool = false
    @AppStorage("ff2.agentTeams") private var agentTeams: Bool = false
    @AppStorage("ff2.autoRenameBranch") private var autoRenameBranch: Bool = false
    @State private var activeTab: WorkstreamTab = .info
    @State private var scriptConfig: ScriptConfig = .empty

    private var claudeID: UUID { workstreamID }
    private var workspaceID: UUID { derivedUUID(from: workstreamID, salt: "workspace") }
    private var setupID: UUID { derivedUUID(from: workstreamID, salt: "setup") }
    private var runID: UUID { derivedUUID(from: workstreamID, salt: "run") }

    private var useTmux: Bool {
        tmuxMode && appEnv.toolStatus.tmux.isInstalled
    }

    private var workstreamPort: Int {
        PortAllocator.port(for: workingDirectory)
    }

    private var claudeCommand: String? {
        guard let basePath = appEnv.toolStatus.claude.path else { return nil }
        let sessionID = workstreamID.uuidString.lowercased()

        // Common flags for both resume and new session
        var resume = CommandBuilder(basePath)
        resume.option("--resume", sessionID)
        resume.option("--name", workstreamName)
        if useTmux { resume.flag("--teammate-mode"); resume.arg("tmux") }
        if bypassPermissions { resume.flag("--dangerously-skip-permissions") }

        // New session gets extra flags
        var fresh = CommandBuilder(basePath)
        fresh.option("--session-id", sessionID)
        fresh.option("--name", workstreamName)
        if useTmux { fresh.flag("--teammate-mode"); fresh.arg("tmux") }
        if bypassPermissions { fresh.flag("--dangerously-skip-permissions") }
        if autoRenameBranch {
            fresh.option("--append-system-prompt", SystemPrompts.autoRenameBranchPrompt)
        }

        let cmd = CommandBuilder.withFallback(
            resume.command, fresh.command,
            message: "Starting new session..."
        )

        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "agent")
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd)
        }
        return cmd
    }

    private var workspaceCommand: String? {
        nil
    }

    private var setupCommand: String? {
        guard let cmd = scriptConfig.setup else { return nil }
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "setup")
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd)
        }
        return cmd
    }

    private var runCommand: String? {
        guard let cmd = scriptConfig.run else { return nil }
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "run")
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd)
        }
        return cmd
    }

    /// Tabs that are visible based on script config.
    private var visibleTabs: [WorkstreamTab] {
        var tabs: [WorkstreamTab] = [.info, .claude, .workspace, .browser]
        if scriptConfig.setup != nil { tabs.append(.setup) }
        if scriptConfig.run != nil { tabs.append(.run) }
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                TabButton(title: "Info", icon: "info.circle", shortcut: "1", isActive: activeTab == .info) {
                    activeTab = .info
                }
                TabButton(title: "Coding Agent", icon: "sparkle", shortcut: "2", isActive: activeTab == .claude) {
                    activeTab = .claude
                }
                TabButton(title: "Terminal", icon: "terminal", shortcut: "3", isActive: activeTab == .workspace) {
                    activeTab = .workspace
                }
                TabButton(title: "Browser", icon: "globe", shortcut: "4", isActive: activeTab == .browser) {
                    activeTab = .browser
                }
                if scriptConfig.setup != nil {
                    TabButton(title: "Setup", icon: "hammer", shortcut: "5", isActive: activeTab == .setup) {
                        activeTab = .setup
                    }
                }
                if scriptConfig.run != nil {
                    TabButton(title: "Run", icon: "play", shortcut: "6", isActive: activeTab == .run) {
                        activeTab = .run
                    }
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
                    projectName: projectName,
                    projectDirectory: projectDirectory,
                    scriptConfig: scriptConfig
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
                BrowserView(defaultURL: "http://localhost:\(workstreamPort)")
            case .setup:
                SingleTerminalView(
                    surfaceID: setupID,
                    workingDirectory: workingDirectory,
                    command: setupCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            case .run:
                SingleTerminalView(
                    surfaceID: runID,
                    workingDirectory: workingDirectory,
                    command: runCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            }
        }
        .onAppear {
            scriptConfig = ScriptConfig.load(from: projectDirectory)
            prewarmSurfaces()
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
            guard let n = notification.object as? Int else { return }
            switch n {
            case 1: activeTab = .info
            case 2: activeTab = .claude
            case 3: activeTab = .workspace
            case 4: activeTab = .browser
            case 5 where scriptConfig.setup != nil: activeTab = .setup
            case 6 where scriptConfig.run != nil: activeTab = .run
            default: break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            let tabs = visibleTabs
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx + 1) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            let tabs = visibleTabs
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx - 1 + tabs.count) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExternalBrowser)) { _ in
            guard let url = URL(string: "http://localhost:\(workstreamPort)") else { return }
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
    /// Setup runs immediately; Run is lazy (created when the user opens the tab).
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
        if scriptConfig.setup != nil {
            _ = surfaceCache.surface(
                for: setupID, app: app, workingDirectory: workingDirectory,
                command: setupCommand, environmentVars: envVars
            )
        }
    }

    private var envVars: [String: String] {
        WorkstreamEnvironment.variables(
            projectName: projectName,
            workstreamName: workstreamName,
            projectDirectory: projectDirectory,
            workingDirectory: workingDirectory,
            port: workstreamPort,
            agentTeams: agentTeams
        )
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

    /// Remove all surfaces for a workstream.
    func removeWorkstreamSurfaces(for workstreamID: UUID) {
        removeSurface(for: workstreamID)
        removeSurface(for: derivedUUID(from: workstreamID, salt: "workspace"))
        removeSurface(for: derivedUUID(from: workstreamID, salt: "setup"))
        removeSurface(for: derivedUUID(from: workstreamID, salt: "run"))
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
