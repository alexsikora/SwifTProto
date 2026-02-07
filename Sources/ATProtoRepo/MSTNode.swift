import Foundation
import ATProtoCore

/// A node in the Merkle Search Tree (MST).
/// The MST is a deterministic search tree used for AT Protocol repositories.
public struct MSTNode: Sendable {
    /// Left subtree pointer (CID of child node)
    public let left: CIDLink?

    /// Entries in this tree node, sorted by key
    public var entries: [MSTEntry]

    public init(left: CIDLink? = nil, entries: [MSTEntry] = []) {
        self.left = left
        self.entries = entries
    }
}

/// An entry in an MST node
public struct MSTEntry: Sendable {
    /// Number of characters shared with the previous key (prefix compression)
    public let prefixLength: Int

    /// The key suffix (remaining characters after prefix)
    public let keySuffix: Data

    /// The value CID (points to the record)
    public let value: CIDLink

    /// Right subtree pointer
    public let tree: CIDLink?

    public init(prefixLength: Int, keySuffix: Data, value: CIDLink, tree: CIDLink? = nil) {
        self.prefixLength = prefixLength
        self.keySuffix = keySuffix
        self.value = value
        self.tree = tree
    }
}

/// A full key-value pair extracted from the MST
public struct MSTRecord: Sendable, Hashable {
    /// The full record path (collection/rkey)
    public let key: String

    /// The CID of the record value
    public let value: CIDLink

    public init(key: String, value: CIDLink) {
        self.key = key
        self.value = value
    }
}
