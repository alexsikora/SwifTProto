import Foundation
import ATProtoCrypto

/// PKCE (Proof Key for Code Exchange) with S256 method only.
///
/// Generates a cryptographically random code verifier and its corresponding
/// SHA-256 challenge as required by RFC 7636. The AT Protocol mandates the
/// S256 challenge method.
public struct PKCE: Sendable {
    /// The code verifier string, a base64url-encoded 32-byte random value.
    public let codeVerifier: String

    /// The code challenge, the base64url-encoded SHA-256 hash of the verifier.
    public let codeChallenge: String

    /// The challenge method, always "S256" for AT Protocol OAuth.
    public let codeChallengeMethod: String = "S256"

    /// Creates a new PKCE challenge pair.
    ///
    /// - Parameter crypto: The cryptographic provider to use for random byte
    ///   generation and hashing. Defaults to ``DefaultCryptoProvider``.
    public init(crypto: CryptoProvider = DefaultCryptoProvider()) {
        // Generate 32 random bytes, base64url encode as verifier
        let randomBytes = crypto.generateRandomBytes(count: 32)
        self.codeVerifier = JWK.base64urlEncode(randomBytes)

        // SHA-256 hash of verifier, base64url encoded as challenge
        let hash = crypto.sha256(data: Data(codeVerifier.utf8))
        self.codeChallenge = JWK.base64urlEncode(hash)
    }
}
