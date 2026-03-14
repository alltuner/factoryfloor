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
        case .settings:
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
            } else if let workstream = activeWorkstream, let project = activeProject {
                TerminalContainerView(
                    workstreamID: workstream.id,
                    workingDirectory: project.directory,
                    projectName: project.name,
                    workstreamName: workstream.name
                )
                .id(workstream.id)
                .navigationTitle(workstream.name)
                .navigationSubtitle(project.name)
            } else if let project = activeProject,
                      let projectIndex = projects.firstIndex(where: { $0.id == project.id }) {
                ProjectOverviewView(
                    project: $projects[projectIndex],
                    onSelectWorkstream: { wsID in selection = .workstream(wsID) },
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("ff2")
            }
        }
        .environmentObject(surfaceCache)
        .environmentObject(appEnvironment)
        .onAppear { appEnvironment.refresh() }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == .settings {
                selectionBeforeSettings = oldValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            if selection == .settings {
                selection = selectionBeforeSettings
            } else {
                selection = .settings
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
