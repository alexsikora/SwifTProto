import Foundation
import ATProtoCore

/// Protocol for content-addressed block storage
public protocol BlockStorage: Sendable {
    /// Store a block and return its CID
    func putBlock(data: Data) throws -> CIDLink

    /// Retrieve a block by its CID
    func getBlock(cid: CIDLink) throws -> Data?

    /// Check if a block exists
    func hasBlock(cid: CIDLink) throws -> Bool

    /// Delete a block
    func deleteBlock(cid: CIDLink) throws
}

/// In-memory block storage for testing and temporary operations
public final class MemoryBlockStorage: BlockStorage, @unchecked Sendable {
    private var blocks: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func putBlock(data: Data) throws -> CIDLink {
        lock.lock()
        defer { lock.unlock() }

        // Use a simple hash as a placeholder CID
        // In production, this would compute a proper CIDv1
        let hash = data.hashValue
        let cid = CIDLink("mem-block-\(abs(hash))")
        blocks[cid.string] = data
        return cid
    }

    public func getBlock(cid: CIDLink) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return blocks[cid.string]
    }

    public func hasBlock(cid: CIDLink) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return blocks[cid.string] != nil
    }

    public func deleteBlock(cid: CIDLink) throws {
        lock.lock()
        defer { lock.unlock() }
        blocks.removeValue(forKey: cid.string)
    }

    /// Get total number of blocks stored
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return blocks.count
    }
}
