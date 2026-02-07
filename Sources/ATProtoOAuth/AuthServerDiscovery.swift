import Foundation
import ATProtoCore

/// OAuth authorization server metadata as defined by RFC 8414.
///
/// Contains the endpoints and capabilities advertised by an AT Protocol
/// authorization server at its `.well-known/oauth-authorization-server` endpoint.
public struct AuthServerMetadata: Codable, Sendable {
    /// The authorization server's issuer identifier (URL).
    public let issuer: String

    /// The URL of the authorization endpoint.
    public let authorizationEndpoint: String

    /// The URL of the token endpoint.
    public let tokenEndpoint: String

    /// The URL of the pushed authorization request (PAR) endpoint, if supported.
    public let pushedAuthorizationRequestEndpoint: String?

    /// The response types supported by the authorization server.
    public let responseTypesSupported: [String]?

    /// The grant types supported by the authorization server.
    public let grantTypesSupported: [String]?

    /// The PKCE code challenge methods supported.
    public let codeChallengeMethodsSupported: [String]?

    /// The client authentication methods supported at the token endpoint.
    public let tokenEndpointAuthMethodsSupported: [String]?

    /// The OAuth scopes supported by the authorization server.
    public let scopesSupported: [String]?

    /// The JWS algorithms supported for DPoP proof signing.
    public let dpopSigningAlgValuesSupported: [String]?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case responseTypesSupported = "response_types_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case scopesSupported = "scopes_supported"
        case dpopSigningAlgValuesSupported = "dpop_signing_alg_values_supported"
    }
}

/// Protected resource metadata as defined by RFC 9728.
///
/// Describes a protected resource (PDS) and lists the authorization servers
/// that can issue tokens for it.
public struct ProtectedResourceMetadata: Codable, Sendable {
    /// The identifier of the protected resource (typically the PDS URL).
    public let resource: String

    /// The authorization server URLs that can issue tokens for this resource.
    public let authorizationServers: [String]

    enum CodingKeys: String, CodingKey {
        case resource
        case authorizationServers = "authorization_servers"
    }
}

/// Discovers OAuth authorization server and protected resource metadata.
///
/// Fetches and caches metadata from well-known endpoints as specified by
/// the AT Protocol OAuth specification. The discovery process follows:
///
/// 1. Fetch protected resource metadata from the PDS to find the authorization server.
/// 2. Fetch authorization server metadata to get endpoint URLs and capabilities.
public actor AuthServerDiscovery {
    private let httpExecutor: HTTPExecutor
    private var metadataCache: [String: AuthServerMetadata] = [:]
    private var resourceCache: [String: ProtectedResourceMetadata] = [:]

    /// Creates a new authorization server discovery instance.
    ///
    /// - Parameter httpExecutor: The HTTP executor to use for metadata requests.
    public init(httpExecutor: HTTPExecutor) {
        self.httpExecutor = httpExecutor
    }

    /// Discovers OAuth authorization server metadata from the well-known endpoint.
    ///
    /// Fetches metadata from `<issuer>/.well-known/oauth-authorization-server`
    /// and caches the result for subsequent calls with the same issuer.
    ///
    /// - Parameter issuer: The authorization server's issuer URL.
    /// - Returns: The authorization server metadata.
    /// - Throws: ``ATProtoError/networkError(underlying:)`` if the request fails,
    ///   or ``ATProtoError/decodingError(_:)`` if the response cannot be parsed.
    public func discover(issuer: URL) async throws -> AuthServerMetadata {
        let issuerKey = issuer.absoluteString

        // Return cached metadata if available
        if let cached = metadataCache[issuerKey] {
            return cached
        }

        // Build well-known URL
        let wellKnownURL = issuer.appendingPathComponent(".well-known/oauth-authorization-server")

        let request = HTTPRequest(method: .get, url: wellKnownURL, headers: [
            "Accept": "application/json",
        ])

        let response = try await httpExecutor.execute(request)

        guard response.isSuccess else {
            throw ATProtoError.networkError(
                underlying: "Authorization server discovery failed with status \(response.statusCode)"
            )
        }

        let metadata: AuthServerMetadata
        do {
            metadata = try JSONDecoder().decode(AuthServerMetadata.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError(
                "Failed to decode authorization server metadata: \(error)"
            )
        }

        // Verify the issuer matches
        guard metadata.issuer == issuerKey else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_issuer",
                errorDescription: "Metadata issuer '\(metadata.issuer)' does not match requested issuer '\(issuerKey)'"
            ))
        }

        metadataCache[issuerKey] = metadata
        return metadata
    }

    /// Discovers protected resource metadata from a PDS.
    ///
    /// Fetches metadata from `<pdsURL>/.well-known/oauth-protected-resource`
    /// to determine which authorization servers can issue tokens for the PDS.
    ///
    /// - Parameter pdsURL: The PDS URL.
    /// - Returns: The protected resource metadata.
    /// - Throws: ``ATProtoError/networkError(underlying:)`` if the request fails,
    ///   or ``ATProtoError/decodingError(_:)`` if the response cannot be parsed.
    public func discoverProtectedResource(pdsURL: URL) async throws -> ProtectedResourceMetadata {
        let pdsKey = pdsURL.absoluteString

        // Return cached metadata if available
        if let cached = resourceCache[pdsKey] {
            return cached
        }

        let wellKnownURL = pdsURL.appendingPathComponent(".well-known/oauth-protected-resource")

        let request = HTTPRequest(method: .get, url: wellKnownURL, headers: [
            "Accept": "application/json",
        ])

        let response = try await httpExecutor.execute(request)

        guard response.isSuccess else {
            throw ATProtoError.networkError(
                underlying: "Protected resource discovery failed with status \(response.statusCode)"
            )
        }

        let metadata: ProtectedResourceMetadata
        do {
            metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError(
                "Failed to decode protected resource metadata: \(error)"
            )
        }

        resourceCache[pdsKey] = metadata
        return metadata
    }

    /// Clears all cached metadata.
    public func clearCache() {
        metadataCache.removeAll()
        resourceCache.removeAll()
    }
}
