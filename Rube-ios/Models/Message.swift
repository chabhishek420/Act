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
    var toolCallID: String?
    var toolCalls: [ToolCall]?
    var attachments: [Attachment]?
    var isFailed: Bool = false
    var failureReason: String?

    init(
        id: String = UUID().uuidString,
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        toolCalls: [ToolCall]? = nil,
        toolCallID: String? = nil,
        attachments: [Attachment]? = nil,
        isFailed: Bool = false,
        failureReason: String? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.attachments = attachments
        self.isFailed = isFailed
        self.failureReason = failureReason
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
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

struct Attachment: Identifiable, Codable, Equatable {
    let id: String
    let fileId: String // Appwrite file ID
    let bucketId: String
    let name: String
    let mimeType: String
    let size: Int
    
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
}
