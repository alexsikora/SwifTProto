import Foundation
import ATProtoCore

/// A mock HTTP executor for testing. Queues up responses and captures
/// requests for assertion. Thread-safe via a lock.
public final class MockHTTPExecutor: HTTPExecutor, @unchecked Sendable {

    // MARK: - State

    private let lock = NSLock()

    /// Queued responses that will be returned in FIFO order.
    private var _responses: [HTTPResponse] = []

    /// Captured requests in the order they were received.
    private var _requests: [HTTPRequest] = []

    /// Returns a copy of all captured requests.
    public var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    /// Returns a copy of all queued (not yet consumed) responses.
    public var responses: [HTTPResponse] {
        lock.lock()
        defer { lock.unlock() }
        return _responses
    }

    public init() {}

    // MARK: - Configuration

    /// Enqueues a response that will be returned by the next call to `execute(_:)`.
    ///
    /// Responses are consumed in FIFO order. If no responses are queued when
    /// `execute` is called, a 500 Internal Server Error is returned.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code. Defaults to 200.
    ///   - headers: Response headers. Defaults to an empty dictionary.
    ///   - body: The response body data. Defaults to empty data.
    public func enqueue(statusCode: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
        lock.lock()
        defer { lock.unlock() }
        _responses.append(HTTPResponse(statusCode: statusCode, headers: headers, body: body))
    }

    /// Convenience: enqueues a response whose body is the UTF-8 encoded JSON string.
    ///
    /// - Parameters:
    ///   - json: A JSON string that will be encoded as UTF-8 for the body.
    ///   - statusCode: The HTTP status code. Defaults to 200.
    /// - Returns: The mock executor (for chaining).
    @discardableResult
    public static func stub(json: String, statusCode: Int = 200) -> MockHTTPExecutor {
        let mock = MockHTTPExecutor()
        let body = json.data(using: .utf8) ?? Data()
        mock.enqueue(statusCode: statusCode, headers: ["Content-Type": "application/json"], body: body)
        return mock
    }

    // MARK: - HTTPExecutor

    public func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.lock()
        _requests.append(request)
        let response: HTTPResponse
        if _responses.isEmpty {
            response = HTTPResponse(
                statusCode: 500,
                headers: [:],
                body: Data("{\"error\":\"MockExhausted\",\"message\":\"No queued responses\"}".utf8)
            )
        } else {
            response = _responses.removeFirst()
        }
        lock.unlock()
        return response
    }

    // MARK: - Assertions Helpers

    /// The most recently captured request, or `nil` if none.
    public var lastRequest: HTTPRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _requests.last
    }

    /// Resets all captured requests and queued responses.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _requests.removeAll()
        _responses.removeAll()
    }
}
