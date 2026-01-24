//
//  Rube_iosApp.swift
//  Rube-ios
//
//  Main app entry point
//

import SwiftUI

@main
struct Rube_iosApp: App {

    init() {
        // Initialize secure configuration on first launch
        // This migrates API keys from hardcoded values to Keychain
        SecureConfig.setupDefaultsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
