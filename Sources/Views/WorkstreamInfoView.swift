// ABOUTME: Info tab for a workstream showing metadata and documentation files.
// ABOUTME: Default tab when opening a workstream, with sub-tabs for markdown files.

import SwiftUI

struct WorkstreamInfoView: View {
    let workstreamName: String
    let workingDirectory: String
    let projectName: String
    let projectDirectory: String
    var scriptConfig: ScriptConfig = .empty

    @EnvironmentObject var appEnv: AppEnvironment
    @State private var branchName: String?
    @State private var docFiles: [DocFile] = []
    @State private var selectedDoc: String?

    struct DocFile: Identifiable {
        let name: String
        let content: String
        var id: String { name }
    }

    // Files to look for, in order
    private static let docFileNames = ["README.md", "CLAUDE.md"]

    var body: some View {
        VStack(spacing: 0) {
            // Workstream metadata
            Form {
                Section("Workstream") {
                    LabeledContent("Name") {
                        Text(workstreamName)
                            .font(.system(.body, design: .monospaced))
                    }

                    if let branch = branchName {
                        LabeledContent("Branch") {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                Text(branch)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Directory") {
                        Text(abbreviatePath(workingDirectory))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    LabeledContent("Project") {
                        Text(projectName)
                            .foregroundStyle(.secondary)
                    }
                }

                // GitHub PR for this branch
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
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(maxHeight: scriptConfig.hasAnyScript ? 420 : (branchName.flatMap({ appEnv.githubPR(for: projectDirectory, branch: $0) }) != nil ? 320 : 200))

            // Document tabs
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Divider()
                    .padding(.horizontal, 16)

                // Rendered document
                if let selected = selectedDoc,
                   let doc = docFiles.first(where: { $0.name == selected }) {
                    MarkdownContentView(markdown: doc.content)
                        .id(selected)
                } else {
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No documentation files found")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadInfo() }
    }

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

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
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
