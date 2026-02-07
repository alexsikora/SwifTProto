import XCTest
@testable import ATProtoRepo
@testable import ATProtoCore

final class BlockStorageTests: XCTestCase {

    // MARK: - Put / Get Roundtrip Tests

    func testPutGetRoundtrip() throws {
        let storage = MemoryBlockStorage()
        let data = Data("Hello, world!".utf8)

        let cid = try storage.putBlock(data: data)
        XCTAssertFalse(cid.string.isEmpty, "CID should not be empty")

        let retrieved = try storage.getBlock(cid: cid)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }

    func testPutGetRoundtripWithBinaryData() throws {
        let storage = MemoryBlockStorage()
        let data = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])

        let cid = try storage.putBlock(data: data)
        let retrieved = try storage.getBlock(cid: cid)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }

    func testPutGetRoundtripWithEmptyData() throws {
        let storage = MemoryBlockStorage()
        let data = Data()

        let cid = try storage.putBlock(data: data)
        let retrieved = try storage.getBlock(cid: cid)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }

    func testPutGetRoundtripWithLargeData() throws {
        let storage = MemoryBlockStorage()
        let data = Data(repeating: 0xAB, count: 100_000)

        let cid = try storage.putBlock(data: data)
        let retrieved = try storage.getBlock(cid: cid)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.count, 100_000)
        XCTAssertEqual(retrieved, data)
    }

    // MARK: - hasBlock Tests

    func testHasBlockReturnsTrueForExistingBlocks() throws {
        let storage = MemoryBlockStorage()
        let data = Data("existing block".utf8)

        let cid = try storage.putBlock(data: data)
        let exists = try storage.hasBlock(cid: cid)

        XCTAssertTrue(exists)
    }

    func testHasBlockReturnsFalseForNonExistentBlocks() throws {
        let storage = MemoryBlockStorage()
        let fakeCID = CIDLink("nonexistent-cid-12345")

        let exists = try storage.hasBlock(cid: fakeCID)

        XCTAssertFalse(exists)
    }

    func testHasBlockReturnsFalseForEmptyStorage() throws {
        let storage = MemoryBlockStorage()
        let fakeCID = CIDLink("some-cid")

        let exists = try storage.hasBlock(cid: fakeCID)

        XCTAssertFalse(exists)
    }

    // MARK: - deleteBlock Tests

    func testDeleteBlockRemovesTheBlock() throws {
        let storage = MemoryBlockStorage()
        let data = Data("delete me".utf8)

        let cid = try storage.putBlock(data: data)

        // Verify it exists
        XCTAssertTrue(try storage.hasBlock(cid: cid))

        // Delete it
        try storage.deleteBlock(cid: cid)

        // Verify it's gone
        XCTAssertFalse(try storage.hasBlock(cid: cid))
        XCTAssertNil(try storage.getBlock(cid: cid))
    }

    func testDeleteBlockDoesNotAffectOtherBlocks() throws {
        let storage = MemoryBlockStorage()
        let data1 = Data("block one".utf8)
        let data2 = Data("block two".utf8)

        let cid1 = try storage.putBlock(data: data1)
        let cid2 = try storage.putBlock(data: data2)

        // Delete only the first block
        try storage.deleteBlock(cid: cid1)

        // First should be gone
        XCTAssertFalse(try storage.hasBlock(cid: cid1))

        // Second should still exist
        XCTAssertTrue(try storage.hasBlock(cid: cid2))
        XCTAssertEqual(try storage.getBlock(cid: cid2), data2)
    }

    func testDeleteNonExistentBlockDoesNotThrow() throws {
        let storage = MemoryBlockStorage()
        let fakeCID = CIDLink("nonexistent-cid")

        // Should not throw
        try storage.deleteBlock(cid: fakeCID)
    }

    // MARK: - Count Property Tests

    func testCountPropertyReturnsZeroForEmptyStorage() {
        let storage = MemoryBlockStorage()
        XCTAssertEqual(storage.count, 0)
    }

    func testCountPropertyReflectsNumberOfBlocks() throws {
        let storage = MemoryBlockStorage()

        _ = try storage.putBlock(data: Data("one".utf8))
        XCTAssertEqual(storage.count, 1)

        _ = try storage.putBlock(data: Data("two".utf8))
        XCTAssertEqual(storage.count, 2)

        _ = try storage.putBlock(data: Data("three".utf8))
        XCTAssertEqual(storage.count, 3)
    }

    func testCountDecrementsAfterDelete() throws {
        let storage = MemoryBlockStorage()

        let cid1 = try storage.putBlock(data: Data("one".utf8))
        let cid2 = try storage.putBlock(data: Data("two".utf8))
        XCTAssertEqual(storage.count, 2)

        try storage.deleteBlock(cid: cid1)
        XCTAssertEqual(storage.count, 1)

        try storage.deleteBlock(cid: cid2)
        XCTAssertEqual(storage.count, 0)
    }

    // MARK: - Multiple Blocks Stored Independently

    func testMultipleBlocksStoredIndependently() throws {
        let storage = MemoryBlockStorage()
        let data1 = Data("first block content".utf8)
        let data2 = Data("second block content".utf8)
        let data3 = Data("third block content".utf8)

        let cid1 = try storage.putBlock(data: data1)
        let cid2 = try storage.putBlock(data: data2)
        let cid3 = try storage.putBlock(data: data3)

        // All CIDs should be different
        XCTAssertNotEqual(cid1.string, cid2.string)
        XCTAssertNotEqual(cid2.string, cid3.string)
        XCTAssertNotEqual(cid1.string, cid3.string)

        // Each should retrieve its own data
        XCTAssertEqual(try storage.getBlock(cid: cid1), data1)
        XCTAssertEqual(try storage.getBlock(cid: cid2), data2)
        XCTAssertEqual(try storage.getBlock(cid: cid3), data3)

        // Verify count
        XCTAssertEqual(storage.count, 3)
    }

    func testGetBlockReturnsNilForUnknownCID() throws {
        let storage = MemoryBlockStorage()

        _ = try storage.putBlock(data: Data("some data".utf8))

        let unknownCID = CIDLink("unknown-cid-xyz")
        let result = try storage.getBlock(cid: unknownCID)

        XCTAssertNil(result)
    }
}
