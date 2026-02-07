import Foundation

/// A Namespaced Identifier (NSID) used in the AT Protocol for method
/// and record type identification.
///
/// NSIDs use reverse domain notation: `com.atproto.repo.createRecord`
/// Format: `<authority>.<name>` where authority is reversed domain segments.
public struct NSID: Sendable, Hashable {
    public let string: String

    /// The authority portion (reversed domain), e.g., `com.atproto.repo`
    public let authority: String

    /// The name/method portion, e.g., `createRecord`
    public let name: String

    public init?(_ string: String) {
        guard Self.validate(string) else { return nil }

        let segments = string.split(separator: ".")
        guard segments.count >= 3 else { return nil }

        self.string = string
        self.name = String(segments.last!)
        self.authority = segments.dropLast().joined(separator: ".")
    }

    private static func validate(_ nsid: String) -> Bool {
        // Overall length check
        guard nsid.count <= 317 else { return false }

        let segments = nsid.split(separator: ".", omittingEmptySubsequences: false)

        // Must have at least 3 segments (domain + tld + name)
        guard segments.count >= 3 else { return false }

        // Check authority segments (all but the last)
        for segment in segments.dropLast() {
            guard !segment.isEmpty, segment.count <= 63 else { return false }
            guard segment.first?.isLetter == true else { return false }
            guard segment.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return false }
        }

        // Check name segment (the last one)
        if let nameSeg = segments.last {
            guard !nameSeg.isEmpty, nameSeg.count <= 63 else { return false }
            guard nameSeg.first?.isLetter == true else { return false }
            guard nameSeg.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        }

        return true
    }

    /// Returns the segments of the NSID
    public var segments: [String] {
        string.split(separator: ".").map(String.init)
    }

    /// Returns the domain authority in normal (non-reversed) order
    public var domainAuthority: String {
        let authoritySegments = authority.split(separator: ".")
        return authoritySegments.reversed().joined(separator: ".")
    }
}

extension NSID: CustomStringConvertible {
    public var description: String { string }
}

extension NSID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let nsid = NSID(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid NSID: \(value)"
            )
        }
        self = nsid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension NSID: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let nsid = NSID(value) else {
            preconditionFailure("Invalid NSID string literal: \(value)")
        }
        self = nsid
    }
}
