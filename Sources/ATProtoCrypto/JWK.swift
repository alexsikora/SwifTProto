import Foundation
import Crypto
import ATProtoCore

/// A JSON Web Key (JWK) as defined by RFC 7517.
///
/// Supports P-256 elliptic curve keys used in the AT Protocol for OAuth
/// DPoP proofs and other cryptographic operations.
public struct JWK: Codable, Sendable, Hashable {
    /// Key type (e.g., "EC" for elliptic curve).
    public let kty: String

    /// Curve name (e.g., "P-256").
    public let crv: String?

    /// The x coordinate of the EC public key (base64url-encoded).
    public let x: String?

    /// The y coordinate of the EC public key (base64url-encoded).
    public let y: String?

    /// The private key value for EC keys (base64url-encoded). Optional; only present for private keys.
    public let d: String?

    /// Key ID.
    public let kid: String?

    /// Intended use of the key (e.g., "sig" for signing).
    public let use: String?

    /// Algorithm intended for use with the key (e.g., "ES256").
    public let alg: String?

    public init(
        kty: String,
        crv: String? = nil,
        x: String? = nil,
        y: String? = nil,
        d: String? = nil,
        kid: String? = nil,
        use: String? = nil,
        alg: String? = nil
    ) {
        self.kty = kty
        self.crv = crv
        self.x = x
        self.y = y
        self.d = d
        self.kid = kid
        self.use = use
        self.alg = alg
    }

    // MARK: - Factory Methods

    /// Creates a JWK from a raw P-256 private key.
    ///
    /// The private key is expected in raw representation (32 bytes of the scalar value).
    /// The corresponding public key coordinates are derived automatically.
    ///
    /// - Parameter privateKeyData: The raw P-256 private key bytes (32 bytes).
    /// - Returns: A JWK containing both private and public key components.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the key data is invalid.
    public static func fromP256PrivateKey(_ privateKeyData: Data) throws -> JWK {
        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        } catch {
            throw ATProtoError.cryptoError("Invalid P-256 private key data: \(error)")
        }

        let publicKey = privateKey.publicKey
        let rawPublic = publicKey.x963Representation

        // x963 format: 0x04 || x (32 bytes) || y (32 bytes)
        let xData = rawPublic[1..<33]
        let yData = rawPublic[33..<65]

        return JWK(
            kty: "EC",
            crv: "P-256",
            x: base64urlEncode(Data(xData)),
            y: base64urlEncode(Data(yData)),
            d: base64urlEncode(privateKeyData),
            alg: "ES256"
        )
    }

    /// Creates a JWK from a P-256 public key.
    ///
    /// Accepts either compressed (33 bytes) or uncompressed (65 bytes, x963) format.
    ///
    /// - Parameter publicKeyData: The P-256 public key bytes.
    /// - Returns: A JWK containing only public key components.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the key data is invalid.
    public static func fromP256PublicKey(_ publicKeyData: Data) throws -> JWK {
        let publicKey: P256.Signing.PublicKey
        do {
            if publicKeyData.count == 33 {
                publicKey = try P256.Signing.PublicKey(compressedRepresentation: publicKeyData)
            } else {
                publicKey = try P256.Signing.PublicKey(x963Representation: publicKeyData)
            }
        } catch {
            throw ATProtoError.cryptoError("Invalid P-256 public key data: \(error)")
        }

        let rawPublic = publicKey.x963Representation

        // x963 format: 0x04 || x (32 bytes) || y (32 bytes)
        let xData = rawPublic[1..<33]
        let yData = rawPublic[33..<65]

        return JWK(
            kty: "EC",
            crv: "P-256",
            x: base64urlEncode(Data(xData)),
            y: base64urlEncode(Data(yData)),
            alg: "ES256"
        )
    }

    // MARK: - JWK Thumbprint

    /// Computes the JWK thumbprint as defined by RFC 7638.
    ///
    /// The thumbprint is the SHA-256 hash of the canonical JSON representation
    /// of the required members for the key type, base64url-encoded.
    ///
    /// For EC keys, the required members are: `crv`, `kty`, `x`, `y`
    /// (in lexicographic order).
    ///
    /// - Returns: The base64url-encoded JWK thumbprint string.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if required fields are missing
    ///   or serialization fails.
    public func thumbprint() throws -> String {
        let canonicalJSON: String

        switch kty {
        case "EC":
            guard let crv = crv, let x = x, let y = y else {
                throw ATProtoError.cryptoError("EC JWK missing required fields for thumbprint (crv, x, y)")
            }
            // RFC 7638: members must be in lexicographic order
            // For EC: crv, kty, x, y
            canonicalJSON = "{\"crv\":\"\(crv)\",\"kty\":\"\(kty)\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"

        default:
            throw ATProtoError.cryptoError("JWK thumbprint not supported for key type: \(kty)")
        }

        guard let jsonData = canonicalJSON.data(using: .utf8) else {
            throw ATProtoError.cryptoError("Failed to encode JWK thumbprint JSON")
        }

        let digest = SHA256.hash(data: jsonData)
        return JWK.base64urlEncode(Data(digest))
    }

    // MARK: - Base64url Utilities

    /// Encodes data using base64url encoding (RFC 4648 Section 5) without padding.
    ///
    /// - Parameter data: The data to encode.
    /// - Returns: The base64url-encoded string with no padding characters.
    public static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decodes a base64url-encoded string (RFC 4648 Section 5).
    ///
    /// Handles both padded and unpadded input.
    ///
    /// - Parameter string: The base64url-encoded string.
    /// - Returns: The decoded data, or `nil` if decoding fails.
    public static func base64urlDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}
