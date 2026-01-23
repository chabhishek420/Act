//
//  OAuthService.swift
//  Rube-ios
//
//  OAuth and app connection service
//

import Foundation
import AuthenticationServices
import UIKit

enum OAuthError: LocalizedError {
    case cancelled
    case invalidURL
    case noCallback
    case failedToStart
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .invalidURL:
            return "Invalid authentication URL"
        case .noCallback:
            return "No callback URL received"
        case .failedToStart:
            return "Unable to start authentication session"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

@Observable
final class OAuthService: NSObject {
    private var authSession: ASWebAuthenticationSession?
    private(set) var isAuthenticating = false

    // MARK: - Start OAuth Flow

    @MainActor
    func startOAuth(url: URL, callbackScheme: String? = nil) async throws -> URL {
        isAuthenticating = true
        defer { isAuthenticating = false }

        let resolvedCallbackScheme = callbackScheme
            ?? Self.extractCallbackScheme(from: url)
            ?? "rube"

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: resolvedCallbackScheme
            ) { callbackURL, error in
                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: OAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.networkError(error))
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.noCallback)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // Allow SSO

            self.authSession = session
            let didStart = session.start()

            if !didStart {
                continuation.resume(throwing: OAuthError.failedToStart)
            }
        }
    }

    // Try to infer callback scheme from redirect_uri in the OAuth URL
    private static func extractCallbackScheme(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirect = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              let redirectURL = URL(string: redirect) else {
            return nil
        }

        return redirectURL.scheme
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
