import Foundation
import ATProtoCore
import ATProtoXRPC

/// Namespace for `com.atproto.*` API methods
public struct ComNamespace: Sendable {
    public let atproto: AtprotoNamespace

    init(xrpc: XRPCClient) {
        self.atproto = AtprotoNamespace(xrpc: xrpc)
    }
}

/// Namespace for `com.atproto.*` methods
public struct AtprotoNamespace: Sendable {
    public let repo: AtprotoRepoNamespace
    public let server: AtprotoServerNamespace
    public let identity: AtprotoIdentityNamespace
    public let sync: AtprotoSyncNamespace

    init(xrpc: XRPCClient) {
        self.repo = AtprotoRepoNamespace(xrpc: xrpc)
        self.server = AtprotoServerNamespace(xrpc: xrpc)
        self.identity = AtprotoIdentityNamespace(xrpc: xrpc)
        self.sync = AtprotoSyncNamespace(xrpc: xrpc)
    }
}

/// com.atproto.repo.* methods
public struct AtprotoRepoNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Create a new record
    public func createRecord(repo: String, collection: String, record: AnyCodable, rkey: String? = nil) async throws -> CreateRecordResponse {
        let input = CreateRecordInput(repo: repo, collection: collection, record: record, rkey: rkey)
        return try await xrpc.procedure("com.atproto.repo.createRecord", input: input, output: CreateRecordResponse.self)
    }

    /// Delete a record
    public func deleteRecord(repo: String, collection: String, rkey: String) async throws {
        let input = DeleteRecordInput(repo: repo, collection: collection, rkey: rkey)
        try await xrpc.procedure("com.atproto.repo.deleteRecord", input: input)
    }

    /// Get a record
    public func getRecord(repo: String, collection: String, rkey: String) async throws -> GetRecordResponse {
        try await xrpc.query(
            "com.atproto.repo.getRecord",
            parameters: ["repo": repo, "collection": collection, "rkey": rkey],
            output: GetRecordResponse.self
        )
    }

    /// List records in a collection
    public func listRecords(repo: String, collection: String, limit: Int = 50, cursor: String? = nil) async throws -> ListRecordsResponse {
        var params = ["repo": repo, "collection": collection, "limit": String(limit)]
        if let cursor = cursor { params["cursor"] = cursor }
        return try await xrpc.query("com.atproto.repo.listRecords", parameters: params, output: ListRecordsResponse.self)
    }

    /// Upload a blob
    public func uploadBlob(data: Data, mimeType: String) async throws -> BlobUploadResponse {
        try await xrpc.uploadBlob(data: data, mimeType: mimeType)
    }

    /// Describe a repository
    public func describeRepo(repo: String) async throws -> DescribeRepoResponse {
        try await xrpc.query("com.atproto.repo.describeRepo", parameters: ["repo": repo], output: DescribeRepoResponse.self)
    }
}

/// com.atproto.server.* methods
public struct AtprotoServerNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Describe the server
    public func describeServer() async throws -> DescribeServerResponse {
        try await xrpc.query("com.atproto.server.describeServer", parameters: [:], output: DescribeServerResponse.self)
    }

    /// Get the current session info
    public func getSession() async throws -> SessionInfo {
        try await xrpc.query("com.atproto.server.getSession", parameters: [:], output: SessionInfo.self)
    }
}

/// com.atproto.identity.* methods
public struct AtprotoIdentityNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Resolve a handle to a DID
    public func resolveHandle(handle: String) async throws -> ResolveHandleResponse {
        try await xrpc.query("com.atproto.identity.resolveHandle", parameters: ["handle": handle], output: ResolveHandleResponse.self)
    }
}

/// com.atproto.sync.* methods
public struct AtprotoSyncNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Get a repository checkout (CAR file)
    public func getRepo(did: String) async throws -> Data {
        try await xrpc.query("com.atproto.sync.getRepo", parameters: ["did": did], output: Data.self)
    }
}

// MARK: - Additional Response Types

public struct GetRecordResponse: Codable, Sendable {
    public let uri: String
    public let cid: String?
    public let value: AnyCodable
}

public struct ListRecordsResponse: Codable, Sendable {
    public let cursor: String?
    public let records: [RecordEntry]
}

public struct RecordEntry: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let value: AnyCodable
}

public struct DescribeRepoResponse: Codable, Sendable {
    public let handle: String
    public let did: String
    public let didDoc: AnyCodable
    public let collections: [String]
    public let handleIsCorrect: Bool
}

public struct DescribeServerResponse: Codable, Sendable {
    public let did: String?
    public let availableUserDomains: [String]?
    public let inviteCodeRequired: Bool?
}

public struct SessionInfo: Codable, Sendable {
    public let did: String
    public let handle: String
    public let email: String?
    public let emailConfirmed: Bool?
}

public struct ResolveHandleResponse: Codable, Sendable {
    public let did: String
}
