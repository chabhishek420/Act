//
//  ComposioConfig.swift
//  Rube-ios
//
//  DEPRECATED: This file is maintained for backward compatibility only.
//  All configuration has been migrated to SecureConfig.swift with Keychain storage.
//
//  Migration date: 2026-01-24
//  TODO: Remove this file after verifying all references use SecureConfig
//

import Foundation

/// Configuration for Composio SDK
/// DEPRECATED: Use SecureConfig instead
enum ComposioConfig {

    /// Composio API Key
    /// DEPRECATED: Use SecureConfig.composioAPIKey
    static var apiKey: String {
        return SecureConfig.composioAPIKey
    }

    /// OAuth callback URL scheme
    static let oauthCallbackScheme = "rube"

    /// OAuth callback URL
    static let oauthCallbackURL = "rube://oauth-callback"

    /// Debug mode - enables verbose logging
    static var debugMode: Bool {
        return SecureConfig.debugMode
    }

    // MARK: - OpenAI / LLM Configuration

    /// OpenAI API Key (or custom provider key)
    /// DEPRECATED: Use SecureConfig.openAIAPIKey
    static var openAIKey: String {
        return SecureConfig.openAIAPIKey
    }

    /// Custom API Base URL (NOTE: Do NOT include /v1 - SwiftOpenAI SDK appends it automatically)
    /// DEPRECATED: Use SecureConfig.openAIBaseURL
    static var openAIBaseURL: String {
        return SecureConfig.openAIBaseURL
    }

    /// LLM Model name
    /// DEPRECATED: Use SecureConfig.llmModel
    static var llmModel: String {
        get {
            return SecureConfig.llmModel
        }
        set {
            try? SecureConfig.setLLMConfig(model: newValue)
        }
    }
}
