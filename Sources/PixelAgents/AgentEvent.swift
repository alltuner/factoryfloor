// ABOUTME: Event types for the Swift-to-JS pixel agents bridge protocol.
// ABOUTME: Encoded as JSON and sent to the WKWebView via evaluateJavaScript.

import Foundation

struct AgentEvent: Codable, Sendable {
    let type: EventType
    let agentId: String
    var name: String?
    var palette: Int?
    var tool: String?
    var status: String?

    enum EventType: String, Codable, Sendable {
        case agentCreated
        case agentRemoved
        case agentStatus
        case agentToolStart
        case agentToolDone
    }

    enum CodingKeys: String, CodingKey {
        case type
        case agentId
        case name
        case palette
        case tool
        case status
    }

    // -- Factory methods --

    static func created(agentId: String, name: String, palette: Int) -> AgentEvent {
        AgentEvent(type: .agentCreated, agentId: agentId, name: name, palette: palette)
    }

    static func removed(agentId: String) -> AgentEvent {
        AgentEvent(type: .agentRemoved, agentId: agentId)
    }

    static func status(agentId: String, status: String) -> AgentEvent {
        AgentEvent(type: .agentStatus, agentId: agentId, status: status)
    }

    static func toolStart(agentId: String, tool: String) -> AgentEvent {
        AgentEvent(type: .agentToolStart, agentId: agentId, tool: tool)
    }

    static func toolDone(agentId: String) -> AgentEvent {
        AgentEvent(type: .agentToolDone, agentId: agentId)
    }
}
