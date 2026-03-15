// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Native Form layout with project info, repo status, and workstream list.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onSelectWorkstream: (UUID) -> Void
    let onArchiveWorkstream: (UUID) -> Void
    let onProjectChanged: () -> Void

    @EnvironmentObject var appEnv: AppEnvironment

    var body: some View {
        Form {
            // MARK: - Project
            Section {
                TextField("Name", text: $project.name)
                    .onChange(of: project.name) { _, _ in onProjectChanged() }

                LabeledContent("Directory") {
                    Text(project.directory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } header: {
                Text("Project")
            } footer: {
                Text("The name is an alias for display only. Changing it does not rename any files or directories.")
            }

            // MARK: - Repository
            if let info = appEnv.repoInfo(for: project.directory) {
                Section("Repository") {
                    if info.isRepo {
                        LabeledContent("Branch") {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.caption)
                                Text(info.branch ?? "unknown")
                            }
                            .foregroundStyle(.secondary)
                        }

                        if let count = info.commitCount {
                            LabeledContent("Commits") {
                                Text("\(count)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let remote = info.remoteURL {
                            LabeledContent("Remote") {
                                Text(remote)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        LabeledContent("Status") {
                            Text(info.isDirty ? "Uncommitted changes" : "Clean")
                                .foregroundStyle(info.isDirty ? .orange : .green)
                        }
                    } else {
                        LabeledContent("Status") {
                            Text("Not a git repository")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - Workstreams
            Section {
                if project.workstreams.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("No workstreams yet")
                                .foregroundStyle(.secondary)
                            (Text("Press ") + Text(Image(systemName: "command")) + Text(" N ") + Text("to create one."))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }) { workstream in
                        WorkstreamRow(
                            workstream: workstream,
                            onSelect: { onSelectWorkstream(workstream.id) },
                            onArchive: { onArchiveWorkstream(workstream.id) },
                            abbreviatePath: abbreviatePath
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Workstreams")
                    Spacer()
                    Text("\(project.workstreams.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appEnv.refreshRepoInfo(for: project.directory) }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

private struct WorkstreamRow: View {
    let workstream: Workstream
    let onSelect: () -> Void
    let onArchive: () -> Void
    let abbreviatePath: (String) -> String

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workstream.name)
                        .font(.system(.body, design: .monospaced))
                    if let path = workstream.worktreePath {
                        Text(abbreviatePath(path))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if isHovering {
                    Button(action: {
                        // Stop propagation to parent button
                        onArchive()
                    }) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
