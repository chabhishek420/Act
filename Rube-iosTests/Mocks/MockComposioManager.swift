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
}
