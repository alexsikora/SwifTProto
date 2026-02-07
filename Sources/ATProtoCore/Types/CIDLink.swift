import Foundation

/// A Content Identifier (CID) link, used for content-addressed references
/// in the AT Protocol. CIDs reference DAG-CBOR encoded blocks.
///
/// In JSON, CID links are encoded as `{"$link": "<cid-string>"}`.
public struct CIDLink: Sendable, Hashable {
    public let string: String

    public init(_ string: String) {
        self.string = string
    }

    /// The CID as raw bytes (base32 decoded)
    public var bytes: Data? {
        // CIDv1 strings are multibase-encoded, typically base32lower
        guard !string.isEmpty else { return nil }

        // bafy... prefix indicates base32lower CIDv1
        if string.hasPrefix("bafy") || string.hasPrefix("b") {
            return decodeBase32Lower(String(string.dropFirst()))
        }

        // Qm... prefix indicates base58btc CIDv0
        return nil // CIDv0 decoding not implemented here
    }

    private func decodeBase32Lower(_ input: String) -> Data? {
        let alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        var bits = 0
        var buffer: UInt32 = 0
        var result = Data()

        for char in input {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            let value = UInt32(alphabet.distance(from: alphabet.startIndex, to: index))
            buffer = (buffer << 5) | value
            bits += 5

            if bits >= 8 {
                bits -= 8
                result.append(UInt8((buffer >> bits) & 0xFF))
            }
        }

        return result
    }
}

extension CIDLink: CustomStringConvertible {
    public var description: String { string }
}

extension CIDLink: Codable {
    private enum CodingKeys: String, CodingKey {
        case link = "$link"
    }

    public init(from decoder: Decoder) throws {
        // Try object form: {"$link": "..."}
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let link = try container.decode(String.self, forKey: .link)
            self.string = link
            return
        }

        // Try string form
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.string = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(string, forKey: .link)
    }
}
