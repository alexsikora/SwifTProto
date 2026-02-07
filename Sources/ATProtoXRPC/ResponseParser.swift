import Foundation
import ATProtoCore

/// Parsed rate limit information from XRPC response headers.
public struct XRPCRateLimitInfo: Sendable {
    /// The maximum number of requests allowed in the window.
    public let limit: Int?

    /// The number of requests remaining in the current window.
    public let remaining: Int?

    /// The Unix timestamp (seconds) when the rate limit window resets.
    public let reset: Date?

    /// The rate limit policy string (e.g., `100;w=300`).
    public let policy: String?

    public init(limit: Int?, remaining: Int?, reset: Date?, policy: String?) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
        self.policy = policy
    }
}

/// Parses XRPC HTTP responses into decoded Swift types or structured errors.
///
/// Handles success (2xx) responses by decoding the JSON body, and error
/// responses by extracting the XRPC error information and mapping it to
/// the appropriate `ATProtoError` case.
public struct XRPCResponseParser: Sendable {

    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    // MARK: - Response Parsing

    /// Parses a successful response body into the expected type.
    ///
    /// - Parameters:
    ///   - response: The HTTP response to parse.
    ///   - type: The expected `Decodable` type.
    /// - Returns: The decoded value.
    /// - Throws: `ATProtoError` if the response indicates an error or decoding fails.
    public func parse<T: Decodable>(_ response: HTTPResponse, as type: T.Type) throws -> T {
        guard response.isSuccess else {
            throw parseError(response)
        }

        // Handle Void-equivalent responses (empty body with success status)
        if response.body.isEmpty {
            // If the caller expects an empty-body type, try decoding anyway
            // This handles cases like 200 with no content
            if let emptyResult = EmptyResponse() as? T {
                return emptyResult
            }
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(type, from: response.body)
        } catch let error as DecodingError {
            throw ATProtoError.decodingError(describeDecodingError(error))
        } catch {
            throw ATProtoError.decodingError(error.localizedDescription)
        }
    }

    /// Parses an error response into an `ATProtoError`.
    ///
    /// Attempts to decode the response body as an `XRPCErrorResponse` to
    /// extract structured error information. Falls back to generic error
    /// cases for known HTTP status codes.
    ///
    /// - Parameter response: The HTTP response to parse.
    /// - Returns: An appropriate `ATProtoError` for the response.
    public func parseError(_ response: HTTPResponse) -> ATProtoError {
        // Attempt to decode structured XRPC error body
        let errorResponse = try? decoder.decode(XRPCErrorResponse.self, from: response.body)

        // Map well-known status codes to specific error cases
        switch response.statusCode {
        case 401:
            if errorResponse?.error == "ExpiredToken" {
                return .tokenExpired
            }
            return .unauthorized
        case 429:
            return .xrpcError(
                status: 429,
                error: errorResponse?.error ?? "RateLimitExceeded",
                message: errorResponse?.message ?? "Rate limit exceeded"
            )
        default:
            return .xrpcError(
                status: response.statusCode,
                error: errorResponse?.error,
                message: errorResponse?.message
            )
        }
    }

    // MARK: - Rate Limit Parsing

    /// Extracts rate limit information from response headers.
    ///
    /// The AT Protocol uses the following standard headers:
    /// - `ratelimit-limit`: Maximum requests allowed in the window
    /// - `ratelimit-remaining`: Requests remaining in the current window
    /// - `ratelimit-reset`: Unix timestamp when the window resets
    /// - `ratelimit-policy`: Description of the rate limit policy
    ///
    /// - Parameter response: The HTTP response containing rate limit headers.
    /// - Returns: Parsed rate limit information, with `nil` fields for missing headers.
    public func parseRateLimitInfo(_ response: HTTPResponse) -> XRPCRateLimitInfo {
        let headers = response.headers

        let limit = headers["ratelimit-limit"].flatMap(Int.init)
        let remaining = headers["ratelimit-remaining"].flatMap(Int.init)
        let reset: Date? = headers["ratelimit-reset"]
            .flatMap(TimeInterval.init)
            .map { Date(timeIntervalSince1970: $0) }
        let policy = headers["ratelimit-policy"]

        return XRPCRateLimitInfo(
            limit: limit,
            remaining: remaining,
            reset: reset,
            policy: policy
        )
    }

    // MARK: - Private Helpers

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch for \(type) at \(path): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Value not found for \(type) at \(path): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Key '\(key.stringValue)' not found at \(path): \(context.debugDescription)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Data corrupted at \(path): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}

/// An empty response placeholder for XRPC procedures that return no body.
public struct EmptyResponse: Codable, Sendable {
    public init() {}
}
