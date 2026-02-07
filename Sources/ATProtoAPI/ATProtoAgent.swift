import Foundation
import ATProtoCore
import ATProtoXRPC
import ATProtoIdentity
import ATProtoOAuth
import ATProtoEventStream

/// The main entry point for the AT Protocol SDK.
/// Provides high-level access to all AT Protocol operations.
public actor ATProtoAgent {
    /// The XRPC client for making API calls
    public nonisolated let xrpc: XRPCClient

    /// The OAuth client for authentication
    private let oauthClient: OAuthClient?

    /// Identity resolution services
    private let didResolver: CompositeDIDResolver
    private let handleResolver: DNSHandleResolver
    private let pdsDiscovery: PDSDiscovery

    /// The firehose client for event streaming
    public nonisolated let firehose: FirehoseClient

    /// The current session
    private var session: OAuthSession?

    /// The HTTP executor used for network requests
    private let httpExecutor: HTTPExecutor

    /// Namespace accessors for organized API access
    public nonisolated let app: AppNamespace
    public nonisolated let com: ComNamespace

    /// The service URL this agent connects to
    public nonisolated let serviceURL: URL

    /// Initialize with a service URL (e.g., https://bsky.social)
    public init(
        serviceURL: URL,
        httpExecutor: HTTPExecutor = URLSessionHTTPExecutor(),
        storage: SecureKeyStorage? = nil,
        clientID: String = "https://swiftproto.dev/client-metadata.json",
        redirectURI: String = "swiftproto://oauth/callback"
    ) throws {
        self.serviceURL = serviceURL

        let executor = httpExecutor
        self.httpExecutor = executor
        self.xrpc = XRPCClient(serviceURL: serviceURL, httpExecutor: executor)

        let plcResolver = PLCDIDResolver(httpExecutor: executor)
        let webResolver = WebDIDResolver(httpExecutor: executor)
        self.didResolver = CompositeDIDResolver(plcResolver: plcResolver, webResolver: webResolver)
        self.handleResolver = DNSHandleResolver(httpExecutor: executor)
        self.pdsDiscovery = PDSDiscovery(didResolver: self.didResolver, handleResolver: self.handleResolver)

        self.oauthClient = try? OAuthClient(
            clientID: clientID,
            redirectURI: redirectURI,
            httpExecutor: executor,
            storage: storage
        )

        self.firehose = FirehoseClient()

        self.app = AppNamespace(xrpc: self.xrpc)
        self.com = ComNamespace(xrpc: self.xrpc)
    }

    // MARK: - Authentication

    /// Start OAuth authorization flow for a handle.
    /// Returns the authorization URL to present to the user.
    public func authorize(handle: Handle) async throws -> URL {
        guard let oauthClient = oauthClient else {
            throw ATProtoError.internalError("OAuth client not configured")
        }

        // Discover the user's PDS and auth server
        let (_, pdsURL) = try await pdsDiscovery.discoverPDS(for: handle)
        let authServerURL = try await pdsDiscovery.discoverAuthServer(from: pdsURL, httpExecutor: httpExecutor)

        // Start OAuth flow
        return try await oauthClient.authorize(authServerURL: authServerURL)
    }

    /// Handle the OAuth callback after user authorization.
    public func handleCallback(url: URL) async throws {
        guard let oauthClient = oauthClient else {
            throw ATProtoError.internalError("OAuth client not configured")
        }

        self.session = try await oauthClient.handleCallback(url: url)

        // Set up auth header provider on the XRPC client
        await setXRPCAuthorization(oauthClient: oauthClient)
    }

    /// Get the current session state
    public func getSession() async -> OAuthSession? {
        return session
    }

    /// Whether the agent has an active authenticated session
    public var isAuthenticated: Bool {
        session?.isAuthenticated ?? false
    }

    // MARK: - Identity

    /// Resolve a handle to a DID
    public func resolveHandle(_ handle: Handle) async throws -> DID {
        try await handleResolver.resolve(handle)
    }

    /// Resolve a DID document
    public func resolveDID(_ did: DID) async throws -> DIDDocument {
        try await didResolver.resolve(did)
    }

    // MARK: - Convenience Methods

    /// Create a text post
    public func post(text: String, createdAt: Date = Date()) async throws -> CreateRecordResponse {
        let record = AnyCodable([
            "$type": AnyCodable("app.bsky.feed.post"),
            "text": AnyCodable(text),
            "createdAt": AnyCodable(ISO8601DateFormatter().string(from: createdAt)),
        ])

        let input = CreateRecordInput(
            repo: session?.did?.string ?? "",
            collection: "app.bsky.feed.post",
            record: record
        )

        return try await xrpc.procedure(
            "com.atproto.repo.createRecord",
            input: input,
            output: CreateRecordResponse.self
        )
    }

    /// Delete a record by AT URI
    public func deleteRecord(uri: ATURI) async throws {
        guard let collection = uri.collection, let rkey = uri.recordKey else {
            throw ATProtoError.invalidATURI(uri.string)
        }

        let input = DeleteRecordInput(
            repo: uri.authority,
            collection: collection.string,
            rkey: rkey
        )

        try await xrpc.procedure("com.atproto.repo.deleteRecord", input: input)
    }

    /// Get a user's profile
    public func getProfile(actor: String) async throws -> ProfileView {
        try await xrpc.query(
            "app.bsky.actor.getProfile",
            parameters: ["actor": actor],
            output: ProfileView.self
        )
    }

    /// Get the authenticated user's timeline
    public func getTimeline(limit: Int = 50, cursor: String? = nil) async throws -> TimelineFeed {
        var params = ["limit": String(limit)]
        if let cursor = cursor {
            params["cursor"] = cursor
        }
        return try await xrpc.query(
            "app.bsky.feed.getTimeline",
            parameters: params,
            output: TimelineFeed.self
        )
    }

    // MARK: - Private Helpers

    /// Configures the XRPC client's authorization provider using the OAuth client.
    private func setXRPCAuthorization(oauthClient: OAuthClient) async {
        await xrpc.setAuthorizationProvider { [weak oauthClient] in
            guard let client = oauthClient else {
                throw ATProtoError.sessionRequired
            }
            return try await client.getAccessToken()
        }
    }
}

// MARK: - XRPCClient Authorization Extension

extension XRPCClient {
    /// Sets the authorization provider closure.
    func setAuthorizationProvider(_ provider: @escaping @Sendable () async throws -> String) {
        self.authorizationProvider = provider
    }
}

// MARK: - API Types

/// Input for com.atproto.repo.createRecord
public struct CreateRecordInput: Encodable, Sendable {
    public let repo: String
    public let collection: String
    public let record: AnyCodable
    public let rkey: String?
    public let validate: Bool?

    public init(repo: String, collection: String, record: AnyCodable, rkey: String? = nil, validate: Bool? = nil) {
        self.repo = repo
        self.collection = collection
        self.record = record
        self.rkey = rkey
        self.validate = validate
    }
}

/// Response from com.atproto.repo.createRecord
public struct CreateRecordResponse: Decodable, Sendable {
    public let uri: String
    public let cid: String
}

/// Input for com.atproto.repo.deleteRecord
public struct DeleteRecordInput: Encodable, Sendable {
    public let repo: String
    public let collection: String
    public let rkey: String
}

/// A profile view from app.bsky.actor.getProfile
public struct ProfileView: Codable, Sendable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let description: String?
    public let avatar: String?
    public let banner: String?
    public let followsCount: Int?
    public let followersCount: Int?
    public let postsCount: Int?
    public let indexedAt: String?
}

/// Timeline feed response
public struct TimelineFeed: Codable, Sendable {
    public let cursor: String?
    public let feed: [FeedViewPost]
}

/// A post in the feed
public struct FeedViewPost: Codable, Sendable {
    public let post: PostView
}

/// A post view
public struct PostView: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let author: ActorView
    public let record: AnyCodable
    public let replyCount: Int?
    public let repostCount: Int?
    public let likeCount: Int?
    public let indexedAt: String?
}

/// An actor view (lightweight profile)
public struct ActorView: Codable, Sendable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let avatar: String?
}
