import XCTest
@testable import ATProtoCore

final class ATURITests: XCTestCase {

    // MARK: - Valid AT URIs

    func testValidATURI_FullDID() {
        let str = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g"
        let uri = ATURI(str)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.string, "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g")
        XCTAssertEqual(uri?.authority, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual(uri?.collection?.string, "app.bsky.feed.post")
        XCTAssertEqual(uri?.recordKey, "3jt5tsfqwen2g")
    }

    func testValidATURI_HandleAuthority() {
        let str = "at://alice.bsky.social/app.bsky.feed.post/abc123"
        let uri = ATURI(str)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.authority, "alice.bsky.social")
        XCTAssertEqual(uri?.collection?.string, "app.bsky.feed.post")
        XCTAssertEqual(uri?.recordKey, "abc123")
    }

    func testValidATURI_AuthorityOnly() {
        let str = "at://did:plc:z72i7hdynmk6r22z27h6tvur"
        let uri = ATURI(str)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.authority, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertNil(uri?.collection)
        XCTAssertNil(uri?.recordKey)
    }

    func testValidATURI_AuthorityAndCollection() {
        let str = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post"
        let uri = ATURI(str)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.authority, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual(uri?.collection?.string, "app.bsky.feed.post")
        XCTAssertNil(uri?.recordKey)
    }

    func testValidATURI_HandleAuthorityOnly() {
        let str = "at://alice.bsky.social"
        let uri = ATURI(str)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.authority, "alice.bsky.social")
        XCTAssertNil(uri?.collection)
        XCTAssertNil(uri?.recordKey)
    }

    // MARK: - Invalid AT URIs

    func testNoSchemeIsInvalid() {
        let str = "did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g"
        XCTAssertNil(ATURI(str))
    }

    func testWrongSchemeIsInvalid() {
        let str = "http://did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertNil(ATURI(str))
    }

    func testEmptyAuthorityIsInvalid() {
        let str = "at://"
        XCTAssertNil(ATURI(str))
    }

    func testEmptyStringIsInvalid() {
        let str = ""
        XCTAssertNil(ATURI(str))
    }

    func testInvalidAuthorityIsInvalid() {
        let str = "at://notvalid"
        XCTAssertNil(ATURI(str))
    }

    func testHTTPSSchemeIsInvalid() {
        let str = "https://bsky.social"
        XCTAssertNil(ATURI(str))
    }

    // MARK: - DID / Handle Accessors

    func testDIDAccessor() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/abc"
        XCTAssertNotNil(uri.did)
        XCTAssertEqual(uri.did?.string, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertNil(uri.handle)
    }

    func testHandleAccessor() {
        let uri: ATURI = "at://alice.bsky.social/app.bsky.feed.post/abc"
        XCTAssertNotNil(uri.handle)
        XCTAssertEqual(uri.handle?.string, "alice.bsky.social")
        XCTAssertNil(uri.did)
    }

    // MARK: - Collection and RecordKey Extraction

    func testCollectionExtraction() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g"
        XCTAssertEqual(uri.collection?.string, "app.bsky.feed.post")
        XCTAssertEqual(uri.collection?.name, "post")
        XCTAssertEqual(uri.collection?.authority, "app.bsky.feed")
    }

    func testRecordKeyExtraction() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g"
        XCTAssertEqual(uri.recordKey, "3jt5tsfqwen2g")
    }

    func testNoRecordKey() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post"
        XCTAssertNil(uri.recordKey)
    }

    func testNoCollectionNoRecordKey() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertNil(uri.collection)
        XCTAssertNil(uri.recordKey)
    }

    // MARK: - Component-Based Initialization

    func testInitFromComponents_Full() {
        let collection: NSID = "app.bsky.feed.post"
        let uri = ATURI(authority: "did:plc:z72i7hdynmk6r22z27h6tvur", collection: collection, recordKey: "abc123")
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.string, "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/abc123")
    }

    func testInitFromComponents_AuthorityOnly() {
        let uri = ATURI(authority: "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.string, "at://did:plc:z72i7hdynmk6r22z27h6tvur")
    }

    func testInitFromComponents_AuthorityAndCollection() {
        let collection: NSID = "app.bsky.feed.post"
        let uri = ATURI(authority: "did:plc:z72i7hdynmk6r22z27h6tvur", collection: collection)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri?.string, "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post")
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jt5tsfqwen2g"
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ATURI.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
        XCTAssertEqual(original.authority, decoded.authority)
        XCTAssertEqual(original.collection, decoded.collection)
        XCTAssertEqual(original.recordKey, decoded.recordKey)
    }

    func testEncodesToString() throws {
        let uri: ATURI = "at://alice.bsky.social/app.bsky.feed.post/abc"
        let data = try JSONEncoder().encode(uri)
        let decodedString = try JSONDecoder().decode(String.self, from: data)
        XCTAssertEqual(decodedString, "at://alice.bsky.social/app.bsky.feed.post/abc")
    }

    func testDecodesFromString() throws {
        let json = "\"at://did:plc:z72i7hdynmk6r22z27h6tvur\""
        let data = json.data(using: .utf8)!
        let uri = try JSONDecoder().decode(ATURI.self, from: data)
        XCTAssertEqual(uri.authority, "did:plc:z72i7hdynmk6r22z27h6tvur")
    }

    func testDecodingInvalidATURIThrows() {
        let json = "\"http://example.com\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ATURI.self, from: data))
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/abc"
        let b: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/abc"
        let c: ATURI = "at://alice.bsky.social/app.bsky.feed.post/abc"

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - URL Property

    func testURLPropertyWithHandle() {
        let uri: ATURI = "at://alice.bsky.social"
        XCTAssertNotNil(uri.url)
    }

    func testURLPropertyWithDIDReturnsNil() {
        // Foundation's URL parser can't handle colons in DID authorities
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertNil(uri.url)
    }

    // MARK: - ExpressibleByStringLiteral

    func testStringLiteralInitialization() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/abc"
        XCTAssertEqual(uri.authority, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual(uri.collection?.string, "app.bsky.feed.post")
        XCTAssertEqual(uri.recordKey, "abc")
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let uri: ATURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertEqual(uri.description, "at://did:plc:z72i7hdynmk6r22z27h6tvur")
    }
}
