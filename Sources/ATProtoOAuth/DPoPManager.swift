import Foundation
import ATProtoCore
import ATProtoCrypto

/// Manages DPoP (Demonstration of Proof-of-Possession) proofs.
///
/// Uses ES256 (P-256) for signing DPoP JWTs as required by the AT Protocol
/// OAuth specification. Each `DPoPManager` instance holds a unique key pair
/// that is bound to the token lifecycle.
///
/// DPoP proofs are short-lived JWTs that demonstrate the client possesses
/// the private key corresponding to the public key bound to the access token.
public actor DPoPManager {
    private let crypto: CryptoProvider
    private let privateKeyData: Data
    private let publicJWK: JWK
    private var serverNonce: String?

    /// Creates a new DPoP manager with a freshly generated ES256 key pair.
    ///
    /// - Parameter crypto: The cryptographic provider to use.
    ///   Defaults to ``DefaultCryptoProvider``.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the key pair cannot be generated
    ///   or the public key cannot be converted to JWK format.
    public init(crypto: CryptoProvider = DefaultCryptoProvider()) throws {
        self.crypto = crypto
        let keyPair = crypto.generateP256KeyPair()
        self.privateKeyData = keyPair.privateKey
        self.publicJWK = try JWK.fromP256PublicKey(keyPair.publicKey)
    }

    /// Generates a DPoP proof JWT for the given HTTP method and URL.
    ///
    /// The proof binds the request to the client's key pair and optionally
    /// to an access token via the `ath` (access token hash) claim.
    ///
    /// - Parameters:
    ///   - httpMethod: The HTTP method of the request (e.g., "POST", "GET").
    ///   - url: The URL of the request.
    ///   - accessToken: An optional access token to bind to the proof.
    ///     When provided, the `ath` claim is included as the base64url-encoded
    ///     SHA-256 hash of the token.
    /// - Returns: A signed DPoP proof JWT string.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if signing fails.
    public func generateProof(httpMethod: String, url: URL, accessToken: String? = nil) throws -> String {
        // Build JWT Header
        let headerDict: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": jwkDictionary(),
        ]

        // Build JWT Payload
        var payloadDict: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": httpMethod.uppercased(),
            "htu": normalizedHTU(url),
            "iat": Int(Date().timeIntervalSince1970),
        ]

        if let nonce = serverNonce {
            payloadDict["nonce"] = nonce
        }

        if let accessToken = accessToken {
            let tokenHash = crypto.sha256(data: Data(accessToken.utf8))
            payloadDict["ath"] = JWK.base64urlEncode(tokenHash)
        }

        // Encode header and payload
        let headerData = try JSONSerialization.data(withJSONObject: headerDict, options: .sortedKeys)
        let payloadData = try JSONSerialization.data(withJSONObject: payloadDict, options: .sortedKeys)

        let headerEncoded = JWK.base64urlEncode(headerData)
        let payloadEncoded = JWK.base64urlEncode(payloadData)

        let signingInput = "\(headerEncoded).\(payloadEncoded)"

        guard let signingInputData = signingInput.data(using: .utf8) else {
            throw ATProtoError.cryptoError("Failed to encode DPoP signing input")
        }

        // Sign with ES256
        let derSignature = try crypto.sign(data: signingInputData, privateKey: privateKeyData)
        let rawSignature = try derToRawES256Signature(derSignature)
        let signatureEncoded = JWK.base64urlEncode(rawSignature)

        return "\(signingInput).\(signatureEncoded)"
    }

    /// Updates the server nonce from a `DPoP-Nonce` response header.
    ///
    /// Authorization servers may require a server-provided nonce in DPoP proofs.
    /// When a response includes a `DPoP-Nonce` header, call this method to
    /// store it for subsequent proof generation.
    ///
    /// - Parameter nonce: The nonce value from the `DPoP-Nonce` header.
    public func updateNonce(_ nonce: String) {
        self.serverNonce = nonce
    }

    /// Computes the JWK thumbprint for token binding (RFC 7638).
    ///
    /// - Returns: The base64url-encoded SHA-256 thumbprint of the public JWK.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the thumbprint cannot be computed.
    public func getJWKThumbprint() throws -> String {
        return try publicJWK.thumbprint()
    }

    // MARK: - Private Helpers

    /// Builds a dictionary representation of the public JWK for JWT header inclusion.
    private func jwkDictionary() -> [String: String] {
        var dict: [String: String] = ["kty": publicJWK.kty]
        if let crv = publicJWK.crv { dict["crv"] = crv }
        if let x = publicJWK.x { dict["x"] = x }
        if let y = publicJWK.y { dict["y"] = y }
        return dict
    }

    /// Builds the `htu` claim value by stripping any query and fragment components.
    private func normalizedHTU(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? url.absoluteString
    }

    /// Converts a DER-encoded ECDSA signature to the raw R || S format
    /// required by JWS (RFC 7515) for ES256.
    ///
    /// Each of R and S is zero-padded to 32 bytes.
    private func derToRawES256Signature(_ der: Data) throws -> Data {
        let bytes = Array(der)

        // DER format: 0x30 <total-len> 0x02 <r-len> <r-bytes> 0x02 <s-len> <s-bytes>
        guard bytes.count >= 8,
              bytes[0] == 0x30,
              bytes[2] == 0x02 else {
            throw ATProtoError.cryptoError("Invalid DER signature format")
        }

        let rLength = Int(bytes[3])
        let rStart = 4
        let rEnd = rStart + rLength

        guard rEnd + 2 <= bytes.count,
              bytes[rEnd] == 0x02 else {
            throw ATProtoError.cryptoError("Invalid DER signature format: missing S integer")
        }

        let sLength = Int(bytes[rEnd + 1])
        let sStart = rEnd + 2
        let sEnd = sStart + sLength

        guard sEnd <= bytes.count else {
            throw ATProtoError.cryptoError("Invalid DER signature format: truncated")
        }

        // Extract R and S, stripping any leading zero padding from DER
        var r = Array(bytes[rStart..<rEnd])
        var s = Array(bytes[sStart..<sEnd])

        // Remove leading zero byte if present (DER uses it for positive sign)
        if r.count == 33 && r[0] == 0x00 { r.removeFirst() }
        if s.count == 33 && s[0] == 0x00 { s.removeFirst() }

        // Left-pad to 32 bytes
        while r.count < 32 { r.insert(0x00, at: 0) }
        while s.count < 32 { s.insert(0x00, at: 0) }

        return Data(r + s)
    }
}
