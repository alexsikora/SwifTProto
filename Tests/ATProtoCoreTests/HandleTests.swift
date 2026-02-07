import XCTest
@testable import ATProtoCore

final class HandleTests: XCTestCase {

    // MARK: - Valid Handles

    func testValidHandle_AliceBskySocial() {
        let str = "alice.bsky.social"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "alice.bsky.social")
    }

    func testValidHandle_TwoLabels() {
        let str = "a.b"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "a.b")
    }

    func testValidHandle_ThreeLabels() {
        let str = "test.example.com"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "test.example.com")
    }

    func testValidHandle_WithHyphens() {
        let str = "my-name.example.com"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "my-name.example.com")
    }

    func testValidHandle_WithNumbers() {
        let str = "user123.test456.com"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "user123.test456.com")
    }

    // MARK: - Invalid Handles

    func testEmptyStringIsInvalid() {
        let str = ""
        XCTAssertNil(Handle(str))
    }

    func testTooLongHandleIsInvalid() {
        let longLabel = String(repeating: "a", count: 63)
        let tooLong = (0..<5).map { _ in longLabel }.joined(separator: ".")
        XCTAssertNil(Handle(tooLong))
    }

    func testSingleLabelIsInvalid() {
        let str = "localhost"
        XCTAssertNil(Handle(str))
    }

    func testNumericTLDIsInvalid() {
        let str = "user.123"
        XCTAssertNil(Handle(str))
    }

    func testStartsWithHyphenIsInvalid() {
        let str = "-alice.bsky.social"
        XCTAssertNil(Handle(str))
    }

    func testEndsWithHyphenLabelIsInvalid() {
        let str = "alice-.bsky.social"
        XCTAssertNil(Handle(str))
    }

    func testDoubleDotIsInvalid() {
        let str = "alice..social"
        XCTAssertNil(Handle(str))
    }

    func testStartsWithDotIsInvalid() {
        let str = ".alice.social"
        XCTAssertNil(Handle(str))
    }

    func testEndsWithDotIsInvalid() {
        let str = "alice.social."
        XCTAssertNil(Handle(str))
    }

    func testEmptyLabelIsInvalid() {
        let str = "alice..bsky.social"
        XCTAssertNil(Handle(str))
    }

    func testNonASCIICharactersInvalid() {
        let str = "alice\u{00E9}.bsky.social"
        XCTAssertNil(Handle(str))
    }

    func testUnderscoreIsInvalid() {
        let str = "alice_name.bsky.social"
        XCTAssertNil(Handle(str))
    }

    // MARK: - Case Normalization

    func testCaseNormalization() {
        let str = "Alice.Bsky.Social"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "alice.bsky.social")
    }

    func testAllUppercaseNormalized() {
        let str = "MYHANDLE.EXAMPLE.COM"
        let handle = Handle(str)
        XCTAssertNotNil(handle)
        XCTAssertEqual(handle?.string, "myhandle.example.com")
    }

    // MARK: - TLD Property

    func testTLDProperty() {
        let handle: Handle = "alice.bsky.social"
        XCTAssertEqual(handle.tld, "social")
    }

    func testTLDPropertyTwoLabels() {
        let handle: Handle = "name.com"
        XCTAssertEqual(handle.tld, "com")
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original: Handle = "alice.bsky.social"
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Handle.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
    }

    func testEncodesToString() throws {
        let handle: Handle = "alice.bsky.social"
        let data = try JSONEncoder().encode(handle)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertEqual(jsonString, "\"alice.bsky.social\"")
    }

    func testDecodesFromString() throws {
        let json = "\"bob.test.com\""
        let data = json.data(using: .utf8)!
        let handle = try JSONDecoder().decode(Handle.self, from: data)
        XCTAssertEqual(handle.string, "bob.test.com")
    }

    func testDecodingInvalidHandleThrows() {
        let json = "\"localhost\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Handle.self, from: data))
    }

    // MARK: - Hashable

    func testHashable() {
        let a: Handle = "alice.bsky.social"
        let b: Handle = "alice.bsky.social"
        let c: Handle = "bob.bsky.social"

        var set = Set<Handle>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2, "a and b should normalize to the same handle")
        XCTAssertTrue(set.contains(a))
        XCTAssertTrue(set.contains(c))
    }

    // MARK: - Equatable

    func testEquatable() {
        let strA = "alice.bsky.social"
        let strB = "ALICE.BSKY.SOCIAL" // normalized
        let strC = "bob.bsky.social"

        let a = Handle(strA)
        let b = Handle(strB)
        let c = Handle(strC)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - ExpressibleByStringLiteral

    func testStringLiteralInitialization() {
        let handle: Handle = "alice.bsky.social"
        XCTAssertEqual(handle.string, "alice.bsky.social")
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let handle: Handle = "alice.bsky.social"
        XCTAssertEqual(handle.description, "alice.bsky.social")
        XCTAssertEqual("\(handle)", "alice.bsky.social")
    }

    // MARK: - Boundary Cases

    func testMaxLengthHandle() {
        let label = String(repeating: "a", count: 63)
        let handle253 = "\(label).\(label).\(label).\(String(repeating: "b", count: 61))"
        XCTAssertEqual(handle253.count, 253)
        XCTAssertNotNil(Handle(handle253))
    }

    func testOverMaxLengthHandle() {
        let label = String(repeating: "a", count: 63)
        let handle254 = "\(label).\(label).\(label).\(String(repeating: "b", count: 62))"
        XCTAssertEqual(handle254.count, 254)
        XCTAssertNil(Handle(handle254))
    }
}
