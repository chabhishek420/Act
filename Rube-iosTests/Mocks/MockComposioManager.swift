import Foundation
import Composio
@testable import Rube_ios

final class MockComposioManager: ComposioManagerProtocol, @unchecked Sendable {
    var toolsToReturn: [Tool] = []
    var executionResultToReturn: ToolResult?
    var lastExecutedTool: String?
    
    func getTools(userId: String, toolkits: [String]) async throws -> [Tool] {
        return toolsToReturn
    }
    
    func executeTool(_ toolSlug: String, userId: String, parameters: [String: Any]) async throws -> ToolResult {
        lastExecutedTool = toolSlug
        if let result = executionResultToReturn {
            return result
        }
        throw ComposioManagerError.connectionFailed("No mock result configured")
    }
    
    func getConnectedAccounts(userId: String) async throws -> [ConnectedAccount] {
        return []
    }
    
    // MARK: - Tool Router (Mocks)
    
    func getSession(for userId: String, conversationId: String) async throws -> ToolRouterSession {
        // Create a dummy session for mocking
        let data = "{\"session_id\": \"mock_session_123\"}".data(using: .utf8)!
        return try JSONDecoder().decode(ToolRouterSession.self, from: data)
    }
    
    func getMetaTools(sessionId: String) async throws -> [Tool] {
        return toolsToReturn
    }
    
    func executeMetaTool(_ slug: String, sessionId: String, arguments: [String: Any]?) async throws -> ToolRouterExecuteResponse {
        let data = "{\"data\": {}, \"log_id\": \"mock_log\"}".data(using: .utf8)!
        return try JSONDecoder().decode(ToolRouterExecuteResponse.self, from: data)
    }
    
    func executeSessionTool(_ toolSlug: String, sessionId: String, arguments: [String: Any]?) async throws -> ToolRouterExecuteResponse {
        let data = "{\"data\": {}, \"log_id\": \"mock_log\"}".data(using: .utf8)!
        return try JSONDecoder().decode(ToolRouterExecuteResponse.self, from: data)
    }
    
    func createSessionLink(for toolkit: String, sessionId: String) async throws -> ToolRouterLinkResponse {
        let data = "{\"connected_account_id\": \"mock_acc\", \"link_token\": \"abc\", \"redirect_url\": \"https://example.com\"}".data(using: .utf8)!
        return try JSONDecoder().decode(ToolRouterLinkResponse.self, from: data)
    }

    func waitForConnection(accountId: String, timeout: TimeInterval) async throws -> ConnectedAccount {
        // Return a mock connected account
        let data = "{\"id\": \"\(accountId)\", \"status\": \"active\", \"appUniqueId\": \"mock_app\"}".data(using: .utf8)!
        return try JSONDecoder().decode(ConnectedAccount.self, from: data)
    }
}
