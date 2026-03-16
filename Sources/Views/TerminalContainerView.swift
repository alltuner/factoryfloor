// ABOUTME: Workspace view with dynamic tabs for agent, terminals, and browsers.
// ABOUTME: Info and Agent are always present; terminals and browsers are added on demand.

import SwiftUI

extension Notification.Name {
    static let terminalSurfaceClosed = Notification.Name("factoryfloor.terminalSurfaceClosed")
    static let toggleInfo = Notification.Name("factoryfloor.toggleInfo")
    static let toggleTerminal = Notification.Name("factoryfloor.toggleTerminal")
    static let toggleBrowser = Notification.Name("factoryfloor.toggleBrowser")
    static let focusAgent = Notification.Name("factoryfloor.focusAgent")
    static let closeTerminal = Notification.Name("factoryfloor.closeTerminal")
    static let nextTab = Notification.Name("factoryfloor.nextTab")
    static let prevTab = Notification.Name("factoryfloor.prevTab")
}

/// Deterministic UUID derived from a base UUID and a salt string.
/// Uses SHA-256 to produce fully deterministic output (no random bytes).
func derivedUUID(from base: UUID, salt: String) -> UUID {
    // Build a deterministic byte sequence from the base UUID and salt
    let input = "\(base.uuidString)-\(salt)"
    // Simple deterministic hash using all characters
    var bytes: [UInt8] = Array(repeating: 0, count: 16)
    for (i, byte) in input.utf8.enumerated() {
        bytes[i % 16] = bytes[i % 16] &+ byte &+ UInt8(i & 0xFF)
    }
    // Set version 4 and variant bits for valid UUID format
    bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant 1
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                       bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11],
                       bytes[12], bytes[13], bytes[14], bytes[15]))
}

/// A tab in the workspace. Info and Agent are permanent; terminals and browsers are closeable.
enum WorkspaceTab: Hashable {
    case info
    case agent
    case terminal(UUID)
    case browser(UUID)

    var isCloseable: Bool {
        switch self {
        case .info, .agent: return false
        case .terminal, .browser: return true
        }
    }
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
    @AppStorage("factoryfloor.defaultBrowser") private var defaultBrowser: String = ""
    @AppStorage("factoryfloor.tmuxMode") private var tmuxMode: Bool = false
    @AppStorage("factoryfloor.agentTeams") private var agentTeams: Bool = false
    @AppStorage("factoryfloor.autoRenameBranch") private var autoRenameBranch: Bool = false
    @State private var activeTab: WorkspaceTab = .info
    @State private var tabs: [WorkspaceTab] = [.info, .agent]
    @State private var terminalCount = 0
    @State private var browserCount = 0
    @State private var scriptConfig: ScriptConfig = .empty
    @State private var branchPR: GitHubPR?

    private var claudeID: UUID { workstreamID }

    private var useTmux: Bool {
        tmuxMode && appEnv.toolStatus.tmux.isInstalled
    }

    private var workstreamPort: Int {
        PortAllocator.port(for: workingDirectory)
    }

    private var claudeCommand: String? {
        guard let basePath = appEnv.toolStatus.claude.path else { return nil }
        let sessionID = workstreamID.uuidString.lowercased()

        var resume = CommandBuilder(basePath)
        resume.option("--resume", sessionID)
        resume.option("--name", workstreamName)
        if useTmux { resume.flag("--teammate-mode"); resume.arg("tmux") }
        if bypassPermissions { resume.flag("--dangerously-skip-permissions") }
        if autoRenameBranch {
            resume.option("--append-system-prompt", SystemPrompts.autoRenameBranchPrompt)
        }

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

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    WorkspaceTabButton(
                        tab: tab,
                        label: tabLabel(tab),
                        icon: tabIcon(tab),
                        shortcut: index < 9 ? "\(index + 1)" : nil,
                        isActive: activeTab == tab,
                        onSelect: { activeTab = tab },
                        onClose: tab.isCloseable ? { closeTab(tab) } : nil
                    )
                }

                Spacer()

                // Add buttons
                AddTabButton(label: "Terminal", icon: "terminal", shortcut: "T", action: addTerminal)
                AddTabButton(label: "Browser", icon: "globe", shortcut: "B", action: addBrowser)

                // PR badge
                if let pr = branchPR, let url = URL(string: pr.url) {
                    Button(action: { NSWorkspace.shared.open(url) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.system(size: 11))
                            Text("#\(pr.number)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help(pr.title)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.bar)

            Divider()

            // Content
            switch activeTab {
            case .info:
                WorkstreamInfoView(
                    workstreamName: workstreamName,
                    workingDirectory: workingDirectory,
                    projectName: projectName,
                    projectDirectory: projectDirectory,
                    scriptConfig: scriptConfig
                )
            case .agent:
                SingleTerminalView(
                    surfaceID: claudeID,
                    workingDirectory: workingDirectory,
                    command: claudeCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            case .terminal(let id):
                SingleTerminalView(
                    surfaceID: id,
                    workingDirectory: workingDirectory,
                    isFocused: true,
                    environmentVars: terminalEnvVars
                )
            case .browser(let id):
                BrowserView(defaultURL: "http://localhost:\(workstreamPort)/")
                    .id(id)
            }
        }
        .onAppear {
            scriptConfig = ScriptConfig.load(from: projectDirectory)
            prewarmAgent()
            runSetupIfNeeded()
            refreshBranchPR()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refreshBranchPR()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInfo)) { _ in
            activeTab = .info
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAgent)) { _ in
            activeTab = .agent
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTerminal)) { _ in
            addTerminal()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleBrowser)) { _ in
            addBrowser()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTerminal)) { _ in
            if activeTab.isCloseable {
                closeTab(activeTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
            guard let n = notification.object as? Int, n >= 1, n <= tabs.count else { return }
            activeTab = tabs[n - 1]
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx + 1) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx - 1 + tabs.count) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .openExternalBrowser)) { _ in
            guard let url = URL(string: "http://localhost:\(workstreamPort)/") else { return }
            if defaultBrowser.isEmpty {
                NSWorkspace.shared.open(url)
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: defaultBrowser) {
                NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Tab management

    private func tabLabel(_ tab: WorkspaceTab) -> String? {
        switch tab {
        case .info: return "Info"
        case .agent: return "Agent"
        case .terminal, .browser: return nil
        }
    }

    private func tabIcon(_ tab: WorkspaceTab) -> String {
        switch tab {
        case .info: return "info.circle"
        case .agent: return "sparkle"
        case .terminal: return "terminal"
        case .browser: return "globe"
        }
    }

    private func tabShortcut(_ tab: WorkspaceTab) -> String? {
        switch tab {
        case .agent: return "\u{21A9}"
        case .info: return "I"
        case .terminal, .browser: return nil
        }
    }

    private func addTerminal() {
        terminalCount += 1
        let id = derivedUUID(from: workstreamID, salt: "terminal-\(terminalCount)")

        // Prewarm the surface before showing the tab, giving Ghostty
        // time to initialize the PTY (same pattern as the agent surface).
        if let app = TerminalApp.shared.app {
            _ = surfaceCache.surface(
                for: id, app: app, workingDirectory: workingDirectory,
                environmentVars: terminalEnvVars
            )
        }

        let tab = WorkspaceTab.terminal(id)
        tabs.append(tab)

        // Small delay to let the surface initialize before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeTab = tab
        }
    }

    private func addBrowser() {
        browserCount += 1
        let id = derivedUUID(from: workstreamID, salt: "browser-\(browserCount)")
        let tab = WorkspaceTab.browser(id)
        tabs.append(tab)
        activeTab = tab
    }

    private func closeTab(_ tab: WorkspaceTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        // Clean up terminal surface
        if case .terminal(let id) = tab {
            surfaceCache.removeSurface(for: id)
        }
        // Switch to previous tab or agent
        if activeTab == tab {
            let newIndex = min(index, tabs.count - 1)
            activeTab = tabs[newIndex]
        }
    }

    // MARK: - Lifecycle

    private func prewarmAgent() {
        guard let app = TerminalApp.shared.app else { return }
        _ = surfaceCache.surface(
            for: claudeID, app: app, workingDirectory: workingDirectory,
            command: claudeCommand, environmentVars: envVars
        )
    }

    private func runSetupIfNeeded() {
        guard let setup = scriptConfig.setup else { return }
        let dir = workingDirectory
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", setup]
            process.currentDirectoryURL = URL(fileURLWithPath: dir)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func refreshBranchPR() {
        guard appEnv.ghAvailable, let ghPath = appEnv.toolStatus.gh.path else { return }
        let dir = projectDirectory
        let workDir = workingDirectory
        Task.detached {
            let branch = GitOperations.repoInfo(at: workDir).branch
            guard let branch else { return }
            let pr = GitHubOperations.prForBranch(ghPath: ghPath, at: dir, branch: branch)
            await MainActor.run {
                self.branchPR = pr
            }
        }
    }

    /// Env vars for plain terminal tabs. Clears tmux vars to prevent inheritance.
    private var terminalEnvVars: [String: String] {
        var vars = envVars
        vars["TMUX"] = ""
        vars["TMUX_PANE"] = ""
        return vars
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

// MARK: - Tab button

private struct WorkspaceTabButton: View {
    let tab: WorkspaceTab
    let label: String?
    let icon: String
    var shortcut: String? = nil
    let isActive: Bool
    let onSelect: () -> Void
    var onClose: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                }
                if let shortcut {
                    (Text(Image(systemName: "command")) + Text(shortcut))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                if let onClose, isHovering || isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                            .background(Color.primary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
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

private struct AddTabButton: View {
    let label: String
    let icon: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11))
                (Text(Image(systemName: "command")) + Text(shortcut))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovering ? Color.primary.opacity(0.05) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - SingleTerminalView

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

        if isFocused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                terminalView.window?.makeFirstResponder(terminalView)
            }
        }
    }
}

// MARK: - Surface cache

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

    /// Unfocus all surfaces except the given one.
    func focusExclusively(_ id: UUID) {
        for (surfaceID, view) in surfaces {
            view.setFocused(surfaceID == id)
        }
    }

    func removeWorkstreamSurfaces(for workstreamID: UUID) {
        removeSurface(for: workstreamID)
        for i in 0..<20 {
            removeSurface(for: derivedUUID(from: workstreamID, salt: "terminal-\(i)"))
            removeSurface(for: derivedUUID(from: workstreamID, salt: "browser-\(i)"))
        }
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
