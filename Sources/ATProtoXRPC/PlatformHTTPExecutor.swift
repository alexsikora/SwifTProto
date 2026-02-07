import Foundation
import ATProtoCore

/// An `HTTPExecutor` implementation backed by Foundation's `URLSession`.
///
/// This is the default HTTP transport for production use. It converts between
/// the platform-agnostic `HTTPRequest`/`HTTPResponse` types and Foundation's
/// `URLRequest`/`URLResponse` types, using `URLSession.shared` for networking.
public struct URLSessionHTTPExecutor: HTTPExecutor, Sendable {

    /// The URLSession used for executing requests.
    private let session: URLSession

    /// Creates an executor using the specified URLSession.
    ///
    /// - Parameter session: The URLSession to use. Defaults to `.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Executes an HTTP request and returns the response.
    ///
    /// Converts the `HTTPRequest` to a Foundation `URLRequest`, performs the
    /// network call using `URLSession`, and maps the result back to an
    /// `HTTPResponse` with extracted headers.
    ///
    /// - Parameter request: The HTTP request to execute.
    /// - Returns: The HTTP response with status code, headers, and body.
    /// - Throws: `ATProtoError.networkError` if the request fails or produces
    ///   an unexpected response type.
    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = request.urlRequest

        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw ATProtoError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw ATProtoError.networkError(underlying: error.localizedDescription)
            default:
                throw ATProtoError.networkError(underlying: error.localizedDescription)
            }
        } catch {
            throw ATProtoError.networkError(underlying: error.localizedDescription)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw ATProtoError.invalidResponse
        }

        let headers = extractHeaders(from: httpResponse)

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data
        )
    }

    // MARK: - Private Helpers

    /// Extracts HTTP headers from an `HTTPURLResponse` as a flat dictionary.
    ///
    /// Header field names are lowercased to enable case-insensitive lookups
    /// downstream (e.g., for rate limit headers).
    private func extractHeaders(from response: HTTPURLResponse) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString.lowercased()] = valueString
            }
        }
        return headers
    }
}
