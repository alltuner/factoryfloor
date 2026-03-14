// ABOUTME: Represents the selected item in the sidebar.
// ABOUTME: Can be either a project or a workstream, enabling single-selection across both.

import Foundation

enum SidebarSelection: Hashable {
    case project(UUID)
    case workstream(UUID)
    case settings

    var projectID: UUID? {
        if case .project(let id) = self { return id }
        return nil
    }

    var workstreamID: UUID? {
        if case .workstream(let id) = self { return id }
        return nil
    }
}
