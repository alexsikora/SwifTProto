import Foundation

/// An AT Protocol URI.
///
/// Format: `at://<authority>/<collection>/<rkey>`
/// Examples:
/// - `at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g`
/// - `at://alice.bsky.social/app.bsky.feed.post/3jt5tsfqwen2g`
public struct ATURI: Sendable, Hashable {
    public let string: String
    public let authority: String
    public let collection: NSID?
    public let recordKey: String?

    public static let scheme = "at"

    public init?(_ string: String) {
        guard string.hasPrefix("at://") else { return nil }

        let remainder = String(string.dropFirst(5)) // drop "at://"
        guard !remainder.isEmpty else { return nil }

        let pathParts = remainder.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: false)
        guard !pathParts.isEmpty else { return nil }

        let authority = String(pathParts[0])

        // Authority must be a valid DID or handle
        guard DID(authority) != nil || Handle(authority) != nil else { return nil }

        var collection: NSID? = nil
        var recordKey: String? = nil

        if pathParts.count > 1 {
            let collStr = String(pathParts[1])
            if !collStr.isEmpty {
                guard let nsid = NSID(collStr) else { return nil }
                collection = nsid
            }
        }

        if pathParts.count > 2 {
            let rkStr = String(pathParts[2])
            if !rkStr.isEmpty {
                recordKey = rkStr
            }
        }

        self.string = string
        self.authority = authority
        self.collection = collection
        self.recordKey = recordKey
    }

    /// Creates an AT URI from components
    public init?(authority: String, collection: NSID? = nil, recordKey: String? = nil) {
        var uri = "at://\(authority)"
        if let collection = collection {
            uri += "/\(collection.string)"
            if let rkey = recordKey {
                uri += "/\(rkey)"
            }
        }
        self.init(uri)
    }

    /// The DID from the authority, if the authority is a DID
    public var did: DID? { DID(authority) }

    /// The handle from the authority, if the authority is a handle
    public var handle: Handle? { Handle(authority) }

    /// Returns the URI as a Foundation URL
    public var url: URL? { URL(string: string) }
}

extension ATURI: CustomStringConvertible {
    public var description: String { string }
}

extension ATURI: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let aturi = ATURI(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid AT URI: \(value)"
            )
        }
        self = aturi
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension ATURI: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let aturi = ATURI(value) else {
            preconditionFailure("Invalid ATURI string literal: \(value)")
        }
        self = aturi
    }
}
