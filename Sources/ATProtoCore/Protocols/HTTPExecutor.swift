import Foundation

/// Abstraction for HTTP request execution, enabling platform-specific
/// implementations and testing with mock transports.
public protocol HTTPExecutor: Sendable {
    /// Executes an HTTP request and returns the response.
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// A platform-agnostic HTTP request representation.
public struct HTTPRequest: Sendable {
    public let method: Method
    public let url: URL
    public var headers: [String: String]
    public var body: Data?
    public var timeoutInterval: TimeInterval

    public enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
        case head = "HEAD"
        case options = "OPTIONS"
    }

    public init(
        method: Method,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeoutInterval: TimeInterval = 30
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
    }

    /// Converts to a Foundation URLRequest
    public var urlRequest: URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = timeoutInterval
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

/// A platform-agnostic HTTP response representation.
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// Whether the response indicates success (2xx status code)
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }
}
