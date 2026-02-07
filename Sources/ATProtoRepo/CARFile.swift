import Foundation
import ATProtoCore

/// Content Addressable aRchive (CAR) file reader/writer.
/// CAR v1 format used for repository export/import.
public struct CARFile: Sendable {
    /// The roots (CIDs) of the DAG
    public let roots: [CIDLink]

    /// The blocks in the CAR file, keyed by CID
    public let blocks: [String: Data]

    public init(roots: [CIDLink], blocks: [String: Data] = [:]) {
        self.roots = roots
        self.blocks = blocks
    }

    /// Read a CAR file from data
    public static func read(from data: Data) throws -> CARFile {
        // CAR v1 format:
        // Header: varint length + DAG-CBOR { version: 1, roots: [CID] }
        // Blocks: repeated (varint length + CID + block data)

        guard data.count >= 2 else {
            throw ATProtoError.repositoryError("CAR file too small")
        }

        var offset = 0

        // Read header length (varint)
        let (headerLen, headerLenSize) = readVarint(from: data, at: offset)
        offset += headerLenSize

        guard offset + Int(headerLen) <= data.count else {
            throw ATProtoError.repositoryError("CAR header exceeds data bounds")
        }

        // Skip header CBOR for now (would need CBOR decoder)
        offset += Int(headerLen)

        // Read blocks
        var blocks: [String: Data] = [:]
        while offset < data.count {
            let (blockLen, blockLenSize) = readVarint(from: data, at: offset)
            offset += blockLenSize

            guard offset + Int(blockLen) <= data.count else { break }

            // Block = CID + data
            // For simplicity, store with offset-based key
            let blockData = data[offset..<(offset + Int(blockLen))]
            let blockKey = "block-\(blocks.count)"
            blocks[blockKey] = Data(blockData)

            offset += Int(blockLen)
        }

        return CARFile(roots: [], blocks: blocks)
    }

    /// Write the CAR file to data
    public func write() throws -> Data {
        var output = Data()

        // Write header
        // DAG-CBOR encoded: {"version": 1, "roots": [...]}
        let header = Data([0xa2, 0x65, 0x72, 0x6f, 0x6f, 0x74, 0x73, 0x80,
                          0x67, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x01])
        writeVarint(UInt64(header.count), to: &output)
        output.append(header)

        // Write blocks
        for (_, blockData) in blocks.sorted(by: { $0.key < $1.key }) {
            writeVarint(UInt64(blockData.count), to: &output)
            output.append(blockData)
        }

        return output
    }

    // MARK: - Varint helpers

    private static func readVarint(from data: Data, at offset: Int) -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        var bytesRead = 0
        var idx = offset

        while idx < data.count {
            let byte = data[idx]
            result |= UInt64(byte & 0x7F) << shift
            bytesRead += 1
            idx += 1

            if byte & 0x80 == 0 { break }
            shift += 7
        }

        return (result, bytesRead)
    }

    private func writeVarint(_ value: UInt64, to data: inout Data) {
        var v = value
        while v >= 0x80 {
            data.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        data.append(UInt8(v))
    }
}
