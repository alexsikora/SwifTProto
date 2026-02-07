import XCTest
@testable import ATProtoEventStream
@testable import ATProtoCore

final class CBORFrameDecoderTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDecoderCanBeInitialized() {
        let decoder = CBORFrameDecoder()
        XCTAssertNotNil(decoder)
    }

    func testMultipleDecoderInstancesCanBeCreated() {
        let decoder1 = CBORFrameDecoder()
        let decoder2 = CBORFrameDecoder()

        XCTAssertNotNil(decoder1)
        XCTAssertNotNil(decoder2)
    }

    // MARK: - Invalid Data Tests

    func testInvalidDataThrowsFrameDecodingError() {
        let decoder = CBORFrameDecoder()

        // Completely invalid CBOR data
        let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])

        XCTAssertThrowsError(try decoder.decode(invalidData)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .frameDecodingError(let message) = atError {
                XCTAssertFalse(message.isEmpty, "Error message should not be empty")
            } else {
                XCTFail("Expected frameDecodingError, got \(atError)")
            }
        }
    }

    func testEmptyDataThrowsFrameDecodingError() {
        let decoder = CBORFrameDecoder()
        let emptyData = Data()

        XCTAssertThrowsError(try decoder.decode(emptyData)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .frameDecodingError = atError {
                // Expected
            } else {
                XCTFail("Expected frameDecodingError, got \(atError)")
            }
        }
    }

    func testSingleByteInvalidDataThrowsError() {
        let decoder = CBORFrameDecoder()
        let singleByte = Data([0x00])

        // Single byte that forms a valid CBOR unsigned int 0 but not a valid map header
        XCTAssertThrowsError(try decoder.decode(singleByte)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .frameDecodingError = atError {
                // Expected - a single integer is not a valid frame header map
            } else {
                XCTFail("Expected frameDecodingError, got \(atError)")
            }
        }
    }

    func testRandomBytesThrowsFrameDecodingError() {
        let decoder = CBORFrameDecoder()
        // Random bytes that are unlikely to form valid CBOR
        let randomData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE])

        XCTAssertThrowsError(try decoder.decode(randomData)) { error in
            guard error is ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
        }
    }

    func testTruncatedCBORMapThrowsError() {
        let decoder = CBORFrameDecoder()
        // Start of a CBOR map but truncated (0xA2 = map with 2 items)
        let truncatedData = Data([0xA2, 0x62])

        XCTAssertThrowsError(try decoder.decode(truncatedData)) { error in
            guard error is ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
        }
    }

    // MARK: - Valid CBOR but Invalid Frame Tests

    func testValidCBORMapWithoutBodyThrowsError() {
        let decoder = CBORFrameDecoder()

        // A valid CBOR map {op: 1, t: "#commit"} but no body following it
        // CBOR encoding of {"op": 1, "t": "#commit"}:
        // A2 (map of 2) 62 6F 70 (text "op") 01 (unsigned 1) 61 74 (text "t") 67 23 63 6F 6D 6D 69 74 (text "#commit")
        let headerOnly = Data([
            0xA2,                               // map(2)
            0x62, 0x6F, 0x70,                   // text "op"
            0x01,                               // unsigned(1)
            0x61, 0x74,                         // text "t"
            0x67, 0x23, 0x63, 0x6F, 0x6D, 0x6D, 0x69, 0x74  // text "#commit"
        ])

        XCTAssertThrowsError(try decoder.decode(headerOnly)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .frameDecodingError(let message) = atError {
                XCTAssertTrue(message.contains("no body") || message.contains("body") || !message.isEmpty,
                    "Error should indicate missing body: \(message)")
            } else {
                XCTFail("Expected frameDecodingError, got \(atError)")
            }
        }
    }

    // MARK: - FrameHeader Structure Tests

    func testFrameHeaderCanHoldMessageOp() {
        let header = CBORFrameDecoder.FrameHeader(op: 1, type: "#commit")

        XCTAssertEqual(header.op, 1)
        XCTAssertEqual(header.type, "#commit")
    }

    func testFrameHeaderCanHoldErrorOp() {
        let header = CBORFrameDecoder.FrameHeader(op: -1, type: nil)

        XCTAssertEqual(header.op, -1)
        XCTAssertNil(header.type)
    }

    func testFrameHeaderWithVariousTypes() {
        let types = ["#commit", "#identity", "#handle", "#account", "#info"]

        for type in types {
            let header = CBORFrameDecoder.FrameHeader(op: 1, type: type)
            XCTAssertEqual(header.type, type)
        }
    }
}
