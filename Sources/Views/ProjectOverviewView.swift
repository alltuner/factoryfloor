// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Native Form layout with editable name, repo info, and workstream cards.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onSelectWorkstream: (UUID) -> Void
    let onProjectChanged: () -> Void

    @EnvironmentObject var appEnv: AppEnvironment

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Project details form
                Form {
                    Section("Project") {
                        TextField("Name", text: $project.name)
                            .onChange(of: project.name) { _, _ in onProjectChanged() }

                        LabeledContent("Directory") {
                            Text(project.directory)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

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
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .frame(maxHeight: 400)

                // Workstreams section
                if project.workstreams.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("No workstreams yet")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        (Text("Press ") + Text(Image(systemName: "command")) + Text(" N ") + Text("to create one."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Workstreams")
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(project.workstreams) { workstream in
                                WorkstreamCard(workstream: workstream)
                                    .onTapGesture { onSelectWorkstream(workstream.id) }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appEnv.refreshRepoInfo(for: project.directory) }
    }
}

private struct WorkstreamCard: View {
    let workstream: Workstream

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text(workstream.name)
                    .font(.system(.title3, weight: .medium))
                Spacer()
            }

            Text("Click to open")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovering ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
