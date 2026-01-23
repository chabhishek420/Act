import Testing
import Foundation
@testable import Rube_ios
import SwiftOpenAI
import Composio

@Suite("NativeChatService Tests")
struct NativeChatServiceTests {
    
    @Test("Test text-only message delivery")
    func testTextMessage() async throws {
        // Arrange
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.responsesToStream = [
            .mock(content: "Hello"),
            .mock(content: " world!")
        ]
        
        let mockComposio = MockComposioManager()
        let service = await NativeChatService(openAI: mockOpenAI, composioManager: mockComposio)
        
        // Act
        let response = try await service.sendMessage(
            "Hi",
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        // Assert
        #expect(response.content == "Hello world!")
        #expect(response.role == .assistant)
    }
    
    @Test("Test empty response handling")
    func testEmptyResponse() async throws {
        // Arrange
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.responsesToStream = []
        
        let mockComposio = MockComposioManager()
        let service = await NativeChatService(openAI: mockOpenAI, composioManager: mockComposio)
        
        // Act
        let response = try await service.sendMessage(
            "Hi",
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        // Assert
        #expect(response.content == "No response.")
    }
    
    @Test("Test error propagation")
    func testErrorPropagation() async throws {
        // Arrange
        let mockOpenAI = MockOpenAIService()
        mockOpenAI.errorToThrow = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Error"])
        
        let mockComposio = MockComposioManager()
        let service = await NativeChatService(openAI: mockOpenAI, composioManager: mockComposio)
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await service.sendMessage(
                "Hi",
                messages: [],
                conversationId: nil,
                onNewConversationId: { _ in }
            )
        }
    }
    
    @Test("Test tool calling loop")
    func testToolCallingLoop() async throws {
        // Arrange
        let mockOpenAI = MockOpenAIService()
        // Call 1: Return a tool call
        let toolCall = ChatCompletionChunkObject.mockToolCall(id: "call_1", name: "get_weather", arguments: "{\"location\":\"San Francisco\"}")
        // Call 2: Return final text
        let finalText = ChatCompletionChunkObject.mock(content: "The weather is nice!")
        
        mockOpenAI.sequentialResponses = [
            [toolCall],
            [finalText]
        ]
        
        let mockComposio = MockComposioManager()
        // Use JSON decoding to create a valid ToolResult without fighting initializers
        let json = "{\"data\": {\"temperature\": 22}}"
        mockComposio.executionResultToReturn = try JSONDecoder().decode(ToolResult.self, from: json.data(using: .utf8)!)
        
        let service = await NativeChatService(openAI: mockOpenAI, composioManager: mockComposio)
        
        // Act
        let response = try await service.sendMessage(
            "What is the weather?",
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        // Assert
        #expect(response.content == "The weather is nice!")
        #expect(mockComposio.lastExecutedTool == "get_weather")
    }
}
