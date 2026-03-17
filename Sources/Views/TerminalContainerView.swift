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
    static let terminalTitleChanged = Notification.Name("factoryfloor.terminalTitleChanged")
}

/// Deterministic UUID derived from a base UUID and a salt string.
/// Uses simple byte-folding to produce fully deterministic output (no random bytes).
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
    @State private var browserTitles: [UUID: String] = [:]
    @State private var terminalTitles: [UUID: String] = [:]
    @State private var cachedClaudeCommand: String?

    private var claudeID: UUID { workstreamID }

    private var useTmux: Bool {
        tmuxMode && appEnv.toolStatus.tmux.isInstalled
    }

    private var workstreamPort: Int {
        PortAllocator.port(for: workingDirectory)
    }

    private var branchPR: GitHubPR? {
        guard let branch = appEnv.branchName(for: workingDirectory) else { return nil }
        return appEnv.githubPR(for: projectDirectory, branch: branch)
    }

    private func buildClaudeCommand() -> String? {
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
                    let customIndex = index - 2 // skip Info and Agent
                    WorkspaceTabButton(
                        tab: tab,
                        label: tabLabel(tab),
                        icon: tabIcon(tab),
                        shortcut: tabShortcut(tab) ?? (customIndex >= 0 && customIndex < 9 ? "\(customIndex + 1)" : nil),
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
                    .buttonStyle(.borderless)
                    .help(pr.title)
                    .accessibilityLabel("Pull request #\(pr.number)")
                    .accessibilityHint(pr.title)
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
                if appEnv.toolStatus.claude.path == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Claude Code not found")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Install Claude Code to use the Coding Agent.")
                            .foregroundStyle(.tertiary)
                        Link("Install Claude Code", destination: URL(string: "https://claude.ai/claude-code")!)
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SingleTerminalView(
                        surfaceID: claudeID,
                        workingDirectory: workingDirectory,
                        command: cachedClaudeCommand,
                        isFocused: true,
                        environmentVars: envVars
                    )
                }
            case .terminal(let id):
                SingleTerminalView(
                    surfaceID: id,
                    workingDirectory: workingDirectory,
                    isFocused: true,
                    environmentVars: terminalEnvVars
                )
            case .browser(let id):
                BrowserView(defaultURL: "http://localhost:\(workstreamPort)/", tabID: id)
                    .id(id)
            }
        }
        .onAppear {
            cachedClaudeCommand = buildClaudeCommand()
            scriptConfig = ScriptConfig.load(from: projectDirectory)
            surfaceCache.respawnableIDs.insert(claudeID)
            runSetupIfNeeded()
        }
        .onChange(of: tmuxMode) { _ in cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: bypassPermissions) { _ in cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: autoRenameBranch) { _ in cachedClaudeCommand = buildClaudeCommand() }
        .onReceive(appEnv.objectWillChange) { _ in cachedClaudeCommand = buildClaudeCommand() }
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
            guard let n = notification.object as? Int, n >= 1 else { return }
            // Cmd+1-9 maps to custom tabs (after Info and Agent)
            let customTabs = Array(tabs.dropFirst(2))
            guard n <= customTabs.count else { return }
            activeTab = customTabs[n - 1]
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx + 1) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            guard let idx = tabs.firstIndex(of: activeTab) else { return }
            activeTab = tabs[(idx - 1 + tabs.count) % tabs.count]
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalTabExited)) { notification in
            guard let surfaceID = notification.object as? UUID else { return }
            if let tab = tabs.first(where: {
                if case .terminal(let id) = $0 { return id == surfaceID }
                return false
            }) {
                closeTab(tab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .browserTitleChanged)) { notification in
            guard let tabID = notification.object as? UUID else { return }
            browserTitles[tabID] = notification.userInfo?["title"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalTitleChanged)) { notification in
            guard let surfaceID = notification.object as? UUID else { return }
            terminalTitles[surfaceID] = notification.userInfo?["title"] as? String
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
        case .terminal(let id):
            guard let title = terminalTitles[id], !title.isEmpty else { return nil }
            return title.count > 20 ? String(title.prefix(20)) + "..." : title
        case .browser(let id):
            guard let title = browserTitles[id], !title.isEmpty else { return nil }
            return title.count > 20 ? String(title.prefix(20)) + "..." : title
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
        case .info: return "I"
        case .agent: return "\u{21A9}"
        default: return nil
        }
    }

    private func addTerminal() {
        terminalCount += 1
        let id = derivedUUID(from: workstreamID, salt: "terminal-\(terminalCount)")
        let tab = WorkspaceTab.terminal(id)
        tabs.append(tab)
        activeTab = tab
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
                    .accessibilityLabel("Close tab")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(isActive ? .primary : .secondary)
        }
        .buttonStyle(.borderless)
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
        .buttonStyle(.borderless)
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

extension Notification.Name {
    static let terminalTabExited = Notification.Name("factoryfloor.terminalTabExited")
}

final class TerminalSurfaceCache: ObservableObject {
    private var surfaces: [UUID: TerminalView] = [:]
    private var surfaceParams: [UUID: SurfaceParams] = [:]
    /// Surface IDs that should respawn when closed (e.g., the agent).
    var respawnableIDs: Set<UUID> = []

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
        // Remove agent surface
        removeSurface(for: workstreamID)
        // Remove all derived terminal/browser surfaces.
        // Generate IDs until we stop finding matches.
        for prefix in ["terminal", "browser"] {
            for i in 0... {
                let id = derivedUUID(from: workstreamID, salt: "\(prefix)-\(i)")
                guard surfaces[id] != nil else { break }
                removeSurface(for: id)
            }
        }
    }

    private func handleSurfaceClosed(_ closedView: TerminalView) {
        guard let (id, _) = surfaces.first(where: { $0.value === closedView }) else { return }

        if respawnableIDs.contains(id) {
            // Agent: respawn the surface
            guard let params = surfaceParams[id],
                  let app = TerminalApp.shared.app else { return }
            surfaces.removeValue(forKey: id)
            let newView = TerminalView(app: app, workingDirectory: params.workingDirectory, command: params.command, initialInput: params.initialInput, environmentVars: params.environmentVars)
            newView.workstreamID = id
            surfaces[id] = newView
            objectWillChange.send()
        } else {
            // Terminal/browser tabs: close the tab
            removeSurface(for: id)
            NotificationCenter.default.post(name: .terminalTabExited, object: id)
        }
    }
}
