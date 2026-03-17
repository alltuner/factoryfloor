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

    private static var fileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("sidebar-selection.json")
    }

    static func loadSaved() -> SidebarSelection? {
        // Try loading from JSON file first
        if let data = try? Data(contentsOf: fileURL) {
            return try? JSONDecoder().decode(SidebarSelection.self, from: data)
        }
        // Migrate from UserDefaults if file doesn't exist
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let selection = try? JSONDecoder().decode(SidebarSelection.self, from: data) {
            selection.save()
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return selection
        }
        return nil
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        do {
            try FilePersistence.writeAtomically(data, to: Self.fileURL)
        } catch {
            logger.warning("Failed to save sidebar selection: \(error.localizedDescription)")
        }
    }
}

enum SidebarState {
    private static let userDefaultsKey = "factoryfloor.expandedProjects"

    private static var fileURL: URL {
        AppConstants.configDirectory.appendingPathComponent("sidebar-state.json")
    }

    static func loadExpanded() -> Set<UUID> {
        // Try loading from JSON file first
        if let data = try? Data(contentsOf: fileURL),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            return ids
        }
        // Migrate from UserDefaults if file doesn't exist
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            saveExpanded(ids)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return ids
        }
        return []
    }

    static func saveExpanded(_ ids: Set<UUID>) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(ids) else { return }
        do {
            try FilePersistence.writeAtomically(data, to: fileURL)
        } catch {
            logger.warning("Failed to save sidebar state: \(error.localizedDescription)")
        }
    }
}
