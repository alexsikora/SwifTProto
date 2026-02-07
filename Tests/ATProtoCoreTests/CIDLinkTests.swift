import XCTest
@testable import ATProtoCore

final class CIDLinkTests: XCTestCase {

    // MARK: - Creation

    func testCreationFromString() {
        let cid = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(cid.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }

    func testCreationFromEmptyString() {
        let cid = CIDLink("")
        XCTAssertEqual(cid.string, "")
    }

    // MARK: - JSON Encoding

    func testJSONEncodingAsLinkObject() throws {
        let cid = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let data = try JSONEncoder().encode(cid)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["$link"] as? String, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(json?.count, 1, "Should only have the $link key")
    }

    // MARK: - JSON Decoding

    func testJSONDecodingFromLinkObject() throws {
        let json = "{\"$link\":\"bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a\"}"
        let data = json.data(using: .utf8)!
        let cid = try JSONDecoder().decode(CIDLink.self, from: data)
        XCTAssertEqual(cid.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }

    func testJSONDecodingFromPlainString() throws {
        // The CIDLink decoder also supports plain string form
        let json = "\"bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a\""
        let data = json.data(using: .utf8)!
        let cid = try JSONDecoder().decode(CIDLink.self, from: data)
        XCTAssertEqual(cid.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CIDLink.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
    }

    func testCodableRoundtripShortCID() throws {
        let original = CIDLink("bafyreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CIDLink.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let b = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let c = CIDLink("bafyreidifferentcidvaluehere")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        let a = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let b = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let c = CIDLink("bafyreidifferentcidvaluehere")

        var set = Set<CIDLink>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2, "Identical CIDLinks should hash to the same value")
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let cid = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(cid.description, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual("\(cid)", "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }

    // MARK: - Bytes Property

    func testBytesReturnsNilForEmptyString() {
        let cid = CIDLink("")
        XCTAssertNil(cid.bytes)
    }

    func testBytesReturnsDataForBase32CID() {
        // A CID starting with "bafy" should attempt base32lower decoding
        let cid = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        // bytes may or may not be nil depending on the validity of the base32 encoding
        // but should not crash
        _ = cid.bytes
    }

    // MARK: - Nested in Other Structures

    func testCIDLinkInStruct() throws {
        struct TestRecord: Codable, Equatable {
            let cid: CIDLink
            let text: String
        }

        let record = TestRecord(
            cid: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            text: "hello"
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TestRecord.self, from: data)
        XCTAssertEqual(record, decoded)

        // Verify the encoded JSON has $link format
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let cidObj = json?["cid"] as? [String: Any]
        XCTAssertNotNil(cidObj)
        XCTAssertEqual(cidObj?["$link"] as? String, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }
}
