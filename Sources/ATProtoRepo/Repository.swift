import Foundation
import ATProtoCore

/// Represents an AT Protocol repository
public struct Repository: Sendable {
    /// The DID of the repository owner
    public let did: DID

    /// The current commit CID
    public var head: CIDLink?

    /// Block storage for the repository
    public var storage: BlockStorage

    public init(did: DID, storage: BlockStorage) {
        self.did = did
        self.storage = storage
        self.head = nil
    }

    /// Get a record from the repository
    public func getRecord(collection: String, rkey: String) throws -> Data? {
        guard let head = head else { return nil }

        // Load commit
        guard let commitData = try storage.getBlock(cid: head) else { return nil }
        let commit = try JSONDecoder().decode(Commit.self, from: commitData)

        // Get record from MST
        let key = "\(collection)/\(rkey)"
        let mst = MerkleSearchTree(storage: storage)
        guard let recordCID = try mst.getRecord(root: commit.data, key: key) else {
            return nil
        }

        return try storage.getBlock(cid: recordCID)
    }

    /// List all records in a collection
    public func listRecords(collection: String) throws -> [MSTRecord] {
        guard let head = head else { return [] }

        guard let commitData = try storage.getBlock(cid: head) else { return [] }
        let commit = try JSONDecoder().decode(Commit.self, from: commitData)

        let mst = MerkleSearchTree(storage: storage)
        let allRecords = try mst.getAllRecords(root: commit.data)

        return allRecords.filter { $0.key.hasPrefix("\(collection)/") }
    }
}
