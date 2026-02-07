import Foundation

/// A Timestamp Identifier (TID) used as record keys in the AT Protocol.
///
/// TIDs are 13-character strings encoding a microsecond timestamp and clock ID.
/// They use a base32-sortable encoding (`234567abcdefghijklmnopqrstuvwxyz`).
public struct TID: Sendable, Hashable, Comparable {
    public let string: String

    /// The timestamp in microseconds since Unix epoch
    public let timestamp: UInt64

    /// The clock identifier
    public let clockID: UInt16

    /// Base32 sortable character set used by TID encoding
    private static let base32Chars = Array("234567abcdefghijklmnopqrstuvwxyz")

    /// Length of a TID string
    public static let length = 13

    public init?(_ string: String) {
        guard string.count == Self.length else { return nil }
        guard string.allSatisfy({ Self.base32Chars.contains($0) }) else { return nil }

        // First character must be in range 2-b (timestamp high bit must be 0)
        guard let first = string.first,
              let idx = Self.base32Chars.firstIndex(of: first),
              idx < 16 else { return nil }

        // Decode the full 64-bit value
        var value: UInt64 = 0
        for char in string {
            guard let idx = Self.base32Chars.firstIndex(of: char) else { return nil }
            value = (value << 5) | UInt64(idx)
        }

        // Top 53 bits = timestamp, bottom 10 bits = clock ID
        self.timestamp = value >> 10
        self.clockID = UInt16(value & 0x3FF)
        self.string = string
    }

    /// Creates a TID from a timestamp and clock ID
    public init(timestamp: UInt64, clockID: UInt16) {
        let clk = UInt64(clockID & 0x3FF)
        let value = (timestamp << 10) | clk

        var result = ""
        var remaining = value
        for _ in 0..<Self.length {
            let idx = Int(remaining & 0x1F)
            result = String(Self.base32Chars[idx]) + result
            remaining >>= 5
        }

        self.string = result
        self.timestamp = timestamp
        self.clockID = clockID & 0x3FF
    }

    /// Creates a TID for the current time
    public static func now(clockID: UInt16 = 0) -> TID {
        let microseconds = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        return TID(timestamp: microseconds, clockID: clockID)
    }

    /// The date represented by this TID
    public var date: Date {
        Date(timeIntervalSince1970: Double(timestamp) / 1_000_000)
    }

    public static func < (lhs: TID, rhs: TID) -> Bool {
        lhs.string < rhs.string
    }
}

extension TID: CustomStringConvertible {
    public var description: String { string }
}

extension TID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let tid = TID(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid TID: \(value)"
            )
        }
        self = tid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}
