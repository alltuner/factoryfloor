// ABOUTME: SwiftUI sidebar showing the list of projects.
// ABOUTME: Supports adding and selecting projects, with the active project highlighted.

import SwiftUI

extension Notification.Name {
    static let addProject = Notification.Name("ff2.addProject")
}

struct ProjectSidebar: View {
    @Binding var projects: [Project]
    @Binding var selectedProjectID: UUID?
    @State private var pendingDirectory: String?
    @State private var pendingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedProjectID) {
                ForEach(projects) { project in
                    ProjectRow(project: project)
                        .tag(project.id)
                }
                .onDelete(perform: deleteProjects)
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button(action: openDirectoryPicker) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .padding(8)

                Spacer()
            }
        }
        .sheet(item: $pendingDirectory) { directory in
            ConfirmProjectSheet(
                directory: directory,
                name: $pendingName,
                onAdd: { addProject(name: pendingName, directory: directory) },
                onCancel: { pendingDirectory = nil }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .addProject)) { _ in
            openDirectoryPicker()
        }
    }

    private func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project directory"
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingName = url.lastPathComponent
        pendingDirectory = url.path
    }

    private func addProject(name: String, directory: String) {
        let projectName = name.isEmpty ? URL(fileURLWithPath: directory).lastPathComponent : name
        let project = Project(name: projectName, directory: directory)
        projects.append(project)
        selectedProjectID = project.id
        pendingDirectory = nil
        pendingName = ""
    }

    private func deleteProjects(at offsets: IndexSet) {
        let idsToDelete = offsets.map { projects[$0].id }
        projects.remove(atOffsets: offsets)
        if let selected = selectedProjectID, idsToDelete.contains(selected) {
            selectedProjectID = projects.first?.id
        }
    }
}

// Make String work as an Identifiable sheet item
extension String: @retroactive Identifiable {
    public var id: String { self }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name)
                .font(.system(.body, weight: .medium))
            Text(abbreviatePath(project.directory))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

private struct ConfirmProjectSheet: View {
    let directory: String
    @Binding var name: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Project")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(directory)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Project Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Project Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
