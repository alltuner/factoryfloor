// ABOUTME: Workspace view with dynamic tabs for agent, terminals, and browsers.
// ABOUTME: Info and Agent are always present; terminals and browsers are added on demand.

import os
import SwiftUI
import WebKit

private let logger = Logger(subsystem: "factoryfloor", category: "surface-cache")

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

enum RestorableWorkspaceTab: String, Codable {
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
    private static let userDefaultsKey = "factoryfloor.workspaceTabs"

    static func load(for workstreamID: UUID) -> RestorableWorkspaceTab? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let saved = try? JSONDecoder().decode([String: RestorableWorkspaceTab].self, from: data)
        else { return nil }
        return saved[workstreamID.uuidString]
    }

    static func save(_ tab: RestorableWorkspaceTab, for workstreamID: UUID) {
        var saved: [String: RestorableWorkspaceTab] = [:]
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let existing = try? JSONDecoder().decode([String: RestorableWorkspaceTab].self, from: data)
        {
            saved = existing
        }
        saved[workstreamID.uuidString] = tab
        guard let data = try? JSONEncoder().encode(saved) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}

func reorderedCustomTabs(_ tabs: [WorkspaceTab], dragging draggedTab: WorkspaceTab, to targetTab: WorkspaceTab) -> [WorkspaceTab] {
    guard draggedTab != targetTab,
          draggedTab.isCloseable,
          targetTab.isCloseable,
          let sourceIndex = tabs.firstIndex(of: draggedTab),
          let targetIndex = tabs.firstIndex(of: targetTab)
    else {
        return tabs
    }

    var reordered = tabs
    let movedTab = reordered.remove(at: sourceIndex)
    let insertionIndex = targetIndex > sourceIndex ? targetIndex - 1 : targetIndex
    reordered.insert(movedTab, at: insertionIndex)
    return reordered
}

/// A tab in the workspace. Info and Agent are permanent; terminals and browsers are closeable.
enum WorkspaceTab: Hashable {
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

/// Captured workspace tab state for a workstream, used to survive navigation.
struct WorkspaceTabSnapshot {
    var tabs: [WorkspaceTab]
    var terminalCount: Int
    var browserCount: Int
    var activeTab: WorkspaceTab
    var browserTitles: [UUID: String]
    var terminalTitles: [UUID: String]

    /// Returns a copy with dead terminal tabs removed.
    /// Browser tabs are kept regardless (they don't use terminal surfaces).
    func reconciled(liveSurfaceIDs: Set<UUID>) -> WorkspaceTabSnapshot {
        let filteredTabs = tabs.filter { tab in
            if case let .terminal(id) = tab {
                return liveSurfaceIDs.contains(id)
            }
            return true
        }
        let resolvedActiveTab = filteredTabs.contains(activeTab) ? activeTab : .agent
        return WorkspaceTabSnapshot(
            tabs: filteredTabs,
            terminalCount: terminalCount,
            browserCount: browserCount,
            activeTab: resolvedActiveTab,
            browserTitles: browserTitles,
            terminalTitles: terminalTitles
        )
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
    @AppStorage("factoryfloor.allowOutsideWorktree") private var allowOutsideWorktree: Bool = false
    @AppStorage("factoryfloor.quickActionDebug") private var quickActionDebug: Bool = false
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
    @State private var runStarted = false
    init(workstreamID: UUID, workingDirectory: String, projectDirectory: String, projectName: String, workstreamName: String, bypassPermissions: Bool) {
        self.workstreamID = workstreamID
        self.workingDirectory = workingDirectory
        self.projectDirectory = projectDirectory
        self.projectName = projectName
        self.workstreamName = workstreamName
        self.bypassPermissions = bypassPermissions
        _portDetector = StateObject(wrappedValue: PortDetector(workstreamID: workstreamID))
    }

    private var claudeID: UUID {
        workstreamID
    }

    private var quickActionRunner: QuickActionRunner {
        surfaceCache.quickActionRunner(for: workstreamID)
    }

    /// Surface IDs that should be rendering for the active tab.
    /// Returns nil for the environment tab (env surface IDs are managed internally).
    private var visibleSurfaceIDs: Set<UUID>? {
        switch activeTab {
        case .agent: return [claudeID]
        case let .terminal(id): return [id]
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

    private var portSubtitle: String {
        let label = appEnv.taskDescription(for: workingDirectory) ?? projectName
        if let port = portDetector.selectedPort {
            return "\(label) · localhost:\(port) · \u{2318}B for browser"
        }
        return label
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

        var systemPromptParts: [String] = []
        if !allowOutsideWorktree {
            systemPromptParts.append(SystemPrompts.restrictToWorktreePrompt(worktreePath: workingDirectory))
        }
        if autoRenameBranch {
            systemPromptParts.append(SystemPrompts.autoRenameBranchPrompt)
        }
        let combinedSystemPrompt = systemPromptParts.isEmpty ? nil : systemPromptParts.joined(separator: "\n\n")

        var resume = CommandBuilder(basePath)
        resume.option("--resume", sessionID)
        if appEnv.toolStatus.claudeSupportsSessionName {
            resume.option("--name", workstreamName)
        }
        if useTmux { resume.flag("--teammate-mode"); resume.arg("tmux") }
        if bypassPermissions { resume.flag("--dangerously-skip-permissions") }
        if let combinedSystemPrompt {
            resume.option("--append-system-prompt", combinedSystemPrompt)
        }

        var fresh = CommandBuilder(basePath)
        fresh.option("--session-id", sessionID)
        if appEnv.toolStatus.claudeSupportsSessionName {
            fresh.option("--name", workstreamName)
        }
        if useTmux { fresh.flag("--teammate-mode"); fresh.arg("tmux") }
        if bypassPermissions { fresh.flag("--dangerously-skip-permissions") }
        if let combinedSystemPrompt {
            fresh.option("--append-system-prompt", combinedSystemPrompt)
        }

        let cmd = CommandBuilder.withFallback(
            resume.command, fresh.command,
            message: "Starting new session..."
        )

        let finalCommand: String
        var intermediates = [resume.command, fresh.command, cmd]
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "agent")
            finalCommand = TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: cmd, environmentVars: envVars, respawnOnExit: true)
            intermediates.append(finalCommand)
        } else {
            finalCommand = cmd
        }

        LaunchLogger.log(LaunchLogEntry(
            workstreamID: workstreamID,
            event: "agent-start",
            finalCommand: finalCommand,
            intermediateCommands: intermediates,
            environmentVariables: envVars,
            workingDirectory: workingDirectory,
            toolPaths: LaunchLogEntry.ToolPaths(
                claude: appEnv.toolStatus.claude.path,
                tmux: appEnv.toolStatus.tmux.path,
                ffRun: RunLauncher.executableURL()?.path
            ),
            settings: LaunchLogEntry.Settings(
                tmuxMode: tmuxMode,
                bypassPermissions: bypassPermissions,
                agentTeams: agentTeams,
                autoRenameBranch: autoRenameBranch,
                allowOutsideWorktree: allowOutsideWorktree
            ),
            shell: CommandBuilder.userShell
        ))

        return finalCommand
    }

    private func rebuildClaudeCommand() {
        cachedClaudeCommand = buildClaudeCommand()
    }

    private var fixedTabs: [WorkspaceTab] {
        tabs.filter { !$0.isCloseable }
    }

    private var closeableTabs: [WorkspaceTab] {
        tabs.filter(\.isCloseable)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            // Fixed tabs (Info, Agent, Environment)
            ForEach(fixedTabs, id: \.self) { tab in
                tabButton(for: tab)
            }

            // Scrollable closeable tabs (terminals, browsers)
            if !closeableTabs.isEmpty {
                ScrollableTabStrip(
                    tabs: closeableTabs,
                    activeTab: activeTab,
                    tabButton: { tab in tabButton(for: tab) }
                )
            }

            Spacer()

            if let pr = branchPR, let url = URL(string: pr.url) {
                let prColor: Color = pr.state == "MERGED" ? .purple : .green
                Button(action: { NSWorkspace.shared.open(url) }) {
                    HStack(spacing: 4) {
                        Image(systemName: pr.state == "MERGED" ? "arrow.triangle.merge" : "arrow.triangle.pull")
                            .font(.system(size: 11))
                        Text(verbatim: "#\(pr.number)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(prColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(prColor)
                }
                .buttonStyle(.borderless)
                .help(pr.title)
                .accessibilityLabel(Text(verbatim: "Pull request #\(pr.number)"))
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
                workstreamID: workstreamID,
                workstreamName: workstreamName,
                workingDirectory: workingDirectory,
                projectName: projectName,
                projectDirectory: projectDirectory,
                scriptConfig: scriptConfig
            )
        case .agent:
            if sessionMode == .waitingForTools || appEnv.isDetecting {
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
            } else if let claudeCommand = cachedClaudeCommand {
                SingleTerminalView(
                    surfaceID: claudeID,
                    workingDirectory: workingDirectory,
                    command: claudeCommand,
                    isFocused: true,
                    environmentVars: envVars
                )
            } else {
                terminalLoadingView(message: "Preparing Coding Agent...")
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
                    runStoppedManually: $runStoppedManually,
                    runStarted: $runStarted
                )
            }
        case let .terminal(id):
            SingleTerminalView(
                surfaceID: id,
                workingDirectory: workingDirectory,
                isFocused: true,
                environmentVars: terminalEnvVars
            )
        case let .browser(id):
            BrowserView(defaultURL: browserDefaultURL, tabID: id, webView: surfaceCache.webView(for: id))
                .id(id)
        }
    }

    private var mainContent: some View {
        mainLayout
            .onChange(of: tmuxMode) { rebuildClaudeCommand() }
            .onChange(of: bypassPermissions) { rebuildClaudeCommand() }
            .onChange(of: autoRenameBranch) { rebuildClaudeCommand() }
            .onChange(of: allowOutsideWorktree) { rebuildClaudeCommand() }
            .onChange(of: workstreamName) { rebuildClaudeCommand() }
            .onChange(of: appEnv.isDetecting) {
                rebuildClaudeCommand()
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

    private var mainLayout: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
            if quickActionDebug {
                Divider()
                QuickActionDebugView(runner: quickActionRunner)
            }
        }
        .onAppear {
            quickActionRunner.onSuccess = { action in
                appEnv.refreshWorktreeState(for: workingDirectory, projectDirectory: projectDirectory)
                if let branch = appEnv.branchName(for: workingDirectory) {
                    if action == .abandonPR {
                        appEnv.clearBranchPR(for: projectDirectory, branch: branch)
                    }
                    if action == .createPR || action == .abandonPR {
                        appEnv.refreshGitHubInfo(for: projectDirectory, branch: branch)
                    }
                }
            }
            appEnv.refreshWorktreeState(for: workingDirectory, projectDirectory: projectDirectory)
            cachedClaudeCommand = buildClaudeCommand()
            scriptConfig = ScriptConfig.load(from: projectDirectory)
            surfaceCache.respawnableIDs.insert(claudeID)
            if let snapshot = surfaceCache.restoreTabSnapshot(for: workstreamID) {
                tabs = snapshot.tabs
                terminalCount = snapshot.terminalCount
                browserCount = snapshot.browserCount
                activeTab = snapshot.activeTab
                browserTitles = snapshot.browserTitles
                terminalTitles = snapshot.terminalTitles
                if scriptConfig.hasAnyScript && !tabs.contains(.environment) {
                    tabs.insert(.environment, at: 2)
                }
            } else {
                if scriptConfig.hasAnyScript && !tabs.contains(.environment) {
                    tabs.insert(.environment, at: 2)
                }
                activeTab = restoredActiveTab()
            }
            preloadSurfaces()
            surfaceCache.updateOcclusion(visibleSurfaceIDs: visibleSurfaceIDs)
        }
        .onDisappear {
            surfaceCache.saveTabSnapshot(for: workstreamID, snapshot: currentTabSnapshot())
        }
        .onChange(of: activeTab) {
            surfaceCache.updateOcclusion(visibleSurfaceIDs: visibleSurfaceIDs)
            WorkspaceStateStore.save(RestorableWorkspaceTab(activeTab: activeTab), for: workstreamID)
            appEnv.refreshWorktreeState(for: workingDirectory, projectDirectory: projectDirectory)
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalActivity)) { notification in
            guard let wsID = notification.object as? UUID, wsID == workstreamID else { return }
            appEnv.refreshWorktreeState(for: workingDirectory, projectDirectory: projectDirectory)
        }
    }

    var body: some View {
        mainContent
            .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
                guard let n = notification.object as? Int, n >= 1 else { return }
                // Cmd+1-9 maps to all tabs in display order
                guard n <= tabs.count else { return }
                activeTab = tabs[n - 1]
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
                guard let currentIndex = tabs.firstIndex(of: activeTab) else { return }
                activeTab = tabs[(currentIndex + 1) % tabs.count]
            }
            .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
                guard let currentIndex = tabs.firstIndex(of: activeTab) else { return }
                activeTab = tabs[(currentIndex - 1 + tabs.count) % tabs.count]
            }
            .onReceive(NotificationCenter.default.publisher(for: .terminalTabExited)) { notification in
                guard let surfaceID = notification.object as? UUID else { return }
                if let tab = tabs.first(where: {
                    if case let .terminal(id) = $0 { return id == surfaceID }
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
            .navigationSubtitle(portSubtitle)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if let githubURL = appEnv.githubURL(for: projectDirectory) {
                        Button {
                            NSWorkspace.shared.open(githubURL)
                        } label: {
                            Label(NSLocalizedString("GitHub", comment: ""), image: "github")
                                .labelStyle(.iconOnly)
                        }
                        .help("Open on GitHub")
                    }

                    Button(action: addTerminal) {
                        Label(NSLocalizedString("Terminal", comment: ""), systemImage: "terminal")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("New Terminal (\u{2318}T)")

                    Button(action: addBrowser) {
                        Label(NSLocalizedString("Browser", comment: ""), systemImage: "globe")
                            .labelStyle(.titleAndIcon)
                    }
                    .help("New Browser (\u{2318}B)")

                    QuickActionButtons(
                        runner: quickActionRunner,
                        claudePath: appEnv.toolStatus.claude.path,
                        ghPath: appEnv.toolStatus.gh.path,
                        workingDirectory: workingDirectory,
                        branchName: appEnv.branchName(for: workingDirectory),
                        bypassPermissions: bypassPermissions,
                        worktreeState: appEnv.worktreeState(for: workingDirectory),
                        hasGitHubRemote: appEnv.hasGitHubRemote(projectDirectory),
                        prState: branchPR?.state
                    )
                }
            }
    }

    // MARK: - Tab management

    /// Number of closeable tabs beyond which labels are hidden to save space.
    private static let compactTabThreshold = 3

    private var useCompactTabs: Bool {
        tabs.filter(\.isCloseable).count > Self.compactTabThreshold
    }

    private func tabLabel(_ tab: WorkspaceTab) -> String? {
        switch tab {
        case .info: return NSLocalizedString("Info", comment: "")
        case .agent: return NSLocalizedString("Agent", comment: "")
        case .environment: return NSLocalizedString("Environment", comment: "")
        case .terminal:
            return nil
        case let .browser(id):
            guard !useCompactTabs else { return nil }
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
        case .agent: return "\u{21A9}"
        default: return nil
        }
    }

    private func tabDragIdentifier(_ tab: WorkspaceTab) -> String {
        switch tab {
        case let .terminal(id), let .browser(id):
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
        saveTabSnapshot()
    }

    private func addBrowser() {
        browserCount += 1
        let id = derivedUUID(from: workstreamID, salt: "browser-\(browserCount)")
        let tab = WorkspaceTab.browser(id)
        tabs.append(tab)
        activeTab = tab
        saveTabSnapshot()
    }

    private func closeTab(_ tab: WorkspaceTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        // Clean up cached views
        switch tab {
        case let .terminal(id):
            surfaceCache.removeSurface(for: id)
        case let .browser(id):
            surfaceCache.removeWebView(for: id)
        default:
            break
        }
        // Switch to previous tab or agent
        if activeTab == tab {
            let newIndex = min(index, tabs.count - 1)
            activeTab = tabs[newIndex]
        }
        saveTabSnapshot()
    }

    private func currentTabSnapshot() -> WorkspaceTabSnapshot {
        WorkspaceTabSnapshot(
            tabs: tabs,
            terminalCount: terminalCount,
            browserCount: browserCount,
            activeTab: activeTab,
            browserTitles: browserTitles,
            terminalTitles: terminalTitles
        )
    }

    private func saveTabSnapshot() {
        surfaceCache.saveTabSnapshot(for: workstreamID, snapshot: currentTabSnapshot())
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
            let cmd = buildEnvironmentCommand(script: setup, role: "setup")
            _ = surfaceCache.surface(
                for: setupID,
                app: app,
                workingDirectory: workingDirectory,
                command: cmd,
                environmentVars: terminalEnvVars
            )
        }
    }

    private func buildEnvironmentCommand(script: String, role: String) -> String {
        let command = scriptCommand(script: script, role: role)
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: role)
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: command, environmentVars: terminalEnvVars)
        }
        return command
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
            workstreamID: workstreamID,
            projectName: projectName,
            workstreamName: workstreamName,
            projectDirectory: projectDirectory,
            workingDirectory: workingDirectory,
            port: workstreamPort,
            agentTeams: agentTeams,
            defaultBranch: GitOperations.defaultBranch(at: projectDirectory),
            scriptSource: scriptConfig.source
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
            }
            if let shortcut {
                (Text(Image(systemName: "command")) + Text(shortcut))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            if let onClose, isHovering || isActive {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
                    .onTapGesture(perform: onClose)
                    .accessibilityLabel("Close tab")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : .clear))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(isActive ? .primary : .secondary)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}

private struct WorkspaceTabDropDelegate: DropDelegate {
    let onDropTab: () -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        true
    }

    func performDrop(info _: DropInfo) -> Bool {
        onDropTab()
        return true
    }
}

private struct QuickActionButtons: View {
    @ObservedObject var runner: QuickActionRunner
    let claudePath: String?
    let ghPath: String?
    let workingDirectory: String
    let branchName: String?
    let bypassPermissions: Bool
    let worktreeState: WorktreeState
    let hasGitHubRemote: Bool
    let prState: String?

    private var hasOpenPR: Bool {
        prState == "OPEN"
    }

    private func isVisible(_ action: QuickAction) -> Bool {
        switch action {
        case .commit:
            return worktreeState.hasUncommittedChanges
        case .push:
            return worktreeState.hasUnpushedCommits && worktreeState.hasRemote
        case .createPR:
            return hasGitHubRemote && worktreeState.hasBranchCommits && prState == nil
        case .abandonPR:
            return hasOpenPR
        }
    }

    private func disabledReason(for action: QuickAction) -> String? {
        if action.usesLLM {
            if claudePath == nil {
                return NSLocalizedString("Claude Code is not installed.", comment: "")
            }
            if !bypassPermissions {
                return NSLocalizedString("Enable \"Bypass permission prompts\" in Settings.", comment: "")
            }
        }
        if action == .abandonPR, ghPath == nil {
            return NSLocalizedString("gh CLI is not installed.", comment: "")
        }
        return nil
    }

    private func isRunningAction(_ action: QuickAction) -> Bool {
        if case let .running(a) = runner.state { return a == action }
        return false
    }

    private func resultState(for action: QuickAction) -> QuickActionState? {
        switch runner.state {
        case let .succeeded(a) where a == action: return runner.state
        case let .failed(a) where a == action: return runner.state
        default: return nil
        }
    }

    var body: some View {
        ForEach(QuickAction.allCases) { action in
            if isVisible(action) {
                QuickActionButton(
                    action: action,
                    isRunning: isRunningAction(action),
                    resultState: resultState(for: action),
                    disabledReason: disabledReason(for: action),
                    onRun: { runAction(action) }
                )
            }
        }
    }

    private func runAction(_ action: QuickAction) {
        guard disabledReason(for: action) == nil else { return }
        runner.run(
            action: action,
            claudePath: claudePath,
            ghPath: ghPath,
            workingDirectory: workingDirectory,
            branchName: branchName
        )
    }
}

private struct QuickActionButton: View {
    let action: QuickAction
    let isRunning: Bool
    let resultState: QuickActionState?
    let disabledReason: String?
    let onRun: () -> Void

    private var isDisabled: Bool {
        disabledReason != nil || isRunning
    }

    var body: some View {
        Button(action: onRun) {
            if isRunning {
                ProgressView()
                    .controlSize(.mini)
            } else if case .succeeded = resultState {
                Label(action.label, systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
            } else if case .failed = resultState {
                Label(action.label, systemImage: "xmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.red)
            } else {
                Label(action.label, systemImage: action.icon)
                    .labelStyle(.titleAndIcon)
            }
        }
        .disabled(isDisabled)
        .help(disabledReason ?? action.label)
        .accessibilityLabel(action.label)
    }
}

private struct ScrollableTabStrip<TabContent: View>: View {
    let tabs: [WorkspaceTab]
    let activeTab: WorkspaceTab
    @ViewBuilder let tabButton: (WorkspaceTab) -> TabContent

    @State private var contentOverflows = false
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    private var canScrollLeft: Bool {
        scrollOffset > 0
    }

    private var canScrollRight: Bool {
        scrollOffset < contentWidth - viewportWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            if contentOverflows, canScrollLeft {
                scrollArrow(direction: .left)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.self) { tab in
                            tabButton(tab)
                                .id(tab)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ContentWidthKey.self, value: geo.size.width)
                    })
                }
                .onPreferenceChange(ContentWidthKey.self) { width in
                    contentWidth = width
                    checkOverflow()
                }
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { viewportWidth = geo.size.width; checkOverflow() }
                        .onChange(of: geo.size.width) { _, new in viewportWidth = new; checkOverflow() }
                })
                .onChange(of: activeTab) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(activeTab, anchor: .center)
                    }
                }
            }

            if contentOverflows, canScrollRight {
                scrollArrow(direction: .right)
            }
        }
    }

    private enum ScrollDirection {
        case left, right
    }

    private func scrollArrow(direction: ScrollDirection) -> some View {
        Button(action: {}) {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }

    private func checkOverflow() {
        contentOverflows = contentWidth > viewportWidth + 1
    }
}

private struct ContentWidthKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

struct SingleTerminalView: View {
    let surfaceID: UUID
    let workingDirectory: String
    var command: String?
    var isFocused: Bool = true
    var environmentVars: [String: String] = [:]

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache

    var body: some View {
        if let failedCommand = surfaceCache.failedSurfaces[surfaceID] {
            SurfaceErrorView(command: failedCommand) {
                surfaceCache.retrySurface(for: surfaceID)
            }
        } else {
            TerminalSurfaceView(
                surfaceID: surfaceID,
                workingDirectory: workingDirectory,
                command: command,
                isFocused: isFocused,
                environmentVars: environmentVars
            )
        }
    }
}

private struct SurfaceErrorView: View {
    let command: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Terminal failed to start")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(3)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TerminalSurfaceView: NSViewRepresentable {
    let surfaceID: UUID
    let workingDirectory: String
    var command: String?
    var isFocused: Bool = true
    var environmentVars: [String: String] = [:]

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache

    func makeNSView(context _: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        return container
    }

    func updateNSView(_ container: NSView, context _: Context) {
        guard let app = TerminalApp.shared.app else { return }

        let terminalView = surfaceCache.surface(
            for: surfaceID,
            app: app,
            workingDirectory: workingDirectory,
            command: command,
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

// MARK: - Quick action debug

private struct QuickActionDebugView: View {
    @ObservedObject var runner: QuickActionRunner

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Quick Action Log")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if !runner.log.isEmpty {
                    Button("Clear") { runner.clearLog() }
                        .font(.system(size: 10))
                        .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if runner.log.isEmpty {
                Text("No quick actions run yet.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(runner.log) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(Self.timeFormatter.string(from: entry.timestamp))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.action.label)
                                        .foregroundStyle(.primary)
                                    if let code = entry.exitCode {
                                        Text("exit \(code)")
                                            .foregroundStyle(code == 0 ? .green : .red)
                                    } else {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                }
                                .font(.system(size: 11, weight: .medium, design: .monospaced))

                                Text("$ " + entry.command)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                if !entry.output.isEmpty {
                                    Text(entry.output)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(height: 200)
        .background(.background)
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
    private var tabSnapshots: [UUID: WorkspaceTabSnapshot] = [:]
    private var webViews: [UUID: WKWebView] = [:]
    private var quickActionRunners: [UUID: QuickActionRunner] = [:]
    /// Surface IDs that should respawn when closed (e.g., the agent).
    var respawnableIDs: Set<UUID> = []
    /// Guards against concurrent respawns for the same surface ID.
    private var respawning = Set<UUID>()
    /// Surface IDs where creation failed, with the command that was attempted.
    private(set) var failedSurfaces: [UUID: String] = [:]
    /// Tracks when each surface was created, for detecting immediate process death.
    private var creationTimes: [UUID: Date] = [:]
    /// Surfaces that died within this interval after creation are treated as launch failures.
    private static let healthCheckWindow: TimeInterval = 2.0

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
        if view.surface == nil {
            logger.error("Surface creation failed for \(id) command=\(command ?? "<shell>")")
            failedSurfaces[id] = command ?? "(default shell)"
            objectWillChange.send()
        } else {
            creationTimes[id] = Date()
        }
        return view
    }

    /// Retry creating a surface that previously failed.
    func retrySurface(for id: UUID) {
        guard let params = surfaceParams[id],
              let app = TerminalApp.shared.app else { return }
        logger.detailed("Retrying surface creation for \(id)")
        if let view = surfaces.removeValue(forKey: id) {
            view.destroy()
        }
        failedSurfaces.removeValue(forKey: id)
        let view = TerminalView(app: app, workingDirectory: params.workingDirectory, command: params.command, initialInput: params.initialInput, environmentVars: params.environmentVars)
        view.workstreamID = id
        surfaces[id] = view
        if view.surface == nil {
            logger.error("Surface retry failed for \(id)")
            failedSurfaces[id] = params.command ?? "(default shell)"
        } else {
            creationTimes[id] = Date()
        }
        objectWillChange.send()
    }

    func webView(for id: UUID) -> WKWebView {
        if let existing = webViews[id] { return existing }
        let view = BrowserWebView()
        webViews[id] = view
        return view
    }

    func quickActionRunner(for workstreamID: UUID) -> QuickActionRunner {
        if let existing = quickActionRunners[workstreamID] {
            return existing
        }
        let runner = QuickActionRunner()
        quickActionRunners[workstreamID] = runner
        return runner
    }

    func removeWebView(for id: UUID) {
        webViews.removeValue(forKey: id)
    }

    func removeSurface(for id: UUID) {
        if let view = surfaces.removeValue(forKey: id) {
            view.destroy()
        }
        surfaceParams.removeValue(forKey: id)
        failedSurfaces.removeValue(forKey: id)
        creationTimes.removeValue(forKey: id)
    }

    func removeWorkstreamSurfaces(for workstreamID: UUID) {
        tabSnapshots.removeValue(forKey: workstreamID)
        if let runner = quickActionRunners.removeValue(forKey: workstreamID) {
            runner.cancel()
        }
        // Remove agent surface
        removeSurface(for: workstreamID)
        // Build a set of all possible derived IDs and remove matches
        var derivedIDs = Set<UUID>()
        for prefix in ["terminal", "browser", "env-setup", "env-run"] {
            for i in 0 ... 99 {
                derivedIDs.insert(derivedUUID(from: workstreamID, salt: "\(prefix)-\(i)"))
            }
        }
        for id in derivedIDs {
            if surfaces[id] != nil { removeSurface(for: id) }
            if webViews[id] != nil { removeWebView(for: id) }
        }
    }

    private func handleSurfaceClosed(_ closedView: TerminalView) {
        guard let (id, _) = surfaces.first(where: { $0.value === closedView }) else { return }

        // Check if the surface died immediately after creation (launch failure).
        let diedImmediately: Bool
        if let created = creationTimes[id] {
            let age = Date().timeIntervalSince(created)
            diedImmediately = age < Self.healthCheckWindow
            if diedImmediately {
                logger.error("Surface \(id) died after \(String(format: "%.1f", age))s, treating as launch failure")
            }
        } else {
            diedImmediately = false
        }

        if respawnableIDs.contains(id) {
            // If the surface died immediately, show error state instead of respawning in a loop.
            if diedImmediately {
                let command = surfaceParams[id]?.command ?? "(default shell)"
                failedSurfaces[id] = command
                objectWillChange.send()
                return
            }

            guard !respawning.contains(id) else {
                logger.detailed("Skipping concurrent respawn for surface \(id)")
                return
            }
            guard let params = surfaceParams[id],
                  let app = TerminalApp.shared.app else { return }

            respawning.insert(id)
            surfaces.removeValue(forKey: id)
            let newView = TerminalView(app: app, workingDirectory: params.workingDirectory, command: params.command, initialInput: params.initialInput, environmentVars: params.environmentVars)
            newView.workstreamID = id
            surfaces[id] = newView
            respawning.remove(id)
            if newView.surface == nil {
                logger.error("Respawn failed for surface \(id)")
                failedSurfaces[id] = params.command ?? "(default shell)"
            } else {
                creationTimes[id] = Date()
                logger.detailed("Respawned surface \(id)")
            }
            objectWillChange.send()
        } else if diedImmediately {
            // Terminal tab died immediately: show error instead of closing the tab.
            let command = surfaceParams[id]?.command ?? "(default shell)"
            failedSurfaces[id] = command
            objectWillChange.send()
        } else {
            removeSurface(for: id)
            NotificationCenter.default.post(name: .terminalTabExited, object: id)
        }
    }

    // MARK: - Text injection

    /// Send text to a terminal surface as if it were typed.
    func sendText(to surfaceID: UUID, text: String) {
        guard let view = surfaces[surfaceID],
              let surface = view.surface else { return }
        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(text.utf8.count))
        }
    }

    // MARK: - Workspace tab snapshots

    func saveTabSnapshot(for workstreamID: UUID, snapshot: WorkspaceTabSnapshot) {
        tabSnapshots[workstreamID] = snapshot
    }

    func restoreTabSnapshot(for workstreamID: UUID) -> WorkspaceTabSnapshot? {
        guard let snapshot = tabSnapshots[workstreamID] else { return nil }
        let liveSurfaceIDs = Set(surfaces.keys)
        return snapshot.reconciled(liveSurfaceIDs: liveSurfaceIDs)
    }

    func removeTabSnapshot(for workstreamID: UUID) {
        tabSnapshots.removeValue(forKey: workstreamID)
    }
}
