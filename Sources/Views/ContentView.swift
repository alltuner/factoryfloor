// ABOUTME: Main application view composing the sidebar and terminal content area.
// ABOUTME: Uses NavigationSplitView for the sidebar/detail pattern.

import OSLog
import SwiftUI

private let logger = Logger(subsystem: "factoryfloor", category: "content-view")

extension Notification.Name {
    static let workstreamCreated = Notification.Name("factoryfloor.workstreamCreated")
    static let projectCreated = Notification.Name("factoryfloor.projectCreated")
}

struct ContentView: View {
    @State private var projects: [Project] = ProjectStore.load()
    @State private var selection: SidebarSelection? = SidebarSelection.loadSaved() ?? ContentView.initialSelection()
    @State private var selectionBeforeSettings: SidebarSelection?
    @StateObject private var surfaceCache = TerminalSurfaceCache()
    @StateObject private var appEnvironment = AppEnvironment()
    @StateObject private var updateChecker = UpdateChecker()
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
        case .project(let id):
            let found = projects.first(where: { $0.id == id })
            if found == nil { logger.warning("[FF] activeProject: project \(id, privacy: .public) not found in \(projects.count, privacy: .public) projects") }
            return found
        case .workstream(let wsID):
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
        } else if let project = activeProject,
                  let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
            ProjectOverviewView(
                project: $projects[projectIndex],
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
            .onChange(of: projects) { _, newValue in
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
                Text("The following projects were removed because their directories no longer exist on disk: \(removedProjectNames.joined(separator: ", "))")
            }
    }

    private var navigationView: some View {
        NavigationSplitView {
            ProjectSidebar(
                projects: $projects,
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
            if case .project(let pid) = selection {
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
               let project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) {
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
            if let sel = selection, case .project(let pid) = sel, missing.contains(pid) {
                selection = nil
            }
            if let sel = selection, case .workstream(_) = sel, activeProject == nil {
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
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
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
           let currentIndex = sorted.firstIndex(where: { $0.id == wsID }) {
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

    private static var fileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("projects.json")
    }

    static func load() -> [Project] {
        // Try loading from JSON file first
        if let data = try? Data(contentsOf: fileURL) {
            return (try? JSONDecoder().decode([Project].self, from: data)) ?? []
        }
        // Migrate from UserDefaults if file doesn't exist
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let projects = try? JSONDecoder().decode([Project].self, from: data) {
            save(projects)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return projects
        }
        return []
    }

    static func save(_ projects: [Project]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(projects) else { return }
        do {
            try FilePersistence.writeAtomically(data, to: fileURL)
        } catch {
            logger.warning("Failed to save projects: \(error.localizedDescription)")
        }
    }
}
