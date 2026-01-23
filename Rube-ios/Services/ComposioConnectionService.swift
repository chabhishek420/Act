//
//  ComposioConnectionService.swift
//  Rube-ios
//
//  Service for managing Composio app connections (OAuth)
//  Replaces backend /api/apps/connection calls with direct SDK calls
//

import Foundation
import Composio

/// Service for managing connected accounts via Composio SDK
@available(iOS 15.0, *)
@Observable
final class ComposioConnectionService {
    
    // MARK: - Singleton
    
    static let shared = ComposioConnectionService()
    
    // MARK: - Properties
    
    private let composioManager = ComposioManager.shared
    
    private(set) var connectedAccounts: [ConnectedAccount] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    
    private init() {}
    
    // MARK: - Load Connected Accounts
    
    /// Loads all connected accounts for the current user
    @MainActor
    func loadConnectedAccounts() async {
        guard let userId = AuthService.shared.userEmail else {
            print("[ComposioConnectionService] No user email available")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            connectedAccounts = try await composioManager.getConnectedAccounts(userId: userId)
            print("[ComposioConnectionService] Loaded \(connectedAccounts.count) connected accounts")
        } catch {
            self.error = error
            print("[ComposioConnectionService] Error loading accounts: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Connect App
    
    /// Initiates OAuth connection for a toolkit
    /// - Parameter toolkit: Toolkit slug (e.g., "github", "gmail")
    /// - Returns: OAuth redirect URL to open in browser
    @MainActor
    func connectApp(toolkit: String) async throws -> URL {
        guard let userId = AuthService.shared.userEmail else {
            throw ComposioConnectionError.noUser
        }
        
        print("[ComposioConnectionService] Initiating connection for: \(toolkit)")
        
        let request = try await composioManager.initiateConnection(
            toolkit: toolkit,
            userId: userId,
            callbackURL: ComposioConfig.oauthCallbackURL
        )
        
        let redirectUrlString = request.redirectUrl
        
        guard let url = URL(string: redirectUrlString) else {
            throw ComposioConnectionError.noRedirectURL
        }
        
        print("[ComposioConnectionService] Got redirect URL: \(url)")
        return url
    }
    
    // MARK: - Disconnect App
    
    /// Disconnects a connected account
    /// - Parameter accountId: The connected account ID
    @MainActor
    func disconnectApp(accountId: String) async throws {
        print("[ComposioConnectionService] Disconnecting account: \(accountId)")
        
        try await composioManager.disconnectAccount(accountId)
        
        // Remove from local list
        connectedAccounts.removeAll { $0.id == accountId }
        
        print("[ComposioConnectionService] Account disconnected successfully")
    }
    
    // MARK: - Check Connection Status
    
    /// Checks if a specific toolkit is connected
    /// - Parameter toolkit: Toolkit slug
    /// - Returns: True if connected
    func isConnected(toolkit: String) -> Bool {
        return connectedAccounts.contains { account in
            account.toolkit.lowercased() == toolkit.lowercased() &&
            account.status == .active
        }
    }
    
    /// Gets connected account for a toolkit if it exists
    /// - Parameter toolkit: Toolkit slug
    /// - Returns: Connected account or nil
    func getConnection(toolkit: String) -> ConnectedAccount? {
        return connectedAccounts.first { account in
            account.toolkit.lowercased() == toolkit.lowercased() &&
            account.status == .active
        }
    }
    
    // MARK: - Wait for Connection
    
    /// Waits for a connection to become active (after OAuth callback)
    /// - Parameters:
    ///   - accountId: The pending account ID
    ///   - timeout: Maximum wait time in seconds
    /// - Returns: The active connected account
    func waitForConnection(accountId: String, timeout: TimeInterval = 60) async throws -> ConnectedAccount {
        print("[ComposioConnectionService] Waiting for connection: \(accountId)")
        
        // The SDK has a built-in waitForConnection method
        let account = try await ComposioManager.shared.composio.connectedAccounts.waitForConnection(
            id: accountId,
            timeout: timeout
        )
        
        // Add to local list
        await MainActor.run {
            if !connectedAccounts.contains(where: { $0.id == account.id }) {
                connectedAccounts.append(account)
            }
        }
        
        print("[ComposioConnectionService] Connection active: \(account.id)")
        return account
    }
}

// MARK: - Errors

enum ComposioConnectionError: LocalizedError {
    case noUser
    case noRedirectURL
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noUser:
            return "No authenticated user"
        case .noRedirectURL:
            return "No redirect URL received from Composio"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
