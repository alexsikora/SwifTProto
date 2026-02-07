import Foundation

/// Protocol for types that can be encoded to/from AT Protocol wire formats.
///
/// This extends Codable with AT Protocol-specific features like
/// `$type` discriminators for union types.
public protocol ATProtoCodable: Codable, Sendable {
    /// The lexicon type identifier (e.g., `app.bsky.feed.post`).
    /// Nil for types that don't carry a type discriminator.
    static var typeIdentifier: String? { get }
}

extension ATProtoCodable {
    public static var typeIdentifier: String? { nil }
}

/// A type-discriminated union value in the AT Protocol.
///
/// Used for encoding/decoding polymorphic types where the concrete type
/// is indicated by a `$type` field in the JSON.
public enum ATProtoUnion<T: ATProtoCodable>: Sendable, Codable {
    case known(T)
    case unknown(type: String, data: [String: AnyCodable])

    private enum CodingKeys: String, CodingKey {
        case type = "$type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeStr = try container.decodeIfPresent(String.self, forKey: .type)

        if typeStr == T.typeIdentifier || T.typeIdentifier == nil {
            let value = try T(from: decoder)
            self = .known(value)
        } else {
            let dynamicContainer = try decoder.singleValueContainer()
            let data = try dynamicContainer.decode([String: AnyCodable].self)
            self = .unknown(type: typeStr ?? "unknown", data: data)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .known(let value):
            try value.encode(to: encoder)
        case .unknown(_, let data):
            var container = encoder.singleValueContainer()
            try container.encode(data)
        }
    }
}

/// A type-erased Codable value for handling dynamic/unknown JSON.
public struct AnyCodable: Sendable, Hashable, Codable {
    public let value: AnyHashableSendable

    public init(_ value: some Sendable & Hashable & Codable) {
        self.value = AnyHashableSendable(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = AnyHashableSendable(NullValue.null)
        } else if let bool = try? container.decode(Bool.self) {
            self.value = AnyHashableSendable(bool)
        } else if let int = try? container.decode(Int.self) {
            self.value = AnyHashableSendable(int)
        } else if let double = try? container.decode(Double.self) {
            self.value = AnyHashableSendable(double)
        } else if let string = try? container.decode(String.self) {
            self.value = AnyHashableSendable(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = AnyHashableSendable(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = AnyHashableSendable(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported AnyCodable value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value.base {
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [AnyCodable]:
            try container.encode(v)
        case let v as [String: AnyCodable]:
            try container.encode(v)
        case is NullValue:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported AnyCodable value type"
                )
            )
        }
    }
}

/// Sentinel value representing JSON null
private enum NullValue: Hashable, Sendable, Codable {
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    init(from decoder: Decoder) throws {
        self = .null
    }
}

/// A type-erased Hashable+Sendable wrapper
public struct AnyHashableSendable: Hashable, Sendable {
    public let base: any Sendable

    private let _hash: @Sendable (inout Hasher) -> Void
    private let _equals: @Sendable (Any) -> Bool

    public init<T: Hashable & Sendable>(_ base: T) {
        self.base = base
        self._hash = { hasher in
            base.hash(into: &hasher)
        }
        self._equals = { other in
            guard let otherTyped = other as? T else { return false }
            return base == otherTyped
        }
    }

    public func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }

    public static func == (lhs: AnyHashableSendable, rhs: AnyHashableSendable) -> Bool {
        lhs._equals(rhs.base)
    }
}
