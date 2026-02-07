import Foundation
import ATProtoCore

/// Supported key algorithms for multikey encoding.
public enum KeyAlgorithm: String, Sendable, Hashable {
    /// NIST P-256 (secp256r1) elliptic curve
    case p256
    /// secp256k1 elliptic curve (used in Bitcoin/Ethereum)
    case secp256k1
}

/// Utilities for encoding and decoding public keys in the did:key multicodec format.
///
/// The did:key method encodes a public key directly in the DID string using
/// multicodec prefixes and base58btc encoding. This is used throughout the
/// AT Protocol for representing cryptographic keys in a compact, self-describing format.
///
/// Format: `did:key:z<base58btc(multicodec_prefix + compressed_public_key)>`
public enum MultikeyEncoder {

    // MARK: - Multicodec Prefixes

    /// Multicodec prefix for P-256 (0x1200 varint-encoded as [0x80, 0x24])
    private static let p256Prefix: [UInt8] = [0x80, 0x24]

    /// Multicodec prefix for secp256k1 (0xe7, 0x01)
    private static let secp256k1Prefix: [UInt8] = [0xe7, 0x01]

    // MARK: - Encoding

    /// Encodes a compressed P-256 public key as a `did:key` string.
    ///
    /// - Parameter compressedKey: The 33-byte compressed P-256 public key.
    /// - Returns: A `did:key` string in the format `did:key:z<base58btc-encoded-data>`.
    public static func encodeP256PublicKey(compressedKey: Data) -> String {
        var payload = Data(p256Prefix)
        payload.append(compressedKey)
        let encoded = base58btcEncode(payload)
        return "did:key:z\(encoded)"
    }

    /// Encodes a compressed secp256k1 public key as a `did:key` string.
    ///
    /// - Parameter compressedKey: The 33-byte compressed secp256k1 public key.
    /// - Returns: A `did:key` string in the format `did:key:z<base58btc-encoded-data>`.
    public static func encodeSecp256k1PublicKey(compressedKey: Data) -> String {
        var payload = Data(secp256k1Prefix)
        payload.append(compressedKey)
        let encoded = base58btcEncode(payload)
        return "did:key:z\(encoded)"
    }

    // MARK: - Decoding

    /// Decodes a `did:key` or bare multikey string into its algorithm and raw public key bytes.
    ///
    /// Accepts strings in the format `did:key:z<base58btc>` or bare `z<base58btc>`.
    ///
    /// - Parameter string: The multikey string to decode.
    /// - Returns: A tuple of the key algorithm and the raw compressed public key data.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the string format is invalid
    ///   or the multicodec prefix is unrecognized.
    public static func decodeMultikey(_ string: String) throws -> (algorithm: KeyAlgorithm, publicKey: Data) {
        // Strip did:key: prefix if present
        var keyPart = string
        if keyPart.hasPrefix("did:key:") {
            keyPart = String(keyPart.dropFirst("did:key:".count))
        }

        // Must start with 'z' (base58btc multibase prefix)
        guard keyPart.hasPrefix("z") else {
            throw ATProtoError.cryptoError("Multikey must use base58btc encoding (z prefix)")
        }
        keyPart = String(keyPart.dropFirst())

        // Base58btc decode
        guard let decoded = base58btcDecode(keyPart) else {
            throw ATProtoError.cryptoError("Invalid base58btc encoding in multikey")
        }

        guard decoded.count >= 2 else {
            throw ATProtoError.cryptoError("Multikey data too short")
        }

        // Identify algorithm from multicodec prefix
        let prefixBytes = [decoded[0], decoded[1]]
        let publicKeyData = decoded.dropFirst(2)

        if prefixBytes == p256Prefix {
            return (algorithm: .p256, publicKey: Data(publicKeyData))
        } else if prefixBytes == secp256k1Prefix {
            return (algorithm: .secp256k1, publicKey: Data(publicKeyData))
        } else {
            throw ATProtoError.unsupportedAlgorithm(
                "Unknown multicodec prefix: [0x\(String(prefixBytes[0], radix: 16)), 0x\(String(prefixBytes[1], radix: 16))]"
            )
        }
    }

    // MARK: - Base58btc

    /// The Base58btc alphabet (Bitcoin variant).
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    /// Encodes data using Base58btc (Bitcoin's base58 alphabet).
    ///
    /// - Parameter data: The data to encode.
    /// - Returns: The base58btc-encoded string.
    public static func base58btcEncode(_ data: Data) -> String {
        var bytes = Array(data)
        var result = [Character]()

        // Count leading zeros
        var leadingZeros = 0
        for byte in bytes {
            if byte == 0 { leadingZeros += 1 } else { break }
        }

        // Convert to base58
        while !bytes.isEmpty {
            var carry = 0
            var newBytes = [UInt8]()
            for byte in bytes {
                carry = carry * 256 + Int(byte)
                if !newBytes.isEmpty || carry / 58 > 0 {
                    newBytes.append(UInt8(carry / 58))
                }
                carry = carry % 58
            }
            result.append(base58Alphabet[carry])
            bytes = newBytes
        }

        // Add leading '1's for leading zero bytes
        for _ in 0..<leadingZeros {
            result.append(base58Alphabet[0])
        }

        return String(result.reversed())
    }

    /// Decodes a Base58btc-encoded string.
    ///
    /// - Parameter string: The base58btc-encoded string.
    /// - Returns: The decoded data, or `nil` if the string contains invalid characters.
    public static func base58btcDecode(_ string: String) -> Data? {
        var result = [UInt8]()

        // Count leading '1's (represent leading zero bytes)
        var leadingOnes = 0
        for char in string {
            if char == "1" { leadingOnes += 1 } else { break }
        }

        // Convert from base58
        for char in string {
            guard let index = base58Alphabet.firstIndex(of: char) else { return nil }
            var carry = base58Alphabet.distance(from: base58Alphabet.startIndex, to: index)

            // Multiply existing result by 58 and add carry
            var i = result.count - 1
            while i >= 0 {
                carry += Int(result[i]) * 58
                result[i] = UInt8(carry & 0xFF)
                carry >>= 8
                i -= 1
            }

            while carry > 0 {
                result.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }

        // Prepend leading zero bytes
        let leadingZeros = [UInt8](repeating: 0, count: leadingOnes)
        return Data(leadingZeros + result)
    }
}
