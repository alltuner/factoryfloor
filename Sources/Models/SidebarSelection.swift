// ABOUTME: Represents the selected item in the sidebar.
// ABOUTME: Can be either a project or a workstream, enabling single-selection across both.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "sidebar-selection")

enum SidebarSelection: Hashable, Codable {
    case project(UUID)
    case workstream(UUID)
    case settings
    case help

    var projectID: UUID? {
        if case let .project(id) = self { return id }
        return nil
    }

    var workstreamID: UUID? {
        if case let .workstream(id) = self { return id }
        return nil
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "factoryfloor.selection"

    static func loadSaved() -> SidebarSelection? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let selection = try? JSONDecoder().decode(SidebarSelection.self, from: data)
        else { return nil }
        return selection
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

enum SidebarState {
    private static let userDefaultsKey = "factoryfloor.expandedProjects"

    static func loadExpanded() -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data)
        else { return [] }
        return ids
    }

    static func saveExpanded(_ ids: Set<UUID>) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
