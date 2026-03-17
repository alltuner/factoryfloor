// ABOUTME: Split-pane view for setup and run scripts in the Environment tab.
// ABOUTME: Shows terminals for each script, or instructions when scripts are not configured.

import SwiftUI

struct EnvironmentTabView: View {
    let workstreamID: UUID
    let workingDirectory: String
    let projectName: String
    let workstreamName: String
    let scriptConfig: ScriptConfig
    let useTmux: Bool
    let environmentVars: [String: String]

    @EnvironmentObject var surfaceCache: TerminalSurfaceCache
    @EnvironmentObject var appEnv: AppEnvironment
    @State private var setupGeneration = 0
    @State private var runGeneration = 0
    @State private var runStarted = false

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
                script: scriptConfig.setup,
                surfaceID: setupID,
                tmuxRole: "setup",
                onRestart: restartSetup
            )

            runPane()
        }
    }

    @ViewBuilder
    private func scriptPane(title: String, icon: String, script: String?, surfaceID: UUID, tmuxRole: String, onRestart: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            // Header bar
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
                    Button(action: onRestart) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                    .help(String(format: NSLocalizedString("Restart %@ script", comment: ""), title.lowercased()))
                    .accessibilityLabel(String(format: NSLocalizedString("Restart %@ script", comment: ""), title.lowercased()))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            // Content
            if let script {
                SingleTerminalView(
                    surfaceID: surfaceID,
                    workingDirectory: workingDirectory,
                    command: buildCommand(script: script, role: tmuxRole),
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
        VStack(spacing: 0) {
            // Header bar
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
                        Button(action: restartRun) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help(String(format: NSLocalizedString("Restart %@ script", comment: ""), title.lowercased()))
                        .accessibilityLabel(String(format: NSLocalizedString("Restart %@ script", comment: ""), title.lowercased()))
                    } else {
                        Button(action: { runStarted = true }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help(String(format: NSLocalizedString("Start %@ script", comment: ""), title.lowercased()))
                        .accessibilityLabel(String(format: NSLocalizedString("Start %@ script", comment: ""), title.lowercased()))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            // Content
            if let script = scriptConfig.run {
                if runStarted {
                    SingleTerminalView(
                        surfaceID: runID,
                        workingDirectory: workingDirectory,
                        command: buildCommand(script: script, role: "run"),
                        isFocused: false,
                        environmentVars: environmentVars
                    )
                    .id(runID)
                } else {
                    VStack(spacing: 12) {
                        Button(action: { runStarted = true }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(.borderless)
                        Text(script)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
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
            Text("Also supports .factoryfloor/config.json.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func buildCommand(script: String, role: String) -> String {
        if useTmux, let tmuxPath = appEnv.toolStatus.tmux.path {
            let session = TmuxSession.sessionName(project: projectName, workstream: workstreamName, role: role)
            return TmuxSession.wrapCommand(tmuxPath: tmuxPath, sessionName: session, command: script)
        }
        return script
    }

    private func restartSetup() {
        surfaceCache.removeSurface(for: setupID)
        setupGeneration += 1
    }

    private func restartRun() {
        surfaceCache.removeSurface(for: runID)
        runStarted = false
        runGeneration += 1
        DispatchQueue.main.async {
            runStarted = true
        }
    }
}
