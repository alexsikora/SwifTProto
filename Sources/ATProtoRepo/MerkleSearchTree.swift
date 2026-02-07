import Foundation
import ATProtoCore
import ATProtoCrypto

/// Merkle Search Tree implementation for AT Protocol repositories.
///
/// The MST is a deterministic balanced tree where the level of each key
/// is determined by counting leading zeros in the SHA-256 hash of the key.
public struct MerkleSearchTree: Sendable {
    private let crypto: CryptoProvider
    private var storage: BlockStorage

    public init(storage: BlockStorage, crypto: CryptoProvider = DefaultCryptoProvider()) {
        self.storage = storage
        self.crypto = crypto
    }

    /// Calculate the tree level for a given key.
    /// Based on leading zeros in SHA-256 hash of the key.
    public func keyLevel(_ key: String) -> Int {
        let hash = crypto.sha256(data: Data(key.utf8))
        var level = 0
        for byte in hash {
            let zeros = byte.leadingZeroBitCount
            level += zeros
            if zeros < 8 { break }
        }
        return level
    }

    /// Get all records from the tree rooted at the given CID
    public func getAllRecords(root: CIDLink) throws -> [MSTRecord] {
        // Traverse the MST in-order and collect all key-value pairs
        // Reconstruct full keys from prefix-compressed entries
        guard let nodeData = try storage.getBlock(cid: root) else {
            return []
        }
        let node = try decodeMSTNode(nodeData)
        return try collectRecords(node: node, prevKey: "")
    }

    /// Get a single record by key
    public func getRecord(root: CIDLink, key: String) throws -> CIDLink? {
        guard let nodeData = try storage.getBlock(cid: root) else {
            return nil
        }
        let node = try decodeMSTNode(nodeData)
        return try findRecord(node: node, key: key, prevKey: "")
    }

    // MARK: - Private

    private func collectRecords(node: MSTNode, prevKey: String) throws -> [MSTRecord] {
        var records: [MSTRecord] = []
        var lastKey = prevKey

        // Traverse left subtree first
        if let left = node.left {
            let leftRecords = try getAllRecords(root: left)
            records.append(contentsOf: leftRecords)
            if let last = leftRecords.last {
                lastKey = last.key
            }
        }

        // Process entries
        for entry in node.entries {
            let prefix = String(lastKey.prefix(entry.prefixLength))
            let suffix = String(data: entry.keySuffix, encoding: .utf8) ?? ""
            let fullKey = prefix + suffix

            records.append(MSTRecord(key: fullKey, value: entry.value))
            lastKey = fullKey

            // Traverse right subtree of this entry
            if let tree = entry.tree {
                let subtreeRecords = try getAllRecords(root: tree)
                records.append(contentsOf: subtreeRecords)
                if let last = subtreeRecords.last {
                    lastKey = last.key
                }
            }
        }

        return records
    }

    private func findRecord(node: MSTNode, key: String, prevKey: String) throws -> CIDLink? {
        var lastKey = prevKey

        if let left = node.left {
            if let found = try getRecord(root: left, key: key) {
                return found
            }
        }

        for entry in node.entries {
            let prefix = String(lastKey.prefix(entry.prefixLength))
            let suffix = String(data: entry.keySuffix, encoding: .utf8) ?? ""
            let fullKey = prefix + suffix

            if fullKey == key {
                return entry.value
            }

            lastKey = fullKey

            if let tree = entry.tree {
                if let found = try getRecord(root: tree, key: key) {
                    return found
                }
            }
        }

        return nil
    }

    private func decodeMSTNode(_ data: Data) throws -> MSTNode {
        // CBOR decode the MST node
        // Format: {"l": CID?, "e": [{"p": int, "k": bytes, "v": CID, "t": CID?}]}
        // Simplified: create from raw structure
        throw ATProtoError.mstError("CBOR MST decoding requires SwiftCBOR integration")
    }
}
