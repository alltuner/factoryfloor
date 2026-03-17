// ABOUTME: Split-pane view for setup and run scripts in the Environment tab.
// ABOUTME: Shows terminals for each script, or instructions when scripts are not configured.

import SwiftUI

func shouldRestoreRunSession(useTmux: Bool, hasRunScript: Bool, hasExistingRunSession: Bool, wasStoppedManually: Bool) -> Bool {
    useTmux && hasRunScript && hasExistingRunSession && !wasStoppedManually
}

func scriptCommand(script: String, role: String) -> String {
    if role == "setup" {
        return "\(script); printf '\\nSetup completed in this terminal.\\n'"
    }
    return script
}

struct EnvironmentTabView: View {
    let workstreamID: UUID
    let workingDirectory: String
    let projectName: String
    let workstreamName: String
    let scriptConfig: ScriptConfig
    let useTmux: Bool
    let environmentVars: [String: String]
    @Binding var runStoppedManually: Bool

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache
    @EnvironmentObject var appEnv: AppEnvironment
    @State private var setupGeneration = 0
    @State private var runGeneration = 0
    @State private var runStarted = false
    @State private var setupRestarting = false
    @State private var runRestarting = false

    private var setupID: UUID {
        derivedUUID(from: workstreamID, salt: "env-setup-\(setupGeneration)")
    }

    private var runID: UUID {
        derivedUUID(from: workstreamID, salt: "env-run-\(runGeneration)")
    }

    var body: some View {
        HSplitView {
            scriptPane(
                title: NSLocalizedString("Setup", comment: ""),
                icon: "hammer",
                restartLabel: NSLocalizedString("Rebuild", comment: ""),
                shortcut: "⌃⇧R",
                script: scriptConfig.setup,
                surfaceID: setupID,
                tmuxRole: "setup",
                restarting: setupRestarting,
                onRestart: restartSetup
            )

            runPane()
        }
        .onReceive(NotificationCenter.default.publisher(for: .rebuildSetup)) { _ in
            if scriptConfig.setup != nil { restartSetup() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rerunScript)) { _ in
            if scriptConfig.run != nil {
                if runStarted {
                    restartRun()
                } else {
                    runStoppedManually = false
                    runStarted = true
                }
            }
        }
        .onAppear {
            restoreRunState()
        }
    }

    @ViewBuilder
    private func scriptPane(title: String, icon: String, restartLabel: String, shortcut: String, script: String?, surfaceID: UUID, tmuxRole: String, restarting: Bool, onRestart: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                if let script {
                    Text(script)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                if script != nil {
                    EnvActionButton(label: restartLabel, icon: "arrow.counterclockwise", shortcut: shortcut, action: onRestart)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if restarting {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let script {
                SingleTerminalView(
                    surfaceID: surfaceID,
                    workingDirectory: workingDirectory,
                    initialInput: envInput(script: script, role: tmuxRole),
                    isFocused: false,
                    environmentVars: environmentVars
                )
                .id(surfaceID)
            } else {
                scriptInstructions(title: title)
            }
        }
    }

    @ViewBuilder
    private func runPane() -> some View {
        let title = NSLocalizedString("Run", comment: "")
        let shortcut = "⌃⇧S"
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "play")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                if let script = scriptConfig.run {
                    Text(script)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                if scriptConfig.run != nil {
                    if runStarted {
                        EnvActionButton(label: NSLocalizedString("Stop", comment: ""), icon: "stop.fill", shortcut: "", action: stopRun)
                        EnvActionButton(label: NSLocalizedString("Rerun", comment: ""), icon: "arrow.counterclockwise", shortcut: shortcut, action: restartRun)
                    } else {
                        EnvActionButton(label: NSLocalizedString("Start", comment: ""), icon: "play.fill", shortcut: shortcut) {
                            runStoppedManually = false
                            runStarted = true
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            if let script = scriptConfig.run {
                if runStarted && !runRestarting {
                    SingleTerminalView(
                        surfaceID: runID,
                        workingDirectory: workingDirectory,
                        initialInput: envInput(script: script, role: "run"),
                        isFocused: false,
                        environmentVars: environmentVars
                    )
                    .id(runID)
                } else if !runStarted {
                    VStack(spacing: 12) {
                        Button(action: {
                            runStoppedManually = false
                            runStarted = true
                        }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.borderless)
                        Text(script)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Text(shortcut)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                scriptInstructions(title: title)
            }
        }
    }

    private func scriptInstructions(title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(String(format: NSLocalizedString("No %@ script configured", comment: ""), title.lowercased()))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(String(format: NSLocalizedString("Add a %@ field to .factoryfloor.json:", comment: ""), title.lowercased()))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text("{ \"\(title.lowercased())\": \"your-command\" }")
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func envInput(script: String, role: String) -> String {
        let command: String
        if role == "run",
           let launcherPath = RunLauncher.executableURL()?.path {
            command = runScriptCommand(script: script, workstreamID: workstreamID, launcherPath: launcherPath)
        } else {
            command = scriptCommand(script: script, role: role)
        }
        if useTmux {
            return buildCommand(script: command, role: role) + "\n"
        }
        return command + "; exec tail -f /dev/null\n"
    }

    private func buildCommand(script: String, role: String) -> String {
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: role)
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: script, environmentVars: environmentVars)
        }
        return script
    }

    private func killTmuxSession(role: String) {
        guard useTmux, let tmuxPath = appEnv.toolStatus.tmux.path else { return }
        let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: role)
        TmuxSession.killSession(tmuxPath: tmuxPath, sessionName: session)
    }

    private func restartSetup() {
        killTmuxSession(role: "setup")
        surfaceCache.removeSurface(for: setupID)
        setupRestarting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            setupGeneration += 1
            setupRestarting = false
        }
    }

    private func stopRun() {
        killTmuxSession(role: "run")
        surfaceCache.removeSurface(for: runID)
        runStoppedManually = true
        runStarted = false
        runGeneration += 1
    }

    private func restartRun() {
        killTmuxSession(role: "run")
        surfaceCache.removeSurface(for: runID)
        runStoppedManually = false
        runRestarting = true
        runStarted = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            runGeneration += 1
            runRestarting = false
            runStarted = true
        }
    }

    private func restoreRunState() {
        guard !runStarted,
              useTmux,
              scriptConfig.run != nil,
              let tmuxPath = appEnv.toolStatus.tmux.path else { return }
        let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: "run")
        let hasExistingRunSession = TmuxSession.sessionExists(tmuxPath: tmuxPath, sessionName: session)
        if shouldRestoreRunSession(useTmux: useTmux, hasRunScript: scriptConfig.run != nil, hasExistingRunSession: hasExistingRunSession, wasStoppedManually: runStoppedManually) {
            runStarted = true
        }
    }
}

extension Notification.Name {
    static let rebuildSetup = Notification.Name("factoryfloor.rebuildSetup")
    static let rerunScript = Notification.Name("factoryfloor.rerunScript")
}

private struct EnvActionButton: View {
    let label: String
    let icon: String
    let shortcut: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11))
                Text(shortcut)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.borderless)
        .onHover { isHovering = $0 }
        .accessibilityLabel(label)
    }
}
