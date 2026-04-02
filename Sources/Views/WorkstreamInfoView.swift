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
    @State private var copiedBranch = false
    @State private var docFiles: [DocFile] = []
    @State private var selectedDoc: String?
    @State private var projectIcon: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            // Pinned header
            VStack(spacing: 4) {
                if let icon = projectIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(projectName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(workstreamName)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                if let branch = branchName {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text(branch)
                        DirectoryActionButton(
                            icon: copiedBranch ? "checkmark" : "doc.on.doc",
                            color: copiedBranch ? .green : nil,
                            tooltip: "Copy branch name"
                        ) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(branch, forType: .string)
                            copiedBranch = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedBranch = false }
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                DirectoryRow(path: workingDirectory, defaultTerminal: defaultTerminal)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)

            // Pinned metadata (PR, scripts)
            if appEnv.ghAvailable, let branch = branchName,
               let pr = appEnv.githubPR(for: projectDirectory, branch: branch)
            {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.pull")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(verbatim: "#\(pr.number)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Text(pr.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(pr.state)
                        .font(.system(size: 10))
                        .foregroundStyle(pr.state == "OPEN" ? .green : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            if scriptConfig.hasAnyScript {
                Divider()
                HStack(spacing: 12) {
                    if let setup = scriptConfig.setup {
                        Label(setup, systemImage: "hammer")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let run = scriptConfig.run {
                        Label(run, systemImage: "play")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let source = scriptConfig.source {
                        Text(source)
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            // Pinned doc tabs
            if !docFiles.isEmpty {
                Divider()
                HStack(spacing: 0) {
                    ForEach(docFiles) { doc in
                        DocTabButton(
                            name: doc.name,
                            isActive: selectedDoc == doc.name,
                            action: { selectedDoc = doc.name }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Divider()

            // Scrollable: only the markdown content
            if let selected = selectedDoc,
               let doc = docFiles.first(where: { $0.name == selected })
            {
                MarkdownContentView(markdown: doc.content)
                    .id(selected)
            } else if docFiles.isEmpty {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadInfo() }
    } // body

    private nonisolated static let iconPaths = [
        "icon.svg", "icon.png",
        ".github/icon.svg", ".github/icon.png",
        "logo.svg", "logo.png",
    ]

    private nonisolated static func findProjectIcon(in directory: String) -> NSImage? {
        let base = URL(fileURLWithPath: directory)
        for relative in iconPaths {
            let path = base.appendingPathComponent(relative).path
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    private nonisolated static func findProjectIconPath(in directory: String) -> String? {
        let base = URL(fileURLWithPath: directory)
        for relative in iconPaths {
            let path = base.appendingPathComponent(relative).path
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func loadInfo() {
        let workingDir = workingDirectory
        let gitHubProjectDir = projectDirectory
        Task.detached {
            let branch = GitOperations.repoInfo(at: workingDir).branch
            await updateBranchInfo(branch, projectDirectory: gitHubProjectDir)
        }

        let projDir = projectDirectory
        Task.detached {
            let iconPath = Self.findProjectIconPath(in: projDir)
            await updateProjectIcon(iconPath: iconPath)
        }

        let dir = workingDirectory
        Task.detached {
            let found = DocFile.loadFrom(directory: dir)
            await updateDocFiles(found)
        }
    }

    @MainActor
    private func updateBranchInfo(_ branch: String?, projectDirectory: String) {
        branchName = branch
        appEnv.refreshGitHubInfo(for: projectDirectory, branch: branch)
    }

    @MainActor
    private func updateProjectIcon(iconPath: String?) {
        if let iconPath {
            projectIcon = NSImage(contentsOfFile: iconPath)
        } else {
            projectIcon = nil
        }
    }

    @MainActor
    private func updateDocFiles(_ docFiles: [DocFile]) {
        self.docFiles = docFiles
        selectedDoc = docFiles.first?.name
    }
}

// MARK: - Directory row with copy and open-in-terminal actions

struct DirectoryRow: View {
    let path: String
    var defaultTerminal: String = ""

    @State private var copied = false

    var body: some View {
        HStack(spacing: 4) {
            Text(path.abbreviatedPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            DirectoryActionButton(
                icon: copied ? "checkmark" : "doc.on.doc",
                color: copied ? .green : nil,
                tooltip: "Copy path"
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            }

            DirectoryActionButton(
                icon: "terminal",
                tooltip: "Open in external terminal"
            ) {
                openInTerminal()
            }
        }
    }

    private func openInTerminal() {
        if !defaultTerminal.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: defaultTerminal)
        {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: appURL, configuration: config)
        } else if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: terminalURL, configuration: config)
        }
    }
}

private struct DirectoryActionButton: View {
    let icon: String
    var color: Color? = nil
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color ?? (isHovering ? Color.primary : Color.secondary))
                .frame(width: 22, height: 22)
                .background(isHovering ? Color.primary.opacity(0.1) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.borderless)
        .onHover { isHovering = $0 }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

struct DocFile: Identifiable {
    let name: String
    let content: String
    var id: String {
        name
    }

    static let standardNames = ["README.md", "CLAUDE.md", "AGENTS.md"]

    static func loadFrom(directory: String) -> [DocFile] {
        let fm = FileManager.default
        var found: [DocFile] = []
        for name in standardNames {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  attrs[.type] as? FileAttributeType == .typeRegular
            else { continue }
            if let data = fm.contents(atPath: path),
               data.count >= 20,
               let content = String(data: data, encoding: .utf8)
            {
                found.append(DocFile(name: name, content: content))
            }
        }
        return found
    }
}

struct DocTabButton: View {
    let name: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 10, weight: isActive ? .medium : .regular, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isActive ? Color.primary.opacity(0.08) : (isHovering ? Color.primary.opacity(0.04) : .clear))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(isActive ? .primary : .tertiary)
        }
        .buttonStyle(.borderless)
        .onHover { isHovering = $0 }
    }
}
