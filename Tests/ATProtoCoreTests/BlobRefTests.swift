import XCTest
@testable import ATProtoCore

final class BlobRefTests: XCTestCase {

    // MARK: - Encoding

    func testEncodingIncludesTypeField() throws {
        let blob = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/jpeg",
            size: 12345
        )

        let data = try JSONEncoder().encode(blob)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["$type"] as? String, "blob")
    }

    func testEncodingIncludesAllFields() throws {
        let blob = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/png",
            size: 54321
        )

        let data = try JSONEncoder().encode(blob)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["$type"] as? String, "blob")
        XCTAssertEqual(json?["mimeType"] as? String, "image/png")
        XCTAssertEqual(json?["size"] as? Int, 54321)

        // ref should be a nested $link object
        let refObj = json?["ref"] as? [String: Any]
        XCTAssertNotNil(refObj)
        XCTAssertEqual(refObj?["$link"] as? String, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
    }

    // MARK: - Decoding

    func testDecodingWithTypeField() throws {
        let json = """
        {
            "$type": "blob",
            "ref": {"$link": "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"},
            "mimeType": "image/jpeg",
            "size": 12345
        }
        """
        let data = json.data(using: .utf8)!
        let blob = try JSONDecoder().decode(BlobRef.self, from: data)

        XCTAssertEqual(blob.ref.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(blob.mimeType, "image/jpeg")
        XCTAssertEqual(blob.size, 12345)
    }

    func testDecodingWithoutTypeField() throws {
        // The decoder allows $type to be absent
        let json = """
        {
            "ref": {"$link": "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"},
            "mimeType": "text/plain",
            "size": 100
        }
        """
        let data = json.data(using: .utf8)!
        let blob = try JSONDecoder().decode(BlobRef.self, from: data)

        XCTAssertEqual(blob.ref.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(blob.mimeType, "text/plain")
        XCTAssertEqual(blob.size, 100)
    }

    func testDecodingWithWrongTypeFieldThrows() {
        let json = """
        {
            "$type": "not-blob",
            "ref": {"$link": "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"},
            "mimeType": "image/jpeg",
            "size": 12345
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(BlobRef.self, from: data))
    }

    // MARK: - Roundtrip

    func testCodableRoundtrip() throws {
        let original = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "application/octet-stream",
            size: 999_999
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BlobRef.self, from: data)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(original.ref, decoded.ref)
        XCTAssertEqual(original.mimeType, decoded.mimeType)
        XCTAssertEqual(original.size, decoded.size)
    }

    func testRoundtripVariousMimeTypes() throws {
        let mimeTypes = ["image/jpeg", "image/png", "video/mp4", "text/plain", "application/json"]

        for mimeType in mimeTypes {
            let original = BlobRef(
                ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
                mimeType: mimeType,
                size: 42
            )

            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(BlobRef.self, from: data)

            XCTAssertEqual(decoded.mimeType, mimeType, "Roundtrip failed for mimeType: \(mimeType)")
        }
    }

    // MARK: - Hashable / Equatable

    func testEquatable() {
        let a = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/jpeg",
            size: 100
        )
        let b = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/jpeg",
            size: 100
        )
        let c = BlobRef(
            ref: CIDLink("bafyreidifferentcid"),
            mimeType: "image/png",
            size: 200
        )

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        let a = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/jpeg",
            size: 100
        )
        let b = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "image/jpeg",
            size: 100
        )

        var set = Set<BlobRef>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Init Properties

    func testInitProperties() {
        let ref = CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        let blob = BlobRef(ref: ref, mimeType: "video/mp4", size: 5_000_000)

        XCTAssertEqual(blob.ref.string, "bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a")
        XCTAssertEqual(blob.mimeType, "video/mp4")
        XCTAssertEqual(blob.size, 5_000_000)
    }

    func testZeroSizeBlob() throws {
        let blob = BlobRef(
            ref: CIDLink("bafyreie5cvv4h45feadgeuwhbcutmh6t7ceseocckahdoe6uat64zmz454a"),
            mimeType: "text/plain",
            size: 0
        )

        let data = try JSONEncoder().encode(blob)
        let decoded = try JSONDecoder().decode(BlobRef.self, from: data)
        XCTAssertEqual(decoded.size, 0)
    }
}
