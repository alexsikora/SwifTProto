import Foundation
import ATProtoCore

/// Protocol for WebSocket connections, enabling platform-specific implementations
public protocol WebSocketTransport: Sendable {
    func connect(to url: URL) async throws -> WebSocketStream
}

/// A stream of WebSocket messages
public protocol WebSocketStream: Sendable {
    func receive() async throws -> WebSocketMessage
    func send(_ message: WebSocketMessage) async throws
    func close(code: URLSessionWebSocketTask.CloseCode) async throws
}

/// WebSocket message types
public enum WebSocketMessage: Sendable {
    case text(String)
    case binary(Data)
}

/// URLSession-based WebSocket transport for Apple platforms
public final class URLSessionWebSocketTransport: WebSocketTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(to url: URL) async throws -> WebSocketStream {
        let task = session.webSocketTask(with: url)
        task.resume()
        return URLSessionWebSocketStream(task: task)
    }
}

/// URLSession-based WebSocket stream implementation
final class URLSessionWebSocketStream: WebSocketStream, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func receive() async throws -> WebSocketMessage {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return .text(text)
        case .data(let data):
            return .binary(data)
        @unknown default:
            throw ATProtoError.frameDecodingError("Unknown WebSocket message type")
        }
    }

    func send(_ message: WebSocketMessage) async throws {
        switch message {
        case .text(let text):
            try await task.send(.string(text))
        case .binary(let data):
            try await task.send(.data(data))
        }
    }

    func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure) async throws {
        task.cancel(with: code, reason: nil)
    }
}
