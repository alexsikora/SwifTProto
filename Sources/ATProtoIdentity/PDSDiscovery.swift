import Foundation
import ATProtoCore

/// Discovers AT Protocol Personal Data Servers (PDS) and authorization servers
/// for a given identity.
///
/// `PDSDiscovery` combines DID and handle resolution to locate the PDS endpoint
/// associated with a user identity. It also supports discovering OAuth
/// authorization servers from a PDS's well-known configuration.
///
/// Usage:
/// ```swift
/// let discovery = PDSDiscovery(didResolver: resolver, handleResolver: handleResolver)
/// let pdsURL = try await discovery.discoverPDS(for: did)
/// ```
public actor PDSDiscovery {
    private let didResolver: DIDResolver
    private let handleResolver: HandleResolver

    /// Creates a new PDS discovery instance.
    ///
    /// - Parameters:
    ///   - didResolver: The resolver for converting DIDs to DID documents.
    ///   - handleResolver: The resolver for converting handles to DIDs.
    public init(didResolver: DIDResolver, handleResolver: HandleResolver) {
        self.didResolver = didResolver
        self.handleResolver = handleResolver
    }

    // MARK: - PDS Discovery

    /// Discovers the PDS URL for a given DID.
    ///
    /// Resolves the DID document and searches for a service entry with
    /// type `AtprotoPersonalDataServer` and id `#atproto_pds`.
    ///
    /// - Parameter did: The DID to discover the PDS for.
    /// - Returns: The PDS service endpoint URL.
    /// - Throws: ``ATProtoError/pdsNotFound(_:)`` if no PDS service is found.
    public func discoverPDS(for did: DID) async throws -> URL {
        let document = try await didResolver.resolve(did)

        guard let services = document.service else {
            throw ATProtoError.pdsNotFound("No services in DID document for \(did.string)")
        }

        guard let pdsService = services.first(where: { service in
            service.type == "AtprotoPersonalDataServer"
                && service.id == "#atproto_pds"
        }) else {
            throw ATProtoError.pdsNotFound(
                "No AtprotoPersonalDataServer service found in DID document for \(did.string)"
            )
        }

        guard let url = URL(string: pdsService.serviceEndpoint) else {
            throw ATProtoError.invalidURL(
                "Invalid PDS service endpoint URL: \(pdsService.serviceEndpoint)"
            )
        }

        return url
    }

    /// Discovers the PDS URL for a given handle.
    ///
    /// First resolves the handle to a DID, then discovers the PDS for that DID.
    ///
    /// - Parameter handle: The handle to discover the PDS for.
    /// - Returns: A tuple containing the resolved DID and the PDS URL.
    /// - Throws: ``ATProtoError/handleResolutionFailed(_:)`` or
    ///   ``ATProtoError/pdsNotFound(_:)`` if resolution fails.
    public func discoverPDS(for handle: Handle) async throws -> (did: DID, pdsURL: URL) {
        let did = try await handleResolver.resolve(handle)
        let pdsURL = try await discoverPDS(for: did)
        return (did: did, pdsURL: pdsURL)
    }

    // MARK: - Authorization Server Discovery

    /// Response structure for the OAuth protected resource metadata endpoint.
    private struct OAuthProtectedResourceMetadata: Codable, Sendable {
        let resource: String?
        let authorizationServers: [String]?

        enum CodingKeys: String, CodingKey {
            case resource
            case authorizationServers = "authorization_servers"
        }
    }

    /// Discovers the OAuth authorization server for a given PDS.
    ///
    /// Fetches the PDS's `/.well-known/oauth-protected-resource` endpoint and
    /// extracts the first authorization server URL from the response.
    ///
    /// - Parameter pdsURL: The PDS base URL to query.
    /// - Returns: The authorization server URL.
    /// - Throws: ``ATProtoError/pdsNotFound(_:)`` if no authorization server is found.
    public func discoverAuthServer(from pdsURL: URL, httpExecutor: HTTPExecutor) async throws -> URL {
        let wellKnownPath = "/.well-known/oauth-protected-resource"
        guard let url = URL(string: pdsURL.absoluteString.trimmingSuffix("/") + wellKnownPath) else {
            throw ATProtoError.invalidURL(
                "Failed to construct OAuth protected resource URL for \(pdsURL.absoluteString)"
            )
        }

        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: ["Accept": "application/json"]
        )

        let response: HTTPResponse
        do {
            response = try await httpExecutor.execute(request)
        } catch {
            throw ATProtoError.pdsNotFound(
                "Network error discovering auth server from \(pdsURL.absoluteString): \(error.localizedDescription)"
            )
        }

        guard response.isSuccess else {
            throw ATProtoError.pdsNotFound(
                "OAuth protected resource endpoint returned HTTP \(response.statusCode) for \(pdsURL.absoluteString)"
            )
        }

        let metadata: OAuthProtectedResourceMetadata
        do {
            let decoder = JSONDecoder()
            metadata = try decoder.decode(OAuthProtectedResourceMetadata.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError(
                "Failed to decode OAuth protected resource metadata from \(pdsURL.absoluteString): \(error.localizedDescription)"
            )
        }

        guard let servers = metadata.authorizationServers, let firstServer = servers.first else {
            throw ATProtoError.pdsNotFound(
                "No authorization servers found in OAuth protected resource metadata for \(pdsURL.absoluteString)"
            )
        }

        guard let authServerURL = URL(string: firstServer) else {
            throw ATProtoError.invalidURL("Invalid authorization server URL: \(firstServer)")
        }

        return authServerURL
    }
}

// MARK: - String Extension

extension String {
    /// Returns a new string with the specified suffix removed if present.
    fileprivate func trimmingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        }
        return self
    }
}
