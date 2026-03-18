// ABOUTME: Represents the selected item in the sidebar.
// ABOUTME: Can be either a project or a workstream, enabling single-selection across both.

import Foundation
import OSLog

private let logger = Logger(subsystem: "factoryfloor", category: "sidebar-selection")

enum SidebarSelection: Hashable, Codable, Sendable {
    case project(UUID)
    case workstream(UUID)
    case settings
    case help

    var projectID: UUID? {
        if case .project(let id) = self { return id }
        return nil
    }

    var workstreamID: UUID? {
        if case .workstream(let id) = self { return id }
        return nil
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "factoryfloor.selection"

    private static var legacyFileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("sidebar-selection.json")
    }

    static func loadSaved() -> SidebarSelection? {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let selection = try? JSONDecoder().decode(SidebarSelection.self, from: data) {
            return selection
        }
        // Migrate from JSON file if UserDefaults is empty
        if let data = try? Data(contentsOf: legacyFileURL),
           let selection = try? JSONDecoder().decode(SidebarSelection.self, from: data) {
            selection.save()
            try? FileManager.default.removeItem(at: legacyFileURL)
            return selection
        }
        return nil
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

enum SidebarState {
    private static let userDefaultsKey = "factoryfloor.expandedProjects"

    private static var legacyFileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("sidebar-state.json")
    }

    static func loadExpanded() -> Set<UUID> {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            return ids
        }
        // Migrate from JSON file if UserDefaults is empty
        if let data = try? Data(contentsOf: legacyFileURL),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            saveExpanded(ids)
            try? FileManager.default.removeItem(at: legacyFileURL)
            return ids
        }
        return []
    }

    static func saveExpanded(_ ids: Set<UUID>) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
