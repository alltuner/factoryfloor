// ABOUTME: Main application view composing the sidebar and terminal content area.
// ABOUTME: Uses NavigationSplitView for the sidebar/detail pattern.

import SwiftUI

struct ContentView: View {
    @State private var projects: [Project] = ProjectStore.load()
    @State private var selection: SidebarSelection? = ContentView.initialSelection()
    @State private var selectionBeforeSettings: SidebarSelection?
    @StateObject private var surfaceCache = TerminalSurfaceCache()
    @StateObject private var appEnvironment = AppEnvironment()
    @State private var saveWork: DispatchWorkItem?

    private static func initialSelection() -> SidebarSelection? {
        let projects = ProjectStore.load()
        guard let mostRecent = projects.max(by: { $0.lastAccessedAt < $1.lastAccessedAt }) else { return nil }
        return .project(mostRecent.id)
    }

    private var activeProject: Project? {
        guard let selection else { return nil }
        switch selection {
        case .project(let id):
            return projects.first(where: { $0.id == id })
        case .workstream(let wsID):
            return projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) })
        case .settings, .help:
            return nil
        }
    }

    private var activeWorkstream: Workstream? {
        guard let wsID = selection?.workstreamID,
              let project = activeProject else { return nil }
        return project.workstreams.first(where: { $0.id == wsID })
    }

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(
                projects: $projects,
                selection: $selection,
                onProjectsChanged: { ProjectStore.save(projects) }
            )
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 350)
        } detail: {
            if selection == .settings {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationSubtitle("ff2")
            } else if selection == .help {
                HelpView()
                    .navigationTitle("Help")
                    .navigationSubtitle("ff2")
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
                    onArchiveWorkstream: { wsID in
                        let project = projects[projectIndex]
                        if let ws = project.workstreams.first(where: { $0.id == wsID }) {
                            let projectDir = project.directory
                            let wsName = ws.name
                            let projName = project.name
                            let tmuxPath = appEnvironment.toolStatus.tmux.path
                            Task.detached {
                                GitOperations.removeWorktree(projectPath: projectDir, workstreamName: wsName, projectName: projName)
                                if let tmuxPath {
                                    TmuxSession.killWorkstreamSessions(tmuxPath: tmuxPath, project: projName, workstream: wsName)
                                }
                            }
                        }
                        surfaceCache.removeWorkstreamSurfaces(for: wsID)
                        projects[projectIndex].workstreams.removeAll { $0.id == wsID }
                        ProjectStore.save(projects)
                    },
                    onProjectChanged: { ProjectStore.save(projects) }
                )
                .navigationTitle(project.name)
                .navigationSubtitle("ff2")
            } else {
                VStack(spacing: 12) {
                    Text("No project selected")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Add a project from the sidebar to get started.")
                        .foregroundStyle(.tertiary)
                    (Text(Image(systemName: "command")) + Text(Image(systemName: "shift")) + Text(" N"))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(alignment: .bottom) {
                    PoblenouSkylineView()
                        .padding(.horizontal, 40)
                        .padding(.bottom, 10)
                }
                .navigationTitle("ff2")
            }
        }
        .environmentObject(surfaceCache)
        .environmentObject(appEnvironment)
        .onAppear {
            appEnvironment.refresh()
            appEnvironment.refreshAllRepoInfo(projects: projects)
            appEnvironment.refreshPathValidity(projects: projects)
            // Apply saved appearance
            switch UserDefaults.standard.string(forKey: "ff2.appearance") ?? "system" {
            case "light": NSApp.appearance = NSAppearance(named: .aqua)
            case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchByNumber)) { notification in
            guard let n = notification.object as? Int else { return }
            // In project view: Cmd+N jumps to Nth workstream
            if case .project(let pid) = selection,
               let project = projects.first(where: { $0.id == pid }) {
                let sorted = project.workstreams.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
                if n >= 1 && n <= sorted.count {
                    selection = .workstream(sorted[n - 1].id)
                }
            }
            // In workstream view: Cmd+1-4 switches tabs (handled by TerminalContainerView)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToProject)) { _ in
            // Go back to project view from any workstream
            if let wsID = selection?.workstreamID,
               let project = projects.first(where: { $0.workstreams.contains(where: { $0.id == wsID }) }) {
                selection = .project(project.id)
            }
        }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            appEnvironment.refreshAllRepoInfo(projects: projects)
            appEnvironment.refreshPathValidity(projects: projects)
        }
        .onChange(of: appEnvironment.missingProjectIDs) { _, missing in
            guard !missing.isEmpty else { return }
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
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .settings {
                selectionBeforeSettings = oldValue
            }
        }
        .onKeyPress(.escape) {
            if selection == .settings || selection == .help {
                selection = selectionBeforeSettings
                return .handled
            }
            return .ignored
        }
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
            let dir: String?
            if let ws = activeWorkstream, let project = activeProject {
                dir = ws.workingDirectory(projectDirectory: project.directory)
            } else if let project = activeProject {
                dir = project.directory
            } else {
                dir = nil
            }
            guard let dir else { return }
            let terminalBundleID = UserDefaults.standard.string(forKey: "ff2.defaultTerminal") ?? ""
            if !terminalBundleID.isEmpty,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([URL(fileURLWithPath: dir)], withApplicationAt: appURL, configuration: config)
            } else {
                // Fallback: open Terminal.app with the directory
                let script = "tell application \"Terminal\" to do script \"cd \(dir.replacingOccurrences(of: "\"", with: "\\\"")) && clear\""
                if let appleScript = NSAppleScript(source: script) {
                    appleScript.executeAndReturnError(nil)
                }
            }
        }
        .onChange(of: projects) { _, newValue in
            // Debounce saves to avoid rapid I/O from activity updates
            saveWork?.cancel()
            let work = DispatchWorkItem { ProjectStore.save(newValue) }
            saveWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }
}

enum ProjectStore {
    private static let key = "ff2.projects"

    static func load() -> [Project] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Project].self, from: data)) ?? []
    }

    static func save(_ projects: [Project]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
