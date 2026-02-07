import XCTest
@testable import ATProtoRepo
@testable import ATProtoCore

final class CommitTests: XCTestCase {

    // MARK: - Codable Roundtrip Tests

    func testCommitCodableRoundtrip() throws {
        let commit = Commit(
            did: "did:plc:testuser",
            version: 3,
            data: CIDLink("bafyreiabc123"),
            rev: "3kzhqhgxthsrq",
            prev: CIDLink("bafyreiprev456"),
            sig: Data([0x01, 0x02, 0x03, 0x04])
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(commit)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Commit.self, from: data)

        XCTAssertEqual(decoded.did, "did:plc:testuser")
        XCTAssertEqual(decoded.version, 3)
        XCTAssertEqual(decoded.data.string, "bafyreiabc123")
        XCTAssertEqual(decoded.rev, "3kzhqhgxthsrq")
        XCTAssertEqual(decoded.prev?.string, "bafyreiprev456")
        XCTAssertNotNil(decoded.sig)
        XCTAssertEqual(decoded.sig, Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testCommitEncodesToValidJSON() throws {
        let commit = Commit(
            did: "did:plc:alice",
            version: 3,
            data: CIDLink("bafyreidata"),
            rev: "tid123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(commit)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"did\""))
        XCTAssertTrue(jsonString.contains("\"did:plc:alice\""))
        XCTAssertTrue(jsonString.contains("\"version\""))
        XCTAssertTrue(jsonString.contains("\"rev\""))
    }

    // MARK: - Commit with nil prev Tests

    func testCommitWithNilPrev() throws {
        let commit = Commit(
            did: "did:plc:firstcommit",
            version: 3,
            data: CIDLink("bafyreifirst"),
            rev: "firstrev"
        )

        XCTAssertNil(commit.prev, "First commit should have nil prev")

        // Verify roundtrip preserves nil prev
        let encoder = JSONEncoder()
        let data = try encoder.encode(commit)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Commit.self, from: data)

        XCTAssertNil(decoded.prev)
        XCTAssertEqual(decoded.did, "did:plc:firstcommit")
    }

    func testCommitWithNilSig() throws {
        let commit = Commit(
            did: "did:plc:nosig",
            version: 3,
            data: CIDLink("bafyreinosig"),
            rev: "rev456"
        )

        XCTAssertNil(commit.sig)

        // Verify roundtrip preserves nil sig
        let encoder = JSONEncoder()
        let data = try encoder.encode(commit)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Commit.self, from: data)

        XCTAssertNil(decoded.sig)
    }

    func testCommitWithNilPrevAndNilSig() throws {
        let commit = Commit(
            did: "did:plc:minimal",
            data: CIDLink("bafyreimin"),
            rev: "minrev"
        )

        XCTAssertNil(commit.prev)
        XCTAssertNil(commit.sig)
        XCTAssertEqual(commit.version, 3) // default version

        let encoder = JSONEncoder()
        let data = try encoder.encode(commit)
        let decoded = try JSONDecoder().decode(Commit.self, from: data)

        XCTAssertNil(decoded.prev)
        XCTAssertNil(decoded.sig)
        XCTAssertEqual(decoded.version, 3)
    }

    // MARK: - Commit with All Fields Tests

    func testCommitWithAllFields() {
        let sigData = Data(repeating: 0xAA, count: 64)
        let commit = Commit(
            did: "did:plc:fullcommit",
            version: 3,
            data: CIDLink("bafyreifulldata"),
            rev: "3kzhqhgxfullrev",
            prev: CIDLink("bafyreiprevcommit"),
            sig: sigData
        )

        XCTAssertEqual(commit.did, "did:plc:fullcommit")
        XCTAssertEqual(commit.version, 3)
        XCTAssertEqual(commit.data.string, "bafyreifulldata")
        XCTAssertEqual(commit.rev, "3kzhqhgxfullrev")
        XCTAssertEqual(commit.prev?.string, "bafyreiprevcommit")
        XCTAssertNotNil(commit.sig)
        XCTAssertEqual(commit.sig?.count, 64)
    }

    func testCommitWithAllFieldsRoundtrip() throws {
        let sigData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let original = Commit(
            did: "did:plc:roundtrip",
            version: 3,
            data: CIDLink("bafyreiround"),
            rev: "rev789",
            prev: CIDLink("bafyreiprevround"),
            sig: sigData
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Commit.self, from: data)

        XCTAssertEqual(decoded.did, original.did)
        XCTAssertEqual(decoded.version, original.version)
        XCTAssertEqual(decoded.data.string, original.data.string)
        XCTAssertEqual(decoded.rev, original.rev)
        XCTAssertEqual(decoded.prev?.string, original.prev?.string)
        XCTAssertEqual(decoded.sig, original.sig)
    }

    // MARK: - Default Version Tests

    func testDefaultVersionIs3() {
        let commit = Commit(
            did: "did:plc:defaultver",
            data: CIDLink("bafyreidef"),
            rev: "defrev"
        )

        XCTAssertEqual(commit.version, 3)
    }

    func testCustomVersion() {
        let commit = Commit(
            did: "did:plc:custom",
            version: 2,
            data: CIDLink("bafyreiv2"),
            rev: "v2rev"
        )

        XCTAssertEqual(commit.version, 2)
    }
}
