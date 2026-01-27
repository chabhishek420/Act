//
//  AuthService.swift
//  Rube-ios
//
//  Appwrite authentication service
//

import Foundation
import Appwrite

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case emailNotVerified
    case networkError(Error)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let message):
            return message
        }
    }
}

@Observable
final class AuthService {
    static let shared = AuthService()

    private let client: Client
    private let account: Account

    private(set) var session: Session?
    private(set) var user: User<[String: AnyCodable]>?
    private(set) var jwt: String?

    var isAuthenticated: Bool { session != nil }
    var userEmail: String? { user?.email }
    var userId: String? { user?.id }

    private init() {
        client = Client()
            .setEndpoint(Config.appwriteEndpoint)
            .setProject(Config.appwriteProjectId)

        account = Account(client)

        // Check for existing session on init
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management

    @MainActor
    private func checkSession() async {
        do {
            let currentUser = try await account.get()
            self.user = currentUser

            // Get current session
            let currentSession = try await account.getSession(sessionId: "current")
            self.session = currentSession

            // Generate JWT for backend calls
            let jwtToken = try await account.createJWT()
            self.jwt = jwtToken.jwt
        } catch {
            // No active session
            self.session = nil
            self.user = nil
            self.jwt = nil
        }
    }

    // MARK: - Sign Up

    @MainActor
    func signUp(email: String, password: String, name: String? = nil) async throws {
        do {
            // Create account
            let newUser = try await account.create(
                userId: ID.unique(),
                email: email,
                password: password,
                name: name
            )
            self.user = newUser

            // Auto sign in after signup
            try await signIn(email: email, password: password)
        } catch let error as AppwriteError {
            throw AuthError.unknown(error.message)
        } catch {
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign In

    @MainActor
    func signIn(email: String, password: String) async throws {
        do {
            let newSession = try await account.createEmailPasswordSession(
                email: email,
                password: password
            )
            self.session = newSession

            // Get user info
            let currentUser = try await account.get()
            self.user = currentUser

            // Generate JWT for backend calls
            let jwtToken = try await account.createJWT()
            self.jwt = jwtToken.jwt
        } catch let error as AppwriteError {
            if error.message.contains("Invalid credentials") {
                throw AuthError.invalidCredentials
            }
            throw AuthError.unknown(error.message)
        } catch {
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Sign Out

    @MainActor
    func signOut() async {
        do {
            _ = try await account.deleteSession(sessionId: "current")
        } catch {
            // Ignore errors on sign out
        }

        session = nil
        user = nil
        jwt = nil
    }

    // MARK: - Refresh JWT

    @MainActor
    func refreshJWT() async throws {
        guard session != nil else {
            throw AuthError.notAuthenticated
        }

        do {
            let jwtToken = try await account.createJWT()
            self.jwt = jwtToken.jwt
        } catch {
            throw AuthError.networkError(error)
        }
    }

    // MARK: - Get Authorization Header

    func getAuthorizationHeader() async throws -> String {
        guard let jwt = jwt else {
            throw AuthError.notAuthenticated
        }
        return "Bearer \(jwt)"
    }

    // MARK: - Auto-Refresh JWT Helper

    /// Executes an HTTP request with automatic JWT refresh on 401 errors
    func performRequestWithAutoRefresh<T>(
        _ makeRequest: @escaping (String) async throws -> (T, HTTPURLResponse)
    ) async throws -> T {
        guard let jwt = jwt else {
            throw AuthError.notAuthenticated
        }

        // Try initial request
        let (result, response) = try await makeRequest(jwt)

        // If 401, refresh JWT and retry once
        if response.statusCode == 401 {
            try await refreshJWT()

            guard let newJWT = self.jwt else {
                throw AuthError.notAuthenticated
            }

            let (retryResult, retryResponse) = try await makeRequest(newJWT)

            guard retryResponse.statusCode != 401 else {
                throw AuthError.notAuthenticated
            }

            return retryResult
        }

        return result
    }
}
