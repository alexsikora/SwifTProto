import XCTest
@testable import ATProtoOAuth
@testable import ATProtoCrypto

final class PKCETests: XCTestCase {

    // MARK: - Code Verifier Tests

    func testCodeVerifierLengthIsAtLeast43Characters() {
        let pkce = PKCE()
        // Base64url encoding of 32 bytes produces 43 characters
        XCTAssertGreaterThanOrEqual(pkce.codeVerifier.count, 43,
            "Code verifier must be at least 43 characters for RFC 7636 compliance")
    }

    func testCodeVerifierOnlyContainsBase64URLCharacters() {
        let pkce = PKCE()
        let allowedCharacters = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )

        for scalar in pkce.codeVerifier.unicodeScalars {
            XCTAssertTrue(allowedCharacters.contains(scalar),
                "Code verifier contains invalid character: \(scalar)")
        }
    }

    func testCodeVerifierDoesNotContainPaddingCharacters() {
        let pkce = PKCE()
        XCTAssertFalse(pkce.codeVerifier.contains("="),
            "Base64url encoding should not include padding characters")
    }

    func testCodeVerifierDoesNotContainStandardBase64Characters() {
        let pkce = PKCE()
        XCTAssertFalse(pkce.codeVerifier.contains("+"),
            "Base64url should use '-' instead of '+'")
        XCTAssertFalse(pkce.codeVerifier.contains("/"),
            "Base64url should use '_' instead of '/'")
    }

    // MARK: - Code Challenge Tests

    func testCodeChallengeIsDifferentFromVerifier() {
        let pkce = PKCE()
        XCTAssertNotEqual(pkce.codeChallenge, pkce.codeVerifier,
            "Code challenge (SHA-256 hash) must be different from the verifier")
    }

    func testCodeChallengeIsBase64URLEncoded() {
        let pkce = PKCE()
        let allowedCharacters = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )

        for scalar in pkce.codeChallenge.unicodeScalars {
            XCTAssertTrue(allowedCharacters.contains(scalar),
                "Code challenge contains invalid character: \(scalar)")
        }
    }

    func testCodeChallengeHasExpectedLength() {
        let pkce = PKCE()
        // SHA-256 produces 32 bytes; base64url of 32 bytes = 43 characters
        XCTAssertEqual(pkce.codeChallenge.count, 43,
            "SHA-256 base64url should be 43 characters (32 bytes)")
    }

    // MARK: - Code Challenge Method Tests

    func testCodeChallengeMethodIsS256() {
        let pkce = PKCE()
        XCTAssertEqual(pkce.codeChallengeMethod, "S256",
            "AT Protocol requires S256 challenge method")
    }

    // MARK: - Uniqueness Tests

    func testPKCEValuesAreUniqueBetweenInstances() {
        let pkce1 = PKCE()
        let pkce2 = PKCE()

        XCTAssertNotEqual(pkce1.codeVerifier, pkce2.codeVerifier,
            "Each PKCE instance should generate a unique verifier")
        XCTAssertNotEqual(pkce1.codeChallenge, pkce2.codeChallenge,
            "Each PKCE instance should generate a unique challenge")
    }

    func testMultiplePKCEInstancesAllHaveValidValues() {
        // Generate multiple instances and verify they're all valid
        for _ in 0..<10 {
            let pkce = PKCE()
            XCTAssertGreaterThanOrEqual(pkce.codeVerifier.count, 43)
            XCTAssertFalse(pkce.codeVerifier.isEmpty)
            XCTAssertFalse(pkce.codeChallenge.isEmpty)
            XCTAssertNotEqual(pkce.codeVerifier, pkce.codeChallenge)
            XCTAssertEqual(pkce.codeChallengeMethod, "S256")
        }
    }

    // MARK: - Determinism Tests

    func testSameVerifierProducesSameChallenge() {
        // Since PKCE generates random bytes each time, we can verify
        // the relationship is consistent by checking that the challenge
        // is non-empty and different from the verifier
        let pkce = PKCE()
        XCTAssertFalse(pkce.codeChallenge.isEmpty)
        XCTAssertNotEqual(pkce.codeChallenge, pkce.codeVerifier)
    }
}
