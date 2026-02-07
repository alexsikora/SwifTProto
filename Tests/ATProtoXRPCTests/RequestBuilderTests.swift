import XCTest
@testable import ATProtoXRPC
@testable import ATProtoCore

final class RequestBuilderTests: XCTestCase {

    private let builder = XRPCRequestBuilder()
    private let baseURL = URL(string: "https://bsky.social")!

    // MARK: - buildQuery Tests

    func testBuildQueryCreatesGETRequestWithCorrectURL() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.actor.getProfile"
        )

        XCTAssertEqual(request.method, .get)
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/app.bsky.actor.getProfile"))
        XCTAssertTrue(request.url.absoluteString.hasPrefix("https://bsky.social"))
    }

    func testBuildQueryIncludesQueryParameters() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.actor.getProfile",
            parameters: ["actor": "alice.bsky.social", "limit": "50"]
        )

        let urlString = request.url.absoluteString
        XCTAssertTrue(urlString.contains("actor=alice.bsky.social"))
        XCTAssertTrue(urlString.contains("limit=50"))
    }

    func testBuildQueryWithEmptyParametersHasNoQueryString() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.feed.getTimeline",
            parameters: [:]
        )

        XCTAssertNil(request.url.query)
    }

    func testBuildQuerySetsAcceptHeaderToJSON() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.feed.getTimeline"
        )

        XCTAssertEqual(request.headers["Accept"], "application/json")
    }

    func testBuildQueryDoesNotOverrideExistingAcceptHeader() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.feed.getTimeline",
            headers: ["Accept": "text/plain"]
        )

        XCTAssertEqual(request.headers["Accept"], "text/plain")
    }

    func testBuildQueryParametersAreSortedByKey() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "com.atproto.repo.listRecords",
            parameters: ["repo": "did:plc:abc", "collection": "app.bsky.feed.post", "limit": "10"]
        )

        let query = request.url.query ?? ""
        // Parameters should be sorted: collection, limit, repo
        let collectionRange = query.range(of: "collection=")
        let limitRange = query.range(of: "limit=")
        let repoRange = query.range(of: "repo=")

        XCTAssertNotNil(collectionRange)
        XCTAssertNotNil(limitRange)
        XCTAssertNotNil(repoRange)

        // Verify order
        XCTAssertTrue(collectionRange!.lowerBound < limitRange!.lowerBound)
        XCTAssertTrue(limitRange!.lowerBound < repoRange!.lowerBound)
    }

    // MARK: - Query Parameter URL Encoding Tests

    func testQueryParametersAreURLEncoded() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.actor.searchActors",
            parameters: ["q": "hello world"]
        )

        let urlString = request.url.absoluteString
        // URL-encoded space should be present
        XCTAssertTrue(urlString.contains("q=hello%20world") || urlString.contains("q=hello+world"),
                       "Expected URL-encoded space in query parameter, got: \(urlString)")
    }

    func testQueryParametersWithSpecialCharacters() {
        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.actor.searchActors",
            parameters: ["q": "test&value=other"]
        )

        let urlString = request.url.absoluteString
        // The ampersand and equals should be encoded since they're inside a value
        XCTAssertFalse(urlString.contains("&value=other"),
                        "Ampersand inside parameter value should be encoded")
    }

    // MARK: - buildProcedure Tests

    func testBuildProcedureCreatesPOSTRequest() {
        let request = builder.buildProcedure(
            baseURL: baseURL,
            nsid: "com.atproto.repo.createRecord"
        )

        XCTAssertEqual(request.method, .post)
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/com.atproto.repo.createRecord"))
    }

    func testBuildProcedureWithBodySetsContentType() {
        let body = Data("{\"text\":\"hello\"}".utf8)
        let request = builder.buildProcedure(
            baseURL: baseURL,
            nsid: "com.atproto.repo.createRecord",
            body: body
        )

        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(request.body, body)
    }

    func testBuildProcedureWithNilBodyDoesNotSetContentType() {
        let request = builder.buildProcedure(
            baseURL: baseURL,
            nsid: "com.atproto.server.deleteSession",
            body: nil
        )

        XCTAssertNil(request.headers["Content-Type"])
        XCTAssertNil(request.body)
    }

    func testBuildProcedureDoesNotOverrideCustomContentType() {
        let body = Data("<xml/>".utf8)
        let request = builder.buildProcedure(
            baseURL: baseURL,
            nsid: "com.atproto.repo.createRecord",
            body: body,
            headers: ["Content-Type": "application/xml"]
        )

        XCTAssertEqual(request.headers["Content-Type"], "application/xml")
    }

    func testBuildProcedureSetsAcceptHeader() {
        let request = builder.buildProcedure(
            baseURL: baseURL,
            nsid: "com.atproto.repo.createRecord"
        )

        XCTAssertEqual(request.headers["Accept"], "application/json")
    }

    // MARK: - Headers Tests

    func testHeadersAreAppliedCorrectly() {
        let customHeaders = [
            "Authorization": "Bearer token123",
            "X-Custom": "value"
        ]

        let request = builder.buildQuery(
            baseURL: baseURL,
            nsid: "app.bsky.feed.getTimeline",
            headers: customHeaders
        )

        XCTAssertEqual(request.headers["Authorization"], "Bearer token123")
        XCTAssertEqual(request.headers["X-Custom"], "value")
        // Accept should still be set
        XCTAssertEqual(request.headers["Accept"], "application/json")
    }

    // MARK: - XRPC URL Construction Tests

    func testXRPCURLConstructionWithTrailingSlash() {
        let urlWithSlash = URL(string: "https://bsky.social/")!
        let result = builder.xrpcURL(baseURL: urlWithSlash, nsid: "app.bsky.feed.getTimeline")

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.absoluteString.contains("/xrpc/app.bsky.feed.getTimeline"))
        // Should not have double slashes before xrpc
        XCTAssertFalse(result!.absoluteString.contains("//xrpc"))
    }

    func testXRPCURLConstructionWithBasePath() {
        let url = URL(string: "https://bsky.social")!
        let result = builder.xrpcURL(baseURL: url, nsid: "com.atproto.server.createSession")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/xrpc/com.atproto.server.createSession")
    }

    // MARK: - Blob Upload Tests

    func testBuildBlobUploadSetsCorrectMIMEType() {
        let data = Data(repeating: 0xFF, count: 100)
        let request = builder.buildBlobUpload(
            baseURL: baseURL,
            data: data,
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.headers["Content-Type"], "image/jpeg")
        XCTAssertEqual(request.body, data)
        XCTAssertTrue(request.url.absoluteString.contains("/xrpc/com.atproto.repo.uploadBlob"))
    }

    func testBuildBlobUploadWithVideoMIMEType() {
        let data = Data(repeating: 0x00, count: 500)
        let request = builder.buildBlobUpload(
            baseURL: baseURL,
            data: data,
            mimeType: "video/mp4"
        )

        XCTAssertEqual(request.headers["Content-Type"], "video/mp4")
    }

    func testBuildBlobUploadIncludesAuthorizationHeader() {
        let data = Data(repeating: 0xFF, count: 100)
        let request = builder.buildBlobUpload(
            baseURL: baseURL,
            data: data,
            mimeType: "image/png",
            headers: ["Authorization": "Bearer my-token"]
        )

        XCTAssertEqual(request.headers["Authorization"], "Bearer my-token")
        XCTAssertEqual(request.headers["Content-Type"], "image/png")
    }
}
