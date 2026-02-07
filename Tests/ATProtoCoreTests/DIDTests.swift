import XCTest
@testable import ATProtoCore

final class DIDTests: XCTestCase {

    // MARK: - Valid DID Parsing

    func testValidPLCDID() {
        let str = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let did = DID(str)
        XCTAssertNotNil(did)
        XCTAssertEqual(did?.string, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual(did?.method, .plc)
        XCTAssertEqual(did?.identifier, "z72i7hdynmk6r22z27h6tvur")
    }

    func testValidWebDID() {
        let str = "did:web:example.com"
        let did = DID(str)
        XCTAssertNotNil(did)
        XCTAssertEqual(did?.string, "did:web:example.com")
        XCTAssertEqual(did?.method, .web)
        XCTAssertEqual(did?.identifier, "example.com")
    }

    func testValidKeyDID() {
        let str = "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"
        let did = DID(str)
        XCTAssertNotNil(did)
        XCTAssertEqual(did?.string, "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")
        XCTAssertEqual(did?.method, .key)
        XCTAssertEqual(did?.identifier, "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF")
    }

    func testUnknownMethodDID() {
        let str = "did:example:abc123"
        let did = DID(str)
        XCTAssertNotNil(did)
        XCTAssertEqual(did?.method, .other)
        XCTAssertEqual(did?.identifier, "abc123")
    }

    // MARK: - Invalid DID Parsing

    func testEmptyStringIsInvalid() {
        let str = ""
        XCTAssertNil(DID(str))
    }

    func testNoPrefixIsInvalid() {
        let str = "plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertNil(DID(str))
    }

    func testMissingMethodIsInvalid() {
        let str = "did::identifier"
        XCTAssertNil(DID(str))
    }

    func testMissingIdentifierIsInvalid() {
        let str = "did:plc:"
        XCTAssertNil(DID(str))
    }

    func testSingleColonIsInvalid() {
        let str = "did:plc"
        XCTAssertNil(DID(str))
    }

    func testJustPrefixIsInvalid() {
        let str = "did:"
        XCTAssertNil(DID(str))
    }

    func testNonDIDStringIsInvalid() {
        let str = "not-a-did"
        XCTAssertNil(DID(str))
    }

    // MARK: - Method Detection

    func testIsPLC() {
        let did: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertTrue(did.isPLC)
        XCTAssertFalse(did.isWeb)
    }

    func testIsWeb() {
        let did: DID = "did:web:example.com"
        XCTAssertTrue(did.isWeb)
        XCTAssertFalse(did.isPLC)
    }

    func testIsNeitherPLCNorWeb() {
        let did: DID = "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"
        XCTAssertFalse(did.isPLC)
        XCTAssertFalse(did.isWeb)
    }

    // MARK: - Codable Roundtrip

    func testCodableRoundtrip() throws {
        let original: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DID.self, from: data)
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.string, decoded.string)
        XCTAssertEqual(original.method, decoded.method)
        XCTAssertEqual(original.identifier, decoded.identifier)
    }

    func testEncodesToString() throws {
        let did: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let data = try JSONEncoder().encode(did)
        let jsonString = String(data: data, encoding: .utf8)!
        XCTAssertEqual(jsonString, "\"did:plc:z72i7hdynmk6r22z27h6tvur\"")
    }

    func testDecodesFromString() throws {
        let json = "\"did:web:example.com\""
        let data = json.data(using: .utf8)!
        let did = try JSONDecoder().decode(DID.self, from: data)
        XCTAssertEqual(did.string, "did:web:example.com")
        XCTAssertEqual(did.method, .web)
    }

    func testDecodingInvalidDIDThrows() {
        let json = "\"not-a-did\""
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(DID.self, from: data))
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let b: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let c: DID = "did:web:example.com"

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        let a: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let b: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        let c: DID = "did:web:example.com"

        var set = Set<DID>()
        set.insert(a)
        set.insert(b)
        set.insert(c)

        XCTAssertEqual(set.count, 2, "Identical DIDs should hash to the same value")
        XCTAssertTrue(set.contains(a))
        XCTAssertTrue(set.contains(c))
    }

    // MARK: - ExpressibleByStringLiteral

    func testStringLiteralInitialization() {
        let did: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertEqual(did.string, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual(did.method, .plc)
    }

    // MARK: - CustomStringConvertible

    func testDescription() {
        let did: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
        XCTAssertEqual(did.description, "did:plc:z72i7hdynmk6r22z27h6tvur")
        XCTAssertEqual("\(did)", "did:plc:z72i7hdynmk6r22z27h6tvur")
    }

    // MARK: - DID with Colons in Identifier

    func testDIDWithColonsInIdentifier() {
        let str = "did:web:example.com:path:to:resource"
        let did = DID(str)
        XCTAssertNotNil(did)
        XCTAssertEqual(did?.method, .web)
        XCTAssertEqual(did?.identifier, "example.com:path:to:resource")
    }
}
