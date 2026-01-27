//
//  Conversation.swift
//  Rube-ios
//
//  Conversation model for chat history
//

import Foundation

struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    let title: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)

        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        createdAt = formatter.date(from: createdAtString) ?? Date()
        updatedAt = formatter.date(from: updatedAtString) ?? Date()
    }

    init(id: String, title: String?, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ConversationsResponse: Codable {
    let conversations: [Conversation]
}

struct APIMessage: Codable {
    let id: String
    let content: String
    let role: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case role
        case createdAt = "created_at"
    }
}

struct MessagesResponse: Codable {
    let messages: [APIMessage]
}
