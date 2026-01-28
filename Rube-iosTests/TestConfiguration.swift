// TestConfiguration.swift
// Rube-iosTests
//
// Test configuration with API keys and endpoints for testing
//

import Foundation

struct TestConfiguration {
    // Composio API Configuration
    static let composioAPIKey = "ak_zADvaco59jaMiHrqpjj4"
    static let composioBaseURL = "https://api.composio.dev"

    // Custom LLM Configuration
    static let customAPIKey = "anything"
    static let customBaseURL = "http://143.198.174.251:8317"
    static let customModel = "gemini-claude-opus-4-5-thinking"

    // Test user IDs
    static let testUserId = "test_integration_user"
    static let githubTestUser = "roshsharma.com@gmail.com"
    static let defaultUser = "default_user"
}