import XCTest
@testable import ATProtoOAuth
@testable import ATProtoCore

final class OAuthSessionTests: XCTestCase {

    // MARK: - Unauthenticated State Tests

    func testDefaultStateIsUnauthenticated() {
        let session = OAuthSession()

        if case .unauthenticated = session.state {
            // Expected
        } else {
            XCTFail("Default state should be unauthenticated, got \(session.state)")
        }
    }

    func testUnauthenticatedSessionHasNilDID() {
        let session = OAuthSession()

        XCTAssertNil(session.did)
    }

    func testUnauthenticatedSessionHasNilPDSURL() {
        let session = OAuthSession()

        XCTAssertNil(session.pdsURL)
    }

    func testUnauthenticatedSessionIsNotAuthenticated() {
        let session = OAuthSession()

        XCTAssertFalse(session.isAuthenticated)
    }

    // MARK: - Authenticated State Tests

    func testAuthenticatedStateWithDID() {
        let did: DID = "did:plc:testuser123"
        let session = OAuthSession(
            did: did,
            state: .authenticated(did: did),
            pdsURL: URL(string: "https://pds.example.com")
        )

        XCTAssertEqual(session.did?.string, "did:plc:testuser123")
        XCTAssertEqual(session.pdsURL?.absoluteString, "https://pds.example.com")
    }

    func testAuthenticatedStateIsAuthenticated() {
        let did: DID = "did:plc:alice"
        let session = OAuthSession(
            did: did,
            state: .authenticated(did: did)
        )

        XCTAssertTrue(session.isAuthenticated)
    }

    func testAuthenticatedStateWithWebDID() {
        let did: DID = "did:web:example.com"
        let session = OAuthSession(
            did: did,
            state: .authenticated(did: did)
        )

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.did?.method, .web)
    }

    func testAuthenticatedStateWithPLCDID() {
        let did: DID = "did:plc:user456"
        let session = OAuthSession(
            did: did,
            state: .authenticated(did: did)
        )

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.did?.method, .plc)
    }

    // MARK: - isAuthenticated Property Tests

    func testIsAuthenticatedReturnsFalseForUnauthenticated() {
        let session = OAuthSession(state: .unauthenticated)
        XCTAssertFalse(session.isAuthenticated)
    }

    func testIsAuthenticatedReturnsFalseForAuthorizing() {
        let session = OAuthSession(state: .authorizing(state: "random-state-string"))
        XCTAssertFalse(session.isAuthenticated)
    }

    func testIsAuthenticatedReturnsTrueForAuthenticated() {
        let did: DID = "did:plc:test"
        let session = OAuthSession(did: did, state: .authenticated(did: did))
        XCTAssertTrue(session.isAuthenticated)
    }

    func testIsAuthenticatedReturnsFalseForExpired() {
        let session = OAuthSession(state: .expired)
        XCTAssertFalse(session.isAuthenticated)
    }

    func testIsAuthenticatedReturnsFalseForFailed() {
        let error = NSError(domain: "test", code: 1)
        let session = OAuthSession(state: .failed(error))
        XCTAssertFalse(session.isAuthenticated)
    }

    // MARK: - State Transitions Tests

    func testAuthorizingStateHasStateParameter() {
        let session = OAuthSession(state: .authorizing(state: "oauth-state-abc"))

        if case .authorizing(let stateParam) = session.state {
            XCTAssertEqual(stateParam, "oauth-state-abc")
        } else {
            XCTFail("Expected authorizing state")
        }

        XCTAssertFalse(session.isAuthenticated)
    }

    func testExpiredState() {
        let did: DID = "did:plc:expired-user"
        let session = OAuthSession(did: did, state: .expired)

        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNotNil(session.did)
        XCTAssertEqual(session.did?.string, "did:plc:expired-user")
    }

    func testFailedStateWithError() {
        let error = ATProtoError.tokenRefreshFailed("Refresh token invalid")
        let session = OAuthSession(state: .failed(error))

        XCTAssertFalse(session.isAuthenticated)

        if case .failed(let sessionError) = session.state {
            XCTAssertNotNil(sessionError)
        } else {
            XCTFail("Expected failed state")
        }
    }

    func testTransitionFromUnauthenticatedToAuthorizing() {
        let session1 = OAuthSession(state: .unauthenticated)
        XCTAssertFalse(session1.isAuthenticated)

        let session2 = OAuthSession(state: .authorizing(state: "new-state"))
        XCTAssertFalse(session2.isAuthenticated)

        if case .authorizing(let state) = session2.state {
            XCTAssertEqual(state, "new-state")
        } else {
            XCTFail("Expected authorizing state")
        }
    }

    func testTransitionFromAuthorizingToAuthenticated() {
        let session1 = OAuthSession(state: .authorizing(state: "pending"))
        XCTAssertFalse(session1.isAuthenticated)

        let did: DID = "did:plc:newuser"
        let session2 = OAuthSession(
            did: did,
            state: .authenticated(did: did),
            pdsURL: URL(string: "https://pds.bsky.social")
        )
        XCTAssertTrue(session2.isAuthenticated)
        XCTAssertEqual(session2.did?.string, "did:plc:newuser")
        XCTAssertEqual(session2.pdsURL?.host, "pds.bsky.social")
    }

    func testTransitionFromAuthenticatedToExpired() {
        let did: DID = "did:plc:user"
        let session1 = OAuthSession(did: did, state: .authenticated(did: did))
        XCTAssertTrue(session1.isAuthenticated)

        let session2 = OAuthSession(did: did, state: .expired)
        XCTAssertFalse(session2.isAuthenticated)
    }

    func testTransitionFromExpiredToAuthenticated() {
        let did: DID = "did:plc:refreshed"
        let session1 = OAuthSession(did: did, state: .expired)
        XCTAssertFalse(session1.isAuthenticated)

        let session2 = OAuthSession(did: did, state: .authenticated(did: did))
        XCTAssertTrue(session2.isAuthenticated)
    }

    // MARK: - Session with Full Details

    func testSessionWithAllFields() {
        let did: DID = "did:plc:fulluser"
        let pdsURL = URL(string: "https://my-pds.example.com")!
        let session = OAuthSession(
            did: did,
            state: .authenticated(did: did),
            pdsURL: pdsURL
        )

        XCTAssertEqual(session.did?.string, "did:plc:fulluser")
        XCTAssertEqual(session.pdsURL, pdsURL)
        XCTAssertTrue(session.isAuthenticated)

        if case .authenticated(let authDID) = session.state {
            XCTAssertEqual(authDID.string, "did:plc:fulluser")
        } else {
            XCTFail("Expected authenticated state")
        }
    }
}
