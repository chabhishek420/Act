//
//  SecureConfigTests.swift
//  Rube-iosTests
//
//  Tests for SecureConfig and Keychain migration logic
//

import XCTest
@testable import Rube_ios

final class SecureConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear Keychain before each test to ensure predictable state
        try? SecureConfig.clearAllCredentials()
    }

    override func tearDown() {
        try? SecureConfig.clearAllCredentials()
        super.tearDown()
    }

    func testMigrationFromEnvironment() throws {
        // 1. Set environment variables
        setenv("COMPOSIO_API_KEY", "test_key", 1)
        setenv("CUSTOM_API_KEY", "test_openai_key", 1)

        // 2. Run setup
        SecureConfig.setupDefaultsIfNeeded()

        // 3. Verify Keychain storage
        XCTAssertEqual(SecureConfig.composioAPIKey, "test_key")
        XCTAssertEqual(SecureConfig.openAIAPIKey, "test_openai_key")

        // 4. Verify Keychain persistence (by clearing env and checking SecureConfig again)
        unsetenv("COMPOSIO_API_KEY")
        XCTAssertEqual(SecureConfig.composioAPIKey, "test_key")
    }

    func testConfigValidation() throws {
        // Initial state should be invalid (all empty)
        XCTAssertFalse(SecureConfig.validateConfiguration())

        // Set all required keys
        try SecureConfig.setComposioAPIKey("valid_key")
        try SecureConfig.setLLMConfig(baseURL: "https://api.example.com", model: "gpt-4", apiKey: "valid_openai_key")

        // Should now be valid
        XCTAssertTrue(SecureConfig.validateConfiguration())
    }

    func testEnvironmentOverride() throws {
        // 1. Set Keychain key
        try SecureConfig.setComposioAPIKey("keychain_key")

        // 2. Verify Keychain value is returned
        XCTAssertEqual(SecureConfig.composioAPIKey, "keychain_key")

        // 3. Set Environment override
        setenv("COMPOSIO_API_KEY", "env_override", 1)

        // 4. Verify Environment takes priority
        XCTAssertEqual(SecureConfig.composioAPIKey, "env_override")

        unsetenv("COMPOSIO_API_KEY")
    }
}
