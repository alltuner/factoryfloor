// ABOUTME: Main application view composing the sidebar and terminal content area.
// ABOUTME: Uses NavigationSplitView for the sidebar/detail pattern.

import OSLog
import SwiftUI

private let logger = Logger(subsystem: "factoryfloor", category: "content-view")

extension Notification.Name {
    static let workstreamCreated = Notification.Name("factoryfloor.workstreamCreated")
    static let workstreamWorktreeReady = Notification.Name("factoryfloor.workstreamWorktreeReady")
    static let workstreamCreationFailed = Notification.Name("factoryfloor.workstreamCreationFailed")
    static let projectCreated = Notification.Name("factoryfloor.projectCreated")
}

final class ProjectList: ObservableObject {
    @Published var items: [Project]

    init() {
        items = ProjectStore.load()
    }
}

struct ContentView: View {
    @StateObject private var projectList = ProjectList()
    @State private var selection: SidebarSelection? = SidebarSelection.loadSaved() ?? ContentView.initialSelection()
    @State private var selectionBeforeSettings: SidebarSelection?

    private var projects: [Project] {
        get { projectList.items }
        nonmutating set { projectList.items = newValue }
    }

    @StateObject private var surfaceCache = TerminalSurfaceCache()
    @StateObject private var appEnvironment = AppEnvironment()
    @StateObject private var updateChecker = UpdateChecker()
    @EnvironmentObject private var updater: Updater
    @State private var saveWork: DispatchWorkItem?
    @State private var workstreamToArchive: UUID?
    @State private var archiveWarningDirty = false
    @State private var removedProjectNames: [String] = []
    @State private var keyMonitorInstalled = false

    private static func initialSelection() -> SidebarSelection? {
        let projects = ProjectStore.load()
        guard let mostRecent = projects.max(by: { $0.lastAccessedAt < $1.lastAccessedAt }) else { return nil }
        return .project(mostRecent.id)
    }

    private var activeProject: Project? {
        guard let selection else {
            logger.warning("[FF] activeProject: selection is nil")
            return nil
        }
        switch selection {
        case let .project(id):
            let found = projects.first(where: { $0.id == id })
            if found == nil { logger.warning("[FF] activeProject: project \(id, privacy: .public) not found in \(projects.count, privacy: .public) projects") }
            return found
        case let .workstream(wsID):
            let found = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
            if found == nil { logger.warning("[FF] activeProject: workstream \(wsID, privacy: .public) not found in any project") }
            return found
        case .settings, .help:
            return nil
        }
    }

    private var activeWorkstream: Workstream? {
        guard let wsID = selection?.workstreamID,
              let project = activeProject else { return nil }
        return project.workstreams.first(where: { $0.id == wsID })
    }

    @ViewBuilder
    private var detailView: some View {
        if selection == .settings {
            SettingsView()
                .navigationTitle("Settings")
                .navigationSubtitle(AppConstants.appName)
        } else if selection == .help {
            HelpView()
                .navigationTitle("Help")
                .navigationSubtitle(AppConstants.appName)
        } else if let workstream = activeWorkstream, let project = activeProject {
            if workstream.worktreePath != nil {
                TerminalContainerView(
                    workstreamID: workstream.id,
                    workingDirectory: workstream.workingDirectory(projectDirectory: project.directory),
                    projectDirectory: project.directory,
                    projectName: project.name,
                    workstreamName: workstream.name,
                    bypassPermissions: workstream.bypassPermissions
                )
                .id(workstream.id)
                .navigationTitle(workstream.name)
                .navigationSubtitle(project.name)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Preparing workstream...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(workstream.name)
                .navigationSubtitle(project.name)
            }
        } else if let project = activeProject,
                  let projectIndex = projects.firstIndex(where: { $0.id == project.id })
        {
            ProjectOverviewView(
                project: $projectList.items[projectIndex],
                onSelectWorkstream: { wsID in selection = .workstream(wsID) },
                onArchiveWorkstream: { wsID in confirmArchive(wsID) },
                onProjectChanged: { ProjectStore.save(projects) }
            )
            .navigationTitle(project.name)
            .navigationSubtitle(AppConstants.appName)
        } else {
            OnboardingView(toolStatus: appEnvironment.toolStatus, isDetecting: appEnvironment.isDetecting)
                .navigationTitle(AppConstants.appName)
        }
    }

    var body: some View {
        navigationView
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openHelp)) { _ in
                if selection == .help {
                    selection = selectionBeforeSettings
                } else {
                    selectionBeforeSettings = selection
                    selection = .help
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                if selection == .settings {
                    selection = selectionBeforeSettings
                } else {
                    selection = .settings
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearProjects)) { _ in
                for project in projects {
                    for ws in project.workstreams {
                        surfaceCache.removeWorkstreamSurfaces(for: ws.id)
                    }
                }
                projects.removeAll()
                selectionBeforeSettings = nil
                selection = .settings
                ProjectStore.save([])
            }
            .onReceive(NotificationCenter.default.publisher(for: .openExternalTerminal)) { _ in
                openExternalTerminal()
            }
            .onChange(of: projectList.items) { _, newValue in
                // Debounce saves to avoid rapid I/O from activity updates
                saveWork?.cancel()
                let work = DispatchWorkItem { ProjectStore.save(newValue) }
                saveWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
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
                "Projects Not Found",
                isPresented: Binding(
                    get: { !removedProjectNames.isEmpty },
                    set: { if !$0 { removedProjectNames = [] } }
                )
            ) {
                Button("OK") { removedProjectNames = [] }
            } message: {
                Text(String(format: NSLocalizedString("The following projects were removed because their directories no longer exist on disk: %@", comment: ""), removedProjectNames.joined(separator: ", ")))
            }
    }

    private var navigationView: some View {
        NavigationSplitView {
            ProjectSidebar(
                projects: $projectList.items,
                selection: $selection,
                onProjectsChanged: { ProjectStore.save(projects) }
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 350)
        } detail: {
            detailView
        }
        .environmentObject(surfaceCache)
        .environmentObject(appEnvironment)
        .environmentObject(updateChecker)
        .environmentObject(updater)
        .onAppear {
            appEnvironment.refresh()
            appEnvironment.refreshAllRepoInfo(projects: projects)
            appEnvironment.refreshPathValidity(projects: projects)
            updateChecker.check()
            // Apply saved appearance
            switch UserDefaults.standard.string(forKey: "factoryfloor.appearance") ?? "system" {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToWorkstream)) { notification in
            guard let n = notification.object as? Int else { return }
            // Find the active project (from project view or workstream view)
            let project: Project?
            if case let .project(pid) = selection {
                project = projects.first(where: { $0.id == pid })
            } else if let wsID = selection?.workstreamID {
                project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
            } else {
                project = nil
            }
            guard let project else { return }
            let sorted = project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
            if n >= 1 && n <= sorted.count {
                selection = .workstream(sorted[n - 1].id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToProject)) { _ in
            // Go back to project view from any workstream
            if let wsID = selection?.workstreamID,
               let project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
            {
                selection = .project(project.id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextTab)) { _ in
            cycleWorkstream(direction: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevTab)) { _ in
            cycleWorkstream(direction: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .workstreamCreated)) { notification in
            guard let info = notification.userInfo,
                  let projectID = info["projectID"] as? UUID,
                  let workstream = info["workstream"] as? Workstream,
                  let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
            projects[index].workstreams.append(workstream)
            selection = .workstream(workstream.id)
            ProjectStore.save(projects)
            logger.warning("[FF] workstreamCreated notification handled: \(workstream.name, privacy: .public)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .workstreamWorktreeReady)) { notification in
            guard let info = notification.userInfo,
                  let workstreamID = info["workstreamID"] as? UUID,
                  let worktreePath = info["worktreePath"] as? String else { return }
            for pi in projects.indices {
                if let wi = projects[pi].workstreams.firstIndex(where: { $0.id == workstreamID }) {
                    projects[pi].workstreams[wi].worktreePath = worktreePath
                    ProjectStore.save(projects)
                    logger.warning("[FF] workstreamWorktreeReady: updated \(workstreamID, privacy: .public) with path \(worktreePath, privacy: .public)")
                    return
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .workstreamCreationFailed)) { notification in
            guard let info = notification.userInfo,
                  let projectID = info["projectID"] as? UUID,
                  let workstreamID = info["workstreamID"] as? UUID,
                  let pi = projects.firstIndex(where: { $0.id == projectID }) else { return }
            projects[pi].workstreams.removeAll { $0.id == workstreamID }
            if case let .workstream(selectedID) = selection, selectedID == workstreamID {
                selection = .project(projectID)
            }
            ProjectStore.save(projects)
            logger.warning("[FF] workstreamCreationFailed: removed \(workstreamID, privacy: .public)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .projectCreated)) { notification in
            guard let project = notification.userInfo?["project"] as? Project else { return }
            projects.append(project)
            selection = .project(project.id)
            ProjectStore.save(projects)
            logger.warning("[FF] projectCreated notification handled: \(project.name, privacy: .public)")
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            appEnvironment.refreshAllRepoInfo(projects: projects)
            appEnvironment.refreshPathValidity(projects: projects)
            appEnvironment.refreshAllBranchPRs(projects: projects)
            syncWorkstreamNamesFromBranches()
        }
        .onReceive(Timer.publish(every: 6 * 60 * 60, on: .main, in: .common).autoconnect()) { _ in
            updateChecker.check()
        }
        .onChange(of: appEnvironment.missingProjectIDs) { _, missing in
            guard !missing.isEmpty else { return }
            logger.warning("[FF] missingProjectIDs changed: \(missing.count, privacy: .public) missing, \(projects.count, privacy: .public) total projects")
            let names = projects.filter { missing.contains($0.id) }.map(\.name)
            logger.warning("[FF] removing projects: \(names, privacy: .public)")
            for id in missing {
                if let project = projects.first(where: { $0.id == id }) {
                    for ws in project.workstreams {
                        surfaceCache.removeWorkstreamSurfaces(for: ws.id)
                    }
                }
            }
            projects.removeAll { missing.contains($0.id) }
            if let sel = selection, case let .project(pid) = sel, missing.contains(pid) {
                selection = nil
            }
            if let sel = selection, case .workstream = sel, activeProject == nil {
                selection = nil
            }
            ProjectStore.save(projects)
            removedProjectNames = names
        }
        .onChange(of: selection) { oldValue, newValue in
            logger.warning("[FF] selection changed: \(String(describing: oldValue), privacy: .public) -> \(String(describing: newValue), privacy: .public)")
            if newValue == .settings || newValue == .help {
                selectionBeforeSettings = oldValue
            }
            // Don't persist settings/help as saved selection
            if newValue != .settings && newValue != .help {
                newValue?.save()
            }
        }
        .onKeyPress(.escape) {
            if selection == .settings || selection == .help {
                selection = selectionBeforeSettings
                return .handled
            }
            return .ignored
        }
        .onAppear {
            // Intercept Cmd+W at the app level to close tabs instead of the window
            guard !keyMonitorInstalled else { return }
            keyMonitorInstalled = true
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                    NotificationCenter.default.post(name: .closeTerminal, object: nil)
                    return nil // swallow the event
                }
                return event
            }
        }
    }

    private func openExternalTerminal() {
        let dir: String?
        if let ws = activeWorkstream, let project = activeProject {
            dir = ws.workingDirectory(projectDirectory: project.directory)
        } else if let project = activeProject {
            dir = project.directory
        } else {
            dir = nil
        }
        guard let dir else { return }
        let terminalBundleID = UserDefaults.standard.string(forKey: "factoryfloor.defaultTerminal") ?? ""
        if !terminalBundleID.isEmpty,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID)
        {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([URL(fileURLWithPath: dir)], withApplicationAt: appURL, configuration: config)
        } else if let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([URL(fileURLWithPath: dir)], withApplicationAt: terminalURL, configuration: config)
        }
    }

    /// Update workstream names to match their branch name (without prefix).
    /// Called periodically so that when the agent renames a branch, the sidebar reflects it.
    private func syncWorkstreamNamesFromBranches() {
        var changed = false
        for pi in projects.indices {
            for wi in projects[pi].workstreams.indices {
                let ws = projects[pi].workstreams[wi]
                guard let branch = appEnvironment.branchName(for: ws.worktreePath) else { continue }
                // Strip the prefix (everything up to and including the last "/")
                let shortName = branch.contains("/") ? String(branch.split(separator: "/").last ?? Substring(branch)) : branch
                if shortName != ws.name {
                    projects[pi].workstreams[wi].name = shortName
                    changed = true
                }
            }
        }
        if changed {
            ProjectStore.save(projects)
        }
    }

    /// Cycle through workstreams within the active project.
    /// Only acts when a project or workstream is selected (not settings/help).
    private func cycleWorkstream(direction: Int) {
        guard let project = activeProject else { return }
        let sorted = project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
        guard !sorted.isEmpty else { return }

        if let wsID = selection?.workstreamID,
           let currentIndex = sorted.firstIndex(where: { $0.id == wsID })
        {
            let next = (currentIndex + direction + sorted.count) % sorted.count
            selection = .workstream(sorted[next].id)
        } else if case .project = selection {
            // In project view: jump to first/last workstream
            selection = .workstream(direction > 0 ? sorted.first!.id : sorted.last!.id)
        }
    }

    private func confirmArchive(_ wsID: UUID) {
        let ws = projects.flatMap(\.workstreams).first(where: { $0.id == wsID })
        if let path = ws?.worktreePath, GitOperations.hasUncommittedChanges(at: path) {
            archiveWarningDirty = true
        } else {
            archiveWarningDirty = false
        }
        workstreamToArchive = wsID
    }

    private func performArchive() {
        guard let wsID = workstreamToArchive,
              let projectIndex = projects.firstIndex(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) else { return }
        WorkstreamArchiver.archive(wsID, in: &projects[projectIndex], surfaceCache: surfaceCache, tmuxPath: appEnvironment.toolStatus.tmux.path)
        ProjectStore.save(projects)
        workstreamToArchive = nil
    }
}

enum ProjectStore {
    private static let userDefaultsKey = "factoryfloor.projects"

    static func load(defaults: UserDefaults = .standard) -> [Project] {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let projects = try? JSONDecoder().decode([Project].self, from: data)
        else { return [] }
        return projects
    }

    static func save(_ projects: [Project], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        defaults.set(data, forKey: userDefaultsKey)
    }
}
