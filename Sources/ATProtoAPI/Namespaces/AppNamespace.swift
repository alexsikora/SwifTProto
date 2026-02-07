import Foundation
import ATProtoCore
import ATProtoXRPC

/// Namespace for `app.bsky.*` API methods
public struct AppNamespace: Sendable {
    public let bsky: BskyNamespace

    init(xrpc: XRPCClient) {
        self.bsky = BskyNamespace(xrpc: xrpc)
    }
}

/// Namespace for `app.bsky.*` methods
public struct BskyNamespace: Sendable {
    public let actor: BskyActorNamespace
    public let feed: BskyFeedNamespace
    public let graph: BskyGraphNamespace
    public let notification: BskyNotificationNamespace

    init(xrpc: XRPCClient) {
        self.actor = BskyActorNamespace(xrpc: xrpc)
        self.feed = BskyFeedNamespace(xrpc: xrpc)
        self.graph = BskyGraphNamespace(xrpc: xrpc)
        self.notification = BskyNotificationNamespace(xrpc: xrpc)
    }
}

/// app.bsky.actor.* methods
public struct BskyActorNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Get a profile by actor identifier
    public func getProfile(actor: String) async throws -> ProfileView {
        try await xrpc.query(
            "app.bsky.actor.getProfile",
            parameters: ["actor": actor],
            output: ProfileView.self
        )
    }

    /// Search for actors
    public func searchActors(query: String, limit: Int = 25) async throws -> SearchActorsResponse {
        try await xrpc.query(
            "app.bsky.actor.searchActors",
            parameters: ["q": query, "limit": String(limit)],
            output: SearchActorsResponse.self
        )
    }

    /// Get suggested follows
    public func getSuggestions(limit: Int = 50) async throws -> SuggestionsResponse {
        try await xrpc.query(
            "app.bsky.actor.getSuggestions",
            parameters: ["limit": String(limit)],
            output: SuggestionsResponse.self
        )
    }
}

/// app.bsky.feed.* methods
public struct BskyFeedNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Get the authenticated user's timeline
    public func getTimeline(limit: Int = 50, cursor: String? = nil) async throws -> TimelineFeed {
        var params = ["limit": String(limit)]
        if let cursor = cursor { params["cursor"] = cursor }
        return try await xrpc.query("app.bsky.feed.getTimeline", parameters: params, output: TimelineFeed.self)
    }

    /// Get a post thread
    public func getPostThread(uri: String, depth: Int = 6) async throws -> PostThreadResponse {
        try await xrpc.query(
            "app.bsky.feed.getPostThread",
            parameters: ["uri": uri, "depth": String(depth)],
            output: PostThreadResponse.self
        )
    }

    /// Get an author's feed
    public func getAuthorFeed(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> AuthorFeed {
        var params = ["actor": actor, "limit": String(limit)]
        if let cursor = cursor { params["cursor"] = cursor }
        return try await xrpc.query("app.bsky.feed.getAuthorFeed", parameters: params, output: AuthorFeed.self)
    }

    /// Get likes on a post
    public func getLikes(uri: String, limit: Int = 50) async throws -> LikesResponse {
        try await xrpc.query(
            "app.bsky.feed.getLikes",
            parameters: ["uri": uri, "limit": String(limit)],
            output: LikesResponse.self
        )
    }
}

/// app.bsky.graph.* methods
public struct BskyGraphNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// Get followers of an actor
    public func getFollowers(actor: String, limit: Int = 50) async throws -> FollowersResponse {
        try await xrpc.query(
            "app.bsky.graph.getFollowers",
            parameters: ["actor": actor, "limit": String(limit)],
            output: FollowersResponse.self
        )
    }

    /// Get accounts an actor follows
    public func getFollows(actor: String, limit: Int = 50) async throws -> FollowsResponse {
        try await xrpc.query(
            "app.bsky.graph.getFollows",
            parameters: ["actor": actor, "limit": String(limit)],
            output: FollowsResponse.self
        )
    }
}

/// app.bsky.notification.* methods
public struct BskyNotificationNamespace: Sendable {
    private let xrpc: XRPCClient

    init(xrpc: XRPCClient) { self.xrpc = xrpc }

    /// List notifications
    public func listNotifications(limit: Int = 50, cursor: String? = nil) async throws -> NotificationsResponse {
        var params = ["limit": String(limit)]
        if let cursor = cursor { params["cursor"] = cursor }
        return try await xrpc.query("app.bsky.notification.listNotifications", parameters: params, output: NotificationsResponse.self)
    }

    /// Update the seen timestamp
    public func updateSeen(seenAt: Date = Date()) async throws {
        let input = UpdateSeenInput(seenAt: ISO8601DateFormatter().string(from: seenAt))
        try await xrpc.procedure("app.bsky.notification.updateSeen", input: input)
    }
}

// MARK: - Additional Response Types

public struct SearchActorsResponse: Codable, Sendable {
    public let cursor: String?
    public let actors: [ActorView]
}

public struct SuggestionsResponse: Codable, Sendable {
    public let cursor: String?
    public let actors: [ActorView]
}

public struct PostThreadResponse: Codable, Sendable {
    public let thread: AnyCodable  // Union type - would be properly typed with codegen
}

public struct AuthorFeed: Codable, Sendable {
    public let cursor: String?
    public let feed: [FeedViewPost]
}

public struct LikesResponse: Codable, Sendable {
    public let cursor: String?
    public let likes: [LikeView]
}

public struct LikeView: Codable, Sendable {
    public let indexedAt: String
    public let createdAt: String
    public let actor: ActorView
}

public struct FollowersResponse: Codable, Sendable {
    public let cursor: String?
    public let followers: [ActorView]
}

public struct FollowsResponse: Codable, Sendable {
    public let cursor: String?
    public let follows: [ActorView]
}

public struct NotificationsResponse: Codable, Sendable {
    public let cursor: String?
    public let notifications: [NotificationView]
}

public struct NotificationView: Codable, Sendable {
    public let uri: String
    public let cid: String
    public let author: ActorView
    public let reason: String
    public let isRead: Bool
    public let indexedAt: String
}

public struct UpdateSeenInput: Encodable, Sendable {
    public let seenAt: String
}
