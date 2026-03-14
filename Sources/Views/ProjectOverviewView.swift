// ABOUTME: Overview shown when a project is selected but no workstream is active.
// ABOUTME: Displays project header with editable alias, and workstream cards.

import SwiftUI

struct ProjectOverviewView: View {
    @Binding var project: Project
    let onSelectWorkstream: (UUID) -> Void
    let onProjectChanged: () -> Void

    @State private var editingAlias = false
    @State private var aliasText = ""

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Project header
                VStack(spacing: 8) {
                    if editingAlias {
                        TextField("Project Name", text: $aliasText)
                            .font(.system(size: 28, weight: .bold))
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.plain)
                            .frame(maxWidth: 400)
                            .onSubmit { commitAlias() }
                            .onExitCommand { editingAlias = false }
                    } else {
                        Text(project.name)
                            .font(.system(size: 32, weight: .bold))
                            .onTapGesture {
                                aliasText = project.name
                                editingAlias = true
                            }
                    }
                    Text(project.directory)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if editingAlias {
                        HStack(spacing: 8) {
                            Button("Cancel") { editingAlias = false }
                                .keyboardShortcut(.cancelAction)
                            Button("Save") { commitAlias() }
                                .keyboardShortcut(.defaultAction)
                                .disabled(aliasText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.caption)
                    } else {
                        Text("Click name to set alias")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)

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
    }

    private func commitAlias() {
        let name = aliasText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        project.name = name
        editingAlias = false
        onProjectChanged()
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
