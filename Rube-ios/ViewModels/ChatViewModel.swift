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
    var pendingUserInputRequest: UserInputRequest? { nativeChatService.pendingUserInputRequest }

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

            // Save conversation to AppWrite with memory
            currentConversationId = await conversationService.saveConversation(
                id: currentConversationId,
                messages: messages,
                memory: nativeChatService.getSerializedMemory()
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
            
            // Mark the last user message as failed
            if let lastMessage = messages.last, lastMessage.role == .user {
                messages.removeLast()
                var failedMessage = lastMessage
                failedMessage.isFailed = true
                failedMessage.failureReason = friendlyMessage
                messages.append(failedMessage)
            }
        }

        isLoading = false
        print("[ChatViewModel] ✅ Send message complete")
    }
    
    // MARK: - Retry Failed Message
    
    @MainActor
    func retryMessage(_ message: Message) async {
        guard message.isFailed else { return }
        
        // Remove the failed message
        messages.removeAll { $0.id == message.id }
        
        // Re-send with original content
        inputText = message.content
        if let attachments = message.attachments {
            pendingAttachments = attachments
        }
        await sendMessage()
    }

    // MARK: - Load Conversation

    @MainActor
    func loadConversation(_ id: String) async {
        currentConversationId = id
        conversationService.clearMessageCache()
        messages = await conversationService.getMessages(conversationId: id)
        
        // Load memory if available
        if let conversation = conversations.first(where: { $0.id == id }),
           let memoryData = conversation.memoryData {
            nativeChatService.loadMemory(from: memoryData)
        } else {
            nativeChatService.clearMemory()
        }
        
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
        nativeChatService.clearMemory()
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
    
    // MARK: - User Input Handling (REQUEST_USER_INPUT tool)
    
    @MainActor
    func handleUserInputSubmission(_ response: UserInputResponse) async {
        // Format the response as a user message
        let responseText = nativeChatService.handleUserInputResponse(response)
        
        // Add the response to the conversation
        let userMessage = Message(
            content: responseText,
            role: .user
        )
        messages.append(userMessage)
        
        // Continue the conversation with the user's input
        do {
            let assistantResponse = try await nativeChatService.sendMessage(
                responseText,
                messages: messages,
                conversationId: currentConversationId,
                onNewConversationId: { [weak self] newId in
                    self?.currentConversationId = newId
                }
            )
            messages.append(assistantResponse)
            
            // Save conversation with memory
            currentConversationId = await conversationService.saveConversation(
                id: currentConversationId,
                messages: messages,
                memory: nativeChatService.getSerializedMemory()
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func dismissUserInputRequest() {
        nativeChatService.clearPendingUserInputRequest()
        
        // Optionally add a message indicating the user cancelled
        let cancelMessage = Message(
            content: "Connection cancelled.",
            role: .assistant
        )
        messages.append(cancelMessage)
    }
}
