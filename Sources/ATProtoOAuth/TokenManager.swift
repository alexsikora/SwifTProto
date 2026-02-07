import Foundation
import ATProtoCore

/// Manages OAuth token lifecycle including storage and refresh.
///
/// `TokenManager` provides thread-safe token storage and retrieval, with
/// automatic expiration tracking. Tokens can optionally be persisted via
/// a ``SecureKeyStorage`` implementation (e.g., Keychain).
public actor TokenManager {
    /// A complete set of OAuth tokens from a token response.
    public struct TokenSet: Codable, Sendable {
        /// The access token for authenticating API requests.
        public let accessToken: String

        /// The refresh token for obtaining new access tokens, if provided.
        public let refreshToken: String?

        /// The token type, typically "DPoP" for AT Protocol OAuth.
        public let tokenType: String

        /// The lifetime of the access token in seconds, if provided.
        public let expiresIn: Int?

        /// The granted scope string.
        public let scope: String?

        /// The DID of the authenticated user.
        public let sub: String

        /// The absolute time at which the access token expires.
        public var expiresAt: Date?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case scope
            case sub
            case expiresAt = "expires_at"
        }

        public init(
            accessToken: String,
            refreshToken: String?,
            tokenType: String,
            expiresIn: Int?,
            scope: String?,
            sub: String,
            expiresAt: Date? = nil
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.tokenType = tokenType
            self.expiresIn = expiresIn
            self.scope = scope
            self.sub = sub
            self.expiresAt = expiresAt
        }
    }

    private var currentTokens: TokenSet?
    private let storage: SecureKeyStorage?
    private let storageKey: String

    /// Creates a new token manager.
    ///
    /// - Parameters:
    ///   - storage: An optional secure storage backend for persisting tokens
    ///     across app launches. If `nil`, tokens are only held in memory.
    ///   - storageKey: The key under which tokens are stored. Defaults to
    ///     `"com.swiftproto.tokens"`.
    public init(storage: SecureKeyStorage? = nil, storageKey: String = "com.swiftproto.tokens") {
        self.storage = storage
        self.storageKey = storageKey
        self.currentTokens = nil
    }

    /// Stores a token set in memory and, if configured, in persistent storage.
    ///
    /// If the token set includes an `expiresIn` value but no `expiresAt` date,
    /// the expiration date is computed automatically from the current time.
    ///
    /// - Parameter tokens: The token set to store.
    /// - Throws: An error if persistent storage fails.
    public func storeTokens(_ tokens: TokenSet) async throws {
        var mutableTokens = tokens
        if mutableTokens.expiresAt == nil, let expiresIn = mutableTokens.expiresIn {
            mutableTokens.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        }
        self.currentTokens = mutableTokens

        if let storage = storage {
            let data = try JSONEncoder().encode(mutableTokens)
            try await storage.store(key: storageKey, data: data)
        }
    }

    /// Returns the current token set, loading from persistent storage if needed.
    ///
    /// - Returns: The current token set, or `nil` if no tokens are available.
    public func getTokens() async -> TokenSet? {
        if let tokens = currentTokens {
            return tokens
        }

        // Attempt to load from persistent storage
        guard let storage = storage else { return nil }
        do {
            guard let data = try await storage.retrieve(key: storageKey) else { return nil }
            let tokens = try JSONDecoder().decode(TokenSet.self, from: data)
            self.currentTokens = tokens
            return tokens
        } catch {
            return nil
        }
    }

    /// Clears all stored tokens from memory and persistent storage.
    ///
    /// - Throws: An error if clearing persistent storage fails.
    public func clearTokens() async throws {
        self.currentTokens = nil
        if let storage = storage {
            try await storage.delete(key: storageKey)
        }
    }

    /// Returns whether the current access token has expired.
    ///
    /// If no tokens are stored or no expiration time is known, returns `true`.
    public func isExpired() async -> Bool {
        guard let tokens = await getTokens(),
              let expiresAt = tokens.expiresAt else {
            return true
        }
        return Date() >= expiresAt
    }

    /// Returns whether the current access token needs refreshing.
    ///
    /// Tokens are considered in need of refresh if they have expired or will
    /// expire within the next 60 seconds.
    ///
    /// - Returns: `true` if tokens should be refreshed.
    public func needsRefresh() async -> Bool {
        guard let tokens = await getTokens(),
              let expiresAt = tokens.expiresAt else {
            return true
        }
        // Refresh if expired or expiring within 60 seconds
        return Date().addingTimeInterval(60) >= expiresAt
    }
}
