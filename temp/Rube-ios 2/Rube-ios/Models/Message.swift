//
//  Message.swift
//  Rube-ios
//
//  Chat message model
//

import Foundation

struct Message: Identifiable, Equatable {
    let id: String
    let content: String
    let role: MessageRole
    let timestamp: Date
    var toolCalls: [ToolCall]?

    init(
        id: String = UUID().uuidString,
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        toolCalls: [ToolCall]? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.toolCalls = toolCalls
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ToolCall: Identifiable, Equatable {
    let id: String
    let name: String
    var input: [String: Any]
    var output: Any?
    var status: ToolCallStatus

    init(
        id: String,
        name: String,
        input: [String: Any] = [:],
        output: Any? = nil,
        status: ToolCallStatus = .running
    ) {
        self.id = id
        self.name = name
        self.input = input
        self.output = output
        self.status = status
    }

    static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

enum ToolCallStatus: Equatable {
    case running
    case completed
    case error
}
