//
//  ChatService.swift
//  Rube-ios
//
//  Chat streaming service using SSE
//

import Foundation

enum ChatError: LocalizedError {
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        case .serverError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

@Observable
final class ChatService {
    private var streamTask: Task<Void, Never>?

    private(set) var isStreaming = false
    private(set) var streamingContent = ""
    private(set) var streamingToolCalls: [ToolCall] = []
    private(set) var pendingConnectionRequest: ConnectionRequest?

    // MARK: - Connection Request Callback

    var onConnectionRequest: ((ConnectionRequest) -> Void)?

    // MARK: - Send Message with Streaming

    func sendMessage(
        _ content: String,
        messages: [Message],
        conversationId: String?,
        onNewConversationId: @escaping (String) -> Void
    ) async throws -> Message {
        // Try sending with auto-retry on 401
        return try await sendMessageWithRetry(
            content,
            messages: messages,
            conversationId: conversationId,
            onNewConversationId: onNewConversationId,
            isRetry: false
        )
    }

    private func sendMessageWithRetry(
        _ content: String,
        messages: [Message],
        conversationId: String?,
        onNewConversationId: @escaping (String) -> Void,
        isRetry: Bool
    ) async throws -> Message {
        guard let token = AuthService.shared.jwt else {
            throw ChatError.unauthorized
        }

        await MainActor.run {
            self.isStreaming = true
            self.streamingContent = ""
            self.streamingToolCalls = []
        }

        defer {
            Task { @MainActor in
                self.isStreaming = false
            }
        }

        // Build request
        var request = URLRequest(url: Config.chatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Build messages array for API
        let apiMessages = messages.map { msg -> [String: String] in
            ["role": msg.role.rawValue, "content": msg.content]
        }

        var body: [String: Any] = ["messages": apiMessages]
        if let conversationId = conversationId {
            body["conversationId"] = conversationId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Start streaming request
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        // Handle 401 - refresh JWT and retry once
        if httpResponse.statusCode == 401 && !isRetry {
            try await AuthService.shared.refreshJWT()
            return try await sendMessageWithRetry(
                content,
                messages: messages,
                conversationId: conversationId,
                onNewConversationId: onNewConversationId,
                isRetry: true
            )
        }

        // Check for new conversation ID in header
        if let newId = httpResponse.value(forHTTPHeaderField: "X-Conversation-Id") {
            await MainActor.run {
                onNewConversationId(newId)
            }
        }

        guard httpResponse.statusCode == 200 else {
            throw ChatError.httpError(httpResponse.statusCode)
        }

        // Parse SSE stream
        var fullContent = ""
        var toolCalls: [String: ToolCall] = [:]
        var buffer = ""

        for try await byte in bytes {
            buffer.append(Character(UnicodeScalar(byte)))

            // Process complete lines
            while let newlineIndex = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<newlineIndex])
                buffer = String(buffer[buffer.index(after: newlineIndex)...])

                guard let event = SSEParser.parse(line: line) else { continue }

                switch event {
                case .textDelta(let delta):
                    fullContent += delta
                    await MainActor.run {
                        self.streamingContent = fullContent
                    }

                case .toolInputStart(let id, let name):
                    let toolCall = ToolCall(id: id, name: name, status: .running)
                    toolCalls[id] = toolCall
                    await MainActor.run {
                        self.streamingToolCalls = Array(toolCalls.values)
                    }

                case .toolInputAvailable(let id, let input):
                    toolCalls[id]?.input = input
                    await MainActor.run {
                        self.streamingToolCalls = Array(toolCalls.values)
                    }

                case .toolOutputAvailable(let id, let output):
                    toolCalls[id]?.output = output
                    toolCalls[id]?.status = .completed
                    await MainActor.run {
                        self.streamingToolCalls = Array(toolCalls.values)
                    }

                case .connectionRequest(let request):
                    // Handle connection request
                    await MainActor.run {
                        self.pendingConnectionRequest = request
                        self.onConnectionRequest?(request)
                    }

                case .done:
                    break

                case .error(let message):
                    throw ChatError.serverError(message)
                }
            }
        }

        return Message(
            id: UUID().uuidString,
            content: fullContent.isEmpty ? "Sorry, I could not process your request." : fullContent,
            role: .assistant,
            toolCalls: Array(toolCalls.values)
        )
    }

    // MARK: - Cancel Stream

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        streamingContent = ""
        streamingToolCalls = []
    }
}
