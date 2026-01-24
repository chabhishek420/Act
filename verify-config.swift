#!/usr/bin/env swift
//
//  verify-config.swift
//  Verification script to check API keys in Keychain
//
//  Usage: swift verify-config.swift
//

import Foundation
import Security

// Simple Keychain wrapper for standalone script
class SimpleKeychain {
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }
}

// Keys to check
let keys = [
    ("com.rube.openai.baseurl", "Custom API URL"),
    ("com.rube.openai.apikey", "Custom API Key"),
    ("com.rube.composio.apikey", "Composio API Key")
]

print("🔍 Verifying API Configuration in Keychain...\n")

var allFound = true
for (key, description) in keys {
    if let value = SimpleKeychain.load(key: key) {
        print("✅ \(description): \(value)")
    } else {
        print("❌ \(description): NOT FOUND")
        allFound = false
    }
}

print("")
if allFound {
    print("✨ All API keys are configured correctly!")
} else {
    print("⚠️ Some API keys are missing. Run configure-apis.swift to fix.")
}
