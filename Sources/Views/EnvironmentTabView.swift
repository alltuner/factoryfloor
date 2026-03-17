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

    private var setupID: UUID {
        derivedUUID(from: workstreamID, salt: "env-setup-\(setupGeneration)")
    }

    private var runID: UUID {
        derivedUUID(from: workstreamID, salt: "env-run-\(runGeneration)")
    }

    var body: some View {
        HSplitView {
            scriptPane(
                title: "Setup",
                icon: "hammer",
                script: scriptConfig.setup,
                surfaceID: setupID,
                tmuxRole: "setup",
                onRestart: restartSetup
            )

            scriptPane(
                title: "Run",
                icon: "play",
                script: scriptConfig.run,
                surfaceID: runID,
                tmuxRole: "run",
                onRestart: restartRun
            )
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
                    .help("Restart \(title.lowercased()) script")
                    .accessibilityLabel("Restart \(title.lowercased()) script")
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

    private func scriptInstructions(title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No \(title.lowercased()) script configured")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Add a \(title.lowercased()) field to .factoryfloor.json:")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Text("{ \"\(title.lowercased())\": \"your-command\" }")
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.secondary)
            Text("Also picks up scripts from .emdash.json, conductor.json, and .superset/config.json.")
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
        runGeneration += 1
    }
}
