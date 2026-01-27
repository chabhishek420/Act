//
//  Config.swift
//  Rube-ios
//
//  Configuration for backend and Appwrite connections
//  Supports both development (localhost) and production (Vercel) environments
//

import Foundation

enum Config {
    // MARK: - Environment Detection
    #if DEBUG
    // Development: Use localhost when running on simulator
    private static let isDevelopment = true
    #else
    // Production: Use Vercel URL when running on real device / App Store build
    private static let isDevelopment = false
    #endif
    
    // MARK: - Backend URLs
    // TODO: Update productionURL when you deploy to Vercel
    private static let developmentURL = "http://localhost:3000"
    private static let productionURL = "https://your-app.vercel.app" // ← Update this after Vercel deploy
    
    static let backendURL = URL(string: isDevelopment ? developmentURL : productionURL)!

    // MARK: - Appwrite Configuration
    static let appwriteEndpoint = "https://nyc.cloud.appwrite.io/v1"
    static let appwriteProjectId = "6961fcac000432c6a72a"

    // MARK: - API Endpoints
    static var chatURL: URL { backendURL.appendingPathComponent("api/chat") }
    static var conversationsURL: URL { backendURL.appendingPathComponent("api/conversations") }
    static var appsConnectionURL: URL { backendURL.appendingPathComponent("api/apps/connection") }
    static var toolkitsURL: URL { backendURL.appendingPathComponent("api/toolkits") }
    
    // MARK: - Debug Helpers
    static func printCurrentConfig() {
        print("🔧 Rube Config:")
        print("   Environment: \(isDevelopment ? "Development" : "Production")")
        print("   Backend URL: \(backendURL.absoluteString)")
    }
}
