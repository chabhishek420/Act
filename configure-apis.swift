#!/usr/bin/env swift
//
//  configure-apis.swift
//  Configuration script to inject API keys into the app
//
//  Usage: swift configure-apis.swift
//

import Foundation
import Security

// Simple Keychain wrapper for standalone script
class SimpleKeychain {
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: "SimpleKeychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid string encoding"])
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "SimpleKeychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to save to Keychain: \(status)"])
        }
    }
}

// Configuration values
let config = [
    "com.rube.openai.baseurl": "http://143.198.174.251:8317/",
    "com.rube.openai.apikey": "anything",
    "com.rube.composio.apikey": "ak_zADvaco59jaMiHrqpjj4"
]

print("🔐 Configuring API keys in Keychain...")

for (key, value) in config {
    do {
        try SimpleKeychain.save(key: key, value: value)
        print("✅ Saved \(key)")
    } catch {
        print("❌ Failed to save \(key): \(error)")
    }
}

print("✨ Configuration complete!")
print("")
print("API Configuration:")
print("  • Custom API URL: http://143.198.174.251:8317/")
print("  • Custom API Key: anything")
print("  • Composio API Key: ak_zADvaco59jaMiHrqpjj4")
print("")
print("The app will now use these values instead of environment variables.")
