import Foundation
import ATProtoCore

/// An AT Protocol repository commit
public struct Commit: Codable, Sendable {
    /// The DID of the repository
    public let did: String

    /// Version number
    public let version: Int

    /// CID of the MST root
    public let data: CIDLink

    /// Revision (TID)
    public let rev: String

    /// Previous commit CID (nil for first commit)
    public let prev: CIDLink?

    /// Signature over the commit
    public let sig: Data?

    public init(did: String, version: Int = 3, data: CIDLink, rev: String, prev: CIDLink? = nil, sig: Data? = nil) {
        self.did = did
        self.version = version
        self.data = data
        self.rev = rev
        self.prev = prev
        self.sig = sig
    }
}
