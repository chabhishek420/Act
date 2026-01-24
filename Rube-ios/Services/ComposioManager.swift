//
//  ComposioManager.swift
//  Rube-ios
//
//  Singleton manager for Composio Swift SDK
//  Handles tool router sessions, OAuth connections, and tool execution
//

import Foundation
import Composio
import OSLog

private let logger = Logger(subsystem: "com.rube.ios", category: "ComposioManager")

/// Manages Composio SDK lifecycle and provides access to tool execution and OAuth
@available(iOS 15.0, *)
@Observable
@MainActor
final class ComposioManager {

    // MARK: - Singleton

    static let shared = ComposioManager()

    // MARK: - Properties

    /// The underlying Composio SDK client
    private var _composio: Composio?

    /// Whether the SDK is properly initialized
    private(set) var isInitialized: Bool = false

    private var currentSession: ToolRouterSession?
    private var sessionUserId: String?

    /// Current session ID if active
    var sessionId: String? { currentSession?.sessionId }

    // MARK: - Initialization

    private init() {
        // Get API key from secure configuration
        let apiKey = ComposioConfig.apiKey

        if !apiKey.isEmpty {
            do {
                self._composio = try Composio(validating: apiKey)
                self.isInitialized = true
                logger.info("✅ SDK initialized successfully")

                // Clean up expired sessions on startup
                cleanupExpiredSessions()
            } catch {
                logger.error("❌ Failed to initialize Composio SDK: \(error.localizedDescription)")
            }
        } else {
            logger.warning("⚠️ COMPOSIO_API_KEY not configured. SDK will remain uninitialized.")
        }
    }

    /// Re-initializes the SDK with a new API key
    func reinitialize(apiKey: String) throws {
        self._composio = try Composio(validating: apiKey)
        self.isInitialized = true
        logger.info("✅ SDK re-initialized successfully")
        cleanupExpiredSessions()
    }

    private func getComposio() throws -> Composio {
        guard let composio = _composio else {
            throw ComposioManagerError.notInitialized
        }
        return composio
    }
    
    /// Cleans up expired session data from UserDefaults
    private func cleanupExpiredSessions() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        
        // Find all session keys
        let sessionKeys = allKeys.filter { $0.hasPrefix("composio_session_v2_") }
        var cleanedCount = 0
        
        for key in sessionKeys {
            // Construct the corresponding time key
            let userId = key.replacingOccurrences(of: "composio_session_v2_", with: "")
            let timeKey = "composio_session_time_\(userId)"
            
            // Check if session is expired (1 hour TTL)
            if let timestamp = defaults.object(forKey: timeKey) as? Date,
               Date().timeIntervalSince(timestamp) > 3600 {
                defaults.removeObject(forKey: key)
                defaults.removeObject(forKey: timeKey)
                cleanedCount += 1
            } else if defaults.object(forKey: timeKey) == nil {
                // No timestamp means orphaned session - remove it
                defaults.removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            logger.info("[ComposioManager] 🧹 Cleaned up \(cleanedCount) expired session(s)")
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

        // 2. Check UserDefaults cache
        let cacheKey = "composio_session_v2_\(userId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? userId)"
        let timeKey = "composio_session_time_\(userId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? userId)"

        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: timeKey) as? Date,
           Date().timeIntervalSince(timestamp) < 3600 { // 1 hour TTL

            do {
                let session = try JSONDecoder().decode(ToolRouterSession.self, from: data)
                logger.info("[ComposioManager] ♻️ Reusing cached Tool Router session: \(session.sessionId)")
                self.currentSession = session
                self.sessionUserId = userId
                return session
            } catch {
                logger.info("[ComposioManager] ⚠️ Failed to decode cached session: \(error)")
                UserDefaults.standard.removeObject(forKey: cacheKey)
            }
        }

        // 3. Create new session with retry logic
        logger.info("[ComposioManager] 🆕 Creating new Tool Router session for: \(userId)")

        let composio = try getComposio()
        let session = try await NetworkRetry.execute(policy: .default) {
            try await composio.toolRouter.createSession(
                for: userId,
                toolkits: nil // Enable all toolkits
            )
        }

        // 4. Update caches
        self.currentSession = session
        self.sessionUserId = userId

        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
        }

        logger.info("[ComposioManager] ✅ Session created: \(session.sessionId)")
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
        logger.info("[ComposioManager] Session cleared")
    }
    
    // MARK: - Connected Accounts
    
    /// Lists all connected accounts for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of connected accounts
    func getConnectedAccounts(userId: String) async throws -> [ConnectedAccount] {
        let composio = try getComposio()
        let response = try await composio.connectedAccounts.fetch(for: userId)
        return response.items
    }
    
    /// Gets auth configs for a specific toolkit
    /// - Parameter toolkit: Toolkit slug (e.g., "github", "gmail")
    /// - Returns: Array of auth configs
    func getAuthConfigs(toolkit: String) async throws -> [Any] {
        let composio = try getComposio()
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
        // Use retry logic for critical OAuth operations
        let composio = try getComposio()
        let request = try await NetworkRetry.execute(policy: .default) {
            try await composio.connectedAccounts.initiateConnection(
                for: userId,
                toolkit: toolkit,
                redirectUrl: callbackURL
            )
        }

        logger.info("[ComposioManager] ✅ Connection initiated for \(toolkit)")
        logger.info("[ComposioManager]    Redirect URL: \(request.redirectUrl)")

        return request
    }
    
    /// Disconnects a connected account
    /// - Parameter accountId: Connected account ID
    func disconnectAccount(_ accountId: String) async throws {
        let composio = try getComposio()
        try await composio.connectedAccounts.delete(id: accountId)
        logger.info("[ComposioManager] ✅ Account disconnected: \(accountId)")
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
        logger.info("[ComposioManager] Executing tool: \(toolSlug)")

        let composio = try getComposio()
        let result = try await composio.tools.execute(
            toolSlug,
            for: userId,
            parameters: parameters
        )

        logger.info("[ComposioManager] ✅ Tool executed successfully")
        return result
    }

    /// Searches for tools matching a query
    /// - Parameter query: Search query
    /// - Returns: Array of matching tools
    func searchTools(query: String) async throws -> [Tool] {
        let composio = try getComposio()
        return try await composio.tools.search(for: query)
    }

    /// Gets tools for specific toolkits
    func getTools(userId: String, toolkits: [String]) async throws -> [Tool] {
        let composio = try getComposio()
        return try await composio.tools.fetch(
            for: userId,
            options: ToolsGetOptions(toolkits: toolkits)
        )
    }
    
    // MARK: - Tool Router (Meta Tools)

    /// Fetches the meta-tools (Search, Multi-Execute, etc.) for an active session
    /// NOTE: Returns empty array to avoid fetching 500+ tool schemas that exceed iOS URL response limits
    /// The meta-tools (COMPOSIO_SEARCH_TOOLS, COMPOSIO_MULTI_EXECUTE_TOOL, COMPOSIO_MANAGE_CONNECTIONS)
    /// are injected by the LLM system prompt and don't need to be fetched from the API
    func getMetaTools(sessionId: String) async throws -> [Tool] {
        logger.info("[ComposioManager] ⚡ Skipping tool fetch (would exceed iOS limits). Meta-tools defined in system prompt.")
        return []
    }
    
    /// Executes a meta-tool (COMPOSIO_*) within a session
    func executeMetaTool(
        _ slug: String,
        sessionId: String,
        arguments: [String: Any]? = nil
    ) async throws -> ToolRouterExecuteResponse {
        logger.info("[ComposioManager] 🛠 Executing meta-tool: \(slug) in session: \(sessionId)")
        let composio = try getComposio()
        return try await composio.toolRouter.executeMeta(slug, in: sessionId, arguments: arguments)
    }

    /// Executes an app tool discovered via Search within a session context
    func executeSessionTool(
        _ toolSlug: String,
        sessionId: String,
        arguments: [String: Any]? = nil
    ) async throws -> ToolRouterExecuteResponse {
        logger.info("[ComposioManager] 🚀 Executing session tool: \(toolSlug)")
        let composio = try getComposio()
        return try await composio.toolRouter.execute(toolSlug, in: sessionId, arguments: arguments)
    }

    /// Creates an auth link for a specific toolkit within the session context
    func createSessionLink(
        for toolkit: String,
        sessionId: String
    ) async throws -> ToolRouterLinkResponse {
        logger.info("[ComposioManager] 🔗 Creating session auth link for: \(toolkit)")
        let composio = try getComposio()
        return try await composio.toolRouter.createLink(for: toolkit, in: sessionId)
    }

    /// Waits for a connection to become active
    func waitForConnection(
        accountId: String,
        timeout: TimeInterval
    ) async throws -> ConnectedAccount {
        let composio = try getComposio()
        return try await composio.connectedAccounts.waitForConnection(
            id: accountId,
            timeout: timeout
        )
    }

    // MARK: - Toolkits

    /// Lists available toolkits
    /// - Parameter limit: Maximum number to return
    /// - Returns: Array of toolkits
    func getToolkits(limit: Int = 50) async throws -> [Any] {
        let composio = try getComposio()
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
