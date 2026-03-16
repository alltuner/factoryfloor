// ABOUTME: Info panel for a workstream showing app branding, metadata, shortcuts, and docs.
// ABOUTME: Default view when opening a workstream, dismissible with Cmd+Return.

import SwiftUI

struct WorkstreamInfoView: View {
    let workstreamName: String
    let workingDirectory: String
    let projectName: String
    let projectDirectory: String
    var scriptConfig: ScriptConfig = .empty

    @EnvironmentObject var appEnv: AppEnvironment
    @AppStorage("factoryfloor.defaultTerminal") private var defaultTerminal: String = ""
    @State private var branchName: String?
    @State private var docFiles: [DocFile] = []
    @State private var selectedDoc: String?
    @State private var docExpanded = false

    struct DocFile: Identifiable {
        let name: String
        let content: String
        var id: String { name }
    }

    private static let docFileNames = ["README.md", "CLAUDE.md"]

    var body: some View {
        GeometryReader { geo in
        VStack(spacing: 0) {
            // Top pane: metadata (tapping it collapses docs)
            ScrollView {
                VStack(spacing: 0) {
                    // Workstream metadata
                    Form {
                        Section {
                            Text(workstreamName)
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))

                            if let branch = branchName {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)
                                    Text(branch)
                                }
                                .foregroundStyle(.secondary)
                            }

                            DirectoryRow(path: workingDirectory, defaultTerminal: defaultTerminal)

                            LabeledContent("Project") {
                                Text(projectName)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // GitHub PR
                        if appEnv.ghAvailable, let branch = branchName,
                           let pr = appEnv.githubPR(for: projectDirectory, branch: branch) {
                            Section("Pull Request") {
                                LabeledContent("#\(pr.number)") {
                                    Text(pr.title)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                LabeledContent("Status") {
                                    Text(pr.state)
                                        .foregroundStyle(pr.state == "OPEN" ? .green : .secondary)
                                }
                            }
                        }

                        // Scripts
                        if scriptConfig.hasAnyScript {
                            Section {
                                if let setup = scriptConfig.setup {
                                    LabeledContent("Setup") {
                                        Text(setup)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                if let run = scriptConfig.run {
                                    LabeledContent("Run") {
                                        Text(run)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                if let teardown = scriptConfig.teardown {
                                    LabeledContent("Teardown") {
                                        Text(teardown)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Scripts")
                                    Spacer()
                                    if let source = scriptConfig.source {
                                        Text(source)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }

                        // Shortcuts
                        Section("Shortcuts") {
                            ShortcutInfoRow(keys: "\u{21A9}", description: "Coding Agent")
                            ShortcutInfoRow(keys: "I", description: "Toggle Info")
                            ShortcutInfoRow(keys: "T", description: "New Terminal")
                            ShortcutInfoRow(keys: "W", description: "Close Tab")
                            ShortcutInfoRow(keys: "B", description: "New Browser")
                            ShortcutInfoRow(keys: "0", description: "Back to Project")
                            ShortcutInfoRow(keys: "1-9", description: "Switch Tab")
                            ShortcutInfoRow(keys: "\u{21E7}[ ]", shift: true, description: "Cycle Tabs")
                            ShortcutInfoRow(keys: "\u{21E7}O", shift: true, description: "External Browser")
                            ShortcutInfoRow(keys: "\u{21E7}E", shift: true, description: "External Terminal")
                        }
                    }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                }
            }
            .frame(height: docExpanded ? geo.size.height * 0.2 : geo.size.height * 0.8)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { docExpanded = false }
            }

            // Document viewer
            if !docFiles.isEmpty {
                HStack(spacing: 0) {
                    ForEach(docFiles) { doc in
                        DocTabButton(
                            name: doc.name,
                            isActive: selectedDoc == doc.name,
                            action: { selectedDoc = doc.name }
                        )
                    }
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { docExpanded.toggle() }
                    }) {
                        Image(systemName: docExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(docExpanded ? "Collapse" : "Expand")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(.bar)

                Divider()

                if let selected = selectedDoc,
                   let doc = docFiles.first(where: { $0.name == selected }) {
                    MarkdownContentView(markdown: doc.content)
                        .id(selected)
                } else {
                    Spacer()
                }
            }
        } // VStack
        } // GeometryReader
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadInfo() }
    } // body

    private func loadInfo() {
        Task.detached {
            let branch = GitOperations.repoInfo(at: workingDirectory).branch
            await MainActor.run {
                branchName = branch
                appEnv.refreshGitHubInfo(for: projectDirectory, branch: branch)
            }
        }

        let dir = workingDirectory
        Task.detached {
            var found: [DocFile] = []
            for name in Self.docFileNames {
                let path = URL(fileURLWithPath: dir).appendingPathComponent(name).path
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    found.append(DocFile(name: name, content: content))
                }
            }
            await MainActor.run {
                docFiles = found
                selectedDoc = found.first?.name
            }
        }
    }

}

// MARK: - Directory row with copy and open-in-terminal actions

struct DirectoryRow: View {
    let path: String
    var defaultTerminal: String = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(abbreviatePath(path))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: copyPath) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy path")

            Button(action: openInTerminal) {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in external terminal")
        }
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    private func openInTerminal() {
        if !defaultTerminal.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: defaultTerminal) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: appURL, configuration: config)
        } else {
            let escaped = path.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "tell application \"Terminal\" to do script \"cd \(escaped) && clear\""
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(nil)
            }
        }
    }

    private func abbreviatePath(_ p: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if p.hasPrefix(home) {
            return "~" + p.dropFirst(home.count)
        }
        return p
    }
}

private struct ShortcutInfoRow: View {
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

private struct DocTabButton: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                Text(name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular, design: .monospaced))
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
