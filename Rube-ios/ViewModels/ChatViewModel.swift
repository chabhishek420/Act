//
//  ChatViewModel.swift
//  Rube-ios
//
//  ViewModel for chat functionality
//

import Foundation

@MainActor
@Observable
final class ChatViewModel {
    private let nativeChatService = NativeChatService()
    private let oauthService = OAuthService()
    private let connectionService = ComposioConnectionService.shared
    private let conversationService = AppwriteConversationService()

    var messages: [Message] = []
    var currentConversationId: String?
    var inputText = ""
    var isLoading = false
    var errorMessage: String?

    // Connection handling
    var pendingConnectionRequest: RubeConnectionRequest?
    var showConnectionPrompt = false
    
    // Attachments
    var pendingAttachments: [Attachment] = []

    // Forwarded from Services
    var streamingContent: String { nativeChatService.streamingContent }
    var streamingToolCalls: [ToolCall] { nativeChatService.streamingToolCalls }
    var isStreaming: Bool { nativeChatService.isStreaming }

    // Conversations
    var conversations: [ConversationModel] { conversationService.conversations }
    var isLoadingConversations: Bool { conversationService.isLoading }

    init() {
        Task { @MainActor in
            await conversationService.loadConversations()
            conversationService.subscribeToConversations()
        }
    }
    
    deinit {
        conversationService.unsubscribe()
    }

    // MARK: - Send Message

    @MainActor
    func sendMessage() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isLoading else { return }

        print("[ChatViewModel] 📤 Sending message: \(content)")
        errorMessage = nil

        // Create optimistic user message
        let userMessage = Message(
            content: content,
            role: .user,
            attachments: pendingAttachments
        )
        messages.append(userMessage)
        inputText = ""
        pendingAttachments = []
        isLoading = true

        do {
            // Native mode only (backend removed)
            print("[ChatViewModel] 🚀 Calling native chat service")

            let assistantMessage = try await nativeChatService.sendMessage(
                content,
                messages: messages,
                conversationId: currentConversationId
            ) { [weak self] (newId: String) in
                print("[ChatViewModel] 🆔 New conversation ID: \(newId)")
                self?.currentConversationId = newId
            }

            print("[ChatViewModel] ✅ Received assistant message")
            messages.append(assistantMessage)

            // Save conversation to AppWrite
            currentConversationId = await conversationService.saveConversation(
                id: currentConversationId,
                messages: messages
            )
            await loadConversations()
        } catch let error as NSError {
            // Detailed error logging
            print("[ChatViewModel] ❌ Error occurred")
            print("[ChatViewModel] ❌ Domain: \(error.domain)")
            print("[ChatViewModel] ❌ Code: \(error.code)")
            print("[ChatViewModel] ❌ Description: \(error.localizedDescription)")
            print("[ChatViewModel] ❌ User Info: \(error.userInfo)")

            // User-friendly error messages
            let friendlyMessage: String
            if error.domain == "SwiftOpenAI.APIError" {
                switch error.code {
                case 1:
                    friendlyMessage = """
                    API Connection Error: Unable to reach the AI service.

                    Possible causes:
                    • The API server might be offline
                    • Network connectivity issues
                    • Invalid API endpoint configuration

                    Current endpoint: \(ComposioConfig.openAIBaseURL)

                    Please check your network connection and try again.
                    """
                case 2:
                    friendlyMessage = "Authentication failed. Please check your API key."
                case 3:
                    friendlyMessage = "Rate limit exceeded. Please wait a moment and try again."
                default:
                    friendlyMessage = "API Error (Code \(error.code)): \(error.localizedDescription)"
                }
            } else {
                friendlyMessage = error.localizedDescription
            }

            errorMessage = friendlyMessage
            messages.append(Message(
                content: "❌ \(friendlyMessage)",
                role: .assistant
            ))
        }

        isLoading = false
        print("[ChatViewModel] ✅ Send message complete")
    }

    // MARK: - Load Conversation

    @MainActor
    func loadConversation(_ id: String) async {
        currentConversationId = id
        conversationService.clearMessageCache()
        messages = await conversationService.getMessages(conversationId: id)
        
        // Subscribe to real-time message updates
        conversationService.subscribeToMessages(conversationId: id) { [weak self] newMessage in
            self?.messages.append(newMessage)
        }
    }

    @MainActor
    func loadMoreMessages() async {
        guard let conversationId = currentConversationId, !isLoading, !messages.isEmpty else { return }
        
        // For orderAsc, first message is oldest
        // To get OLDER messages, we need the messages BEFORE the first one
        let firstId = messages.first?.id
        
        let olderMessages = await conversationService.getMessages(
            conversationId: conversationId,
            cursorBeforeId: firstId
        )
        
        if !olderMessages.isEmpty {
            messages.insert(contentsOf: olderMessages, at: 0)
        }
    }

    // MARK: - Start New Chat

    @MainActor
    func startNewChat() {
        currentConversationId = nil
        messages = []
        inputText = ""
        errorMessage = nil
    }

    // MARK: - Load Conversations

    @MainActor
    func loadConversations() async {
        await conversationService.loadConversations()
    }

    @MainActor
    func searchConversations(_ query: String) async {
        await conversationService.searchConversations(query: query)
    }

    // MARK: - Delete Conversation

    @MainActor
    func deleteConversation(_ id: String) async -> Bool {
        let success = await conversationService.deleteConversation(id)

        if success && id == currentConversationId {
            startNewChat()
        }

        return success
    }
    // MARK: - Handle OAuth Connection

    @MainActor
    func connectApp(toolkit: String) async {
        do {
            let oauthUrl = try await connectionService.connectApp(toolkit: toolkit)
            _ = try await oauthService.startOAuth(url: oauthUrl)

            // OAuth succeeded - verify connection via SDK
            // We should ideally wait for the status to become ACTIVE
            // For now, assume success and notify
            
            messages.append(Message(
                content: "Successfully connected \(toolkit)!",
                role: .system
            ))

            // Close connection prompt
            showConnectionPrompt = false
            pendingConnectionRequest = nil
            
            // Reload connected accounts
            await connectionService.loadConnectedAccounts()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func connectApp(oauthUrl: String) async {
        guard let url = URL(string: oauthUrl) else {
            errorMessage = "Invalid OAuth URL"
            return
        }

        do {
            let callbackURL = try await oauthService.startOAuth(url: url)

            // OAuth succeeded - notify backend by sending a follow-up message
            messages.append(Message(
                content: "Connected successfully! Callback: \(callbackURL.absoluteString)",
                role: .system
            ))

            // Close connection prompt
            showConnectionPrompt = false
            pendingConnectionRequest = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Dismiss Connection Request

    @MainActor
    func dismissConnectionRequest() {
        showConnectionPrompt = false
        pendingConnectionRequest = nil
    }
}
