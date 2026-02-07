import XCTest
@testable import ATProtoXRPC
@testable import ATProtoCore

private struct TestDecodable: Codable, Equatable {
    let name: String
    let value: Int
}

final class ResponseParserTests: XCTestCase {

    private let parser = XRPCResponseParser()

    // MARK: - Successful JSON Response Parsing

    func testSuccessfulJSONResponseParsing() throws {
        let json = """
        {"name":"test","value":42}
        """
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(json.utf8)
        )

        let result = try parser.parse(response, as: TestDecodable.self)
        XCTAssertEqual(result.name, "test")
        XCTAssertEqual(result.value, 42)
    }

    func testSuccessful201ResponseParsing() throws {
        let json = """
        {"name":"created","value":1}
        """
        let response = HTTPResponse(
            statusCode: 201,
            headers: [:],
            body: Data(json.utf8)
        )

        let result = try parser.parse(response, as: TestDecodable.self)
        XCTAssertEqual(result.name, "created")
    }

    func testEmptyBodyWithEmptyResponseType() throws {
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data())

        let result = try parser.parse(response, as: EmptyResponse.self)
        // EmptyResponse should decode successfully
        XCTAssertNotNil(result)
    }

    func testEmptyBodyWithNonEmptyTypeThrows() {
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data())

        XCTAssertThrowsError(try parser.parse(response, as: TestDecodable.self)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .invalidResponse = atError {
                // Expected
            } else {
                XCTFail("Expected invalidResponse, got \(atError)")
            }
        }
    }

    // MARK: - Error Response Parsing

    func testErrorResponseParsingExtractsErrorAndMessage() {
        let errorJSON = """
        {"error":"InvalidRequest","message":"Parameter 'actor' is required"}
        """
        let response = HTTPResponse(
            statusCode: 400,
            headers: [:],
            body: Data(errorJSON.utf8)
        )

        let error = parser.parseError(response)

        if case .xrpcError(let status, let errorStr, let message) = error {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(errorStr, "InvalidRequest")
            XCTAssertEqual(message, "Parameter 'actor' is required")
        } else {
            XCTFail("Expected xrpcError, got \(error)")
        }
    }

    func testErrorResponseParsing401Unauthorized() {
        let errorJSON = """
        {"error":"AuthenticationRequired","message":"Login needed"}
        """
        let response = HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(errorJSON.utf8)
        )

        let error = parser.parseError(response)

        if case .unauthorized = error {
            // Expected
        } else {
            XCTFail("Expected unauthorized, got \(error)")
        }
    }

    func testErrorResponseParsing401ExpiredToken() {
        let errorJSON = """
        {"error":"ExpiredToken","message":"Token has expired"}
        """
        let response = HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(errorJSON.utf8)
        )

        let error = parser.parseError(response)

        if case .tokenExpired = error {
            // Expected
        } else {
            XCTFail("Expected tokenExpired, got \(error)")
        }
    }

    func testErrorResponseParsing429RateLimit() {
        let errorJSON = """
        {"error":"RateLimitExceeded","message":"Too many requests"}
        """
        let response = HTTPResponse(
            statusCode: 429,
            headers: [:],
            body: Data(errorJSON.utf8)
        )

        let error = parser.parseError(response)

        if case .xrpcError(let status, let errorStr, let message) = error {
            XCTAssertEqual(status, 429)
            XCTAssertEqual(errorStr, "RateLimitExceeded")
            XCTAssertEqual(message, "Too many requests")
        } else {
            XCTFail("Expected xrpcError with 429, got \(error)")
        }
    }

    func testErrorResponseParsing429WithoutBody() {
        let response = HTTPResponse(
            statusCode: 429,
            headers: [:],
            body: Data()
        )

        let error = parser.parseError(response)

        if case .xrpcError(let status, let errorStr, let message) = error {
            XCTAssertEqual(status, 429)
            XCTAssertEqual(errorStr, "RateLimitExceeded")
            XCTAssertEqual(message, "Rate limit exceeded")
        } else {
            XCTFail("Expected xrpcError with 429 defaults, got \(error)")
        }
    }

    func testErrorResponseWithInvalidJSONBody() {
        let response = HTTPResponse(
            statusCode: 500,
            headers: [:],
            body: Data("not json".utf8)
        )

        let error = parser.parseError(response)

        if case .xrpcError(let status, let errorStr, let message) = error {
            XCTAssertEqual(status, 500)
            XCTAssertNil(errorStr)
            XCTAssertNil(message)
        } else {
            XCTFail("Expected xrpcError with nil fields, got \(error)")
        }
    }

    // MARK: - Rate Limit Header Parsing

    func testRateLimitHeaderParsingWithAllHeaders() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [
                "ratelimit-limit": "3000",
                "ratelimit-remaining": "2999",
                "ratelimit-reset": "1700000000",
                "ratelimit-policy": "3000;w=300"
            ],
            body: Data()
        )

        let rateLimitInfo = parser.parseRateLimitInfo(response)

        XCTAssertEqual(rateLimitInfo.limit, 3000)
        XCTAssertEqual(rateLimitInfo.remaining, 2999)
        XCTAssertNotNil(rateLimitInfo.reset)
        XCTAssertEqual(rateLimitInfo.reset?.timeIntervalSince1970, 1700000000)
        XCTAssertEqual(rateLimitInfo.policy, "3000;w=300")
    }

    func testRateLimitHeaderParsingWithMissingHeaders() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data()
        )

        let rateLimitInfo = parser.parseRateLimitInfo(response)

        XCTAssertNil(rateLimitInfo.limit)
        XCTAssertNil(rateLimitInfo.remaining)
        XCTAssertNil(rateLimitInfo.reset)
        XCTAssertNil(rateLimitInfo.policy)
    }

    func testRateLimitHeaderParsingWithPartialHeaders() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [
                "ratelimit-limit": "100",
                "ratelimit-remaining": "50"
            ],
            body: Data()
        )

        let rateLimitInfo = parser.parseRateLimitInfo(response)

        XCTAssertEqual(rateLimitInfo.limit, 100)
        XCTAssertEqual(rateLimitInfo.remaining, 50)
        XCTAssertNil(rateLimitInfo.reset)
        XCTAssertNil(rateLimitInfo.policy)
    }

    func testRateLimitHeaderParsingWithInvalidNumericValues() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [
                "ratelimit-limit": "not-a-number",
                "ratelimit-remaining": "abc"
            ],
            body: Data()
        )

        let rateLimitInfo = parser.parseRateLimitInfo(response)

        XCTAssertNil(rateLimitInfo.limit)
        XCTAssertNil(rateLimitInfo.remaining)
    }

    // MARK: - Non-JSON Response Handling

    func testDecodingErrorForMalformedJSON() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data("{invalid json}".utf8)
        )

        XCTAssertThrowsError(try parser.parse(response, as: TestDecodable.self)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .decodingError(let description) = atError {
                XCTAssertFalse(description.isEmpty)
            } else {
                XCTFail("Expected decodingError, got \(atError)")
            }
        }
    }

    func testDecodingErrorForMismatchedTypes() {
        // JSON has wrong types for the expected model
        let json = """
        {"name":123,"value":"not a number"}
        """
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data(json.utf8)
        )

        XCTAssertThrowsError(try parser.parse(response, as: TestDecodable.self)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .decodingError = atError {
                // Expected
            } else {
                XCTFail("Expected decodingError, got \(atError)")
            }
        }
    }

    func testParseThrowsForErrorStatusCode() {
        let json = """
        {"error":"NotFound","message":"Record not found"}
        """
        let response = HTTPResponse(
            statusCode: 404,
            headers: [:],
            body: Data(json.utf8)
        )

        XCTAssertThrowsError(try parser.parse(response, as: TestDecodable.self)) { error in
            guard let atError = error as? ATProtoError else {
                XCTFail("Expected ATProtoError, got \(error)")
                return
            }
            if case .xrpcError(let status, _, _) = atError {
                XCTAssertEqual(status, 404)
            } else {
                XCTFail("Expected xrpcError, got \(atError)")
            }
        }
    }
}
