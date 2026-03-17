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
    static let toggleEnvironment = Notification.Name("factoryfloor.toggleEnvironment")
    static let terminalTitleChanged = Notification.Name("factoryfloor.terminalTitleChanged")
}

enum RestorableWorkspaceTab: String, Codable, Sendable {
    case info
    case agent
    case environment

    init(activeTab: WorkspaceTab) {
        switch activeTab {
        case .agent:
            self = .agent
        case .environment:
            self = .environment
        case .info, .terminal, .browser:
            self = .info
        }
    }

    func workspaceTab(hasEnvironmentTab: Bool) -> WorkspaceTab {
        switch self {
        case .info:
            return .info
        case .agent:
            return .agent
        case .environment:
            return hasEnvironmentTab ? .environment : .info
        }
    }
}

enum WorkspaceStateStore {
    private static var fileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("workspace-tabs.json")
    }

    static func load(for workstreamID: UUID) -> RestorableWorkspaceTab? {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([String: RestorableWorkspaceTab].self, from: data) else {
            return nil
        }
        return saved[workstreamID.uuidString]
    }

    static func save(_ tab: RestorableWorkspaceTab, for workstreamID: UUID) {
        var saved: [String: RestorableWorkspaceTab] = [:]
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONDecoder().decode([String: RestorableWorkspaceTab].self, from: data) {
            saved = existing
        }
        saved[workstreamID.uuidString] = tab
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(saved) else { return }
        try? FilePersistence.writeAtomically(data, to: fileURL)
    }
}

func reorderedCustomTabs(_ tabs: [WorkspaceTab], dragging draggedTab: WorkspaceTab, to targetTab: WorkspaceTab) -> [WorkspaceTab] {
    guard draggedTab != targetTab,
          draggedTab.isCloseable,
          targetTab.isCloseable,
          let sourceIndex = tabs.firstIndex(of: draggedTab),
          let targetIndex = tabs.firstIndex(of: targetTab) else {
        return tabs
    }

    var reordered = tabs
    let movedTab = reordered.remove(at: sourceIndex)
    let insertionIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
    reordered.insert(movedTab, at: insertionIndex)
    return reordered
}

/// A tab in the workspace. Info and Agent are permanent; terminals and browsers are closeable.
enum WorkspaceTab: Hashable, Sendable {
    case info
    case agent
    case environment
    case terminal(UUID)
    case browser(UUID)

    var isCloseable: Bool {
        switch self {
        case .info, .agent, .environment: return false
        case .terminal, .browser: return true
        }
    }
}

enum TerminalSessionMode: Equatable {
    case standard
    case tmux
    case waitingForTools

    static func resolve(tmuxModeEnabled: Bool, isDetectingTools: Bool, tmuxInstalled: Bool) -> Self {
        if tmuxModeEnabled {
            if isDetectingTools {
                return .waitingForTools
            }
            if tmuxInstalled {
                return .tmux
            }
        }
        return .standard
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
    @State private var draggedCustomTab: WorkspaceTab?
    @StateObject private var portDetector: PortDetector
    @State private var runStoppedManually = false

    init(workstreamID: UUID, workingDirectory: String, projectDirectory: String, projectName: String, workstreamName: String, bypassPermissions: Bool) {
        self.workstreamID = workstreamID
        self.workingDirectory = workingDirectory
        self.projectDirectory = projectDirectory
        self.projectName = projectName
        self.workstreamName = workstreamName
        self.bypassPermissions = bypassPermissions
        _portDetector = StateObject(wrappedValue: PortDetector(workstreamID: workstreamID))
    }

    private var claudeID: UUID { workstreamID }

    /// Surface IDs that should be rendering for the active tab.
    /// Returns nil for the environment tab (env surface IDs are managed internally).
    private var visibleSurfaceIDs: Set<UUID>? {
        switch activeTab {
        case .agent: return [claudeID]
        case .terminal(let id): return [id]
        case .info, .browser: return []
        case .environment: return nil
        }
    }

    private var sessionMode: TerminalSessionMode {
        TerminalSessionMode.resolve(
            tmuxModeEnabled: tmuxMode,
            isDetectingTools: appEnv.isDetecting,
            tmuxInstalled: appEnv.toolStatus.tmux.isInstalled
        )
    }

    private var useTmux: Bool {
        sessionMode == .tmux
    }

    private var workstreamPort: Int {
        PortAllocator.port(for: workingDirectory)
    }

    private var browserDefaultURL: String {
        let port = portDetector.selectedPort ?? workstreamPort
        return "http://localhost:\(port)/"
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
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd, environmentVars: envVars)
        }
        return cmd
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { _, tab in
                tabButton(for: tab)
            }

            Spacer()

            AddTabButton(label: NSLocalizedString("Terminal", comment: ""), icon: "terminal", shortcut: "T", action: addTerminal)
            AddTabButton(label: NSLocalizedString("Browser", comment: ""), icon: "globe", shortcut: "B", action: addBrowser)

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
    }

    @ViewBuilder
    private func tabButton(for tab: WorkspaceTab) -> some View {
        let shortcut = tabShortcut(tab) ?? closeableTabShortcut(tab)
        let button = WorkspaceTabButton(
            tab: tab,
            label: tabLabel(tab),
            icon: tabIcon(tab),
            shortcut: shortcut,
            isActive: activeTab == tab,
            onSelect: { activeTab = tab },
            onClose: tab.isCloseable ? { closeTab(tab) } : nil
        )

        if tab.isCloseable {
            button
                .onDrag {
                    draggedCustomTab = tab
                    return NSItemProvider(object: NSString(string: tabDragIdentifier(tab)))
                }
                .onDrop(of: [.text], delegate: WorkspaceTabDropDelegate {
                    moveCustomTab(to: tab)
                })
        } else {
            button
        }
    }

    @ViewBuilder
    private var tabContent: some View {
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
            if sessionMode == .waitingForTools {
                terminalLoadingView(message: "Checking terminal tools...")
            } else if appEnv.toolStatus.claude.path == nil {
                VStack(spacing: 16) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("Claude Code not found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Install Claude Code to use the Coding Agent.")
                        .foregroundStyle(.tertiary)
                    Link("Install Claude Code", destination: URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!)
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
        case .environment:
            if sessionMode == .waitingForTools {
                terminalLoadingView(message: "Checking terminal tools...")
            } else {
                EnvironmentTabView(
                    workstreamID: workstreamID,
                    workingDirectory: workingDirectory,
                    projectName: projectName,
                    workstreamName: workstreamName,
                    scriptConfig: scriptConfig,
                    useTmux: useTmux,
                    environmentVars: terminalEnvVars,
                    runStoppedManually: $runStoppedManually
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
            BrowserView(defaultURL: browserDefaultURL, tabID: id)
                .id(id)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .onAppear {
            cachedClaudeCommand = buildClaudeCommand()
            scriptConfig = ScriptConfig.load(from: projectDirectory)
            surfaceCache.respawnableIDs.insert(claudeID)
            if scriptConfig.hasAnyScript && !tabs.contains(.environment) {
                tabs.insert(.environment, at: 2)
            }
            activeTab = restoredActiveTab()
            preloadSurfaces()
            surfaceCache.updateOcclusion(visibleSurfaceIDs: visibleSurfaceIDs)
        }
        .onChange(of: activeTab) {
            surfaceCache.updateOcclusion(visibleSurfaceIDs: visibleSurfaceIDs)
            WorkspaceStateStore.save(RestorableWorkspaceTab(activeTab: activeTab), for: workstreamID)
        }
        .onChange(of: tmuxMode) { cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: bypassPermissions) { cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: autoRenameBranch) { cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: workstreamName) { cachedClaudeCommand = buildClaudeCommand() }
        .onChange(of: appEnv.isDetecting) {
            cachedClaudeCommand = buildClaudeCommand()
            preloadSurfaces()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleInfo)) { _ in activeTab = .info }
        .onReceive(NotificationCenter.default.publisher(for: .focusAgent)) { _ in activeTab = .agent }
        .onReceive(NotificationCenter.default.publisher(for: .toggleEnvironment)) { _ in
            if tabs.contains(.environment) { activeTab = .environment }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTerminal)) { _ in addTerminal() }
        .onReceive(NotificationCenter.default.publisher(for: .toggleBrowser)) { _ in addBrowser() }
        .onReceive(NotificationCenter.default.publisher(for: .closeTerminal)) { _ in
            if activeTab.isCloseable { closeTab(activeTab) }
        }
    }

    var body: some View {
        mainContent
            .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
            guard let n = notification.object as? Int, n >= 1 else { return }
            // Cmd+1-9 maps to closeable tabs (terminals and browsers)
            let customTabs = tabs.filter(\.isCloseable)
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
            guard let url = URL(string: browserDefaultURL) else { return }
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
        case .info: return NSLocalizedString("Info", comment: "")
        case .agent: return NSLocalizedString("Agent", comment: "")
        case .environment: return NSLocalizedString("Environment", comment: "")
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
        case .environment: return "gearshape.2"
        case .terminal: return "terminal"
        case .browser: return "globe"
        }
    }

    private func closeableTabShortcut(_ tab: WorkspaceTab) -> String? {
        guard tab.isCloseable,
              let idx = tabs.filter(\.isCloseable).firstIndex(of: tab),
              idx < 9 else { return nil }
        return "\(idx + 1)"
    }

    private func tabShortcut(_ tab: WorkspaceTab) -> String? {
        switch tab {
        case .info: return "I"
        case .agent: return "\u{21A9}"
        case .environment: return "E"
        default: return nil
        }
    }

    private func tabDragIdentifier(_ tab: WorkspaceTab) -> String {
        switch tab {
        case .terminal(let id), .browser(let id):
            return id.uuidString
        case .info:
            return "info"
        case .agent:
            return "agent"
        case .environment:
            return "environment"
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

    private func moveCustomTab(to targetTab: WorkspaceTab) {
        guard let currentDraggedTab = draggedCustomTab else { return }
        tabs = reorderedCustomTabs(tabs, dragging: currentDraggedTab, to: targetTab)
        draggedCustomTab = nil
    }

    private func restoredActiveTab() -> WorkspaceTab {
        let hasEnvironmentTab = scriptConfig.hasAnyScript
        guard let savedTab = WorkspaceStateStore.load(for: workstreamID) else { return .info }
        return savedTab.workspaceTab(hasEnvironmentTab: hasEnvironmentTab)
    }

    /// Pre-create terminal surfaces so they start running before their tab is visible.
    private func preloadSurfaces() {
        guard sessionMode != .waitingForTools else { return }
        guard let app = TerminalApp.shared.app else { return }

        // Agent surface
        if let cmd = cachedClaudeCommand {
            _ = surfaceCache.surface(
                for: claudeID,
                app: app,
                workingDirectory: workingDirectory,
                command: cmd,
                environmentVars: envVars
            )
        }

        // Environment script surfaces
        if let setup = scriptConfig.setup {
            let setupID = derivedUUID(from: workstreamID, salt: "env-setup-0")
            let input: String
            if useTmux {
                input = buildEnvironmentCommand(script: setup, role: "setup") + "\n"
            } else {
                input = setup + "; exec tail -f /dev/null\n"
            }
            _ = surfaceCache.surface(
                for: setupID,
                app: app,
                workingDirectory: workingDirectory,
                initialInput: input,
                environmentVars: terminalEnvVars
            )
        }
    }

    private func buildEnvironmentCommand(script: String, role: String) -> String {
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: role)
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: script, environmentVars: envVars)
        }
        return script
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

    private func terminalLoadingView(message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct WorkspaceTabDropDelegate: DropDelegate {
    let onDropTab: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        true
    }

    func performDrop(info: DropInfo) -> Bool {
        onDropTab()
        return true
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

@MainActor
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
            Task { @MainActor in
                self.handleSurfaceClosed(closedView)
            }
        }
    }

    /// Marks surfaces in the given set as visible; all others are occluded.
    /// Pass nil to mark all surfaces as visible.
    func updateOcclusion(visibleSurfaceIDs: Set<UUID>?) {
        for (id, view) in surfaces {
            let visible = visibleSurfaceIDs.map { $0.contains(id) } ?? true
            view.setVisible(visible)
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
        if let view = surfaces.removeValue(forKey: id) {
            view.destroy()
        }
        surfaceParams.removeValue(forKey: id)
    }

    func removeWorkstreamSurfaces(for workstreamID: UUID) {
        // Remove agent surface
        removeSurface(for: workstreamID)
        // Build a set of all possible derived IDs and remove matches
        var derivedIDs = Set<UUID>()
        for prefix in ["terminal", "browser", "env-setup", "env-run"] {
            for i in 0...99 {
                derivedIDs.insert(derivedUUID(from: workstreamID, salt: "\(prefix)-\(i)"))
            }
        }
        for id in derivedIDs where surfaces[id] != nil {
            removeSurface(for: id)
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
