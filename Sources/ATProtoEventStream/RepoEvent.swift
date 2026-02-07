import Foundation
import ATProtoCore

/// Events from the AT Protocol event stream (firehose)
public enum RepoEvent: Sendable {
    /// A repository commit event
    case commit(CommitEvent)

    /// An identity update event
    case identity(IdentityEvent)

    /// An account status event
    case account(AccountEvent)

    /// A handle update event
    case handle(HandleEvent)

    /// An info/status event
    case info(InfoEvent)

    /// Unknown event type
    case unknown(type: String, data: Data)
}

/// A commit event from the firehose
public struct CommitEvent: Sendable {
    /// The sequence number
    public let seq: Int64

    /// Whether this should be processed immediately
    public let tooBig: Bool

    /// The repository DID
    public let repo: String

    /// The commit CID
    public let commit: CIDLink?

    /// The previous commit CID
    public let prev: CIDLink?

    /// Revision string
    public let rev: String?

    /// Timestamp of the event
    public let time: String

    /// Operations in this commit
    public let ops: [RepoOp]

    /// The raw blocks (CAR file data)
    public let blocks: Data?

    public init(seq: Int64, tooBig: Bool = false, repo: String, commit: CIDLink? = nil,
                prev: CIDLink? = nil, rev: String? = nil, time: String, ops: [RepoOp] = [], blocks: Data? = nil) {
        self.seq = seq
        self.tooBig = tooBig
        self.repo = repo
        self.commit = commit
        self.prev = prev
        self.rev = rev
        self.time = time
        self.ops = ops
        self.blocks = blocks
    }
}

/// An operation within a commit
public struct RepoOp: Sendable {
    public enum Action: String, Sendable {
        case create
        case update
        case delete
    }

    /// The action performed
    public let action: Action

    /// The record path (collection/rkey)
    public let path: String

    /// The CID of the record (nil for deletes)
    public let cid: CIDLink?

    public init(action: Action, path: String, cid: CIDLink? = nil) {
        self.action = action
        self.path = path
        self.cid = cid
    }

    /// The collection NSID from the path
    public var collection: String? {
        let parts = path.split(separator: "/")
        guard parts.count >= 1 else { return nil }
        return String(parts[0])
    }

    /// The record key from the path
    public var rkey: String? {
        let parts = path.split(separator: "/")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }
}

/// An identity event
public struct IdentityEvent: Sendable {
    public let seq: Int64
    public let did: String
    public let time: String
    public let handle: String?

    public init(seq: Int64, did: String, time: String, handle: String? = nil) {
        self.seq = seq
        self.did = did
        self.time = time
        self.handle = handle
    }
}

/// An account status event
public struct AccountEvent: Sendable {
    public let seq: Int64
    public let did: String
    public let time: String
    public let active: Bool
    public let status: String?

    public init(seq: Int64, did: String, time: String, active: Bool, status: String? = nil) {
        self.seq = seq
        self.did = did
        self.time = time
        self.active = active
        self.status = status
    }
}

/// A handle update event
public struct HandleEvent: Sendable {
    public let seq: Int64
    public let did: String
    public let handle: String
    public let time: String

    public init(seq: Int64, did: String, handle: String, time: String) {
        self.seq = seq
        self.did = did
        self.handle = handle
        self.time = time
    }
}

/// An info/status event from the stream
public struct InfoEvent: Sendable {
    public let name: String
    public let message: String?

    public init(name: String, message: String? = nil) {
        self.name = name
        self.message = message
    }
}
