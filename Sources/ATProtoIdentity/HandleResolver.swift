import Foundation
import ATProtoCore

// MARK: - Handle Resolver Protocol

/// A protocol for resolving AT Protocol handles to their corresponding DIDs.
///
/// Handles are domain-based identifiers (e.g., `alice.bsky.social`) that
/// map to a DID. Resolution can be performed via DNS TXT records or HTTP
/// well-known endpoints.
public protocol HandleResolver: Sendable {
    /// Resolves a handle to its corresponding DID.
    ///
    /// - Parameter handle: The handle to resolve.
    /// - Returns: The DID associated with the handle.
    /// - Throws: ``ATProtoError/handleResolutionFailed(_:)`` if resolution fails.
    func resolve(_ handle: Handle) async throws -> DID
}

// MARK: - DNS Handle Resolver

/// Resolves AT Protocol handles using the HTTP well-known method.
///
/// This resolver attempts to resolve a handle by fetching
/// `https://<handle>/.well-known/atproto-did` and parsing the response body
/// as a DID string.
///
/// Per the AT Protocol specification, handles can be resolved via:
/// 1. A DNS TXT record at `_atproto.<handle>` containing `did=<did>`
/// 2. An HTTP GET to `https://<handle>/.well-known/atproto-did`
///
/// This implementation uses the HTTP method, which is more broadly accessible
/// from client environments where direct DNS queries may not be available.
public actor DNSHandleResolver: HandleResolver {
    /// The HTTP executor used to perform network requests.
    private let httpExecutor: HTTPExecutor

    /// Creates a new DNS handle resolver.
    ///
    /// - Parameter httpExecutor: The HTTP executor for performing network requests.
    public init(httpExecutor: HTTPExecutor) {
        self.httpExecutor = httpExecutor
    }

    public func resolve(_ handle: Handle) async throws -> DID {
        return try await resolveViaHTTP(handle)
    }

    // MARK: - Private

    /// Attempts resolution via the HTTP well-known endpoint.
    ///
    /// Fetches `https://<handle>/.well-known/atproto-did` and expects the
    /// response body to contain a bare DID string.
    private func resolveViaHTTP(_ handle: Handle) async throws -> DID {
        guard let url = URL(string: "https://\(handle.string)/.well-known/atproto-did") else {
            throw ATProtoError.invalidURL("Failed to construct well-known URL for handle: \(handle.string)")
        }

        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: ["Accept": "text/plain"]
        )

        let response: HTTPResponse
        do {
            response = try await httpExecutor.execute(request)
        } catch {
            throw ATProtoError.handleResolutionFailed(
                "Network error resolving handle \(handle.string): \(error.localizedDescription)"
            )
        }

        guard response.isSuccess else {
            throw ATProtoError.handleResolutionFailed(
                "Well-known endpoint returned HTTP \(response.statusCode) for handle: \(handle.string)"
            )
        }

        return try parseDIDFromResponse(response.body, handle: handle)
    }

    /// Parses and validates a DID from an HTTP response body.
    ///
    /// The response is expected to contain a bare DID string, optionally
    /// surrounded by whitespace.
    private func parseDIDFromResponse(_ data: Data, handle: Handle) throws -> DID {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ATProtoError.handleResolutionFailed(
                "Invalid UTF-8 response for handle: \(handle.string)"
            )
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            throw ATProtoError.handleResolutionFailed(
                "Empty DID response for handle: \(handle.string)"
            )
        }

        guard let did = DID(cleaned) else {
            throw ATProtoError.handleResolutionFailed(
                "Invalid DID in response for handle \(handle.string): \(cleaned)"
            )
        }

        return did
    }
}
