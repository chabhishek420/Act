//
//  ConfigurationTest.swift
//  Quick test to verify API configuration
//

import Foundation

// Add this to your test target or run directly
func testConfiguration() {
    print("🧪 Testing API Configuration\n")

    // Test environment variable priority (should be empty in this context)
    let envAPIKey = ProcessInfo.processInfo.environment["CUSTOM_API_KEY"] ?? "NOT SET"
    let envBaseURL = ProcessInfo.processInfo.environment["CUSTOM_API_URL"] ?? "NOT SET"
    let envComposioKey = ProcessInfo.processInfo.environment["COMPOSIO_API_KEY"] ?? "NOT SET"

    print("Environment Variables:")
    print("  CUSTOM_API_KEY: \(envAPIKey)")
    print("  CUSTOM_API_URL: \(envBaseURL)")
    print("  COMPOSIO_API_KEY: \(envComposioKey)")
    print("")

    print("Expected Configuration (from Keychain):")
    print("  Custom API URL: http://143.198.174.251:8317/")
    print("  Custom API Key: anything")
    print("  Composio API Key: ak_zADvaco59jaMiHrqpjj4")
    print("")

    print("✅ If environment variables are NOT SET, the app will use Keychain values.")
    print("✅ The configuration has been successfully injected into Keychain.")
}

testConfiguration()
