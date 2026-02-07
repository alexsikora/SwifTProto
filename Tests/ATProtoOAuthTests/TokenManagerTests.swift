import XCTest
@testable import ATProtoOAuth
@testable import ATProtoCore

final class TokenManagerTests: XCTestCase {

    // MARK: - Helpers

    private func makeTokenSet(
        accessToken: String = "access-token-123",
        refreshToken: String? = "refresh-token-456",
        tokenType: String = "DPoP",
        expiresIn: Int? = 3600,
        scope: String? = "atproto",
        sub: String = "did:plc:testuser123",
        expiresAt: Date? = nil
    ) -> TokenManager.TokenSet {
        TokenManager.TokenSet(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            scope: scope,
            sub: sub,
            expiresAt: expiresAt
        )
    }

    // MARK: - Store and Retrieve Tests

    func testStoreAndRetrieveTokens() async throws {
        let manager = TokenManager()
        let tokens = makeTokenSet()

        try await manager.storeTokens(tokens)

        let retrieved = await manager.getTokens()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.accessToken, "access-token-123")
        XCTAssertEqual(retrieved?.refreshToken, "refresh-token-456")
        XCTAssertEqual(retrieved?.tokenType, "DPoP")
        XCTAssertEqual(retrieved?.sub, "did:plc:testuser123")
        XCTAssertEqual(retrieved?.scope, "atproto")
    }

    func testStoreTokensSetsExpiresAtFromExpiresIn() async throws {
        let manager = TokenManager()
        let tokens = makeTokenSet(expiresIn: 3600, expiresAt: nil)

        let beforeStore = Date()
        try await manager.storeTokens(tokens)
        let afterStore = Date()

        let retrieved = await manager.getTokens()
        XCTAssertNotNil(retrieved?.expiresAt)

        // The expiresAt should be approximately now + 3600 seconds
        if let expiresAt = retrieved?.expiresAt {
            let expectedMin = beforeStore.addingTimeInterval(3600)
            let expectedMax = afterStore.addingTimeInterval(3600)
            XCTAssertGreaterThanOrEqual(expiresAt, expectedMin)
            XCTAssertLessThanOrEqual(expiresAt, expectedMax)
        }
    }

    func testStoreTokensPreservesExplicitExpiresAt() async throws {
        let manager = TokenManager()
        let specificDate = Date(timeIntervalSince1970: 1700000000)
        let tokens = makeTokenSet(expiresIn: 3600, expiresAt: specificDate)

        try await manager.storeTokens(tokens)

        let retrieved = await manager.getTokens()
        // When expiresAt is already set, it should remain as-is
        XCTAssertNotNil(retrieved?.expiresAt)
        XCTAssertEqual(retrieved?.expiresAt?.timeIntervalSince1970, 1700000000)
    }

    func testRetrieveTokensReturnsNilWhenEmpty() async {
        let manager = TokenManager()

        let retrieved = await manager.getTokens()
        XCTAssertNil(retrieved)
    }

    // MARK: - Clear Tokens Tests

    func testClearTokensRemovesStoredTokens() async throws {
        let manager = TokenManager()
        let tokens = makeTokenSet()

        try await manager.storeTokens(tokens)

        // Verify tokens exist
        let beforeClear = await manager.getTokens()
        XCTAssertNotNil(beforeClear)

        // Clear
        try await manager.clearTokens()

        // Verify tokens are gone
        let afterClear = await manager.getTokens()
        XCTAssertNil(afterClear)
    }

    func testClearTokensOnEmptyManagerDoesNotThrow() async throws {
        let manager = TokenManager()

        // Should not throw even if no tokens are stored
        try await manager.clearTokens()

        let retrieved = await manager.getTokens()
        XCTAssertNil(retrieved)
    }

    // MARK: - isExpired Tests

    func testIsExpiredReturnsTrueWhenNoTokensStored() async {
        let manager = TokenManager()

        let expired = await manager.isExpired()
        XCTAssertTrue(expired)
    }

    func testIsExpiredReturnsTrueWithExpiredToken() async throws {
        let manager = TokenManager()
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let tokens = makeTokenSet(expiresAt: pastDate)

        try await manager.storeTokens(tokens)

        let expired = await manager.isExpired()
        XCTAssertTrue(expired, "Token with expiry in the past should be expired")
    }

    func testIsExpiredReturnsFalseWithValidToken() async throws {
        let manager = TokenManager()
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: futureDate)

        try await manager.storeTokens(tokens)

        let expired = await manager.isExpired()
        XCTAssertFalse(expired, "Token with future expiry should not be expired")
    }

    func testIsExpiredReturnsTrueWhenNoExpiresAt() async throws {
        let manager = TokenManager()
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: nil)

        try await manager.storeTokens(tokens)

        let expired = await manager.isExpired()
        // When expiresAt is nil and expiresIn is nil, no date is computed, so isExpired returns true
        XCTAssertTrue(expired, "Token without expiry information should be treated as expired")
    }

    // MARK: - needsRefresh Tests

    func testNeedsRefreshReturnsTrueWhenNoTokensStored() async {
        let manager = TokenManager()

        let needsRefresh = await manager.needsRefresh()
        XCTAssertTrue(needsRefresh)
    }

    func testNeedsRefreshReturnsTrueWhenCloseToExpiry() async throws {
        let manager = TokenManager()
        // Token expires in 30 seconds, which is within the 60-second refresh window
        let nearFutureDate = Date().addingTimeInterval(30)
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: nearFutureDate)

        try await manager.storeTokens(tokens)

        let needsRefresh = await manager.needsRefresh()
        XCTAssertTrue(needsRefresh, "Token expiring within 60 seconds should need refresh")
    }

    func testNeedsRefreshReturnsFalseWhenWellWithinValidity() async throws {
        let manager = TokenManager()
        // Token expires in 2 hours, well beyond the 60-second window
        let farFutureDate = Date().addingTimeInterval(7200)
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: farFutureDate)

        try await manager.storeTokens(tokens)

        let needsRefresh = await manager.needsRefresh()
        XCTAssertFalse(needsRefresh, "Token with distant expiry should not need refresh")
    }

    func testNeedsRefreshReturnsTrueWhenExpired() async throws {
        let manager = TokenManager()
        let pastDate = Date().addingTimeInterval(-600) // 10 minutes ago
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: pastDate)

        try await manager.storeTokens(tokens)

        let needsRefresh = await manager.needsRefresh()
        XCTAssertTrue(needsRefresh, "Expired token should need refresh")
    }

    func testNeedsRefreshReturnsTrueExactlyAt60SecondBoundary() async throws {
        let manager = TokenManager()
        // Token expires in exactly 60 seconds -- the boundary
        let boundaryDate = Date().addingTimeInterval(60)
        let tokens = makeTokenSet(expiresIn: nil, expiresAt: boundaryDate)

        try await manager.storeTokens(tokens)

        let needsRefresh = await manager.needsRefresh()
        // Date().addingTimeInterval(60) >= boundaryDate should be true
        XCTAssertTrue(needsRefresh, "Token at exact 60-second boundary should need refresh")
    }

    // MARK: - Multiple Store Operations

    func testStoringNewTokensOverwritesPrevious() async throws {
        let manager = TokenManager()

        let tokens1 = makeTokenSet(accessToken: "first-token", sub: "did:plc:user1")
        try await manager.storeTokens(tokens1)

        let tokens2 = makeTokenSet(accessToken: "second-token", sub: "did:plc:user2")
        try await manager.storeTokens(tokens2)

        let retrieved = await manager.getTokens()
        XCTAssertEqual(retrieved?.accessToken, "second-token")
        XCTAssertEqual(retrieved?.sub, "did:plc:user2")
    }
}
