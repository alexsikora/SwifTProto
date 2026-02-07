import Foundation

/// A domain-based handle in the AT Protocol.
///
/// Handles are domain names that resolve to DIDs. They follow standard
/// domain name rules with additional AT Protocol constraints.
/// Example: `alice.bsky.social`
public struct Handle: Sendable, Hashable {
    public let string: String

    /// Maximum length of a handle in characters
    public static let maxLength = 253

    public init?(_ string: String) {
        let normalized = string.lowercased()

        guard Self.validate(normalized) else { return nil }

        self.string = normalized
    }

    private static func validate(_ handle: String) -> Bool {
        // Must not be empty and within length limits
        guard !handle.isEmpty, handle.count <= maxLength else { return false }

        // Must not start or end with a dot
        guard !handle.hasPrefix("."), !handle.hasSuffix(".") else { return false }

        let labels = handle.split(separator: ".", omittingEmptySubsequences: false)

        // Must have at least two labels (e.g., "name.tld")
        guard labels.count >= 2 else { return false }

        for label in labels {
            // Each label must be 1-63 characters
            guard !label.isEmpty, label.count <= 63 else { return false }

            // Labels must contain only alphanumerics and hyphens
            guard label.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else {
                return false
            }

            // Labels must not start or end with a hyphen
            guard !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
        }

        // TLD must not be all-numeric
        if let tld = labels.last {
            if tld.allSatisfy({ $0.isNumber }) { return false }
        }

        return true
    }

    /// The TLD portion of the handle
    public var tld: String? {
        string.split(separator: ".").last.map(String.init)
    }
}

extension Handle: CustomStringConvertible {
    public var description: String { string }
}

extension Handle: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let handle = Handle(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid handle: \(value)"
            )
        }
        self = handle
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

extension Handle: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        guard let handle = Handle(value) else {
            preconditionFailure("Invalid Handle string literal: \(value)")
        }
        self = handle
    }
}
