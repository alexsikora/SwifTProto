import Foundation
import Crypto
import ATProtoCore

/// Default ``CryptoProvider`` implementation using swift-crypto (CryptoKit on Apple platforms).
///
/// Uses P256 for key generation and ECDSA signing, and SHA256 for hashing.
/// All operations are synchronous.
public struct DefaultCryptoProvider: CryptoProvider, Sendable {

    public init() {}

    // MARK: - Key Generation

    public func generateP256KeyPair() -> (privateKey: Data, publicKey: Data) {
        let privateKey = P256.Signing.PrivateKey()
        let privateKeyData = Data(privateKey.rawRepresentation)
        let publicKeyData = Data(privateKey.publicKey.compressedRepresentation)
        return (privateKey: privateKeyData, publicKey: publicKeyData)
    }

    // MARK: - Signing

    public func sign(data: Data, privateKey: Data) throws -> Data {
        let key: P256.Signing.PrivateKey
        do {
            key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        } catch {
            throw ATProtoError.cryptoError("Failed to import P-256 private key: \(error)")
        }

        let signature: P256.Signing.ECDSASignature
        do {
            signature = try key.signature(for: data)
        } catch {
            throw ATProtoError.cryptoError("Failed to sign data: \(error)")
        }

        return Data(signature.derRepresentation)
    }

    // MARK: - Verification

    public func verify(signature: Data, data: Data, publicKey: Data) throws -> Bool {
        let key: P256.Signing.PublicKey
        do {
            key = try P256.Signing.PublicKey(compressedRepresentation: publicKey)
        } catch {
            throw ATProtoError.cryptoError("Failed to import P-256 public key: \(error)")
        }

        let ecdsaSignature: P256.Signing.ECDSASignature
        do {
            ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
        } catch {
            throw ATProtoError.cryptoError("Failed to parse DER signature: \(error)")
        }

        return key.isValidSignature(ecdsaSignature, for: data)
    }

    // MARK: - Hashing

    public func sha256(data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }

    // MARK: - Random Bytes

    public func generateRandomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            bytes[i] = UInt8.random(in: 0...255)
        }
        return Data(bytes)
    }
}
