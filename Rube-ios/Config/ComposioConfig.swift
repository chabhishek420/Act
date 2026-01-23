//
//  ComposioConfig.swift
//  Rube-ios
//
//  Secure configuration for Composio API
//  NOTE: In production, consider using Keychain or environment-based injection
//

import Foundation

/// Configuration for Composio SDK
enum ComposioConfig {

    /// Composio API Key
    ///
    /// For production, this should be:
    /// 1. Stored in Keychain
    /// 2. Injected at build time
    /// 3. Retrieved from a secure backend
    ///
    /// Current setup uses a static key for development.
    static var apiKey: String {
        // Try environment variable first (for CI/CD)
        if let envKey = ProcessInfo.processInfo.environment["COMPOSIO_API_KEY"],
           !envKey.isEmpty {
            return envKey
        }

        // Development key - replace with secure storage in production
        // This key should match what's in rube-backend/.env.local
        return "ak_5j2LU5s9bVapMLI2kHfL"
    }

    /// OAuth callback URL scheme
    static let oauthCallbackScheme = "rube"

    /// OAuth callback URL
    static let oauthCallbackURL = "rube://oauth-callback"

    /// Debug mode - enables verbose logging
    static var debugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - OpenAI / LLM Configuration

    /// OpenAI API Key (or custom provider key)
    static var openAIKey: String {
        return "anything"
    }

    /// Custom API Base URL (NOTE: Do NOT include /v1 - SwiftOpenAI SDK appends it automatically)
    static var openAIBaseURL: String {
        return "http://143.198.174.251:8317"
    }

    /// LLM Model name
    static var llmModel: String = "gemini-2.5-flash"
}
