//
//  SecureConfig.swift
//  Rube-ios
//
//  Centralized secure configuration management using Keychain
//  Migrated from hardcoded values for production security
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.rube.ios", category: "SecureConfig")

/// Secure configuration manager for API keys and sensitive data
/// Uses Keychain for storage with fallback to environment variables
enum SecureConfig {

    // MARK: - Keychain Keys

    private enum KeychainKeys {
        static let composioAPIKey = "com.rube.composio.apikey"
        static let openAIAPIKey = "com.rube.openai.apikey"
        static let openAIBaseURL = "com.rube.openai.baseurl"
        static let llmModel = "com.rube.llm.model"
    }

    // MARK: - First Run Setup

    /// Call this on first launch to migrate from environment variables to Keychain.
    /// In production, keys should be injected via environment variables in the build system
    /// or provided by the user via a UI (not implemented here).
    static func setupDefaultsIfNeeded() {
        // Only run if keys don't exist in Keychain
        if KeychainManager.loadString(key: KeychainKeys.composioAPIKey) == nil {
            logger.info("First run detected - migrating API keys to Keychain")

            do {
                // Migrate Composio API key
                if let composioKey = ProcessInfo.processInfo.environment["COMPOSIO_API_KEY"] {
                    try KeychainManager.saveString(key: KeychainKeys.composioAPIKey, value: composioKey)
                    logger.info("Composio API key migrated to Keychain")
                } else {
                    logger.warning("COMPOSIO_API_KEY not found in environment during setup")
                }

                // Migrate OpenAI configuration
                if let openAIKey = ProcessInfo.processInfo.environment["CUSTOM_API_KEY"] {
                    try KeychainManager.saveString(key: KeychainKeys.openAIAPIKey, value: openAIKey)
                }

                if let baseURL = ProcessInfo.processInfo.environment["CUSTOM_API_URL"] {
                    try KeychainManager.saveString(key: KeychainKeys.openAIBaseURL, value: baseURL)
                }

                if let model = ProcessInfo.processInfo.environment["LLM_MODEL"] {
                    try KeychainManager.saveString(key: KeychainKeys.llmModel, value: model)
                }

                logger.info("Environment API keys migrated to secure storage")
            } catch {
                logger.error("Failed to migrate API keys to Keychain: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Composio Configuration

    /// Composio API Key (retrieved from Keychain)
    static var composioAPIKey: String {
        // Priority order:
        // 1. Environment variable (for CI/CD or debug overrides)
        // 2. Keychain (production storage)

        if let envKey = ProcessInfo.processInfo.environment["COMPOSIO_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        if let keychainKey = KeychainManager.loadString(key: KeychainKeys.composioAPIKey) {
            return keychainKey
        }

        logger.error("Composio API key not found in Keychain or environment")
        return ""
    }

    /// Update Composio API key in Keychain
    static func setComposioAPIKey(_ key: String) throws {
        try KeychainManager.saveString(key: KeychainKeys.composioAPIKey, value: key)
        logger.info("Composio API key updated in Keychain")
    }

    // MARK: - OpenAI / LLM Configuration

    /// OpenAI API Key (or custom provider key)
    static var openAIAPIKey: String {
        if let envKey = ProcessInfo.processInfo.environment["CUSTOM_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        return KeychainManager.loadString(key: KeychainKeys.openAIAPIKey) ?? ""
    }

    /// Custom API Base URL
    static var openAIBaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["CUSTOM_API_URL"], !envURL.isEmpty {
            return envURL
        }

        return KeychainManager.loadString(key: KeychainKeys.openAIBaseURL) ?? ""
    }

    /// LLM Model name
    static var llmModel: String {
        if let envModel = ProcessInfo.processInfo.environment["LLM_MODEL"], !envModel.isEmpty {
            return envModel
        }

        return KeychainManager.loadString(key: KeychainKeys.llmModel) ?? ""
    }

    /// Update LLM configuration
    static func setLLMConfig(baseURL: String? = nil, model: String? = nil, apiKey: String? = nil) throws {
        if let baseURL = baseURL {
            try KeychainManager.saveString(key: KeychainKeys.openAIBaseURL, value: baseURL)
        }
        if let model = model {
            try KeychainManager.saveString(key: KeychainKeys.llmModel, value: model)
        }
        if let apiKey = apiKey {
            try KeychainManager.saveString(key: KeychainKeys.openAIAPIKey, value: apiKey)
        }
        logger.info("LLM configuration updated in Keychain")
    }

    // MARK: - OAuth Configuration

    /// OAuth callback URL scheme
    static let oauthCallbackScheme = "rube"

    /// OAuth callback URL
    static let oauthCallbackURL = "rube://oauth-callback"

    // MARK: - Debug Configuration

    /// Debug mode - enables verbose logging
    static var debugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Security Utilities

    /// Validate that all required keys are present
    static func validateConfiguration() -> Bool {
        let hasComposioKey = !composioAPIKey.isEmpty
        let hasOpenAIKey = !openAIAPIKey.isEmpty
        let hasBaseURL = !openAIBaseURL.isEmpty
        let hasModel = !llmModel.isEmpty

        let isValid = hasComposioKey && hasOpenAIKey && hasBaseURL && hasModel

        if !isValid {
            logger.error("Configuration validation failed - missing required keys")
        }

        return isValid
    }

    /// Clear all stored credentials (for logout or reset)
    static func clearAllCredentials() throws {
        try KeychainManager.delete(key: KeychainKeys.composioAPIKey)
        try KeychainManager.delete(key: KeychainKeys.openAIAPIKey)
        try KeychainManager.delete(key: KeychainKeys.openAIBaseURL)
        try KeychainManager.delete(key: KeychainKeys.llmModel)
        logger.info("All credentials cleared from Keychain")
    }
}
