// ABOUTME: Data models for projects and workstreams.
// ABOUTME: Each project has a directory and multiple workstreams, each with its own terminal.

import Foundation

struct Workstream: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var lastAccessedAt: Date

    init(name: String, id: UUID = UUID(), lastAccessedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.lastAccessedAt = lastAccessedAt
    }
}

struct Project: Identifiable, Hashable, Codable {
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
}

enum ProjectSortOrder: String, CaseIterable {
    case recent = "Recent"
    case alphabetical = "A-Z"
}
