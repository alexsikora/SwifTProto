import Foundation
import ATProtoCore

/// Represents the state of an OAuth session.
///
/// An `OAuthSession` tracks where in the OAuth lifecycle the client currently is,
/// from unauthenticated through authorization, authentication, expiration, and failure.
public struct OAuthSession: Sendable {
    /// The possible states of an OAuth session.
    public enum State: Sendable {
        /// No authentication has been initiated.
        case unauthenticated
        /// An authorization flow is in progress with the given state parameter.
        case authorizing(state: String)
        /// The user is authenticated with the given DID.
        case authenticated(did: DID)
        /// The access token has expired and needs refreshing.
        case expired
        /// The session encountered an unrecoverable error.
        case failed(Error)
    }

    /// The DID of the authenticated user, if available.
    public let did: DID?

    /// The current session state.
    public let state: State

    /// The PDS URL for the authenticated user, if known.
    public let pdsURL: URL?

    /// Whether the session is currently authenticated.
    public var isAuthenticated: Bool {
        if case .authenticated = state { return true } else { return false }
    }

    /// Creates a new OAuth session.
    ///
    /// - Parameters:
    ///   - did: The DID of the authenticated user, if available.
    ///   - state: The current session state.
    ///   - pdsURL: The PDS URL for the authenticated user, if known.
    public init(did: DID? = nil, state: State = .unauthenticated, pdsURL: URL? = nil) {
        self.did = did
        self.state = state
        self.pdsURL = pdsURL
    }
}
