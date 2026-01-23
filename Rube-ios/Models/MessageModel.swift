//
//  MessageModel.swift
//  Rube-ios
//
//  SwiftData model for message persistence
//

import Foundation
import SwiftData

@Model
final class MessageModel {
    @Attribute(.unique) var id: String
    var content: String
    var role: String  // "user" or "assistant"
    var createdAt: Date
    
    var conversation: ConversationModel?
    
    init(
        id: String = UUID().uuidString,
        content: String,
        role: String,
        createdAt: Date = Date(),
        conversation: ConversationModel? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.createdAt = createdAt
        self.conversation = conversation
    }
    
    /// Convert to app's Message type
    func toMessage() -> Message {
        let mappedRole: MessageRole
        switch role {
        case "user":
            mappedRole = .user
        case "system":
            mappedRole = .system
        case "assistant": fallthrough
        default:
            mappedRole = .assistant
        }
        return Message(
            id: id,
            content: content,
            role: mappedRole,
            timestamp: createdAt
        )
    }
    
    /// Create from app's Message type
    static func from(_ message: Message) -> MessageModel {
        MessageModel(
            id: message.id,
            content: message.content,
            role: message.role.rawValue,
            createdAt: message.timestamp
        )
    }
}

