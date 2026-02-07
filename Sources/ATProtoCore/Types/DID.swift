import Foundation

/// A Decentralized Identifier (DID) as defined by the AT Protocol.
///
/// DIDs follow the pattern: `did:<method>:<method-specific-id>`
/// The AT Protocol primarily uses `did:plc` and `did:web` methods.
public struct DID: Sendable, Hashable {
    public let string: String
    public let method: Method
    public let identifier: String

    public enum Method: String, Sendable, Hashable {
        case plc
        case web
        case key
        case other
    }

    public init?(_ string: String) {
        guard string.hasPrefix("did:") else { return nil }

        let parts = string.split(separator: ":", maxSplits: 2)
        guard parts.count == 3 else { return nil }

        let methodStr = String(parts[1])
        let id = String(parts[2])

        // Validate method characters (lowercase alpha + digits)
        guard methodStr.allSatisfy({ $0.isLowercase || $0.isNumber }) else { return nil }

        // Validate identifier is not empty and contains valid characters
        guard !id.isEmpty else { return nil }

        self.string = string
        self.method = Method(rawValue: methodStr) ?? .other
        self.identifier = id
    }

    /// Whether this DID uses the `did:plc` method
    public var isPLC: Bool { method == .plc }

    /// Whether this DID uses the `did:web` method
    public var isWeb: Bool { method == .web }
}

extension DID: CustomStringConvertible {
    public var description: String { string }
}

extension DID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let did = DID(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid DID: \(value)"
            )
        }
        self = did
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension DID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let did = DID(value) else {
            preconditionFailure("Invalid DID string literal: \(value)")
        }
        self = did
    }
}
