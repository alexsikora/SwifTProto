import Foundation
import ATProtoCore

/// The main XRPC client for communicating with AT Protocol services.
///
/// `XRPCClient` provides typed methods for the two XRPC method kinds --
/// **queries** (GET requests) and **procedures** (POST requests) -- as well
/// as blob uploads. It relies on an `HTTPExecutor` for the actual network
/// transport, making it easy to swap in mock executors for testing.
///
/// The client is an `actor` to ensure thread-safe mutation of its
/// `authorizationProvider` and to serialize access to shared state.
///
/// ```swift
/// let client = XRPCClient(
///     serviceURL: URL(string: "https://bsky.social")!,
///     httpExecutor: URLSessionHTTPExecutor()
/// )
/// client.authorizationProvider = { "Bearer \(accessToken)" }
///
/// let profile = try await client.query(
///     "app.bsky.actor.getProfile",
///     parameters: ["actor": "alice.bsky.social"],
///     output: ProfileViewDetailed.self
/// )
/// ```
public actor XRPCClient {

    // MARK: - Properties

    /// The base URL of the XRPC service (e.g., `https://bsky.social`).
    public let serviceURL: URL

    /// The HTTP executor used to perform network requests.
    public let httpExecutor: HTTPExecutor

    /// An optional closure that provides an `Authorization` header value.
    ///
    /// When set, every outgoing request will include an `Authorization`
    /// header with the string returned by this closure (e.g., `"Bearer <token>"`).
    public var authorizationProvider: (@Sendable () async throws -> String)?

    private let requestBuilder: XRPCRequestBuilder
    private let responseParser: XRPCResponseParser
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new XRPC client.
    ///
    /// - Parameters:
    ///   - serviceURL: The base URL of the AT Protocol service.
    ///   - httpExecutor: The HTTP transport implementation to use.
    public init(serviceURL: URL, httpExecutor: HTTPExecutor) {
        self.serviceURL = serviceURL
        self.httpExecutor = httpExecutor
        self.requestBuilder = XRPCRequestBuilder()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        let parser = XRPCResponseParser(decoder: self.decoder)
        self.responseParser = parser
    }

    // MARK: - Query (GET)

    /// Executes an XRPC query (GET request) and decodes the response.
    ///
    /// - Parameters:
    ///   - nsid: The NSID of the query method (e.g., `"app.bsky.feed.getTimeline"`).
    ///   - parameters: Query string parameters to include in the URL.
    ///   - output: The expected response type.
    /// - Returns: The decoded response.
    /// - Throws: `ATProtoError` on network, decoding, or server errors.
    public func query<Output: Decodable>(
        _ nsid: String,
        parameters: [String: String] = [:],
        output: Output.Type
    ) async throws -> Output {
        let headers = try await buildAuthHeaders()
        let request = requestBuilder.buildQuery(
            baseURL: serviceURL,
            nsid: nsid,
            parameters: parameters,
            headers: headers
        )
        let response = try await executeRequest(request)
        return try responseParser.parse(response, as: output)
    }

    // MARK: - Procedure (POST) with Input and Output

    /// Executes an XRPC procedure (POST request) with an input body and decodes the response.
    ///
    /// - Parameters:
    ///   - nsid: The NSID of the procedure method (e.g., `"com.atproto.repo.createRecord"`).
    ///   - input: The request body to encode as JSON. Pass `nil` for procedures with no body.
    ///   - output: The expected response type.
    /// - Returns: The decoded response.
    /// - Throws: `ATProtoError` on encoding, network, decoding, or server errors.
    public func procedure<Input: Encodable, Output: Decodable>(
        _ nsid: String,
        input: Input?,
        output: Output.Type
    ) async throws -> Output {
        let body = try encodeInput(input)
        let headers = try await buildAuthHeaders()
        let request = requestBuilder.buildProcedure(
            baseURL: serviceURL,
            nsid: nsid,
            body: body,
            headers: headers
        )
        let response = try await executeRequest(request)
        return try responseParser.parse(response, as: output)
    }

    // MARK: - Procedure (POST) with Void Return

    /// Executes an XRPC procedure (POST request) with an input body and no expected response body.
    ///
    /// Use this variant for procedures that return `200 OK` with an empty body,
    /// such as `com.atproto.server.deleteSession`.
    ///
    /// - Parameters:
    ///   - nsid: The NSID of the procedure method.
    ///   - input: The request body to encode as JSON. Pass `nil` for procedures with no body.
    /// - Throws: `ATProtoError` on encoding, network, or server errors.
    public func procedure<Input: Encodable>(
        _ nsid: String,
        input: Input?
    ) async throws {
        let body = try encodeInput(input)
        let headers = try await buildAuthHeaders()
        let request = requestBuilder.buildProcedure(
            baseURL: serviceURL,
            nsid: nsid,
            body: body,
            headers: headers
        )
        let response = try await executeRequest(request)
        try handleVoidResponse(response)
    }

    // MARK: - Blob Upload

    /// Uploads binary data as a blob to the service.
    ///
    /// Calls `com.atproto.repo.uploadBlob` with the raw data and specified MIME type.
    /// The server returns a `BlobRef` (or similar type) that can be used in subsequent
    /// record creation calls.
    ///
    /// - Parameters:
    ///   - data: The raw blob data to upload.
    ///   - mimeType: The MIME type of the data (e.g., `"image/jpeg"`, `"video/mp4"`).
    /// - Returns: The decoded upload response (typically containing a blob reference).
    /// - Throws: `ATProtoError` on network or server errors.
    public func uploadBlob(data: Data, mimeType: String) async throws -> BlobUploadResponse {
        let headers = try await buildAuthHeaders()
        let request = requestBuilder.buildBlobUpload(
            baseURL: serviceURL,
            data: data,
            mimeType: mimeType,
            headers: headers
        )
        let response = try await executeRequest(request)
        return try responseParser.parse(response, as: BlobUploadResponse.self)
    }

    // MARK: - Private Helpers

    /// Builds an authorization header dictionary if a provider is set.
    private func buildAuthHeaders() async throws -> [String: String] {
        var headers: [String: String] = [:]
        if let provider = authorizationProvider {
            let authValue = try await provider()
            headers["Authorization"] = authValue
        }
        return headers
    }

    /// Encodes an optional `Encodable` input to JSON data.
    private func encodeInput<Input: Encodable>(_ input: Input?) throws -> Data? {
        guard let input = input else { return nil }
        do {
            return try encoder.encode(input)
        } catch {
            throw ATProtoError.encodingError(error.localizedDescription)
        }
    }

    /// Executes the HTTP request and maps transport errors.
    private func executeRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            return try await httpExecutor.execute(request)
        } catch let error as ATProtoError {
            throw error
        } catch {
            throw ATProtoError.networkError(underlying: error.localizedDescription)
        }
    }

    /// Validates a response for void-returning procedures.
    ///
    /// Succeeds for any 2xx response, throws for error responses.
    private func handleVoidResponse(_ response: HTTPResponse) throws {
        guard response.isSuccess else {
            throw responseParser.parseError(response)
        }
    }
}

// MARK: - Blob Upload Response

/// The response from `com.atproto.repo.uploadBlob`.
///
/// Contains a `blob` field with a reference to the uploaded blob,
/// which can be embedded in records.
public struct BlobUploadResponse: Codable, Sendable {
    /// The blob reference returned by the server.
    public let blob: BlobRef

    public init(blob: BlobRef) {
        self.blob = blob
    }
}
