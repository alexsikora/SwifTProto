import Foundation
import ATProtoCore

/// Client for subscribing to the AT Protocol event stream (firehose).
///
/// Connects via WebSocket to `com.atproto.sync.subscribeRepos` and yields
/// decoded events as an AsyncSequence.
public actor FirehoseClient {
    private let transport: WebSocketTransport
    private let decoder: CBORFrameDecoder
    private var connection: WebSocketStream?
    private var isConnected: Bool = false

    /// The default relay URL for Bluesky's firehose
    public static let defaultRelayURL = URL(string: "wss://bsky.network")!

    public init(transport: WebSocketTransport = URLSessionWebSocketTransport()) {
        self.transport = transport
        self.decoder = CBORFrameDecoder()
    }

    /// Subscribe to repository events from the firehose.
    ///
    /// - Parameters:
    ///   - url: The relay WebSocket URL (defaults to bsky.network)
    ///   - cursor: Optional sequence number to resume from
    /// - Returns: An AsyncThrowingStream of RepoEvents
    public func subscribeRepos(
        url: URL? = nil,
        cursor: Int64? = nil
    ) -> AsyncThrowingStream<RepoEvent, Error> {
        let relayURL = url ?? Self.defaultRelayURL

        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                do {
                    // Build subscription URL
                    var components = URLComponents(url: relayURL, resolvingAgainstBaseURL: false)!
                    components.path = "/xrpc/com.atproto.sync.subscribeRepos"
                    if let cursor = cursor {
                        components.queryItems = [URLQueryItem(name: "cursor", value: String(cursor))]
                    }

                    guard let subscribeURL = components.url else {
                        continuation.finish(throwing: ATProtoError.invalidURL(relayURL.absoluteString))
                        return
                    }

                    let stream = try await self.connect(to: subscribeURL)

                    // Read messages in a loop
                    while true {
                        let message = try await stream.receive()

                        switch message {
                        case .binary(let data):
                            do {
                                let event = try await self.decodeFrame(data)
                                continuation.yield(event)
                            } catch {
                                // Log but don't fail the stream on individual decode errors
                                continue
                            }
                        case .text:
                            // Text messages are unexpected on the firehose
                            continue
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Disconnect from the firehose
    public func disconnect() async {
        if let connection = connection {
            try? await connection.close(code: .normalClosure)
        }
        connection = nil
        isConnected = false
    }

    /// Whether the client is currently connected
    public var connected: Bool {
        isConnected
    }

    // MARK: - Private

    private func connect(to url: URL) async throws -> WebSocketStream {
        let stream = try await transport.connect(to: url)
        self.connection = stream
        self.isConnected = true
        return stream
    }

    private func decodeFrame(_ data: Data) throws -> RepoEvent {
        try decoder.decode(data)
    }
}
