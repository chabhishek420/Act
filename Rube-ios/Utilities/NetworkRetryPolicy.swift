//
//  NetworkRetryPolicy.swift
//  Rube-ios
//
//  Utility for handling network failures with exponential backoff
//  Implements best practices for API call resilience
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.rube.ios", category: "NetworkRetry")

/// Errors that can occur during retry operations
enum RetryError: Error, LocalizedError {
    case maxAttemptsExceeded(underlyingError: Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded(let error):
            return "Network request failed after multiple attempts: \(error.localizedDescription)"
        case .cancelled:
            return "Network request was cancelled"
        }
    }
}

/// Configuration for retry behavior
struct RetryPolicy {
    /// Maximum number of retry attempts (default: 3)
    let maxAttempts: Int

    /// Initial delay before first retry in seconds (default: 2.0)
    let initialDelay: TimeInterval

    /// Multiplier for exponential backoff (default: 2.0)
    let backoffMultiplier: Double

    /// Maximum delay between retries in seconds (default: 30.0)
    let maxDelay: TimeInterval

    /// HTTP status codes that should trigger a retry
    let retryableStatusCodes: Set<Int>

    /// Default policy: 3 attempts with 2s, 4s, 8s delays
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 2.0,
        backoffMultiplier: 2.0,
        maxDelay: 30.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )

    /// Aggressive policy for critical operations: 5 attempts
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 30.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )

    /// Conservative policy for non-critical operations: 2 attempts
    static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 3.0,
        backoffMultiplier: 2.0,
        maxDelay: 30.0,
        retryableStatusCodes: [429, 503, 504]
    )

    /// Calculate delay for a given attempt number
    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }

    /// Determine if an error is retryable.
    /// This now handles URLError, common HTTP status codes, and can be customized.
    func isRetryable(_ error: Error) -> Bool {
        // 1. Check for system network errors (URLError)
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                 .notConnectedToInternet, .dnsLookupFailed, .internationalRoamingOff,
                 .callIsActive, .dataNotAllowed, .requestBodyStreamExhausted:
                return true
            default:
                return false
            }
        }

        // 2. Check for HTTP status codes if the error is an NSError with response metadata
        let nsError = error as NSError

        // Check "statusCode" key or "response" key commonly used by SDKs
        let statusCode = nsError.code
        if retryableStatusCodes.contains(statusCode) {
            return true
        }

        if let httpResponse = nsError.userInfo["response"] as? HTTPURLResponse {
            return retryableStatusCodes.contains(httpResponse.statusCode)
        }

        // 3. Fallback: check for common transient error patterns in the description
        let description = error.localizedDescription.lowercased()
        let transientKeywords = ["timeout", "timed out", "connection lost", "too many requests", "429", "503", "504"]

        if transientKeywords.contains(where: { description.contains($0) }) {
            return true
        }

        return false
    }
}

/// Utility for executing network requests with retry logic
enum NetworkRetry {

    /// Execute an async operation with automatic retry on failure
    /// - Parameters:
    ///   - policy: The retry policy to use (defaults to .default)
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: RetryError if all attempts fail
    static func execute<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...policy.maxAttempts {
            do {
                logger.info("Attempting network request (attempt \(attempt)/\(policy.maxAttempts))")
                let result = try await operation()

                if attempt > 1 {
                    logger.info("Network request succeeded on attempt \(attempt)")
                }

                return result

            } catch {
                lastError = error
                logger.warning("Network request failed (attempt \(attempt)): \(error.localizedDescription)")

                // Don't retry if error is not retryable
                if !policy.isRetryable(error) {
                    logger.info("Error is not retryable, failing immediately")
                    throw error
                }

                // Don't delay after the last attempt
                if attempt < policy.maxAttempts {
                    let delay = policy.delay(for: attempt)
                    logger.info("Retrying in \(String(format: "%.1f", delay))s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // All attempts failed
        logger.error("All \(policy.maxAttempts) attempts failed")
        throw RetryError.maxAttemptsExceeded(underlyingError: lastError ?? URLError(.unknown))
    }

    /// Execute an async operation with retry, supporting cancellation
    /// - Parameters:
    ///   - policy: The retry policy to use (defaults to .default)
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: RetryError if all attempts fail or operation is cancelled
    static func executeCancellable<T>(
        policy: RetryPolicy = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withTaskCancellationHandler {
            try await execute(policy: policy, operation: operation)
        } onCancel: {
            logger.info("Network retry operation cancelled")
        }
    }
}

// MARK: - URLSession Extension

extension URLSession {

    /// Perform a data request with automatic retry
    func dataWithRetry(
        for request: URLRequest,
        retryPolicy: RetryPolicy = .default
    ) async throws -> (Data, URLResponse) {
        try await NetworkRetry.execute(policy: retryPolicy) {
            try await self.data(for: request)
        }
    }

    /// Perform a data request from URL with automatic retry
    func dataWithRetry(
        from url: URL,
        retryPolicy: RetryPolicy = .default
    ) async throws -> (Data, URLResponse) {
        try await NetworkRetry.execute(policy: retryPolicy) {
            try await self.data(from: url)
        }
    }
}
