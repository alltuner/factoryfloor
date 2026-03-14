// ABOUTME: SwiftUI sidebar showing projects as a collapsible tree with workstreams.
// ABOUTME: Supports adding projects via picker/drag-drop and workstreams inline.

import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let addProject = Notification.Name("ff2.addProject")
    static let addNew = Notification.Name("ff2.addNew")
}

struct ProjectSidebar: View {
    @Binding var projects: [Project]
    @Binding var selection: SidebarSelection?
    let onProjectsChanged: () -> Void

    @State private var showingAddProjectChoice = false
    @State private var showingNewProjectName = false
    @State private var newProjectName = ""
    @State private var newProjectError = ""
    @State private var isDropTargeted = false
    @State private var addingWorkstreamForProject: UUID?
    @State private var newWorkstreamName = ""
    @State private var projectToDelete: UUID?
    @State private var expandedProjects: Set<UUID> = []
    @State private var cachedSortedIDs: [UUID] = []
    @AppStorage("ff2.sortOrder") private var sortOrder: ProjectSortOrder = .recent

    /// Index from UUID to project array index for O(1) lookups.
    private var projectIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($1.id, $0) })
    }

    /// Index from workstream UUID to (project index, workstream index).
    private var workstreamIndex: [UUID: (Int, Int)] {
        var result: [UUID: (Int, Int)] = [:]
        for (pi, project) in projects.enumerated() {
            for (wi, ws) in project.workstreams.enumerated() {
                result[ws.id] = (pi, wi)
            }
        }
        return result
    }

    private func recomputeSortedIDs() -> [UUID] {
        switch sortOrder {
        case .recent:
            return projects.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.map(\.id)
        case .alphabetical:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map(\.id)
        }
    }

    private func projectBinding(for id: UUID) -> Binding<Project> {
        Binding(
            get: {
                if let idx = projectIndex[id] { return projects[idx] }
                return projects.first(where: { $0.id == id })!
            },
            set: { newValue in
                if let idx = projectIndex[id] {
                    projects[idx] = newValue
                }
            }
        )
    }

    var body: some View {
        GeometryReader { geo in
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
            List(selection: $selection) {
                ForEach(cachedSortedIDs, id: \.self) { projectID in
                    let projectBind = projectBinding(for: projectID)
                    let project = projectBind.wrappedValue
                    let hasChildren = !project.workstreams.isEmpty

                    ProjectHeaderRow(
                        project: project,
                        isExpanded: expandedProjects.contains(project.id),
                        onToggle: hasChildren ? {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedProjects.contains(project.id) {
                                    expandedProjects.remove(project.id)
                                } else {
                                    expandedProjects.insert(project.id)
                                }
                            }
                        } : nil,
                        onAdd: { startAddingWorkstream(for: project.id) },
                        onDelete: { projectToDelete = project.id }
                    )
                    .tag(SidebarSelection.project(project.id))

                    if hasChildren && expandedProjects.contains(project.id) {
                        let sortedWS = project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
                        ForEach(sortedWS) { workstream in
                            WorkstreamRow(
                                name: workstream.name,
                                onArchive: { archiveWorkstream(workstream.id, in: &projectBind.wrappedValue) }
                            )
                            .tag(SidebarSelection.workstream(workstream.id))
                            .padding(.leading, 22)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .top) {
                if !projects.isEmpty {
                    Picker("", selection: $sortOrder) {
                        ForEach(ProjectSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .onChange(of: selection) { _, sel in
                guard let sel else { return }
                if case .workstream(let wsID) = sel,
                   let (pi, _) = workstreamIndex[wsID] {
                    expandedProjects.insert(projects[pi].id)
                }
                withAnimation {
                    scrollProxy.scrollTo(sel, anchor: .center)
                }
            }
            } // ScrollViewReader

            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Drop a folder here")
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(.tertiary)
                (Text(Image(systemName: "command")) + Text(Image(systemName: "shift")) + Text(" N ") + Text("to add a project"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                HStack {
                    Button(action: { showingAddProjectChoice = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(8)

                    Spacer()

                    Button(action: {
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(80, geo.size.height * 0.2))
        }
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalActivity)) { notification in
            guard let wsID = notification.object as? UUID else { return }
            guard let (pi, wi) = workstreamIndex[wsID] else { return }
            let now = Date()
            projects[pi].lastAccessedAt = now
            projects[pi].workstreams[wi].lastAccessedAt = now
            onProjectsChanged()
        }
        .onAppear { cachedSortedIDs = recomputeSortedIDs() }
        .onChange(of: sortOrder) { _, _ in cachedSortedIDs = recomputeSortedIDs() }
        .onChange(of: projects.count) { _, _ in cachedSortedIDs = recomputeSortedIDs() }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .sheet(isPresented: $showingAddProjectChoice) {
            AddProjectChoiceSheet(
                onNewProject: {
                    showingAddProjectChoice = false
                    newProjectName = ""
                    newProjectError = ""
                    showingNewProjectName = true
                },
                onExistingDirectory: {
                    showingAddProjectChoice = false
                    openDirectoryPicker()
                },
                onCancel: { showingAddProjectChoice = false }
            )
        }
        .sheet(isPresented: $showingNewProjectName) {
            NewProjectSheet(
                name: $newProjectName,
                error: $newProjectError,
                baseDirectory: baseDirectory,
                onAdd: { createNewProject() },
                onCancel: { showingNewProjectName = false }
            )
        }
        .sheet(item: $addingWorkstreamForProject) { projectID in
            AddWorkstreamSheet(
                name: $newWorkstreamName,
                onAdd: { commitWorkstream(forProjectID: projectID) },
                onCancel: { addingWorkstreamForProject = nil }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .addProject)) { _ in
            showingAddProjectChoice = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNew)) { _ in
            if case .workstream(let wsID) = selection,
               let project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) {
                startAddingWorkstream(for: project.id)
            } else if case .project(let pid) = selection {
                startAddingWorkstream(for: pid)
            } else {
                showingAddProjectChoice = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDirectory)) { notification in
            guard let directory = notification.object as? String else { return }
            addProject(name: URL(fileURLWithPath: directory).lastPathComponent, directory: directory)
        }
        .alert(
            "Remove Project",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { projectToDelete = nil }
            Button("Remove", role: .destructive) {
                if let id = projectToDelete {
                    deleteProject(id: id)
                }
            }
        } message: {
            if let id = projectToDelete, let project = projects.first(where: { $0.id == id }) {
                Text("Remove \"\(project.name)\" from the list? Files in \(project.directory) will not be deleted.")
            }
        }
    }

    // MARK: - Workstream management

    private func startAddingWorkstream(for projectID: UUID) {
        newWorkstreamName = ""
        expandedProjects.insert(projectID)
        addingWorkstreamForProject = projectID
    }

    private func commitWorkstream(forProjectID projectID: UUID) {
        let name = newWorkstreamName.trimmingCharacters(in: .whitespaces)
        addingWorkstreamForProject = nil
        newWorkstreamName = ""
        guard !name.isEmpty else { return }
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
        expandedProjects.insert(projectID)

        let workstream = Workstream(name: name)
        projects[index].workstreams.append(workstream)
        selection = .workstream(workstream.id)
        onProjectsChanged()
    }

    @EnvironmentObject private var surfaceCache: TerminalSurfaceCache

    private func archiveWorkstream(_ workstreamID: UUID, in project: inout Project) {
        surfaceCache.removeWorkstreamSurfaces(for: workstreamID)
        project.workstreams.removeAll { $0.id == workstreamID }
        if case .workstream(let id) = selection, id == workstreamID {
            selection = project.workstreams.first.map { .workstream($0.id) } ?? .project(project.id)
        }
        onProjectsChanged()
    }

    // MARK: - Project management

    private func deleteProject(id: UUID) {
        if let project = projects.first(where: { $0.id == id }) {
            for ws in project.workstreams {
                surfaceCache.removeWorkstreamSurfaces(for: ws.id)
            }
        }
        projects.removeAll { $0.id == id }
        if case .project(let pid) = selection, pid == id { selection = nil }
        if case .workstream(let wsID) = selection,
           !projects.contains(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) {
            selection = nil
        }
        projectToDelete = nil
        onProjectsChanged()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.hasDirectoryPath || FileManager.default.isDirectory(at: url) else { return }

                DispatchQueue.main.async {
                    addProject(name: url.lastPathComponent, directory: url.path)
                }
            }
        }
        return true
    }

    @AppStorage("ff2.baseDirectory") private var baseDirectory: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""

    private func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: baseDirectory)
        panel.message = NSLocalizedString("Choose a project directory", comment: "")
        panel.prompt = NSLocalizedString("Select", comment: "")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addProject(name: url.lastPathComponent, directory: url.path)
    }

    private func createNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let dirURL = URL(fileURLWithPath: baseDirectory).appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dirURL.path) {
            newProjectError = NSLocalizedString("A file or directory with this name already exists.", comment: "")
            return
        }

        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        } catch {
            newProjectError = error.localizedDescription
            return
        }

        showingNewProjectName = false
        addProject(name: name, directory: dirURL.path)
    }

    private func addProject(name: String, directory: String) {
        if let existing = projects.first(where: { $0.directory == directory }) {
            selection = .project(existing.id)
            return
        }

        let projectName = name.isEmpty ? URL(fileURLWithPath: directory).lastPathComponent : name
        let project = Project(name: projectName, directory: directory)
        projects.append(project)
        selection = .project(project.id)
        onProjectsChanged()
    }
}

// Make String work as an Identifiable sheet item
extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

extension FileManager {
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

private struct ProjectHeaderRow: View {
    let project: Project
    let isExpanded: Bool
    let onToggle: (() -> Void)?
    let onAdd: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isChevronHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Group {
                if onToggle != nil {
                    Button(action: { onToggle?() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(isChevronHovering ? .primary : .secondary)
                            .frame(width: 22, height: 22)
                            .background(isChevronHovering ? Color.primary.opacity(0.1) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .onHover { isChevronHovering = $0 }
                } else {
                    Color.clear
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(.body, weight: .medium))

                    if !project.workstreams.isEmpty {
                        Text("\(project.workstreams.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }

                Text(abbreviatePath(project.directory))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    SidebarIconButton(icon: "plus", action: onAdd)
                    SidebarIconButton(icon: "trash", action: onDelete)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
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
    let name: String
    let onArchive: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            Label(name, systemImage: "terminal")
                .font(.system(.body))

            Spacer()

            if isHovering {
                SidebarIconButton(icon: "archivebox", action: onArchive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct SidebarIconButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 22, height: 22)
                .background(isHovering ? Color.primary.opacity(0.1) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct AddProjectChoiceSheet: View {
    let onNewProject: () -> Void
    let onExistingDirectory: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Project")
                .font(.headline)

            VStack(spacing: 12) {
                Button(action: onNewProject) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Project")
                                .font(.system(.body, weight: .medium))
                            Text("Create a new directory in the base folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: onExistingDirectory) {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Existing Directory")
                                .font(.system(.body, weight: .medium))
                            Text("Select an existing directory from disk")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 380)
    }
}

private struct NewProjectSheet: View {
    @Binding var name: String
    @Binding var error: String
    let baseDirectory: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Project")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Base directory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(abbreviatePath(baseDirectory))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Text("(change in Settings)")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Project Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { onAdd() } }

            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

private struct AddWorkstreamSheet: View {
    @Binding var name: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Workstream")
                .font(.headline)

            TextField("Workstream Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty { onAdd() }
                }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add", action: onAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
