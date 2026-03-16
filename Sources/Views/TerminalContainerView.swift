// ABOUTME: Agent-centric workspace view for a workstream.
// ABOUTME: Coding Agent is always the main view; Info, Terminal, Browser open on demand.

import SwiftUI

extension Notification.Name {
    static let terminalSurfaceClosed = Notification.Name("factoryfloor.terminalSurfaceClosed")
    static let toggleInfo = Notification.Name("factoryfloor.toggleInfo")
    static let toggleTerminal = Notification.Name("factoryfloor.toggleTerminal")
    static let toggleBrowser = Notification.Name("factoryfloor.toggleBrowser")
    static let focusAgent = Notification.Name("factoryfloor.focusAgent")
    static let closeTerminal = Notification.Name("factoryfloor.closeTerminal")
}

/// Deterministic UUID derived from a base UUID and a salt string.
func derivedUUID(from base: UUID, salt: String) -> UUID {
    var hasher = Hasher()
    hasher.combine(base)
    hasher.combine(salt)
    let hash = hasher.finalize()
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
    @State private var showingInfo = true
    @State private var showingBrowser = false
    @State private var terminalIDs: [UUID] = []
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
            // Toolbar
            toolbar
            Divider()

            // Content: show one view at a time
            if showingInfo {
                WorkstreamInfoView(
                    workstreamName: workstreamName,
                    workingDirectory: workingDirectory,
                    projectName: projectName,
                    projectDirectory: projectDirectory,
                    scriptConfig: scriptConfig
                )
            } else if showingBrowser {
                BrowserView(defaultURL: "http://localhost:\(workstreamPort)")
            } else {
                VStack(spacing: 0) {
                    SingleTerminalView(
                        surfaceID: claudeID,
                        workingDirectory: workingDirectory,
                        command: claudeCommand,
                        isFocused: terminalIDs.isEmpty,
                        environmentVars: envVars
                    )

                    ForEach(terminalIDs, id: \.self) { id in
                        Divider()
                        SingleTerminalView(
                            surfaceID: id,
                            workingDirectory: workingDirectory,
                            isFocused: id == terminalIDs.last,
                            environmentVars: envVars
                        )
                        .frame(minHeight: 100)
                    }
                }
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
            withAnimation(.easeInOut(duration: 0.15)) {
                showingInfo.toggle()
                if showingInfo { showingBrowser = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleTerminal)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                addTerminal()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTerminal)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                closeLastTerminal()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleBrowser)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                showingBrowser.toggle()
                if showingBrowser { showingInfo = false }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAgent)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                showingInfo = false
                showingBrowser = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
            guard let n = notification.object as? Int else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                switch n {
                case 1:
                    showingInfo.toggle()
                    if showingInfo { showingBrowser = false }
                case 2:
                    showingInfo = false
                    showingBrowser = false
                case 3:
                    addTerminal()
                case 4:
                    showingBrowser.toggle()
                    if showingBrowser { showingInfo = false }
                default: break
                }
            }
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

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            // Workstream info
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if let branch = appEnv.branchName(for: workingDirectory) ?? Optional(workstreamName) {
                    Text(branch)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Panel toggles
            ToolbarIconButton(icon: "info.circle", isActive: showingInfo, shortcut: "I") {
                NotificationCenter.default.post(name: .toggleInfo, object: nil)
            }
            .help("Toggle Info (\u{2318}1)")

            ToolbarIconButton(icon: "terminal", isActive: !terminalIDs.isEmpty, shortcut: "T", badge: terminalIDs.isEmpty ? nil : "\(terminalIDs.count)") {
                NotificationCenter.default.post(name: .toggleTerminal, object: nil)
            }
            .help("New Terminal (\u{2318}T)")

            ToolbarIconButton(icon: "globe", isActive: showingBrowser, shortcut: "B") {
                NotificationCenter.default.post(name: .toggleBrowser, object: nil)
            }
            .help("Toggle Browser (\u{2318}4)")

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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Actions

    private func addTerminal() {
        let id = derivedUUID(from: workstreamID, salt: "terminal-\(terminalIDs.count)")
        terminalIDs.append(id)
    }

    private func closeLastTerminal() {
        guard let last = terminalIDs.popLast() else { return }
        surfaceCache.removeSurface(for: last)
    }

    /// Only prewarm the Coding Agent. Everything else is on demand.
    private func prewarmAgent() {
        guard let app = TerminalApp.shared.app else { return }
        _ = surfaceCache.surface(
            for: claudeID, app: app, workingDirectory: workingDirectory,
            command: claudeCommand, environmentVars: envVars
        )
    }

    /// Run setup script in the background if configured.
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

// MARK: - Toolbar icon button

private struct ToolbarIconButton: View {
    let icon: String
    var isActive: Bool = false
    var shortcut: String? = nil
    var badge: String? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 28, height: 24)
                    .background(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : .clear))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(isActive ? .primary : .secondary)
                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - SingleTerminalView

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            terminalView.setFocused(isFocused)
        }
    }
}

// MARK: - Surface cache

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
        // Clean up any terminal splits (up to a reasonable number)
        for i in 0..<20 {
            removeSurface(for: derivedUUID(from: workstreamID, salt: "terminal-\(i)"))
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
