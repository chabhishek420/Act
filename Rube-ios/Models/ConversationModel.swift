//
//  ConversationModel.swift
//  Rube-ios
//
//  SwiftData model for local conversation persistence
//

import Foundation
import SwiftData

@Model
final class ConversationModel {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \MessageModel.conversation)
    var messages: [MessageModel]
    
    init(
        id: String = UUID().uuidString,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [MessageModel] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
    
    /// Generate a title from the first user message
    static func generateTitle(from firstMessage: String) -> String {
        let trimmed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 50
        
        if trimmed.count <= maxLength {
            return trimmed
        }
        
        return String(trimmed.prefix(maxLength)) + "..."
    }
}
