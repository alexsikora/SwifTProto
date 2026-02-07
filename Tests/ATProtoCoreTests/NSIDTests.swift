import XCTest
@testable import ATProtoCore

final class NSIDTests: XCTestCase {

    // MARK: - Valid NSIDs

    func testValidNSID_CreateRecord() {
        let str = "com.atproto.repo.createRecord"
        let nsid = NSID(str)
        XCTAssertNotNil(nsid)
        XCTAssertEqual(nsid?.string, "com.atproto.repo.createRecord")
    }

    func testValidNSID_FeedPost() {
        let str = "app.bsky.feed.post"
        let nsid = NSID(str)
        XCTAssertNotNil(nsid)
        XCTAssertEqual(nsid?.string, "app.bsky.feed.post")
    }

    func testValidNSID_ThreeSegments() {
        let str = "com.example.thing"
        let nsid = NSID(str)
        XCTAssertNotNil(nsid)
        XCTAssertEqual(nsid?.string, "com.example.thing")
    }

    func testValidNSID_WithHyphensInAuthority() {
        let str = "com.my-domain.method"
        let nsid = NSID(str)
        XCTAssertNotNil(nsid)
        XCTAssertEqual(nsid?.string, "com.my-domain.method")
    }

    // MARK: - Invalid NSIDs

    func testSingleSegmentIsInvalid() {
        let str = "com"
        XCTAssertNil(NSID(str))
    }

    func testTwoSegmentsIsInvalid() {
        let str = "com.atproto"
        XCTAssertNil(NSID(str))
    }

    func testEmptyStringIsInvalid() {
        let str = ""
        XCTAssertNil(NSID(str))
    }

    func testSegmentStartsWithNumberIsInvalid() {
        let str = "123.456.method"
        XCTAssertNil(NSID(str))
    }

    func testNameSegmentStartsWithNumberIsInvalid() {
        let str = "com.example.123method"
        XCTAssertNil(NSID(str))
    }

    func testEmptySegmentIsInvalid() {
        let str = "com..createRecord"
        XCTAssertNil(NSID(str))
    }

    func testNameWithHyphenIsInvalid() {
        let str = "com.example.my-method"
        XCTAssertNil(NSID(str))
    }

    // MARK: - Authority Property

    func testAuthorityProperty() {
        let nsid: NSID = "com.atproto.repo.createRecord"
        XCTAssertEqual(nsid.authority, "com.atproto.repo")
    }

    func testAuthorityPropertyThreeSegments() {
        let nsid: NSID = "app.bsky.feed.post"
        XCTAssertEqual(nsid.authority, "app.bsky.feed")
    }

    func testAuthorityPropertyMinimal() {
        let nsid: NSID = "com.example.thing"
        XCTAssertEqual(nsid.authority, "com.example")
    }

    // MARK: - Name Property

    func testNameProperty() {
        let nsid: NSID = "com.atproto.repo.createRecord"
        XCTAssertEqual(nsid.name, "createRecord")
    }

    func testNamePropertyPost() {
        let nsid: NSID = "app.bsky.feed.post"
        XCTAssertEqual(nsid.name, "post")
    }

    // MARK: - Domain Authority (Reversed)

    func testDomainAuthority() {
        let nsid: NSID = "com.atproto.repo.createRecord"
        XCTAssertEqual(nsid.domainAuthority, "repo.atproto.com")
    }

    func testDomainAuthorityBsky() {
        let nsid: NSID = "app.bsky.feed.post"
        XCTAssertEqual(nsid.domainAuthority, "feed.bsky.app")
    }

    func testDomainAuthorityMinimal() {
        let nsid: NSID = "com.example.thing"
        XCTAssertEqual(nsid.domainAuthority, "example.com")
    }

    // MARK: - Segments Property

    func testSegmentsProperty() {
        let nsid: NSID = "com.atproto.repo.createRecord"
        XCTAssertEqual(nsid.segments, ["com", "atproto", "repo", "createRecord"])
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original: NSID = "com.atproto.repo.createRecord"
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NSID.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
        XCTAssertEqual(original.authority, decoded.authority)
        XCTAssertEqual(original.name, decoded.name)
    }

    func testEncodesToString() throws {
        let nsid: NSID = "app.bsky.feed.post"
        let data = try JSONEncoder().encode(nsid)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertEqual(jsonString, "\"app.bsky.feed.post\"")
    }

    func testDecodesFromString() throws {
        let json = "\"com.atproto.repo.createRecord\""
        let data = json.data(using: .utf8)!
        let nsid = try JSONDecoder().decode(NSID.self, from: data)
        XCTAssertEqual(nsid.string, "com.atproto.repo.createRecord")
    }

    func testDecodingInvalidNSIDThrows() {
        let json = "\"not.valid\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(NSID.self, from: data))
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a: NSID = "app.bsky.feed.post"
        let b: NSID = "app.bsky.feed.post"
        let c: NSID = "com.atproto.repo.createRecord"

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        let a: NSID = "app.bsky.feed.post"
        let b: NSID = "app.bsky.feed.post"
        let c: NSID = "com.atproto.repo.createRecord"

        var set = Set<NSID>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - ExpressibleByStringLiteral

    func testStringLiteralInitialization() {
        let nsid: NSID = "app.bsky.feed.post"
        XCTAssertEqual(nsid.string, "app.bsky.feed.post")
        XCTAssertEqual(nsid.name, "post")
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let nsid: NSID = "app.bsky.feed.post"
        XCTAssertEqual(nsid.description, "app.bsky.feed.post")
        XCTAssertEqual("\(nsid)", "app.bsky.feed.post")
    }
}
