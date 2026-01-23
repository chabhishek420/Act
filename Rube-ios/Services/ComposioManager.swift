//
//  ComposioManager.swift
//  Rube-ios
//
//  Singleton manager for Composio Swift SDK
//  Handles tool router sessions, OAuth connections, and tool execution
//

import Foundation
import Composio

/// Manages Composio SDK lifecycle and provides access to tool execution and OAuth
@available(iOS 15.0, *)
@Observable
@MainActor
final class ComposioManager {
    
    // MARK: - Singleton
    
    static let shared = ComposioManager()
    
    // MARK: - Properties
    
    /// The underlying Composio SDK client (internal for service access)
    let composio: Composio
    private var currentSession: ToolRouterSession?
    private var sessionUserId: String?
    
    /// Whether the SDK is properly initialized
    private(set) var isInitialized: Bool = false
    
    /// Current session ID if active
    var sessionId: String? { currentSession?.sessionId }
    
    // MARK: - Initialization
    
    private init() {
        // Get API key from secure configuration
        let apiKey = ComposioConfig.apiKey
        
        guard !apiKey.isEmpty else {
            fatalError("[ComposioManager] ❌ COMPOSIO_API_KEY not configured. Check ComposioConfig.swift")
        }
        
        do {
            self.composio = try Composio(validating: apiKey)
            self.isInitialized = true
            print("[ComposioManager] ✅ SDK initialized successfully")
        } catch {
            fatalError("[ComposioManager] ❌ Failed to initialize Composio SDK: \(error)")
        }
    }
    
    // MARK: - Session Management
    
    /// Creates or returns existing Tool Router session for a user
    /// - Parameter userId: User identifier (typically email)
    /// - Returns: Active ToolRouterSession
    func getSession(for userId: String) async throws -> ToolRouterSession {
        // 1. Check in-memory cache
        if let session = currentSession, sessionUserId == userId {
            return session
        }

        // 2. Create new session (UserDefaults cache removed - SDK struct not instantiable)
        print("[ComposioManager] 🆕 Creating new Tool Router session for: \(userId)")
        
        let session = try await composio.toolRouter.createSession(
            for: userId,
            toolkits: nil // Enable all toolkits
        )

        // 3. Update in-memory cache
        self.currentSession = session
        self.sessionUserId = userId

        print("[ComposioManager] ✅ Session created: \(session.sessionId)")
        return session
    }
    
    /// Clears the current session and persistent cache
    func clearSession() {
        if let userId = sessionUserId {
            UserDefaults.standard.removeObject(forKey: "composio_session_\(userId)")
            UserDefaults.standard.removeObject(forKey: "composio_session_time_\(userId)")
        }
        currentSession = nil
        sessionUserId = nil
        print("[ComposioManager] Session cleared")
    }
    
    // MARK: - Connected Accounts
    
    /// Lists all connected accounts for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of connected accounts
    func getConnectedAccounts(userId: String) async throws -> [ConnectedAccount] {
        let response = try await composio.connectedAccounts.fetch(for: userId)
        return response.items
    }
    
    /// Gets auth configs for a specific toolkit
    /// - Parameter toolkit: Toolkit slug (e.g., "github", "gmail")
    /// - Returns: Array of auth configs
    func getAuthConfigs(toolkit: String) async throws -> [Any] {
        let configs = try await composio.authConfigs.fetch(for: toolkit)
        return configs.map { config -> [String: Any] in
            [
                "id": config.id,
                "toolkit": config.toolkit,
                "name": config.name ?? "",
                "auth_scheme": config.authScheme ?? ""
            ]
        }
    }
    
    /// Initiates an OAuth connection for a toolkit
    /// - Parameters:
    ///   - toolkit: Toolkit slug
    ///   - userId: User identifier
    ///   - callbackURL: OAuth callback URL (e.g., "rube://oauth-callback")
    /// - Returns: Connection request with redirect URL
    func initiateConnection(
        toolkit: String,
        userId: String,
        callbackURL: String = "rube://oauth-callback"
    ) async throws -> ConnectionRequest {
        // The SDK has a convenience method that handles auth config lookup
        let request = try await composio.connectedAccounts.initiateConnection(
            for: userId,
            toolkit: toolkit,
            redirectUrl: callbackURL
        )
        
        print("[ComposioManager] ✅ Connection initiated for \(toolkit)")
        print("[ComposioManager]    Redirect URL: \(request.redirectUrl)")
        
        return request
    }
    
    /// Disconnects a connected account
    /// - Parameter accountId: Connected account ID
    func disconnectAccount(_ accountId: String) async throws {
        try await composio.connectedAccounts.delete(id: accountId)
        print("[ComposioManager] ✅ Account disconnected: \(accountId)")
    }
    
    // MARK: - Tool Execution
    
    /// Executes a tool with given parameters
    /// - Parameters:
    ///   - toolSlug: Tool identifier (e.g., "GITHUB_STAR_A_REPOSITORY")
    ///   - userId: User identifier
    ///   - parameters: Tool parameters
    /// - Returns: Tool execution result
    func executeTool(
        _ toolSlug: String,
        userId: String,
        parameters: [String: Any]
    ) async throws -> ToolResult {
        print("[ComposioManager] Executing tool: \(toolSlug)")
        
        let result = try await composio.tools.execute(
            toolSlug,
            for: userId,
            parameters: parameters
        )
        
        print("[ComposioManager] ✅ Tool executed successfully")
        return result
    }
    
    /// Searches for tools matching a query
    /// - Parameter query: Search query
    /// - Returns: Array of matching tools
    func searchTools(query: String) async throws -> [Tool] {
        return try await composio.tools.search(for: query)
    }
    
    /// Gets tools for specific toolkits
    /// - Parameters:
    ///   - userId: User identifier
    ///   - toolkits: Array of toolkit slugs
    /// - Returns: Array of tools
    func getTools(userId: String, toolkits: [String]) async throws -> [Tool] {
        return try await composio.tools.fetch(
            for: userId,
            options: ToolsGetOptions(toolkits: toolkits)
        )
    }
    
    // MARK: - Toolkits
    
    /// Lists available toolkits
    /// - Parameter limit: Maximum number to return
    /// - Returns: Array of toolkits
    func getToolkits(limit: Int = 50) async throws -> [Any] {
        let toolkits = try await composio.toolkits.fetch()
        return toolkits.map { toolkit -> [String: Any] in
            [
                "slug": toolkit.slug,
                "name": toolkit.displayName ?? toolkit.slug,
                "description": toolkit.description ?? ""
            ]
        }
    }
}

// MARK: - Protocol Conformance

@available(iOS 15.0, *)
extension ComposioManager: ComposioManagerProtocol {}

// MARK: - Errors

enum ComposioManagerError: LocalizedError {
    case notInitialized
    case noAuthConfigFound(toolkit: String)
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Composio SDK not initialized"
        case .noAuthConfigFound(let toolkit):
            return "No auth configuration found for \(toolkit)"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
