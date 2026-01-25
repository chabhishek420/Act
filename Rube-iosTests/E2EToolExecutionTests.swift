import Testing
import Foundation
import Composio
@testable import Rube_ios

@Suite("E2E Tool Execution Tests")
struct ToolExecutionTests {
    
    @Test("Verify GitHub Star Tool Pipeline")
    func testGitHubStarTool() async throws {
        let service = await NativeChatService()
        
        // This test requires a connected GitHub account.
        // We prompt the agent to star the composio repository.
        let prompt = "Star the repository 'composiohq/composio' on GitHub using GITHUB_ACTIVITY_STAR_REPO_FOR_AUTHENTICATED_USER."
        
        print("[E2E Test] 🚀 Starting tool execution flow for: \(prompt)")
        
        let response = try await service.sendMessage(
            prompt,
            messages: [],
            conversationId: nil,
            onNewConversationId: { _ in }
        )
        
        // Assertions
        #expect(!response.content.isEmpty)
        
        // Assert that tool calls were actually made
        guard let toolCalls = response.toolCalls else {
            Issue.record("LLM did not attempt any tool calls")
            return
        }
        
        #expect(!toolCalls.isEmpty)
        let hasGithubTool = toolCalls.contains(where: { $0.name.contains("GITHUB") })
        #expect(hasGithubTool, "LLM should have called a GitHub tool")
        
        for call in toolCalls {
            print("[E2E Test] 🛠 Tool call detected: \(call.name) with status \(call.status)")
        }
        
        print("✅ E2E: Tool execution pipeline response: \(response.content)")
    }

    @Test("Direct Tool Execution - GitHub Star")
    func testDirectGitHubStar() async throws {
        let manager = ComposioManager.shared
        // Using default_user which seems to have connections in the proxy
        let testUser = "default_user" 
        
        print("[E2E Test] 🚀 Executing direct tool call: GITHUB_ACTIVITY_STAR_REPO_FOR_AUTHENTICATED_USER")
        
        do {
            let result = try await manager.executeTool(
                "GITHUB_ACTIVITY_STAR_REPO_FOR_AUTHENTICATED_USER",
                userId: testUser,
                parameters: ["owner": "composiohq", "repo": "composio"]
            )
            
            print("[E2E Test] ✅ Tool execution status: \(result.isSuccess)")
            print("[E2E Test] 📝 Response: \(result.data)")
            
            #expect(result.isSuccess, "Tool execution should be successful")
        } catch {
            print("[E2E Test] ❌ Tool execution failed: \(error.localizedDescription)")
            throw error
        }
    }

    @Test("List Available Tools")
    func testListTools() async throws {
        let manager = ComposioManager.shared
        let testEmail = "roshsharma.com@gmail.com"
        
        print("[E2E Test] 🔍 Fetching all tools for: \(testEmail)")
        let tools = try await manager.getTools(userId: testEmail, toolkits: ["GITHUB", "GMAIL", "SLACK"])
        
        print("[E2E Test] 🛠 Found \(tools.count) tools")
        for tool in tools {
            print("[E2E Test]    - \(tool.slug): \(tool.name ?? "No Name")")
        }
    }
}
