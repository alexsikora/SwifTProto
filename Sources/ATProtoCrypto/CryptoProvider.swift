import Foundation

/// Protocol defining cross-platform cryptographic operations for the AT Protocol.
///
/// Implementations provide key generation, signing, verification, hashing,
/// and random byte generation. The default implementation uses swift-crypto
/// (Apple CryptoKit on Apple platforms).
public protocol CryptoProvider: Sendable {
    /// Generates a new P-256 (secp256r1) key pair.
    ///
    /// - Returns: A tuple containing the raw private key bytes and the
    ///   compressed public key bytes.
    func generateP256KeyPair() -> (privateKey: Data, publicKey: Data)

    /// Signs data using ES256 (ECDSA with P-256 and SHA-256).
    ///
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - privateKey: The raw P-256 private key bytes.
    /// - Returns: The DER-encoded ECDSA signature.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if signing fails.
    func sign(data: Data, privateKey: Data) throws -> Data

    /// Verifies an ES256 signature against data and a public key.
    ///
    /// - Parameters:
    ///   - signature: The DER-encoded ECDSA signature to verify.
    ///   - data: The data that was signed.
    ///   - publicKey: The compressed P-256 public key bytes.
    /// - Returns: `true` if the signature is valid, `false` otherwise.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if verification cannot be performed.
    func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool

    /// Computes the SHA-256 hash of the given data.
    ///
    /// - Parameter data: The data to hash.
    /// - Returns: The 32-byte SHA-256 digest.
    func sha256(data: Data) -> Data

    /// Generates cryptographically secure random bytes.
    ///
    /// - Parameter count: The number of random bytes to generate.
    /// - Returns: A `Data` value containing `count` random bytes.
    func generateRandomBytes(count: Int) -> Data
}
