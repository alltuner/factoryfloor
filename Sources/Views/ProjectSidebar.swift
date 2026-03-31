// ABOUTME: SwiftUI sidebar showing projects as a collapsible tree with workstreams.
// ABOUTME: Supports adding projects via picker/drag-drop and workstreams inline.

import OSLog
import SwiftUI
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "factoryfloor", category: "sidebar")

extension Notification.Name {
    static let addProject = Notification.Name("factoryfloor.addProject")
    static let addNew = Notification.Name("factoryfloor.addNew")
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
    @State private var projectToDelete: UUID?
    @State private var workstreamToArchive: UUID?
    @State private var archiveWarningDirty = false
    @State private var expandedProjects: Set<UUID> = SidebarState.loadExpanded()
    @State private var cachedSortedIDs: [UUID] = []
    @State private var cachedProjectIndex: [UUID: Int] = [:]
    @State private var cachedWorkstreamIndex: [UUID: (Int, Int)] = [:]
    @State private var showWorktreeError = false
    @State private var showNotGitRepoError = false
    @AppStorage("factoryfloor.sortOrder") private var sortOrder: ProjectSortOrder = .recent

    private func recomputeSortedIDs() -> [UUID] {
        switch sortOrder {
        case .recent:
            return projects.sorted { $0.lastAccessedAt > $1.lastAccessedAt }.map(\.id)
        case .alphabetical:
            return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map(\.id)
        }
    }

    private func rebuildIndices() {
        cachedProjectIndex = Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($1.id, $0) })
        var wsIndex: [UUID: (Int, Int)] = [:]
        for (pi, project) in projects.enumerated() {
            for (wi, ws) in project.workstreams.enumerated() {
                wsIndex[ws.id] = (pi, wi)
            }
        }
        cachedWorkstreamIndex = wsIndex
    }

    private func projectBinding(for id: UUID) -> Binding<Project> {
        Binding(
            get: {
                if let idx = cachedProjectIndex[id], idx < projects.count { return projects[idx] }
                return projects.first(where: { $0.id == id }) ?? Project(name: "", directory: "")
            },
            set: { newValue in
                if let idx = cachedProjectIndex[id], idx < projects.count {
                    projects[idx] = newValue
                }
            }
        )
    }

    private func projectRows() -> some View {
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
                isGitRepo: GitOperations.isGitRepo(at: project.directory),
                onAdd: { logger.warning("[FF] onAdd button tapped for project \(project.name, privacy: .public)"); addWorkstream(for: project.id) },
                onAddWithPermissions: { addWorkstream(for: project.id, bypassPermissions: true) },
                onAddWithoutPermissions: { addWorkstream(for: project.id, bypassPermissions: false) },
                onDelete: { projectToDelete = project.id }
            )
            .tag(SidebarSelection.project(project.id))

            if hasChildren && expandedProjects.contains(project.id) {
                let sortedWS = project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
                ForEach(sortedWS) { workstream in
                    WorkstreamRow(
                        name: workstream.name,
                        branchName: appEnv.branchName(for: workstream.worktreePath),
                        worktreePath: workstream.worktreePath,
                        isPathValid: appEnv.isPathValid(workstream.worktreePath),
                        hasActivePort: Self.hasPort(workstream.id),
                        onArchive: { confirmArchive(workstream) }
                    )
                    .tag(SidebarSelection.workstream(workstream.id))
                    .padding(.leading, 22)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 4) {
            if let version = updateChecker.availableVersion {
                UpdateBanner(version: version, releaseNotesURL: updateChecker.releaseNotesURL, updater: updater)
            }

            // Credit
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("by ")
                        .foregroundStyle(.tertiary)
                    Link("David Poblador i Garcia.", destination: URL(string: "https://davidpoblador.com/")!)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    Text("Help ")
                        .foregroundStyle(.tertiary)
                    Link("supporting", destination: sponsorURL)
                        .foregroundStyle(.secondary)
                    Text(" the development.")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 10))

            HStack {
                SidebarBottomButton(icon: "plus") {
                    showingAddProjectChoice = true
                }
                .accessibilityLabel("Add project")
                Spacer()
                SidebarBottomButton(icon: "questionmark.circle") {
                    NotificationCenter.default.post(name: .openHelp, object: nil)
                }
                .accessibilityLabel("Help")
                SidebarBottomButton(icon: "gear") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    var body: some View {
        sidebar
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
                    Text(String(format: NSLocalizedString("Remove \"%@\" from the list? Files in %@ will not be deleted.", comment: ""), project.name, project.directory))
                }
            }
            .alert(
                "Archive Workstream",
                isPresented: Binding(
                    get: { workstreamToArchive != nil },
                    set: { if !$0 { workstreamToArchive = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { workstreamToArchive = nil }
                Button(archiveWarningDirty ? "Archive Anyway" : "Archive", role: .destructive) {
                    performArchive()
                }
            } message: {
                if archiveWarningDirty {
                    Text("This workstream has uncommitted changes that will be lost.")
                } else {
                    Text("The worktree and its branch will be removed.")
                }
            }
            .alert(
                "Worktree Creation Failed",
                isPresented: $showWorktreeError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not create the git worktree. The branch may already exist, or there may be an ongoing merge or rebase.")
            }
            .alert(
                "Not a Git Repository",
                isPresented: $showNotGitRepoError
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Workstreams require a git repository. Initialize one with git init or select a different directory.")
            }
    }

    private var sidebar: some View {
        sidebarList
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
            .onReceive(NotificationCenter.default.publisher(for: .addProject)) { _ in
                showingAddProjectChoice = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .addNew)) { _ in
                if case let .workstream(wsID) = selection,
                   let project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
                {
                    addWorkstream(for: project.id)
                } else if case let .project(pid) = selection {
                    addWorkstream(for: pid)
                } else {
                    showingAddProjectChoice = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openDirectory)) { notification in
                guard let directory = notification.object as? String else { return }
                addProject(name: URL(fileURLWithPath: directory).lastPathComponent, directory: directory)
            }
    }

    private var sidebarList: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                ScrollViewReader { scrollProxy in
                    List(selection: $selection) {
                        projectRows()
                    }
                    .listStyle(.sidebar)
                    .safeAreaInset(edge: .top) {
                        if projects.count > 1 {
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
                        if case let .project(pid) = sel {
                            expandedProjects.insert(pid)
                        }
                        if case let .workstream(wsID) = sel,
                           let (pi, _) = cachedWorkstreamIndex[wsID]
                        {
                            expandedProjects.insert(projects[pi].id)
                        }
                        withAnimation {
                            scrollProxy.scrollTo(sel, anchor: .center)
                        }
                    }
                } // ScrollViewReader

                // Bottom bar (always visible)
                bottomBar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalActivity)) { notification in
            guard let wsID = notification.object as? UUID else { return }
            guard let (pi, wi) = cachedWorkstreamIndex[wsID] else { return }
            let now = Date()
            projects[pi].lastAccessedAt = now
            projects[pi].workstreams[wi].lastAccessedAt = now
            onProjectsChanged()
        }
        .onAppear {
            cachedSortedIDs = recomputeSortedIDs()
            rebuildIndices()
        }
        .onChange(of: sortOrder) { _, _ in cachedSortedIDs = recomputeSortedIDs() }
        .onChange(of: expandedProjects) { _, newValue in SidebarState.saveExpanded(newValue) }
        .onChange(of: projects.count) { _, _ in
            cachedSortedIDs = recomputeSortedIDs()
            rebuildIndices()
        }
        .onChange(of: projects.flatMap(\.workstreams).map(\.id)) { _, _ in
            rebuildIndices()
        }
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
    }

    // MARK: - Workstream management

    @AppStorage("factoryfloor.bypassPermissions") private var defaultBypass: Bool = false
    @AppStorage("factoryfloor.symlinkEnv") private var symlinkEnv: Bool = true

    private static func hasPort(_ workstreamID: UUID) -> Bool {
        RunStateStore.loadValidated(for: workstreamID)?.detectedPorts.isEmpty == false
    }

    private func addWorkstream(for projectID: UUID, bypassPermissions: Bool? = nil) {
        logger.warning("[FF] addWorkstream called for projectID=\(projectID, privacy: .public)")
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            logger.warning("[FF] addWorkstream: project not found")
            return
        }
        let project = projects[index]
        logger.warning("[FF] addWorkstream: project=\(project.name, privacy: .public) dir=\(project.directory, privacy: .public)")

        guard GitOperations.isGitRepo(at: project.directory) else {
            logger.warning("[FF] addWorkstream: not a git repo")
            showNotGitRepoError = true
            return
        }
        logger.warning("[FF] addWorkstream: is git repo")

        let existingNames = Set(project.workstreams.map(\.name))
        let name = NameGenerator.generate(avoiding: existingNames)
        logger.warning("[FF] addWorkstream: generated name=\(name, privacy: .public)")

        let bypass = bypassPermissions ?? defaultBypass
        let workstream = Workstream(name: name, worktreePath: nil, bypassPermissions: bypass)
        expandedProjects.insert(projectID)
        NotificationCenter.default.post(
            name: .workstreamCreated,
            object: nil,
            userInfo: ["projectID": projectID, "workstream": workstream]
        )
        rebuildIndices()
        logger.warning("[FF] addWorkstream: posted notification (optimistic), starting background worktree creation")

        let projectPath = project.directory
        let projectName = project.name
        let prefix = branchPrefix
        let symlink = symlinkEnv
        let workstreamID = workstream.id

        DispatchQueue.global(qos: .userInitiated).async {
            let worktreePath = GitOperations.createWorktree(
                projectPath: projectPath,
                projectName: projectName,
                workstreamName: name,
                branchPrefix: prefix,
                symlinkEnv: symlink
            )
            DispatchQueue.main.async {
                if let worktreePath {
                    logger.warning("[FF] addWorkstream: worktree created at \(worktreePath, privacy: .public)")
                    NotificationCenter.default.post(
                        name: .workstreamWorktreeReady,
                        object: nil,
                        userInfo: ["workstreamID": workstreamID, "worktreePath": worktreePath]
                    )
                } else {
                    logger.warning("[FF] addWorkstream: createWorktree FAILED, rolling back")
                    NotificationCenter.default.post(
                        name: .workstreamCreationFailed,
                        object: nil,
                        userInfo: ["projectID": projectID, "workstreamID": workstreamID]
                    )
                    showWorktreeError = true
                }
            }
        }
    }

    @EnvironmentObject private var surfaceCache: TerminalSurfaceCache
    @EnvironmentObject private var appEnv: AppEnvironment
    @EnvironmentObject private var updateChecker: UpdateChecker
    @EnvironmentObject private var updater: Updater

    private func confirmArchive(_ workstream: Workstream) {
        if let path = workstream.worktreePath, GitOperations.hasUncommittedChanges(at: path) {
            archiveWarningDirty = true
        } else {
            archiveWarningDirty = false
        }
        workstreamToArchive = workstream.id
    }

    private func performArchive() {
        guard let wsID = workstreamToArchive,
              let pi = projects.firstIndex(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) else { return }
        let projectID = projects[pi].id
        WorkstreamArchiver.archive(wsID, in: &projects[pi], surfaceCache: surfaceCache, tmuxPath: appEnv.toolStatus.tmux.path)
        rebuildIndices()
        if case let .workstream(id) = selection, id == wsID {
            selection = projects[pi].workstreams.first.map { .workstream($0.id) } ?? .project(projectID)
        }
        onProjectsChanged()
        workstreamToArchive = nil
    }

    // MARK: - Project management

    private func deleteProject(id: UUID) {
        if let project = projects.first(where: { $0.id == id }) {
            for ws in project.workstreams {
                surfaceCache.removeWorkstreamSurfaces(for: ws.id)
            }
        }
        projects.removeAll { $0.id == id }
        if case let .project(pid) = selection, pid == id { selection = nil }
        if case let .workstream(wsID) = selection,
           !projects.contains(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
        {
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

    private var sponsorURL: URL {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let path = lang == "en" ? "/sponsor" : "/\(lang)/sponsor"
        return URL(string: "https://factory-floor.com\(path)")!
    }

    @AppStorage("factoryfloor.baseDirectory") private var baseDirectory: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
    @AppStorage("factoryfloor.branchPrefix") private var branchPrefix: String = "ff"

    private func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: baseDirectory)
        panel.message = NSLocalizedString("Choose a project directory", comment: "")
        panel.prompt = NSLocalizedString("Select", comment: "")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.addProject(name: url.lastPathComponent, directory: url.path)
        }
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

        // Initialize git repo in the new directory
        _ = GitOperations.initRepo(at: dirURL.path)

        showingNewProjectName = false
        addProject(name: name, directory: dirURL.path)
    }

    private func addProject(name: String, directory: String) {
        // Resolve worktree branches to their main repository
        let resolvedDirectory: String
        let resolvedName: String
        if let mainRepoPath = GitOperations.mainRepositoryPath(for: directory) {
            resolvedDirectory = mainRepoPath
            resolvedName = URL(fileURLWithPath: mainRepoPath).lastPathComponent
        } else {
            resolvedDirectory = directory
            resolvedName = name
        }

        if let existing = projects.first(where: { $0.directory == resolvedDirectory }) {
            selection = .project(existing.id)
            return
        }

        let projectName = resolvedName.isEmpty ? URL(fileURLWithPath: resolvedDirectory).lastPathComponent : resolvedName
        let project = Project(name: projectName, directory: resolvedDirectory)
        NotificationCenter.default.post(
            name: .projectCreated,
            object: nil,
            userInfo: ["project": project]
        )
    }
}

extension FileManager {
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

private func copyTextToPasteboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private struct ProjectHeaderRow: View {
    let project: Project
    let isExpanded: Bool
    let onToggle: (() -> Void)?
    let isGitRepo: Bool
    let onAdd: () -> Void
    let onAddWithPermissions: () -> Void
    let onAddWithoutPermissions: () -> Void
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
                    .buttonStyle(.borderless)
                    .onHover { isChevronHovering = $0 }
                    .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                    .accessibilityValue(isExpanded ? "expanded" : "collapsed")
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
                            .accessibilityLabel("\(project.workstreams.count) workstreams")
                    }
                }

                Text(project.directory.abbreviatedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                if isGitRepo {
                    SidebarIconButton(icon: "plus", action: onAdd)
                        .accessibilityLabel("Add workstream to \(project.name)")
                        .contextMenu {
                            Button(action: onAddWithPermissions) {
                                Label("New workstream (full permissions)", systemImage: "lock.open")
                            }
                            Button(action: onAddWithoutPermissions) {
                                Label("New workstream (with prompts)", systemImage: "lock.shield")
                            }
                        }
                }
                SidebarIconButton(icon: "trash", action: onDelete)
                    .accessibilityLabel("Remove project")
            }
            .opacity(isHovering ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button {
                copyTextToPasteboard(project.directory)
            } label: {
                Label("Copy project path", systemImage: "doc.on.doc")
            }
        }
    }
}

private struct WorkstreamRow: View {
    let name: String
    var branchName: String?
    var worktreePath: String?
    let isPathValid: Bool
    var hasActivePort: Bool = false
    let onArchive: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(name)
                            .font(.system(.body))
                            .strikethrough(!isPathValid)
                            .foregroundStyle(isPathValid ? .primary : .secondary)
                        if hasActivePort {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.green)
                        }
                    }
                    if let branchName, isPathValid {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text(branchName)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: isPathValid ? "terminal" : "exclamationmark.triangle")
                    .foregroundStyle(isPathValid ? Color.secondary : Color.orange)
            }

            Spacer()

            SidebarIconButton(icon: "archivebox", action: onArchive)
                .accessibilityLabel("Archive workstream")
                .opacity(isHovering ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            if let branchName {
                Button {
                    copyTextToPasteboard(branchName)
                } label: {
                    Label("Copy branch name", systemImage: "arrow.triangle.branch")
                }
            }
            if let worktreePath {
                Button {
                    copyTextToPasteboard(worktreePath)
                } label: {
                    Label("Copy worktree path", systemImage: "doc.on.doc")
                }
            }
        }
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
        .buttonStyle(.borderless)
        .onHover { isHovering = $0 }
    }
}

private struct SidebarBottomButton: View {
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 32, height: 32)
                .background(isHovering ? Color.primary.opacity(0.08) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.borderless)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
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
                        Image(systemName: "plus.rectangle.on.folder")
                            .font(.system(size: 20))
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New Project")
                                .font(.system(.body, weight: .medium))
                            Text("Create a new directory in the base directory")
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
                .buttonStyle(.borderless)
                .keyboardShortcut(.defaultAction)

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
                .buttonStyle(.borderless)
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
                    Text(baseDirectory.abbreviatedPath)
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
}
