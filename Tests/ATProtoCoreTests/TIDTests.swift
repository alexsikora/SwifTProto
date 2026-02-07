import XCTest
@testable import ATProtoCore

final class TIDTests: XCTestCase {

    // MARK: - TID.now()

    func testTIDNowCreatesValidTID() {
        let tid = TID.now()
        XCTAssertEqual(tid.string.count, TID.length)
        XCTAssertEqual(tid.string.count, 13)

        // Should be parseable back
        let parsed = TID(tid.string)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.string, tid.string)
    }

    func testTIDNowTimestampIsReasonable() {
        let before = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let tid = TID.now()
        let after = UInt64(Date().timeIntervalSince1970 * 1_000_000)

        XCTAssertGreaterThanOrEqual(tid.timestamp, before)
        XCTAssertLessThanOrEqual(tid.timestamp, after)
    }

    func testTIDNowWithClockID() {
        let tid = TID.now(clockID: 42)
        XCTAssertEqual(tid.clockID, 42)
    }

    // MARK: - Roundtrip: Timestamp + ClockID -> String -> Parse

    func testRoundtripFromComponents() {
        let timestamp: UInt64 = 1_700_000_000_000_000 // a specific microsecond timestamp
        let clockID: UInt16 = 7

        let tid = TID(timestamp: timestamp, clockID: clockID)
        XCTAssertEqual(tid.string.count, 13)
        XCTAssertEqual(tid.timestamp, timestamp)
        XCTAssertEqual(tid.clockID, clockID)

        // Parse the string back
        let parsed = TID(tid.string)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.timestamp, timestamp)
        XCTAssertEqual(parsed?.clockID, clockID)
        XCTAssertEqual(parsed?.string, tid.string)
    }

    func testRoundtripMultipleValues() {
        let testCases: [(UInt64, UInt16)] = [
            (0, 0),
            (1, 0),
            (1_000_000, 1),
            (1_700_000_000_000_000, 1023), // max clockID (10 bits)
            (1_234_567_890_123_456, 512),
        ]

        for (timestamp, clockID) in testCases {
            let tid = TID(timestamp: timestamp, clockID: clockID)
            let parsed = TID(tid.string)
            XCTAssertNotNil(parsed, "Failed to parse TID for timestamp=\(timestamp), clockID=\(clockID)")
            XCTAssertEqual(parsed?.timestamp, timestamp)
            XCTAssertEqual(parsed?.clockID, clockID)
        }
    }

    // MARK: - String Length

    func testStringLengthIsExactly13() {
        let tid = TID.now()
        XCTAssertEqual(tid.string.count, 13)
    }

    func testStringLengthFromComponents() {
        let tid = TID(timestamp: 999_999_999, clockID: 0)
        XCTAssertEqual(tid.string.count, 13)
    }

    // MARK: - Comparison (Sorting)

    func testComparison() {
        let earlier = TID(timestamp: 1_000_000, clockID: 0)
        let later = TID(timestamp: 2_000_000, clockID: 0)

        XCTAssertTrue(earlier < later)
        XCTAssertFalse(later < earlier)
        XCTAssertFalse(earlier < earlier)
    }

    func testSortingMultipleTIDs() {
        let t1 = TID(timestamp: 3_000_000, clockID: 0)
        let t2 = TID(timestamp: 1_000_000, clockID: 0)
        let t3 = TID(timestamp: 2_000_000, clockID: 0)

        let sorted = [t1, t2, t3].sorted()
        XCTAssertEqual(sorted[0].timestamp, 1_000_000)
        XCTAssertEqual(sorted[1].timestamp, 2_000_000)
        XCTAssertEqual(sorted[2].timestamp, 3_000_000)
    }

    func testComparisonSameTimestampDifferentClockID() {
        let a = TID(timestamp: 1_000_000, clockID: 0)
        let b = TID(timestamp: 1_000_000, clockID: 1)

        // String comparison should still work correctly
        // since clockID is in the lower bits
        XCTAssertTrue(a < b || b < a || a.string == b.string)
    }

    // MARK: - Date Extraction

    func testDateExtraction() {
        let timestamp: UInt64 = 1_700_000_000_000_000 // microseconds
        let tid = TID(timestamp: timestamp, clockID: 0)
        let expectedDate = Date(timeIntervalSince1970: 1_700_000_000.0)
        XCTAssertEqual(tid.date.timeIntervalSince1970, expectedDate.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDateRoundtrip() {
        let now = Date()
        let microseconds = UInt64(now.timeIntervalSince1970 * 1_000_000)
        let tid = TID(timestamp: microseconds, clockID: 0)
        XCTAssertEqual(tid.date.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Invalid TIDs

    func testWrongLengthIsInvalid() {
        XCTAssertNil(TID("short"))
        XCTAssertNil(TID("toolongstring12345"))
        XCTAssertNil(TID(""))
    }

    func testInvalidCharactersIsInvalid() {
        // TID uses base32 sortable: "234567abcdefghijklmnopqrstuvwxyz"
        // Characters '0', '1', 'A'-'Z' are not valid
        XCTAssertNil(TID("0000000000000")) // '0' is not in the alphabet
        XCTAssertNil(TID("1111111111111")) // '1' is not in the alphabet
        XCTAssertNil(TID("AAAAAAAAAAAAA")) // uppercase not valid
    }

    func testExactly13ButInvalidCharsIsInvalid() {
        XCTAssertNil(TID("!@#$%^&*()abc")) // special chars
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original = TID.now()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TID.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
        XCTAssertEqual(original.timestamp, decoded.timestamp)
        XCTAssertEqual(original.clockID, decoded.clockID)
    }

    func testEncodesToString() throws {
        let tid = TID(timestamp: 1_700_000_000_000_000, clockID: 0)
        let data = try JSONEncoder().encode(tid)
        let jsonString = String(data: data, encoding: .utf8)!
        // Should be a quoted string
        XCTAssertTrue(jsonString.hasPrefix("\""))
        XCTAssertTrue(jsonString.hasSuffix("\""))
        // The inner string should be 13 chars
        let inner = jsonString.dropFirst().dropLast()
        XCTAssertEqual(inner.count, 13)
    }

    func testDecodingInvalidTIDThrows() {
        let json = "\"tooshort\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(TID.self, from: data))
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a = TID(timestamp: 1_000_000, clockID: 5)
        let b = TID(timestamp: 1_000_000, clockID: 5)
        let c = TID(timestamp: 2_000_000, clockID: 5)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        let a = TID(timestamp: 1_000_000, clockID: 5)
        let b = TID(timestamp: 1_000_000, clockID: 5)
        let c = TID(timestamp: 2_000_000, clockID: 5)

        var set = Set<TID>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let tid = TID(timestamp: 1_700_000_000_000_000, clockID: 0)
        XCTAssertEqual(tid.description, tid.string)
        XCTAssertEqual("\(tid)", tid.string)
    }

    // MARK: - ClockID Masking

    func testClockIDMaskedTo10Bits() {
        // clockID should only use lowest 10 bits (max 1023)
        let tid = TID(timestamp: 1_000_000, clockID: 0xFFFF) // 65535
        XCTAssertEqual(tid.clockID, 0x3FF) // 1023 - only bottom 10 bits
    }

    // MARK: - Base32 Character Validation

    func testValidBase32Characters() {
        // All valid base32 sortable chars
        let validChars = "234567abcdefghijklmnopqrstuvwxyz"
        let tid = TID.now()
        for char in tid.string {
            XCTAssertTrue(validChars.contains(char), "TID contains invalid character: \(char)")
        }
    }
}
