//
//  ConversationService.swift
//  Rube-ios
//
//  Service for conversation history operations
//

import Foundation

@Observable
final class ConversationService {
    private(set) var conversations: [Conversation] = []
    private(set) var isLoading = false

    // MARK: - Load Conversations

    func loadConversations() async {
        guard AuthService.shared.jwt != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await AuthService.shared.performRequestWithAutoRefresh { jwt in
                var request = URLRequest(url: Config.conversationsURL)
                request.httpMethod = "GET"
                request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "ConversationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }

                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "ConversationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to load conversations"])
                }

                let decoder = JSONDecoder()
                let decoded = try decoder.decode(ConversationsResponse.self, from: data)
                return (decoded.conversations, httpResponse)
            }

            await MainActor.run {
                self.conversations = result
            }
        } catch {
            print("Error loading conversations: \(error)")
        }
    }

    // MARK: - Load Messages for Conversation

    func getMessages(conversationId: String) async -> [Message] {
        guard AuthService.shared.jwt != nil else { return [] }

        let url = Config.conversationsURL
            .appendingPathComponent(conversationId)
            .appendingPathComponent("messages")

        do {
            let result = try await AuthService.shared.performRequestWithAutoRefresh { jwt in
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "ConversationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }

                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "ConversationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to load messages"])
                }

                let decoder = JSONDecoder()
                let decoded = try decoder.decode(MessagesResponse.self, from: data)

                let messages = decoded.messages.map { apiMessage in
                    let role: MessageRole = apiMessage.role == "user" ? .user : .assistant
                    return Message(
                        id: apiMessage.id,
                        content: apiMessage.content,
                        role: role
                    )
                }

                return (messages, httpResponse)
            }

            return result
        } catch {
            print("Error loading messages: \(error)")
            return []
        }
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ id: String) async -> Bool {
        guard let token = AuthService.shared.jwt else { return false }

        let url = Config.conversationsURL.appendingPathComponent(id)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            // Remove from local list
            await MainActor.run {
                self.conversations.removeAll { $0.id == id }
            }

            return true
        } catch {
            print("Error deleting conversation: \(error)")
            return false
        }
    }
}
