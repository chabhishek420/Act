import Testing
import Foundation
@testable import Rube_ios

@Suite("Live API Integration Tests")
struct LiveApiTests {
    
    @Test("Verify Composio Connectivity (Live)")
    func testComposioLiveTools() async throws {
        let manager = ComposioManager.shared
        
        // This actually hits the Composio API
        let toolkits = try await manager.getToolkits()
        
        #expect(!toolkits.isEmpty)
        print("✅ Live: Successfully fetched \(toolkits.count) toolkits from Composio")
    }
    
    @Test("Verify OpenAI Proxy Connectivity (Live)")
    func testOpenAILiveResponse() async throws {
        // We use the real service with NO mocks
        let service = await NativeChatService()
        
        let response = try await service.sendMessage(
            "Respond with only the word 'PING'.",
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        #expect(response.content.contains("PING"))
        print("✅ Live: LLM responded: \(response.content)")
    }
    
    @Test("Verify Tool Call Pipeline (Live Integration)")
    func testLiveToolCallPipeline() async throws {
        let service = await NativeChatService()
        
        // This test asks for something that should trigger a tool call if available.
        // We test that the loop executes without crashing.
        let response = try await service.sendMessage(
            "What tools do you have access to? List them.",
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        #expect(!response.content.isEmpty)
        print("✅ Live: Pipeline successfully executed. Response length: \(response.content.count)")
    }
}
