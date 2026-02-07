import XCTest
@testable import ATProtoXRPC
@testable import ATProtoCore

// MARK: - Mock HTTP Executor (local to this test file)

final class MockHTTPExecutor: HTTPExecutor, @unchecked Sendable {
    private let lock = NSLock()

    private var _responses: [HTTPResponse] = []
    private var _capturedRequests: [HTTPRequest] = []

    var responses: [HTTPResponse] {
        lock.lock()
        defer { lock.unlock() }
        return _responses
    }

    var capturedRequests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRequests
    }

    init() {}

    func enqueue(_ response: HTTPResponse) {
        lock.lock()
        defer { lock.unlock() }
        _responses.append(response)
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.lock()
        _capturedRequests.append(request)
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
}

// MARK: - Helper Response Type

private struct TestProfile: Codable, Equatable {
    let handle: String
    let displayName: String
}

private struct TestInput: Codable {
    let text: String
}

private struct TestOutput: Codable, Equatable {
    let uri: String
    let cid: String
}

// MARK: - XRPCClient Tests

final class XRPCClientTests: XCTestCase {

    private let baseURL = URL(string: "https://bsky.social")!

    // MARK: - Query Tests

    func testQueryBuildsCorrectURLWithXRPCPathAndQueryParameters() async throws {
        let mock = MockHTTPExecutor()
        let profileJSON = """
        {"handle":"alice.bsky.social","displayName":"Alice"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(profileJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let result = try await client.query(
            "app.bsky.actor.getProfile",
            parameters: ["actor": "alice.bsky.social"],
            output: TestProfile.self
        )

        XCTAssertEqual(result.handle, "alice.bsky.social")
        XCTAssertEqual(result.displayName, "Alice")

        // Verify the captured request
        let capturedRequests = mock.capturedRequests
        XCTAssertEqual(capturedRequests.count, 1)

        let request = capturedRequests[0]
        XCTAssertEqual(request.method, .get)
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/app.bsky.actor.getProfile"))
        XCTAssertTrue(request.url.absoluteString.contains("actor=alice.bsky.social"))
    }

    func testQueryWithNoParameters() async throws {
        let mock = MockHTTPExecutor()
        let json = """
        {"handle":"bob.bsky.social","displayName":"Bob"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(json.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let result = try await client.query(
            "app.bsky.actor.getProfile",
            output: TestProfile.self
        )

        XCTAssertEqual(result.handle, "bob.bsky.social")

        let request = mock.capturedRequests[0]
        XCTAssertNil(request.url.query)
    }

    // MARK: - Procedure Tests

    func testProcedureSendsPOSTWithJSONBody() async throws {
        let mock = MockHTTPExecutor()
        let outputJSON = """
        {"uri":"at://did:plc:abc/app.bsky.feed.post/123","cid":"bafyabc"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(outputJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let input = TestInput(text: "Hello, world!")
        let result = try await client.procedure(
            "com.atproto.repo.createRecord",
            input: input,
            output: TestOutput.self
        )

        XCTAssertEqual(result.uri, "at://did:plc:abc/app.bsky.feed.post/123")
        XCTAssertEqual(result.cid, "bafyabc")

        let request = mock.capturedRequests[0]
        XCTAssertEqual(request.method, .post)
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/com.atproto.repo.createRecord"))
        XCTAssertNotNil(request.body)

        // Verify body contains the input
        let bodyString = String(data: request.body!, encoding: .utf8)
        XCTAssertNotNil(bodyString)
        XCTAssertTrue(bodyString!.contains("Hello, world!"))
    }

    func testProcedureWithVoidReturn() async throws {
        let mock = MockHTTPExecutor()
        mock.enqueue(HTTPResponse(statusCode: 200, headers: [:], body: Data()))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let input = TestInput(text: "delete me")

        // Should not throw for a 200 response
        try await client.procedure(
            "com.atproto.server.deleteSession",
            input: input
        )

        let request = mock.capturedRequests[0]
        XCTAssertEqual(request.method, .post)
    }

    // MARK: - Error Response Parsing

    func testErrorResponse4xxThrowsXRPCError() async throws {
        let mock = MockHTTPExecutor()
        let errorJSON = """
        {"error":"InvalidRequest","message":"Bad actor parameter"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 400,
            headers: [:],
            body: Data(errorJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        do {
            _ = try await client.query(
                "app.bsky.actor.getProfile",
                parameters: ["actor": ""],
                output: TestProfile.self
            )
            XCTFail("Expected an error to be thrown")
        } catch let error as ATProtoError {
            if case .xrpcError(let status, let errorStr, let message) = error {
                XCTAssertEqual(status, 400)
                XCTAssertEqual(errorStr, "InvalidRequest")
                XCTAssertEqual(message, "Bad actor parameter")
            } else {
                XCTFail("Expected xrpcError, got \(error)")
            }
        }
    }

    func testErrorResponse5xxThrowsXRPCError() async throws {
        let mock = MockHTTPExecutor()
        let errorJSON = """
        {"error":"InternalServerError","message":"Something went wrong"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 500,
            headers: [:],
            body: Data(errorJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        do {
            _ = try await client.query(
                "app.bsky.feed.getTimeline",
                output: TestProfile.self
            )
            XCTFail("Expected an error to be thrown")
        } catch let error as ATProtoError {
            if case .xrpcError(let status, _, _) = error {
                XCTAssertEqual(status, 500)
            } else {
                XCTFail("Expected xrpcError, got \(error)")
            }
        }
    }

    func testErrorResponse401UnauthorizedThrowsUnauthorized() async throws {
        let mock = MockHTTPExecutor()
        let errorJSON = """
        {"error":"AuthenticationRequired","message":"Login required"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(errorJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        do {
            _ = try await client.query(
                "app.bsky.feed.getTimeline",
                output: TestProfile.self
            )
            XCTFail("Expected an error to be thrown")
        } catch let error as ATProtoError {
            if case .unauthorized = error {
                // Expected
            } else {
                XCTFail("Expected unauthorized, got \(error)")
            }
        }
    }

    func testErrorResponse401ExpiredTokenThrowsTokenExpired() async throws {
        let mock = MockHTTPExecutor()
        let errorJSON = """
        {"error":"ExpiredToken","message":"Token has expired"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(errorJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        do {
            _ = try await client.query(
                "app.bsky.feed.getTimeline",
                output: TestProfile.self
            )
            XCTFail("Expected an error to be thrown")
        } catch let error as ATProtoError {
            if case .tokenExpired = error {
                // Expected
            } else {
                XCTFail("Expected tokenExpired, got \(error)")
            }
        }
    }

    // MARK: - Authorization Header Tests

    func testAuthorizationHeaderIsIncludedWhenProviderIsSet() async throws {
        let mock = MockHTTPExecutor()
        let json = """
        {"handle":"alice.bsky.social","displayName":"Alice"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(json.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)
        await setAuthProvider(on: client, value: "Bearer test-access-token-123")

        _ = try await client.query(
            "app.bsky.actor.getProfile",
            parameters: ["actor": "alice.bsky.social"],
            output: TestProfile.self
        )

        let request = mock.capturedRequests[0]
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-access-token-123")
    }

    func testNoAuthorizationHeaderWhenProviderIsNotSet() async throws {
        let mock = MockHTTPExecutor()
        let json = """
        {"handle":"public.bsky.social","displayName":"Public"}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(json.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        _ = try await client.query(
            "app.bsky.actor.getProfile",
            output: TestProfile.self
        )

        let request = mock.capturedRequests[0]
        XCTAssertNil(request.headers["Authorization"])
    }

    // MARK: - Blob Upload Tests

    func testBlobUploadSendsCorrectContentType() async throws {
        let mock = MockHTTPExecutor()
        let blobResponseJSON = """
        {"blob":{"$type":"blob","ref":{"$link":"bafyreiabc123"},"mimeType":"image/jpeg","size":1024}}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(blobResponseJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let imageData = Data(repeating: 0xFF, count: 1024)
        let response = try await client.uploadBlob(data: imageData, mimeType: "image/jpeg")

        XCTAssertEqual(response.blob.mimeType, "image/jpeg")
        XCTAssertEqual(response.blob.size, 1024)

        let request = mock.capturedRequests[0]
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.headers["Content-Type"], "image/jpeg")
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/com.atproto.repo.uploadBlob"))
        XCTAssertEqual(request.body?.count, 1024)
    }

    func testBlobUploadWithPNGContentType() async throws {
        let mock = MockHTTPExecutor()
        let blobResponseJSON = """
        {"blob":{"$type":"blob","ref":{"$link":"bafyreipng456"},"mimeType":"image/png","size":2048}}
        """
        mock.enqueue(HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(blobResponseJSON.utf8)
        ))

        let client = XRPCClient(serviceURL: baseURL, httpExecutor: mock)

        let pngData = Data(repeating: 0x89, count: 2048)
        let response = try await client.uploadBlob(data: pngData, mimeType: "image/png")

        XCTAssertEqual(response.blob.mimeType, "image/png")

        let request = mock.capturedRequests[0]
        XCTAssertEqual(request.headers["Content-Type"], "image/png")
    }
}

// MARK: - Helper for setting auth provider on actor

private func setAuthProvider(on client: XRPCClient, value: String) async {
    await client.setAuthProvider(value)
}

extension XRPCClient {
    /// Test helper to set the authorization provider from outside actor isolation.
    func setAuthProvider(_ token: String) {
        self.authorizationProvider = { token }
    }
}
