//
//  ChatViewModel.swift
//  Rube-ios
//
//  ViewModel for chat functionality
//

import Foundation

@Observable
final class ChatViewModel {
    private let chatService = ChatService()
    private let conversationService = ConversationService()
    private let oauthService = OAuthService()

    var messages: [Message] = []
    var currentConversationId: String?
    var inputText = ""
    var isLoading = false
    var errorMessage: String?

    // Connection handling
    var pendingConnectionRequest: ConnectionRequest?
    var showConnectionPrompt = false

    // Forwarded from ChatService
    var streamingContent: String { chatService.streamingContent }
    var streamingToolCalls: [ToolCall] { chatService.streamingToolCalls }
    var isStreaming: Bool { chatService.isStreaming }

    // Conversations
    var conversations: [Conversation] { conversationService.conversations }
    var isLoadingConversations: Bool { conversationService.isLoading }

    init() {
        // Set up connection request callback
        chatService.onConnectionRequest = { [weak self] request in
            Task { @MainActor in
                self?.pendingConnectionRequest = request
                self?.showConnectionPrompt = true
            }
        }
    }

    // MARK: - Send Message

    @MainActor
    func sendMessage() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !isLoading else { return }

        errorMessage = nil

        // Create optimistic user message
        let userMessage = Message(
            content: content,
            role: .user
        )
        messages.append(userMessage)
        inputText = ""
        isLoading = true

        do {
            let assistantMessage = try await chatService.sendMessage(
                content,
                messages: messages,
                conversationId: currentConversationId
            ) { [weak self] newId in
                self?.currentConversationId = newId
                // Reload conversations to show new one
                Task {
                    await self?.loadConversations()
                }
            }

            messages.append(assistantMessage)
        } catch {
            errorMessage = error.localizedDescription
            messages.append(Message(
                content: "Error: \(error.localizedDescription)",
                role: .assistant
            ))
        }

        isLoading = false
    }

    // MARK: - Load Conversation

    @MainActor
    func loadConversation(_ id: String) async {
        currentConversationId = id
        messages = await conversationService.getMessages(conversationId: id)
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

    func loadConversations() async {
        await conversationService.loadConversations()
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
