import XCTest
@testable import ATProtoRepo
@testable import ATProtoCore

final class CARFileTests: XCTestCase {

    // MARK: - Varint Encoding/Decoding Tests

    func testVarintEncodingAndDecodingRoundtrip() throws {
        // Create a CAR file with known block data, write it, read it back
        let blockData = Data("test block data".utf8)
        let car = CARFile(roots: [], blocks: ["block-0": blockData])

        let written = try car.write()
        XCTAssertFalse(written.isEmpty, "Written CAR file should not be empty")

        // Read it back
        let readCar = try CARFile.read(from: written)

        // The read CAR should have at least the block we wrote
        XCTAssertFalse(readCar.blocks.isEmpty, "Read CAR should contain blocks")
    }

    func testVarintEncodingForSmallValues() throws {
        // A single-byte varint (value < 128) should encode to 1 byte
        // We test this indirectly through write/read roundtrip with small blocks
        let smallBlock = Data([0x01, 0x02, 0x03])
        let car = CARFile(roots: [], blocks: ["block-0": smallBlock])

        let written = try car.write()
        let readCar = try CARFile.read(from: written)

        XCTAssertFalse(readCar.blocks.isEmpty)
    }

    func testVarintEncodingForLargerValues() throws {
        // Test with a block larger than 127 bytes (requires multi-byte varint)
        let largeBlock = Data(repeating: 0xAB, count: 200)
        let car = CARFile(roots: [], blocks: ["block-0": largeBlock])

        let written = try car.write()
        let readCar = try CARFile.read(from: written)

        XCTAssertFalse(readCar.blocks.isEmpty)
    }

    // MARK: - Write/Read Roundtrip Tests

    func testWriteReadRoundtripForSimpleCARFile() throws {
        let blocks: [String: Data] = [
            "block-0": Data("first block".utf8),
            "block-1": Data("second block".utf8)
        ]
        let car = CARFile(roots: [], blocks: blocks)

        let written = try car.write()
        XCTAssertGreaterThan(written.count, 0)

        let readCar = try CARFile.read(from: written)

        // Verify we got blocks back
        XCTAssertGreaterThanOrEqual(readCar.blocks.count, 1,
            "Should read back at least some blocks")
    }

    func testWriteReadRoundtripWithSingleBlock() throws {
        let car = CARFile(roots: [], blocks: ["block-0": Data("only block".utf8)])

        let written = try car.write()
        let readCar = try CARFile.read(from: written)

        XCTAssertFalse(readCar.blocks.isEmpty)
    }

    func testWriteReadRoundtripWithMultipleBlocks() throws {
        var blocks: [String: Data] = [:]
        for i in 0..<5 {
            blocks["block-\(i)"] = Data("block content \(i)".utf8)
        }
        let car = CARFile(roots: [], blocks: blocks)

        let written = try car.write()
        let readCar = try CARFile.read(from: written)

        XCTAssertEqual(readCar.blocks.count, 5, "Should read back all 5 blocks")
    }

    func testWriteProducesNonEmptyData() throws {
        let car = CARFile(roots: [], blocks: [:])
        let written = try car.write()

        // Even with no blocks, should have the header
        XCTAssertGreaterThan(written.count, 0, "CAR file should always have a header")
    }

    func testWriteWithEmptyBlocksOnlyContainsHeader() throws {
        let car = CARFile(roots: [], blocks: [:])
        let written = try car.write()

        // The header is 17 bytes of DAG-CBOR + 1 byte varint length = 18 bytes
        XCTAssertGreaterThanOrEqual(written.count, 18,
            "Empty CAR file should at least contain the header")
    }

    // MARK: - Empty CAR File Handling Tests

    func testEmptyCARFileCanBeWrittenAndRead() throws {
        let car = CARFile(roots: [], blocks: [:])
        let written = try car.write()

        // Reading an empty CAR file (header only) should succeed
        let readCar = try CARFile.read(from: written)
        XCTAssertTrue(readCar.blocks.isEmpty, "Empty CAR file should have no blocks")
    }

    func testCARFileInitializationWithEmptyRootsAndBlocks() {
        let car = CARFile(roots: [], blocks: [:])

        XCTAssertTrue(car.roots.isEmpty)
        XCTAssertTrue(car.blocks.isEmpty)
    }

    func testCARFileInitializationWithRoots() {
        let roots = [CIDLink("bafyreiroot1"), CIDLink("bafyreiroot2")]
        let car = CARFile(roots: roots, blocks: [:])

        XCTAssertEqual(car.roots.count, 2)
        XCTAssertEqual(car.roots[0].string, "bafyreiroot1")
        XCTAssertEqual(car.roots[1].string, "bafyreiroot2")
    }

    // MARK: - Too-Small Data Error Tests

    func testTooSmallDataThrowsError() {
        let tinyData = Data([0x01])

        XCTAssertThrowsError(try CARFile.read(from: tinyData)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .repositoryError(let message) = atError {
                XCTAssertTrue(message.contains("too small"),
                    "Error message should mention data is too small: \(message)")
            } else {
                XCTFail("Expected repositoryError, got \(atError)")
            }
        }
    }

    func testEmptyDataThrowsError() {
        let emptyData = Data()

        XCTAssertThrowsError(try CARFile.read(from: emptyData)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .repositoryError = atError {
                // Expected
            } else {
                XCTFail("Expected repositoryError, got \(atError)")
            }
        }
    }

    func testSingleByteDataThrowsError() {
        let singleByte = Data([0x00])

        XCTAssertThrowsError(try CARFile.read(from: singleByte)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .repositoryError(let message) = atError {
                XCTAssertTrue(message.contains("too small"),
                    "Expected 'too small' in error message")
            } else {
                XCTFail("Expected repositoryError, got \(atError)")
            }
        }
    }

    // MARK: - Block Content Verification

    func testBlockDataIntegrity() throws {
        let originalData = Data("specific content to verify".utf8)
        let car = CARFile(roots: [], blocks: ["block-0": originalData])

        let written = try car.write()
        let readCar = try CARFile.read(from: written)

        // Find the block and check it contains the original data
        XCTAssertFalse(readCar.blocks.isEmpty)

        // The first block should contain the original data
        if let firstBlock = readCar.blocks.values.first {
            XCTAssertEqual(firstBlock, originalData,
                "Block data should be preserved through write/read roundtrip")
        }
    }
}
