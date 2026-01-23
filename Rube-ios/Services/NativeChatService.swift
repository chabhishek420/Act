import Foundation
import SwiftOpenAI
import Composio
import OSLog

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
    
    private(set) var isStreaming = false
    private(set) var streamingContent = ""
    private(set) var streamingToolCalls: [ToolCall] = []
    
    // MARK: - Initialization
    
    init(
        openAI: OpenAIStreamService? = nil,
        composioManager: ComposioManagerProtocol? = nil
    ) {
        self.composioManager = composioManager ?? ComposioManager.shared
        if let openAI = openAI {
            self.openAI = openAI
        } else {
            // Base URL should NOT include /v1 - the SDK appends it automatically
            // See: https://github.com/jamesrochabrun/SwiftOpenAI README "Custom URL" section
            let service = OpenAIServiceFactory.service(
                apiKey: ComposioConfig.openAIKey,
                overrideBaseURL: ComposioConfig.openAIBaseURL,
                debugEnabled: true  // Enable debug logging to see request URLs
            )
            self.openAI = OpenAIServiceWrapper(service: service)
        }
    }

    // MARK: - Models

    func fetchModels() async throws -> [String] {
        try await openAI.listModels()
    }
    
    // MARK: - Send Message

    func sendMessage(
        _ content: String,
        messages: [Message],
        conversationId: String?,
        onNewConversationId: @escaping (String) -> Void
    ) async throws -> Message {
        logger.debug("Starting sendMessage for content: \(content, privacy: .private)")
        logger.info("Message history count: \(messages.count)")
        print("[NativeChatService] 🔑 API Key: \(ComposioConfig.openAIKey.prefix(10))...")
        print("[NativeChatService] 🌐 Base URL: \(ComposioConfig.openAIBaseURL)")
        print("[NativeChatService] 🤖 Model: \(ComposioConfig.llmModel)")

        await MainActor.run {
            self.isStreaming = true
            self.streamingContent = ""
            self.streamingToolCalls = []
        }

        defer {
            self.isStreaming = false
        }

        // 1. Get Tools from Composio
        let userId = AuthService.shared.userEmail ?? "default_user"
        print("[NativeChatService] 🔧 Fetching tools for user: \(userId)")
        
        // Dynamically fetch connected toolkits first
        let connectedAccounts = try? await composioManager.getConnectedAccounts(userId: userId)
        var toolkits = Array(Set(connectedAccounts?.map { $0.toolkit } ?? []))
        
        // Fallback to defaults if none connected
        if toolkits.isEmpty {
            toolkits = ["GITHUB", "GMAIL", "SLACK"]
        }
        print("[NativeChatService] 📦 Toolkits determined: \(toolkits)")

        let composioTools = try await composioManager.getTools(userId: userId, toolkits: toolkits)
        print("[NativeChatService] ✅ Fetched \(composioTools.count) tools")

        // 2. Format tools for SwiftOpenAI with mapping
        var toolNameMapping: [String: String] = [:]
        let openAITools = composioTools.compactMap { tool -> ChatCompletionParameters.Tool? in
            // OpenAI requires: ^[a-zA-Z0-9_-]{1,64}$
            let technicalName = tool.slug
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: " ", with: "_")
                .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-")).inverted)
                .joined()

            guard !technicalName.isEmpty else { return nil }
            toolNameMapping[technicalName] = tool.slug

            return ChatCompletionParameters.Tool(
                function: .init(
                    name: technicalName,
                    strict: nil,
                    description: tool.description ?? "",
                    parameters: tool.inputParameters?.asJSONSchema ?? JSONSchema(type: .object, additionalProperties: false)
                )
            )
        }
        
        // 3. Prepare Messages
        var chatMessages: [ChatCompletionParameters.Message] = messages.compactMap { msg in
            switch msg.role {
            case .user: return .init(role: .user, content: .text(msg.content))
            case .assistant: return .init(role: .assistant, content: .text(msg.content))
            case .system: return .init(role: .system, content: .text(msg.content))
            }
        }
        
        if messages.last?.content != content || messages.last?.role != .user {
            chatMessages.append(.init(role: .user, content: .text(content)))
        }
        
        let assistantMessage = try await runChatLoop(
            messages: &chatMessages,
            tools: openAITools,
            toolMapping: toolNameMapping
        )
        
        return assistantMessage
    }
    
    // MARK: - Chat Loop & Tool Execution

    private func runChatLoop(
        messages: inout [ChatCompletionParameters.Message],
        tools: [ChatCompletionParameters.Tool],
        toolMapping: [String: String],
        depth: Int = 0
    ) async throws -> Message {
        // Prevent infinite loops
        guard depth < 10 else {
            print("[NativeChatService] ⚠️ Maximum recursion depth reached")
            return Message(content: "Error: Tool calling depth exceeded.", role: .assistant)
        }

        print("[NativeChatService] 🔄 Chat loop iteration \(depth + 1)")
        print("[NativeChatService] 💬 Messages in history: \(messages.count)")
        print("[NativeChatService] 🛠️ Available tools: \(tools.count)")

        let parameters = ChatCompletionParameters(
            messages: messages,
            model: .custom(ComposioConfig.llmModel),
            tools: tools.isEmpty ? nil : tools
        )

        var fullContent = ""
        let accumulator = ToolCallAccumulator()
        var hasToolCalls = false

        // 1. Stream response with error handling and retry logic
        print("[NativeChatService] 📡 Starting API stream...")

        let stream: AsyncThrowingStream<ChatCompletionChunkObject, Error>
        do {
            stream = try await executeWithRetry {
                try await self.openAI.startStreamedChat(parameters: parameters)
            }
            print("[NativeChatService] ✅ Stream started successfully")
        } catch let error as NSError {
            print("[NativeChatService] ❌ Stream initiation failed after retries")
            print("[NativeChatService] ❌ Error domain: \(error.domain), Code: \(error.code)")
            throw NativeChatError.apiError(error)
        }

        do {
            for try await result in stream {
                guard let choice = result.choices?.first, let delta = choice.delta else { continue }

                if let content = delta.content {
                    fullContent += content
                    let currentContent = fullContent
                    self.streamingContent = fullContent
                }

                if let toolCallsDelta = delta.toolCalls {
                    hasToolCalls = true
                    for call in toolCallsDelta {
                        let part = ToolCallPart(
                            index: call.index ?? 0,
                            id: call.id,
                            name: call.function.name,
                            argumentsPart: call.function.arguments
                        )
                        accumulator.add(part)
                    }
                }
            }
            print("[NativeChatService] ✅ Stream completed successfully")
        } catch let error as NSError {
            print("[NativeChatService] ❌ Stream processing error")
            print("[NativeChatService] ❌ Error: \(error)")
            print("[NativeChatService] ❌ Domain: \(error.domain), Code: \(error.code)")
            throw NativeChatError.apiError(error)
        }
        
        // 2. Handle assistant message
        if hasToolCalls {
            let finalizedCalls = accumulator.finalize()
            
            let assistantToolCalls = finalizedCalls.map { call in
                let argsString: String
                if let encoded = try? JSONEncoder().encode(call.arguments) {
                    argsString = String(data: encoded, encoding: .utf8) ?? "{}"
                } else {
                    argsString = "{}"
                }
                return SwiftOpenAI.ToolCall(
                    id: call.id,
                    function: .init(arguments: argsString, name: call.name)
                )
            }
            
            // Add assistant message with tool calls to history
            messages.append(.init(
                role: .assistant,
                content: .text(fullContent),
                toolCalls: assistantToolCalls
            ))
            
            // Execute each tool call
            for call in finalizedCalls {
                // Get original slug from mapping
                let originalSlug = toolMapping[call.name] ?? call.name
                
                print("[NativeChatService] 🔧 Executing: \(originalSlug) (via \(call.name))")
                print("[NativeChatService] 📥 Arguments: \(call.arguments)")

                self.streamingToolCalls.append(ToolCall(id: call.id, name: call.name, status: .running))

                do {
                    let toolResult = try await composioManager.executeTool(
                        originalSlug,
                        userId: AuthService.shared.userEmail ?? "default_user",
                        parameters: call.arguments.dictionary
                    )

                    print("[NativeChatService] ✅ Tool execution successful")

                    if let index = self.streamingToolCalls.firstIndex(where: { $0.id == call.id }) {
                        self.streamingToolCalls[index].status = .completed
                        self.streamingToolCalls[index].output = toolResult.data
                    }

                    // Add tool result to history
                    let resultString: String
                    if let data = toolResult.data,
                       let encodedData = try? JSONEncoder().encode(data) {
                        resultString = String(data: encodedData, encoding: .utf8) ?? "{}"
                    } else {
                        resultString = "{}"
                    }

                    messages.append(.init(
                        role: .tool,
                        content: .text(resultString),
                        toolCallID: call.id
                    ))
                } catch {
                    print("[NativeChatService] ❌ Tool execution failed: \(error)")

                    if let index = self.streamingToolCalls.firstIndex(where: { $0.id == call.id }) {
                        self.streamingToolCalls[index].status = .error
                    }

                    // Add error result to history
                    messages.append(.init(
                        role: .tool,
                        content: .text("{\"error\": \"\(error.localizedDescription)\"}"),
                        toolCallID: call.id
                    ))
                }
            }
            
            // 3. Recurse for final answer
            return try await runChatLoop(
                messages: &messages,
                tools: tools,
                toolMapping: toolMapping,
                depth: depth + 1
            )
        } else {
            // Final message
            return Message(
                id: UUID().uuidString,
                content: fullContent.isEmpty ? "No response." : fullContent,
                role: .assistant
            )
        }
    }
    
    // MARK: - Helpers
    
    private func executeWithRetry<T>(
        maxAttempts: Int = 3,
        operation: @MainActor () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                print("[NativeChatService] ⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }
        throw lastError ?? NativeChatError.invalidResponse
    }
}


// MARK: - Extensions

extension [String: AnyCodable] {
    var dictionary: [String: Any] {
        self.mapValues { $0.value }
    }
}

extension ToolParameters {
    var asJSONSchema: JSONSchema {
        // Dictionary-based approach is safer when we don't have direct access to internal SDK types
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return JSONSchema(type: .object, additionalProperties: false)
        }
        
        return mapToSchema(dict: dict)
    }
    
    private func mapToSchema(dict: [String: Any]) -> JSONSchema {
        let properties = dict["properties"] as? [String: [String: Any]] ?? [:]
        let required = dict["required"] as? [String]
        
        var schemaProperties: [String: JSONSchema] = [:]
        for (key, propDict) in properties {
            schemaProperties[key] = mapProperty(propDict)
        }
        
        return JSONSchema(
            type: .object,
            properties: schemaProperties.isEmpty ? nil : schemaProperties,
            required: required,
            additionalProperties: false
        )
    }
    
    private func mapProperty(_ dict: [String: Any]) -> JSONSchema {
        let typeStr = dict["type"] as? String ?? "string"
        let description = dict["description"] as? String
        let enumValues = dict["enum"] as? [String]
        
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
            for (k, v) in propsDict {
                mapped[k] = mapProperty(v)
            }
            nestedProperties = mapped
        }
        
        var items: JSONSchema? = nil
        if type == .array, let itemDict = dict["items"] as? [String: Any] {
            items = mapProperty(itemDict)
        }
        
        // Correct initializer order and parameter assignment
        return JSONSchema(
            type: type,
            description: description,
            properties: nestedProperties,
            items: items,
            required: dict["required"] as? [String],
            additionalProperties: type == .object ? false : false, // Defaulting to false as required by SDK init
            enum: enumValues
        )
    }
}
