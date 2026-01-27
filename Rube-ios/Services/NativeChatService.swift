import Foundation
import SwiftOpenAI
import OSLog
// Import SDK types specifically to avoid module-name collision with 'Composio' class
import struct Composio.AnyCodable
import struct Composio.Tool
import struct Composio.ToolParameters
import struct Composio.ToolRouterSession
import struct Composio.ToolRouterExecuteResponse
import struct Composio.ToolRouterLinkResponse

// MARK: - Custom Errors

enum NativeChatError: LocalizedError {
    case toolFetchFailed(Error)
    case apiError(Error)
    case invalidResponse
    case toolExecutionFailed(String, Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .toolFetchFailed(let error):
            return "Failed to fetch tools: \(error.localizedDescription)"
        case .apiError(let error):
            return "API Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from API"
        case .toolExecutionFailed(let toolName, let error):
            return "Failed to execute tool '\(toolName)': \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@Observable
@MainActor
final class NativeChatService {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.rube.ios", category: "NativeChatService")
    
    // MARK: - Properties

    private let openAI: OpenAIStreamService
    private let composioManager: ComposioManagerProtocol
    private let oauthService: OAuthService
    
    private(set) var isStreaming = false
    private(set) var streamingContent = ""
    private(set) var streamingToolCalls: [ToolCall] = []
    
    // Memory storage as prescribed by Rube system prompt
    private var currentMemory: [String: [String]] = [:]
    
    // Pending user input request from REQUEST_USER_INPUT tool
    private(set) var pendingUserInputRequest: UserInputRequest?
    
    // MARK: - Initialization
    
    init(
        openAI: OpenAIStreamService? = nil,
        composioManager: ComposioManagerProtocol? = nil,
        oauthService: OAuthService? = nil
    ) {
        self.composioManager = composioManager ?? ComposioManager.shared
        if let openAI = openAI {
            self.openAI = openAI
        } else {
            let service = OpenAIServiceFactory.service(
                apiKey: ComposioConfig.openAIKey,
                overrideBaseURL: ComposioConfig.openAIBaseURL,
                debugEnabled: true
            )
            self.openAI = OpenAIServiceWrapper(service: service)
        }
        self.oauthService = oauthService ?? OAuthService()
    }

    func fetchModels() async throws -> [String] {
        try await openAI.listModels()
    }
    
    func sendMessage(
        _ content: String,
        messages: [Message],
        conversationId: String?,
        onNewConversationId: @escaping (String) -> Void
    ) async throws -> Message {
        await MainActor.run {
            self.isStreaming = true
            self.streamingContent = ""
            self.streamingToolCalls = []
        }
        defer { self.isStreaming = false }

        let userId = AuthService.shared.userEmail ?? "default_user"
        let effectiveConversationId = conversationId ?? "default_conversation"
        let session = try await composioManager.getSession(for: userId, conversationId: effectiveConversationId)
        let sessionId = session.sessionId

        // Skip fetching tools from API (causes "resource exceeds maximum size" error with 500+ tools)
        // Instead, manually define meta-tools for OpenAI function calling
        let openAITools = createMetaToolSchemas()

        // Dynamic context
        let timezone = TimeZone.current.identifier
        let currentTime = Date().formatted(date: .abbreviated, time: .shortened)
        let executionMode = ExecutionModeSettings.shared.currentMode

        // Generate system prompt from external configuration
        let systemPrompt = SystemPromptConfig.generatePrompt(
            timezone: timezone,
            currentTime: currentTime,
            executionMode: executionMode
        )

        var chatMessages: [ChatCompletionParameters.Message] = [.init(role: .system, content: .text(systemPrompt))]
        
        // Accurate History Mapping
        chatMessages.append(contentsOf: messages.compactMap { msg in
            switch msg.role {
            case .user: 
                return .init(role: .user, content: .text(msg.content))
            case .assistant: 
                let openaiToolCalls = msg.toolCalls?.map { tc in
                    let argsString = (try? JSONSerialization.data(withJSONObject: tc.input)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    return SwiftOpenAI.ToolCall(id: tc.id, function: .init(arguments: argsString, name: tc.name))
                }
                return .init(role: .assistant, content: .text(msg.content), toolCalls: openaiToolCalls)
            case .system: 
                return .init(role: .system, content: .text(msg.content))
            case .tool:
                return .init(role: .tool, content: .text(msg.content), toolCallID: msg.toolCallID ?? "")
            }
        })
        
        if messages.last?.content != content || messages.last?.role != .user {
            chatMessages.append(.init(role: .user, content: .text(content)))
        }
        
        var currentTools = openAITools
        return try await runChatLoop(messages: &chatMessages, tools: &currentTools, sessionId: sessionId)
    }
    
    private func runChatLoop(
        messages: inout [ChatCompletionParameters.Message],
        tools: inout [ChatCompletionParameters.Tool],
        sessionId: String,
        depth: Int = 0
    ) async throws -> Message {
        guard depth < 10 else { return Message(content: "Error: Tool depth exceeded.", role: .assistant) }

        let parameters = ChatCompletionParameters(
            messages: messages,
            model: .custom(ComposioConfig.llmModel),
            tools: tools.isEmpty ? nil : tools
        )

        var fullContent = ""
        let accumulator = ToolCallAccumulator()
        var hasToolCalls = false

        let stream = try await executeWithRetry { try await self.openAI.startStreamedChat(parameters: parameters) }

        do {
            for try await result in stream {
                guard let choice = result.choices?.first, let delta = choice.delta else { continue }
                if let content = delta.content {
                    fullContent += content
                    self.streamingContent = fullContent
                }
                if let toolCallsDelta = delta.toolCalls {
                    hasToolCalls = true
                    for call in toolCallsDelta {
                        accumulator.add(ToolCallPart(index: call.index ?? 0, id: call.id, name: call.function.name, argumentsPart: call.function.arguments))
                    }
                }
            }
        } catch { throw NativeChatError.apiError(error) }
        
        if hasToolCalls {
            let finalizedCalls = accumulator.finalize()
            let assistantToolCalls = finalizedCalls.map { call in
                let argsString = (try? JSONEncoder().encode(call.arguments)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return SwiftOpenAI.ToolCall(id: call.id, function: .init(arguments: argsString, name: call.name))
            }
            messages.append(.init(role: .assistant, content: .text(fullContent), toolCalls: assistantToolCalls))
            
            for call in finalizedCalls {
                self.streamingToolCalls.append(ToolCall(id: call.id, name: call.name, status: .running))
                do {
                    // Handle REQUEST_USER_INPUT specially - this pauses the chat loop for user input
                    if call.name == "REQUEST_USER_INPUT" {
                        let request = UserInputRequest(from: call.arguments.dictionary)
                        self.pendingUserInputRequest = request
                        
                        // Update tool call status
                        if let index = self.streamingToolCalls.firstIndex(where: { $0.id == call.id }) {
                            self.streamingToolCalls[index].status = .completed
                            self.streamingToolCalls[index].output = ["status": "waiting_for_user_input", "provider": request.provider]
                        }
                        
                        // Return early with a message indicating we need user input
                        return Message(
                            id: UUID().uuidString,
                            content: "I need some additional information to connect to \(request.provider.capitalized). Please fill in the required fields.",
                            role: .assistant,
                            toolCalls: self.streamingToolCalls
                        )
                    }
                    
                    // Inject memory for MULTI_EXECUTE
                    var toolArgs = call.arguments.dictionary
                    if call.name.hasSuffix("MULTI_EXECUTE_TOOL") {
                        toolArgs["memory"] = currentMemory
                    }

                    let result: ToolRouterExecuteResponse
                    if call.name.hasPrefix("COMPOSIO_") {
                        result = try await composioManager.executeMetaTool(call.name, sessionId: sessionId, arguments: toolArgs)
                    } else {
                        result = try await composioManager.executeSessionTool(call.name, sessionId: sessionId, arguments: toolArgs)
                    }

                    if let index = self.streamingToolCalls.firstIndex(where: { $0.id == call.id }) {
                        self.streamingToolCalls[index].status = .completed
                        self.streamingToolCalls[index].output = result.data.mapValues { $0.value }
                        
                        // Capture memory updates from Search or Multi-Execute
                        if let updatedMemory = result.data["memory"]?.value as? [String: [String]] {
                            for (app, entries) in updatedMemory {
                                var current = currentMemory[app] ?? []
                                current.append(contentsOf: entries)
                                currentMemory[app] = Array(Set(current)) // De-duplicate
                            }
                        }
                    }

                    // Discover tools
                    if let schemas = result.data["tool_schemas"]?.value as? [String: Any] {
                        for (slug, schemaWrapper) in schemas {
                            if !tools.contains(where: { $0.function.name == slug }), let toolDict = schemaWrapper as? [String: Any] {
                                let desc = toolDict["description"] as? String ?? ""
                                let params = toolDict["input_parameters"] as? [String: Any] ?? [:]
                                tools.append(ChatCompletionParameters.Tool(
                                    function: .init(name: slug, strict: nil, description: desc, parameters: mapRawDictToSchema(dict: params))
                                ))
                            }
                        }
                    }

                    let resultString = (try? JSONEncoder().encode(result.data)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    messages.append(.init(role: .tool, content: .text(resultString), toolCallID: call.id))
                } catch {
                    if let index = self.streamingToolCalls.firstIndex(where: { $0.id == call.id }) { self.streamingToolCalls[index].status = .error }

                    // THREE-LAYER ERROR RECOVERY (From open-rube pattern)

                    // Layer 1: Check if this is a transient error that should be retried
                    if isTransientError(error) {
                        logger.info("[NativeChatService] ⚠️ Transient error detected for \(call.name), will retry: \(error.localizedDescription)")
                        // Let the outer loop retry on transient errors
                        messages.append(.init(role: .tool, content: .text("{\"error\": \"temporary_error\", \"should_retry\": true}"), toolCallID: call.id))
                        continue
                    }

                    // Layer 2: Check if this is an authentication error that can be handled in-chat
                    if let toolkit = oauthService.detectAuthRequired(error: error) {
                        logger.info("[NativeChatService] 🔐 Detected auth error for toolkit: \(toolkit)")

                        // Try to get a Connect Link for in-chat authentication
                        do {
                            let userId = AuthService.shared.userEmail ?? "default_user"
                            let conversationId = "default_conversation" // TODO: Pass actual conversation ID

                            let connectLink = try await oauthService.getConnectLink(
                                toolkit: toolkit,
                                userId: userId,
                                conversationId: conversationId
                            )

                            // Return a message with the Connect Link instead of failing
                            let authMessage = """
                            I need you to connect your \(toolkit.capitalized) account first.

                            Please click here to authorize: [Connect \(toolkit.capitalized)](\(connectLink))

                            Once connected, I'll continue with your request.
                            """

                            messages.append(.init(role: .tool, content: .text("{\"auth_required\": \"\(toolkit)\", \"connect_link\": \"\(connectLink)\"}"), toolCallID: call.id))

                            let connectMessage = Message(
                                id: UUID().uuidString,
                                content: authMessage,
                                role: .assistant
                            )
                            return connectMessage

                        } catch {
                            logger.error("[NativeChatService] ❌ Failed to get Connect Link: \(error)")
                            // Fall back to Layer 3 (graceful degradation)
                            messages.append(.init(role: .tool, content: .text("{\"error\": \"\(error.localizedDescription)\"}"), toolCallID: call.id))
                        }
                    } else {
                        // Layer 3: Graceful degradation for non-recoverable errors
                        let userFriendlyError = generateUserFriendlyErrorMessage(error: error, toolName: call.name)
                        logger.error("[NativeChatService] ❌ Tool execution failed: \(userFriendlyError)")
                        messages.append(.init(role: .tool, content: .text("{\"error\": \"\(userFriendlyError)\"}"), toolCallID: call.id))
                    }
            }
            var nextTools = tools
            return try await runChatLoop(messages: &messages, tools: &nextTools, sessionId: sessionId, depth: depth + 1)
        } else {
            return Message(id: UUID().uuidString, content: fullContent.isEmpty ? "No response." : fullContent, role: .assistant)
        }
    }
    
    private func mapRawDictToSchema(dict: [String: Any]) -> JSONSchema {
        let properties = dict["properties"] as? [String: [String: Any]] ?? [:]
        var schemaProperties: [String: JSONSchema] = [:]
        for (key, propDict) in properties { schemaProperties[key] = mapRawProperty(propDict) }
        return JSONSchema(type: .object, description: dict["description"] as? String, properties: schemaProperties.isEmpty ? nil : schemaProperties, required: dict["required"] as? [String], additionalProperties: false)
    }

    private func mapRawProperty(_ dict: [String: Any]) -> JSONSchema {
        let typeStr = dict["type"] as? String ?? "string"
        let type: JSONSchemaType
        switch typeStr.lowercased() {
        case "string": type = .string
        case "number": type = .number
        case "integer": type = .integer
        case "boolean": type = .boolean
        case "array": type = .array
        case "object": type = .object
        default: type = .string
        }
        var nestedProperties: [String: JSONSchema]? = nil
        if type == .object, let propsDict = dict["properties"] as? [String: [String: Any]] {
            var mapped: [String: JSONSchema] = [:]
            for (k, v) in propsDict { mapped[k] = mapRawProperty(v) }
            nestedProperties = mapped
        }
        var items: JSONSchema? = nil
        if type == .array, let itemDict = dict["items"] as? [String: Any] { items = mapRawProperty(itemDict) }
        return JSONSchema(type: type, description: dict["description"] as? String, properties: nestedProperties, items: items, required: dict["required"] as? [String], additionalProperties: type == .object ? false : false, enum: dict["enum"] as? [String])
    }
    
    // MARK: - User Input Handling
    
    /// Clear the pending user input request after form is dismissed or submitted
    func clearPendingUserInputRequest() {
        pendingUserInputRequest = nil
    }
    
    /// Handle user input response and continue the OAuth flow
    /// - Parameter response: The user's input response
    /// - Returns: A formatted string to inject into the conversation
    func handleUserInputResponse(_ response: UserInputResponse) -> String {
        clearPendingUserInputRequest()
        
        // Format the response as a message the LLM can understand
        var components: [String] = []
        components.append("User provided the following information for \(response.provider):")
        for (field, value) in response.values {
            components.append("- \(field): \(value)")
        }
        if let authConfigId = response.authConfigId {
            components.append("Auth config ID: \(authConfigId)")
        }
        
        return components.joined(separator: "\n")
    }
    
    // MARK: - Memory Persistence
    
    /// Get serialized memory for persistence
    func getSerializedMemory() -> Data? {
        try? JSONEncoder().encode(currentMemory)
    }
    
    /// Load memory from persisted data
    func loadMemory(from data: Data) {
        if let memory = try? JSONDecoder().decode([String: [String]].self, from: data) {
            currentMemory = memory
            logger.info("[NativeChatService] 📦 Loaded \(memory.count) memory entries")
        }
    }
    
    /// Clear all memory
    func clearMemory() {
        currentMemory = [:]
        logger.info("[NativeChatService] 🧹 Memory cleared")
    }

    private func executeWithRetry<T>(maxAttempts: Int = 3, operation: @MainActor () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do { return try await operation() }
            catch {
                lastError = error
                if attempt < maxAttempts { try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)) }
            }
        }
        throw lastError ?? NativeChatError.invalidResponse
    }

    // MARK: - Error Handling (Three-Layer Recovery Pattern)

    /// Determines if an error is transient and should be automatically retried
    /// Transient errors: network timeouts, temporary service unavailability, rate limits
    private func isTransientError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Check for common transient error patterns
        return errorString.contains("timeout") ||
               errorString.contains("temporary") ||
               errorString.contains("rate limit") ||
               errorString.contains("service unavailable") ||
               errorString.contains("connection reset") ||
               errorString.contains("network") && errorString.contains("error")
    }

    /// Generates a user-friendly error message based on error type
    /// Used for Layer 3 (graceful degradation) error handling
    private func generateUserFriendlyErrorMessage(error: Error, toolName: String) -> String {
        let errorString = error.localizedDescription.lowercased()
        let toolDisplay = toolName.replacingOccurrences(of: "_", with: " ").lowercased()

        // Categorize and provide actionable error messages
        if errorString.contains("timeout") {
            return "The tool \(toolDisplay) is taking too long to respond. Please try again in a moment."
        } else if errorString.contains("rate limit") {
            return "Too many requests to \(toolDisplay). Please wait a moment before trying again."
        } else if errorString.contains("connection") || errorString.contains("network") {
            return "Network connection error while using \(toolDisplay). Please check your internet connection and try again."
        } else if errorString.contains("unauthorized") || errorString.contains("forbidden") {
            return "You don't have permission to use \(toolDisplay). Please check your credentials."
        } else if errorString.contains("not found") {
            return "The resource for \(toolDisplay) was not found. It may have been deleted."
        } else if errorString.contains("invalid") || errorString.contains("malformed") {
            return "Invalid parameters passed to \(toolDisplay). Please check your input."
        } else {
            // Generic fallback message
            return "Failed to execute \(toolDisplay) tool. Error: \(error.localizedDescription)"
        }
    }

    private func createMetaToolSchemas() -> [ChatCompletionParameters.Tool] {
        return [
            .init(
                function: .init(
                    name: "COMPOSIO_SEARCH_TOOLS",
                    strict: nil,
                    description: "Discover available tools for a use case and get execution guidance with recommended plan steps",
                    parameters: .init(
                        type: .object,
                        properties: [
                            "queries": .init(
                                type: .array,
                                description: "Array of use case queries to search for tools",
                                items: .init(
                                    type: .object,
                                    properties: [
                                        "use_case": .init(type: .string, description: "The use case to search for (e.g., 'send an email via gmail')")
                                    ],
                                    required: ["use_case"]
                                )
                            ),
                            "session_id": .init(type: .string, description: "Session ID from previous SEARCH_TOOLS call (use 'load' for first call)")
                        ],
                        required: ["queries"],
                        additionalProperties: false
                    )
                )
            ),
            .init(
                function: .init(
                    name: "COMPOSIO_MULTI_EXECUTE_TOOL",
                    strict: nil,
                    description: "Execute multiple tools in parallel (up to 50). Include memory parameter for context.",
                    parameters: .init(
                        type: .object,
                        properties: [
                            "tool_calls": .init(
                                type: .array,
                                description: "Array of tool calls to execute",
                                items: .init(
                                    type: .object,
                                    properties: [
                                        "tool_slug": .init(type: .string, description: "The tool slug to execute"),
                                        "arguments": .init(type: .object, description: "Tool arguments")
                                    ],
                                    required: ["tool_slug"]
                                )
                            ),
                            "memory": .init(type: .object, description: "Persistent memory context (app names as keys, arrays of strings as values)"),
                            "session_id": .init(type: .string, description: "Session ID from SEARCH_TOOLS")
                        ],
                        required: ["tool_calls"],
                        additionalProperties: false
                    )
                )
            ),
            .init(
                function: .init(
                    name: "COMPOSIO_MANAGE_CONNECTIONS",
                    strict: nil,
                    description: "Initiate OAuth connections for toolkits. Returns redirect URLs for user authentication.",
                    parameters: .init(
                        type: .object,
                        properties: [
                            "toolkits": .init(
                                type: .array,
                                description: "Array of toolkit slugs to connect (e.g., ['gmail', 'slack'])",
                                items: .init(type: .string, description: "Toolkit slug")
                            ),
                            "session_id": .init(type: .string, description: "Session ID from SEARCH_TOOLS")
                        ],
                        required: ["toolkits"],
                        additionalProperties: false
                    )
                )
            ),
            // REQUEST_USER_INPUT - for OAuth flows requiring custom parameters
            .init(
                function: .init(
                    name: "REQUEST_USER_INPUT",
                    strict: nil,
                    description: "Request custom input fields from the user BEFORE starting OAuth flow. Use ONLY when a service requires additional parameters beyond standard OAuth (e.g., Pipedrive subdomain, Salesforce instance URL). DO NOT use for standard OAuth services like Gmail, Slack, GitHub.",
                    parameters: .init(
                        type: .object,
                        properties: [
                            "provider": .init(type: .string, description: "Name of the service provider (e.g., 'pipedrive', 'salesforce')"),
                            "fields": .init(
                                type: .array,
                                description: "List of input fields to request from the user",
                                items: .init(
                                    type: .object,
                                    properties: [
                                        "name": .init(type: .string, description: "Field identifier (e.g., 'subdomain')"),
                                        "label": .init(type: .string, description: "User-friendly label (e.g., 'Company Subdomain')"),
                                        "type": .init(type: .string, description: "Input type: 'text', 'url', 'email', 'password', 'number'"),
                                        "required": .init(type: .boolean, description: "Whether this field is required"),
                                        "placeholder": .init(type: .string, description: "Placeholder text for the input")
                                    ],
                                    required: ["name", "label"]
                                )
                            ),
                            "authConfigId": .init(type: .string, description: "Auth config ID to use after collecting inputs"),
                            "logoUrl": .init(type: .string, description: "URL to provider logo for display")
                        ],
                        required: ["provider", "fields"],
                        additionalProperties: false
                    )
                )
            )
        ]
    }
}

extension [String: AnyCodable] {
    var dictionary: [String: Any] { self.mapValues { $0.value } }
}

extension ToolParameters {
    var asJSONSchema: JSONSchema {
        guard let data = try? JSONEncoder().encode(self), let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return JSONSchema(type: .object, additionalProperties: false) }
        return mapToSchema(dict: dict)
    }
    private func mapToSchema(dict: [String: Any]) -> JSONSchema {
        let properties = dict["properties"] as? [String: [String: Any]] ?? [:]
        var schemaProperties: [String: JSONSchema] = [:]
        for (key, propDict) in properties { schemaProperties[key] = mapProperty(propDict) }
        return JSONSchema(type: .object, properties: schemaProperties.isEmpty ? nil : schemaProperties, required: dict["required"] as? [String], additionalProperties: false)
    }
    private func mapProperty(_ dict: [String: Any]) -> JSONSchema {
        let typeStr = dict["type"] as? String ?? "string"
        let type: JSONSchemaType
        switch typeStr.lowercased() {
        case "string": type = .string
        case "number": type = .number
        case "integer": type = .integer
        case "boolean": type = .boolean
        case "array": type = .array
        case "object": type = .object
        default: type = .string
        }
        var nestedProperties: [String: JSONSchema]? = nil
        if type == .object, let propsDict = dict["properties"] as? [String: [String: Any]] {
            var mapped: [String: JSONSchema] = [:]
            for (k, v) in propsDict { mapped[k] = mapProperty(v) }
            nestedProperties = mapped
        }
        var items: JSONSchema? = nil
        if type == .array, let itemDict = dict["items"] as? [String: Any] { items = mapProperty(itemDict) }
        return JSONSchema(type: type, description: dict["description"] as? String, properties: nestedProperties, items: items, required: dict["required"] as? [String], additionalProperties: type == .object ? false : false, enum: dict["enum"] as? [String])
    }
}
