//
//  AppwriteConversationService.swift
//  Rube-ios
//
//  Appwrite-based conversation persistence with cloud storage
//

import Foundation
import Appwrite

@Observable
final class AppwriteConversationService {

    private(set) var conversations: [ConversationModel] = []
    private(set) var isLoading = false
    private var savedMessageIds: Set<String> = [] // Track saved messages to avoid duplicate queries

    private var userId: String? {
        AuthService.shared.userEmail
    }
    
    // Realtime subscriptions
    private var messageSubscription: RealtimeSubscription?
    private var conversationSubscription: RealtimeSubscription?

    // MARK: - Realtime Subscriptions
    
    @MainActor
    func subscribeToMessages(conversationId: String, onNewMessage: @escaping (Message) -> Void) {
        // Stop previous subscription if any
        Task { try? await messageSubscription?.close() }

        let channel = "databases.\(AppwriteDatabase.databaseId).collections.\(AppwriteDatabase.messagesCollection).documents"

        Task {
            messageSubscription = try? await realtime.subscribe(channels: [channel]) { response in
            // Filter events locally for this conversation
            guard let events = response.events,
                  events.contains(where: { $0.contains("create") }),
                  let payload = response.payload else { return }
            
            // Check if message belongs to current conversation
            if let msgConvId = payload["conversationId"] as? String,
               msgConvId == conversationId,
               let id = payload["$id"] as? String,
               !self.savedMessageIds.contains(id) {
                
                // Parse message
                let content = payload["content"] as? String ?? ""
                let roleStr = payload["role"] as? String ?? "assistant"
                let role = MessageRole(rawValue: roleStr) ?? .assistant
                let timestampStr = payload["createdAt"] as? String
                let timestamp = self.parseDate(timestampStr) ?? Date()
                let toolCalls = self.decodeToolCalls(payload["toolCalls"] as? String)
                let attachments = self.decodeAttachments(payload["attachments"] as? String)
                
                let message = Message(
                    id: id,
                    content: content,
                    role: role,
                    timestamp: timestamp,
                    toolCalls: toolCalls,
                    attachments: attachments
                )
                
                self.savedMessageIds.insert(id)
                
                Task { @MainActor in
                    onNewMessage(message)
                }
            }
            }
        }
    }
    
    @MainActor
    func subscribeToConversations() {
        Task { try? await conversationSubscription?.close() }

        guard let userId = userId else { return }

        let channel = "databases.\(AppwriteDatabase.databaseId).collections.\(AppwriteDatabase.conversationsCollection).documents"

        Task {
            conversationSubscription = try? await realtime.subscribe(channels: [channel]) { response in
            guard let events = response.events,
                  let payload = response.payload else { return }

            // Filter by userId
            if let docUserId = payload["userId"] as? String, docUserId == userId {
                Task { @MainActor in
                    await self.loadConversations()
                }
            }
            }
        }
    }
    
    func unsubscribe() {
        Task {
            try? await messageSubscription?.close()
            try? await conversationSubscription?.close()
        }
        messageSubscription = nil
        conversationSubscription = nil
    }
    
    /// Clears the message cache when switching conversations
    func clearMessageCache() {
        savedMessageIds.removeAll()
    }

    // MARK: - Load Conversations

    @MainActor
    func loadConversations() async {
        guard let userId = userId else {
            print("[AppwriteConversationService] No user logged in")
            conversations = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await databases.listDocuments(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.conversationsCollection,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.orderDesc("updatedAt"),
                    Query.limit(50)
                ]
            )

            conversations = result.documents.compactMap { doc -> ConversationModel? in
                guard let id = doc.data["$id"]?.value as? String,
                      let title = doc.data["title"]?.value as? String else {
                    return nil
                }

                let createdAt = parseDate(doc.data["createdAt"]?.value as? String) ?? Date()
                let updatedAt = parseDate(doc.data["updatedAt"]?.value as? String) ?? Date()

                return ConversationModel(
                    id: id,
                    title: title,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }

            print("[AppwriteConversationService] Loaded \(conversations.count) conversations")
        } catch {
            print("[AppwriteConversationService] Error loading conversations: \(error)")
            conversations = []
        }
    }

    @MainActor
    func searchConversations(query: String) async {
        guard let userId = userId, !query.isEmpty else {
            await loadConversations()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await databases.listDocuments(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.conversationsCollection,
                queries: [
                    Query.equal("userId", value: userId),
                    Query.search("title", value: query),
                    Query.orderDesc("updatedAt"),
                    Query.limit(20)
                ]
            )

            conversations = result.documents.compactMap { doc -> ConversationModel? in
                guard let id = doc.data["$id"]?.value as? String,
                      let title = doc.data["title"]?.value as? String else {
                    return nil
                }

                let createdAt = parseDate(doc.data["createdAt"]?.value as? String) ?? Date()
                let updatedAt = parseDate(doc.data["updatedAt"]?.value as? String) ?? Date()

                return ConversationModel(
                    id: id,
                    title: title,
                    createdAt: createdAt,
                    updatedAt: updatedAt
                )
            }
        } catch {
            print("[AppwriteConversationService] Search error: \(error)")
        }
    }

    // MARK: - Get Messages for Conversation

    @MainActor
    func getMessages(conversationId: String, cursorBeforeId: String? = nil) async -> [Message] {
        do {
            var queries = [
                Query.equal("conversationId", value: conversationId),
                Query.orderAsc("createdAt"),
                Query.limit(20)
            ]
            
            // cursorBefore gets messages BEFORE this ID (older messages)
            if let cursorBeforeId = cursorBeforeId {
                queries.append(Query.cursorBefore(cursorBeforeId))
            }
            
            let result = try await databases.listDocuments(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.messagesCollection,
                queries: queries
            )

            let messages = result.documents.compactMap { doc -> Message? in
                guard let id = doc.data["$id"]?.value as? String,
                      let content = doc.data["content"]?.value as? String,
                      let roleStr = doc.data["role"]?.value as? String else {
                    return nil
                }

                let role = MessageRole(rawValue: roleStr) ?? .assistant
                let timestamp = parseDate(doc.data["createdAt"]?.value as? String) ?? Date()
                let toolCalls = decodeToolCalls(doc.data["toolCalls"]?.value as? String)
                let attachments = decodeAttachments(doc.data["attachments"]?.value as? String)

                // Track that we've loaded this message
                savedMessageIds.insert(id)

                return Message(
                    id: id,
                    content: content,
                    role: role,
                    timestamp: timestamp,
                    toolCalls: toolCalls,
                    attachments: attachments
                )
            }

            print("[AppwriteConversationService] Loaded \(messages.count) messages for conversation \(conversationId)")
            return messages
        } catch {
            print("[AppwriteConversationService] Error loading messages: \(error)")
            return []
        }
    }

    // MARK: - Save Conversation

    @MainActor
    func saveConversation(id: String? = nil, messages: [Message]) async -> String {
        guard let userId = userId else {
            print("[AppwriteConversationService] No user logged in, cannot save")
            return id ?? UUID().uuidString
        }

        let conversationId = id ?? UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())

        do {
            // Check if conversation exists in DATABASE (not cache) to avoid race conditions
            let conversationExists = await checkConversationExists(conversationId: conversationId)

            if !conversationExists {
                // Create new conversation with proper permissions
                let firstUserMessage = messages.first(where: { $0.role == .user })?.content ?? "New Chat"
                let title = ConversationModel.generateTitle(from: firstUserMessage)

                _ = try await databases.createDocument(
                    databaseId: AppwriteDatabase.databaseId,
                    collectionId: AppwriteDatabase.conversationsCollection,
                    documentId: conversationId,
                    data: [
                        "userId": userId,
                        "title": title,
                        "createdAt": now,
                        "updatedAt": now
                    ],
                    permissions: [
                        Permission.read(Role.user(userId)),
                        Permission.update(Role.user(userId)),
                        Permission.delete(Role.user(userId))
                    ]
                )

                print("[AppwriteConversationService] Created conversation: \(conversationId)")
            } else {
                // Update existing conversation timestamp
                _ = try await databases.updateDocument(
                    databaseId: AppwriteDatabase.databaseId,
                    collectionId: AppwriteDatabase.conversationsCollection,
                    documentId: conversationId,
                    data: ["updatedAt": now]
                )
            }

            // Save new messages efficiently using local tracking
            let newMessages = messages.filter { !savedMessageIds.contains($0.id) }

            for message in newMessages {
                do {
                    _ = try await databases.createDocument(
                        databaseId: AppwriteDatabase.databaseId,
                        collectionId: AppwriteDatabase.messagesCollection,
                        documentId: message.id,
                        data: [
                            "conversationId": conversationId,
                            "content": message.content,
                            "role": message.role.rawValue,
                            "createdAt": ISO8601DateFormatter().string(from: message.timestamp),
                            "toolCalls": encodeToolCalls(message.toolCalls),
                            "attachments": encodeAttachments(message.attachments)
                        ],
                        permissions: [
                            Permission.read(Role.user(userId)),
                            Permission.update(Role.user(userId)),
                            Permission.delete(Role.user(userId))
                        ]
                    )
                    savedMessageIds.insert(message.id)
                } catch {
                    // If document already exists, just track it
                    if error.localizedDescription.contains("already exists") || error.localizedDescription.contains("409") {
                        savedMessageIds.insert(message.id)
                    } else {
                        throw error
                    }
                }
            }

            print("[AppwriteConversationService] Saved \(newMessages.count) new messages")

            // Update cache efficiently - only update if this conversation isn't in cache
            if !conversations.contains(where: { $0.id == conversationId }) {
                await loadConversations()
            } else {
                // Just update the timestamp locally
                if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                    conversations[index] = ConversationModel(
                        id: conversationId,
                        title: conversations[index].title,
                        createdAt: conversations[index].createdAt,
                        updatedAt: Date()
                    )
                }
            }

        } catch {
            print("[AppwriteConversationService] Error saving conversation: \(error)")
        }

        return conversationId
    }

    // MARK: - Delete Conversation

    @MainActor
    func deleteConversation(_ id: String) async -> Bool {
        do {
            // Delete all messages first
            let messagesResult = try await databases.listDocuments(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.messagesCollection,
                queries: [Query.equal("conversationId", value: id)]
            )

            for doc in messagesResult.documents {
                if let docId = doc.data["$id"]?.value as? String {
                    _ = try await databases.deleteDocument(
                        databaseId: AppwriteDatabase.databaseId,
                        collectionId: AppwriteDatabase.messagesCollection,
                        documentId: docId
                    )
                }
            }

            // Delete conversation
            _ = try await databases.deleteDocument(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.conversationsCollection,
                documentId: id
            )

            conversations.removeAll { $0.id == id }
            print("[AppwriteConversationService] Deleted conversation: \(id)")
            return true
        } catch {
            print("[AppwriteConversationService] Error deleting conversation: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    private func checkConversationExists(conversationId: String) async -> Bool {
        do {
            _ = try await databases.getDocument(
                databaseId: AppwriteDatabase.databaseId,
                collectionId: AppwriteDatabase.conversationsCollection,
                documentId: conversationId
            )
            return true
        } catch {
            return false
        }
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string = string else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    // MARK: - ToolCalls Encoding/Decoding

    private func encodeToolCalls(_ toolCalls: [ToolCall]?) -> String {
        guard let toolCalls = toolCalls, !toolCalls.isEmpty else {
            return "[]"
        }

        // Convert to simple dictionary format that can be JSON encoded
        let simpleArray = toolCalls.map { call -> [String: Any] in
            return [
                "id": call.id,
                "name": call.name,
                "status": statusToString(call.status)
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: simpleArray),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }

        return jsonString
    }

    private func decodeToolCalls(_ jsonString: String?) -> [ToolCall]? {
        guard let jsonString = jsonString,
              jsonString != "[]",
              let jsonData = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }

        let toolCalls = array.compactMap { dict -> ToolCall? in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let statusStr = dict["status"] as? String else {
                return nil
            }

            return ToolCall(
                id: id,
                name: name,
                input: [:],
                output: nil,
                status: stringToStatus(statusStr)
            )
        }

        return toolCalls.isEmpty ? nil : toolCalls
    }

    private func statusToString(_ status: ToolCallStatus) -> String {
        switch status {
        case .running: return "running"
        case .completed: return "completed"
        case .error: return "error"
        }
    }

    private func stringToStatus(_ string: String) -> ToolCallStatus {
        switch string {
        case "running": return .running
        case "completed": return .completed
        case "error": return .error
        default: return .completed
        }
    }

    // MARK: - Attachments Encoding/Decoding

    private func encodeAttachments(_ attachments: [Attachment]?) -> String {
        guard let attachments = attachments, !attachments.isEmpty else {
            return "[]"
        }

        guard let jsonData = try? JSONEncoder().encode(attachments),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }

        return jsonString
    }

    private func decodeAttachments(_ jsonString: String?) -> [Attachment]? {
        guard let jsonString = jsonString,
              jsonString != "[]",
              let jsonData = jsonString.data(using: .utf8),
              let attachments = try? JSONDecoder().decode([Attachment].self, from: jsonData) else {
            return nil
        }

        return attachments.isEmpty ? nil : attachments
    }
}
