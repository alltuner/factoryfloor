// ABOUTME: Data models for projects and workstreams.
// ABOUTME: Each project has a directory and multiple workstreams, each with its own terminal.

import Foundation

struct Workstream: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var worktreePath: String?
    var bypassPermissions: Bool
    var lastAccessedAt: Date

    init(name: String, worktreePath: String? = nil, bypassPermissions: Bool = false, id: UUID = UUID(), lastAccessedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.worktreePath = worktreePath
        self.bypassPermissions = bypassPermissions
        self.lastAccessedAt = lastAccessedAt
    }

    /// The working directory for this workstream's terminals.
    /// Uses the worktree path if available, otherwise falls back to the project directory.
    func workingDirectory(projectDirectory: String) -> String {
        worktreePath ?? projectDirectory
    }

    static func == (lhs: Workstream, rhs: Workstream) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Project: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var directory: String
    var workstreams: [Workstream]
    var lastAccessedAt: Date

    init(name: String, directory: String, id: UUID = UUID(), workstreams: [Workstream] = [], lastAccessedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.directory = directory
        self.workstreams = workstreams
        self.lastAccessedAt = lastAccessedAt
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum ProjectSortOrder: String, CaseIterable, Sendable {
    case recent = "Recent"
    case alphabetical = "A-Z"
}
