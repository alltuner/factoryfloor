// ABOUTME: Help view showing app info, version, and keyboard shortcuts.
// ABOUTME: Displayed in the detail pane via the help icon or Cmd+?.

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App header
                VStack(spacing: 8) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(AppConstants.appID)
                        .font(.system(size: 28, weight: .bold))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Shortcuts
                Form {
                    Section {
                        ShortcutRow(keys: ",", description: "Settings")
                        ShortcutRow(keys: "?", shift: true, description: "Help")
                        ShortcutRow(keys: "N", description: "New workstream or project")
                        ShortcutRow(keys: "N", shift: true, description: "New project")
                    } header: {
                        ShortcutSectionHeader(title: "Global", description: "Available everywhere")
                    }

                    Section {
                        ShortcutRow(keys: "0", description: "Back to project view")
                        ShortcutRow(keys: "1", description: "Info tab")
                        ShortcutRow(keys: "2", description: "Coding Agent tab")
                        ShortcutRow(keys: "3", description: "Terminal tab")
                        ShortcutRow(keys: "4", description: "Browser tab")
                        ShortcutRow(keys: "5", description: "Setup tab (if configured)")
                        ShortcutRow(keys: "6", description: "Run tab (if configured)")
                        ShortcutRow(keys: "[", shift: true, description: "Previous tab")
                        ShortcutRow(keys: "]", shift: true, description: "Next tab")
                    } header: {
                        ShortcutSectionHeader(title: "Workstream Tabs", description: "When a workstream is active")
                    }

                    Section {
                        ShortcutRow(keys: "1-9", description: "Open workstream by position")
                    } header: {
                        ShortcutSectionHeader(title: "Project View", description: "When viewing a project")
                    }

                    Section {
                        ShortcutRow(keys: "O", shift: true, description: "Open in external browser")
                        ShortcutRow(keys: "E", shift: true, description: "Open in external terminal")
                    } header: {
                        ShortcutSectionHeader(title: "External Apps", description: "Opens the current workstream directory")
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)

                // Credits
                VStack(spacing: 4) {
                    Text("Built by David Poblador i Garcia")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("with the support of")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Link("All Tuner Labs", destination: URL(string: "https://alltuner.com")!)
                            .font(.caption)
                    }
                    Link("davidpoblador.com", destination: URL(string: "https://davidpoblador.com")!)
                        .font(.caption)
                }
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .bottom) {
            PoblenouSkylineView()
                .padding(.horizontal, 40)
                .padding(.bottom, 10)
        }
    }
}

private struct ShortcutSectionHeader: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ShortcutRow: View {
    let keys: String
    var shift: Bool = false
    let description: String

    var body: some View {
        LabeledContent(description) {
            HStack(spacing: 2) {
                Image(systemName: "command")
                if shift {
                    Image(systemName: "shift")
                }
                Text(keys)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }
}
