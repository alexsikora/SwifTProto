import Foundation
import ATProtoCore

/// Builds XRPC HTTP requests for query, procedure, and blob upload operations.
///
/// XRPC endpoints follow the pattern `<baseURL>/xrpc/<nsid>`, where the NSID
/// identifies the specific lexicon method being called.
public struct XRPCRequestBuilder: Sendable {

    public init() {}

    // MARK: - URL Construction

    /// Constructs the full XRPC endpoint URL from a base URL and NSID.
    ///
    /// - Parameters:
    ///   - baseURL: The service base URL (e.g., `https://bsky.social`).
    ///   - nsid: The namespaced identifier for the method (e.g., `com.atproto.repo.getRecord`).
    /// - Returns: The full endpoint URL, or `nil` if construction fails.
    public func xrpcURL(baseURL: URL, nsid: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        let basePath = components?.path ?? ""
        let trimmedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        components?.path = "\(trimmedBase)/xrpc/\(nsid)"
        return components?.url
    }

    // MARK: - Request Builders

    /// Builds a GET request for an XRPC query method.
    ///
    /// - Parameters:
    ///   - baseURL: The service base URL.
    ///   - nsid: The namespaced identifier for the query method.
    ///   - parameters: Query parameters to append to the URL.
    ///   - headers: HTTP headers to include in the request.
    /// - Returns: A configured `HTTPRequest` for the query.
    public func buildQuery(
        baseURL: URL,
        nsid: String,
        parameters: [String: String] = [:],
        headers: [String: String] = [:]
    ) -> HTTPRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
        let basePath = components.path
        let trimmedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        components.path = "\(trimmedBase)/xrpc/\(nsid)"

        if !parameters.isEmpty {
            components.queryItems = parameters.sorted(by: { $0.key < $1.key }).map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        let url = components.url ?? baseURL
        var allHeaders = headers
        allHeaders["Accept"] = allHeaders["Accept"] ?? "application/json"

        return HTTPRequest(
            method: .get,
            url: url,
            headers: allHeaders
        )
    }

    /// Builds a POST request for an XRPC procedure method.
    ///
    /// - Parameters:
    ///   - baseURL: The service base URL.
    ///   - nsid: The namespaced identifier for the procedure method.
    ///   - body: Optional JSON-encoded request body.
    ///   - headers: HTTP headers to include in the request.
    /// - Returns: A configured `HTTPRequest` for the procedure call.
    public func buildProcedure(
        baseURL: URL,
        nsid: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) -> HTTPRequest {
        guard let url = xrpcURL(baseURL: baseURL, nsid: nsid) else {
            // Fallback: append path directly
            let url = baseURL.appendingPathComponent("xrpc").appendingPathComponent(nsid)
            return HTTPRequest(method: .post, url: url, headers: headers, body: body)
        }

        var allHeaders = headers
        if body != nil {
            allHeaders["Content-Type"] = allHeaders["Content-Type"] ?? "application/json"
        }
        allHeaders["Accept"] = allHeaders["Accept"] ?? "application/json"

        return HTTPRequest(
            method: .post,
            url: url,
            headers: allHeaders,
            body: body
        )
    }

    /// Builds a POST request for uploading a blob.
    ///
    /// - Parameters:
    ///   - baseURL: The service base URL.
    ///   - data: The raw blob data to upload.
    ///   - mimeType: The MIME type of the blob (e.g., `image/jpeg`).
    ///   - headers: Additional HTTP headers to include.
    /// - Returns: A configured `HTTPRequest` for the blob upload.
    public func buildBlobUpload(
        baseURL: URL,
        data: Data,
        mimeType: String,
        headers: [String: String] = [:]
    ) -> HTTPRequest {
        guard let url = xrpcURL(baseURL: baseURL, nsid: "com.atproto.repo.uploadBlob") else {
            let url = baseURL
                .appendingPathComponent("xrpc")
                .appendingPathComponent("com.atproto.repo.uploadBlob")
            return HTTPRequest(method: .post, url: url, headers: headers, body: data)
        }

        var allHeaders = headers
        allHeaders["Content-Type"] = mimeType
        allHeaders["Accept"] = allHeaders["Accept"] ?? "application/json"

        return HTTPRequest(
            method: .post,
            url: url,
            headers: allHeaders,
            body: data
        )
    }
}
