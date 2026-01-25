//
//  NetworkRetryTests.swift
//  Rube-iosTests
//
//  Tests for NetworkRetry utility and RetryPolicy
//

import XCTest
@testable import Rube_ios

final class NetworkRetryTests: XCTestCase {

    func testRetrySuccessAfterFailure() async throws {
        var attempts = 0
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.1, // Fast tests
            backoffMultiplier: 2.0,
            maxDelay: 1.0,
            retryableStatusCodes: [500]
        )

        let result = try await NetworkRetry.execute(policy: policy) {
            attempts += 1
            if attempts < 2 {
                throw URLError(.timedOut)
            }
            return "success"
        }

        XCTAssertEqual(result, "success")
        XCTAssertEqual(attempts, 2)
    }

    func testMaxAttemptsExceeded() async throws {
        var attempts = 0
        let policy = RetryPolicy(
            maxAttempts: 2,
            initialDelay: 0.1,
            backoffMultiplier: 2.0,
            maxDelay: 1.0,
            retryableStatusCodes: [500]
        )

        do {
            _ = try await NetworkRetry.execute(policy: policy) {
                attempts += 1
                throw URLError(.timedOut)
            }
            XCTFail("Should have thrown maxAttemptsExceeded")
        } catch let error as RetryError {
            if case .maxAttemptsExceeded(let underlying) = error {
                XCTAssertEqual((underlying as? URLError)?.code, .timedOut)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }

        XCTAssertEqual(attempts, 2)
    }

    func testNonRetryableError() async throws {
        var attempts = 0
        let policy = RetryPolicy(
            maxAttempts: 3,
            initialDelay: 0.1,
            backoffMultiplier: 2.0,
            maxDelay: 1.0,
            retryableStatusCodes: [500]
        )

        do {
            _ = try await NetworkRetry.execute(policy: policy) {
                attempts += 1
                throw URLError(.badURL) // Not retryable in policy
            }
            XCTFail("Should have thrown badURL immediately")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL)
        }

        XCTAssertEqual(attempts, 1)
    }

    func testKeywordBasedRetry() throws {
        let policy = RetryPolicy.default
        let error = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "The request timed out"])

        XCTAssertTrue(policy.isRetryable(error))
    }
}
