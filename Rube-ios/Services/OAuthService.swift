//
//  OAuthService.swift
//  Rube-ios
//
//  OAuth and app connection service
//

import Foundation
import AuthenticationServices
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.rube.ios", category: "OAuthService")

enum OAuthError: LocalizedError {
    case cancelled
    case invalidURL
    case noCallback
    case failedToStart
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .invalidURL:
            return "Invalid authentication URL"
        case .noCallback:
            return "No callback URL received"
        case .failedToStart:
            return "Unable to start authentication session"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Represents a pending authentication request for in-chat auth
struct PendingAuthRequest {
    let toolkit: String
    let connectLink: String
    let requestId: String
    let timestamp: Date

    /// Check if request is still valid (within 30 minutes)
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 1800 // 30 minutes
    }
}

@Observable
final class OAuthService: NSObject {
    private var authSession: ASWebAuthenticationSession?
    private(set) var isAuthenticating = false

    // Pending authentication requests waiting for user completion
    private var pendingAuthRequests: [String: PendingAuthRequest] = [:]

    // MARK: - Start OAuth Flow

    @MainActor
    func startOAuth(url: URL, callbackScheme: String? = nil) async throws -> URL {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let resolvedCallbackScheme = callbackScheme
            ?? Self.extractCallbackScheme(from: url)
            ?? "rube"

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: resolvedCallbackScheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.networkError(error))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.noCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Allow SSO

            self.authSession = session
            let didStart = session.start()

            if !didStart {
                continuation.resume(throwing: OAuthError.failedToStart)
            }
        }
    }

    // MARK: - In-Chat Authentication (From open-rube pattern)

    /// Detects if a tool execution error is due to missing authentication
    /// Returns toolkit name if auth is required, nil otherwise
    func detectAuthRequired(error: Error) -> String? {
        let errorString = error.localizedDescription.lowercased()

        // Check for common auth-related error patterns
        if errorString.contains("not authenticated") ||
           errorString.contains("authentication required") ||
           errorString.contains("unauthorized") ||
           errorString.contains("not connected") {
            return extractToolkitFromError(errorString)
        }

        return nil
    }

    /// Extracts toolkit name from error message
    private func extractToolkitFromError(_ error: String) -> String? {
        // Common toolkits to check for
        let toolkits = ["github", "gmail", "slack", "notion", "linear", "discord", "twitter", "linkedin"]

        for toolkit in toolkits {
            if error.lowercased().contains(toolkit) {
                return toolkit
            }
        }

        return nil
    }

    /// Gets a Connect Link for a toolkit within a session context
    /// This enables in-chat authentication where users get OAuth links during conversation
    @MainActor
    func getConnectLink(
        toolkit: String,
        userId: String,
        conversationId: String
    ) async throws -> String {
        // Get or create session for this user/conversation
        let session = try await ComposioManager.shared.getSession(for: userId, conversationId: conversationId)

        // Create auth link for the toolkit
        let linkResponse = try await ComposioManager.shared.createSessionLink(
            for: toolkit,
            sessionId: session.sessionId
        )

        // Store pending request for later completion
        let requestId = UUID().uuidString
        let pendingRequest = PendingAuthRequest(
            toolkit: toolkit,
            connectLink: linkResponse.redirectUrl,
            requestId: requestId,
            timestamp: Date()
        )
        pendingAuthRequests[requestId] = pendingRequest

        return linkResponse.redirectUrl
    }

    /// Starts OAuth flow for a pending authentication request
    /// This is called when user clicks the Connect Link in chat
    @MainActor
    func startInChatAuth(requestId: String) async throws -> URL {
        guard let pendingRequest = pendingAuthRequests[requestId],
              pendingRequest.isValid else {
            throw OAuthError.invalidURL
        }

        guard let url = URL(string: pendingRequest.connectLink) else {
            throw OAuthError.invalidURL
        }

        // Start OAuth flow - this will redirect user to provider
        let callbackURL = try await startOAuth(url: url)

        // Clean up pending request after successful auth
        pendingAuthRequests.removeValue(forKey: requestId)

        return callbackURL
    }

    /// Handles OAuth callback and waits for connection to be established
    /// This is called after user completes OAuth flow
    @MainActor
    func handleAuthCallback(
        callbackURL: URL,
        userId: String,
        conversationId: String
    ) async throws -> Bool {
        // Parse callback URL to extract connection details
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }

        // Look for connection/account ID in callback
        if let accountId = queryItems.first(where: { $0.name == "account_id" })?.value ??
                          queryItems.first(where: { $0.name == "connection_id" })?.value {

            // Wait for connection to become active (with timeout)
            do {
                _ = try await ComposioManager.shared.waitForConnection(
                    accountId: accountId,
                    timeout: 30.0 // 30 seconds
                )
                return true
            } catch {
                // Connection didn't become active within timeout
                return false
            }
        }

        return false
    }

    /// Cleans up expired pending authentication requests
    func cleanupExpiredRequests() {
        let now = Date()
        pendingAuthRequests = pendingAuthRequests.filter { $0.value.isValid }
    }

    // Try to infer callback scheme from redirect_uri in the OAuth URL
    private static func extractCallbackScheme(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirect = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              let redirectURL = URL(string: redirect) else {
            return nil
        }

        return redirectURL.scheme
    }
}

// MARK: - OAuth Callback Handling (for resuming conversations)

extension OAuthService {

    /// Handles OAuth callback and resumes conversation after authentication
    /// This is called when user completes OAuth flow and returns to the app
    @MainActor
    func handleAuthCallbackAndResume(
        callbackURL: URL,
        userId: String,
        conversationId: String
    ) async throws -> Bool {
        let success = try await handleAuthCallback(
            callbackURL: callbackURL,
            userId: userId,
            conversationId: conversationId
        )

        if success {
            // Authentication succeeded - clean up any pending requests
            cleanupExpiredRequests()

            // TODO: Signal to ChatViewModel that auth completed successfully
            // This could trigger a follow-up message like "Connection successful! How can I help?"

            logger.info("[OAuthService] ✅ Authentication completed successfully")
        } else {
            logger.warning("[OAuthService] ⚠️ Authentication callback processed but connection not verified")
        }

        return success
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
