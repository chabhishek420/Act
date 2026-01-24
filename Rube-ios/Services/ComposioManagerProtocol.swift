//
//  ComposioManagerProtocol.swift
//  Rube-ios
//
//  Protocol for Composio Manager to enable testability
//

import Foundation
import Composio

/// Protocol for Composio Manager operations
/// Enables dependency injection and mocking for unit tests
@available(iOS 15.0, *)
protocol ComposioManagerProtocol: Sendable {

    /// Fetches tools for specific toolkits
    /// - Parameters:
    ///   - userId: User identifier
    ///   - toolkits: Array of toolkit slugs
    /// - Returns: Array of available tools
    func getTools(userId: String, toolkits: [String]) async throws -> [Tool]

    /// Executes a tool with given parameters
    /// - Parameters:
    ///   - toolSlug: Tool identifier
    ///   - userId: User identifier
    ///   - parameters: Tool execution parameters
    /// - Returns: Tool execution result
    func executeTool(_ toolSlug: String, userId: String, parameters: [String: Any]) async throws -> ToolResult

    /// Gets connected accounts for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of connected accounts
    func getConnectedAccounts(userId: String) async throws -> [ConnectedAccount]
    
    // MARK: - Tool Router
    
    func getSession(for userId: String) async throws -> ToolRouterSession
    
    func getMetaTools(sessionId: String) async throws -> [Tool]
    
    func executeMetaTool(
        _ slug: String,
        sessionId: String,
        arguments: [String: Any]?
    ) async throws -> ToolRouterExecuteResponse
    
    func executeSessionTool(
        _ toolSlug: String,
        sessionId: String,
        arguments: [String: Any]?
    ) async throws -> ToolRouterExecuteResponse
    
    func createSessionLink(
        for toolkit: String,
        sessionId: String
    ) async throws -> ToolRouterLinkResponse

    func waitForConnection(
        accountId: String,
        timeout: TimeInterval
    ) async throws -> ConnectedAccount
}
