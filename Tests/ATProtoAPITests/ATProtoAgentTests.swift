import XCTest
@testable import ATProtoAPI
@testable import ATProtoCore

final class ATProtoAgentTests: XCTestCase {

    func testAgentInitialization() throws {
        let url = URL(string: "https://bsky.social")!
        let agent = try ATProtoAgent(serviceURL: url)
        XCTAssertEqual(agent.serviceURL, url)
    }

    func testAgentIsNotAuthenticatedByDefault() async throws {
        let url = URL(string: "https://bsky.social")!
        let agent = try ATProtoAgent(serviceURL: url)
        let isAuth = await agent.isAuthenticated
        XCTAssertFalse(isAuth)
    }

    func testAgentSessionIsNilByDefault() async throws {
        let url = URL(string: "https://bsky.social")!
        let agent = try ATProtoAgent(serviceURL: url)
        let session = await agent.getSession()
        XCTAssertNil(session)
    }

    func testNamespaceAccessorsExist() throws {
        let url = URL(string: "https://bsky.social")!
        let agent = try ATProtoAgent(serviceURL: url)
        // Verify namespace accessors are available
        _ = agent.app
        _ = agent.com
        _ = agent.firehose
    }

    // MARK: - Response Type Tests

    func testProfileViewCodable() throws {
        let json = """
        {
            "did": "did:plc:test123",
            "handle": "alice.bsky.social",
            "displayName": "Alice",
            "description": "Hello world",
            "followsCount": 100,
            "followersCount": 200,
            "postsCount": 50
        }
        """
        let data = json.data(using: .utf8)!
        let profile = try JSONDecoder().decode(ProfileView.self, from: data)

        XCTAssertEqual(profile.did, "did:plc:test123")
        XCTAssertEqual(profile.handle, "alice.bsky.social")
        XCTAssertEqual(profile.displayName, "Alice")
        XCTAssertEqual(profile.followsCount, 100)
        XCTAssertEqual(profile.followersCount, 200)
        XCTAssertEqual(profile.postsCount, 50)
    }

    func testCreateRecordResponseCodable() throws {
        let json = """
        {"uri": "at://did:plc:test/app.bsky.feed.post/abc", "cid": "bafyrei123"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(CreateRecordResponse.self, from: data)

        XCTAssertEqual(response.uri, "at://did:plc:test/app.bsky.feed.post/abc")
        XCTAssertEqual(response.cid, "bafyrei123")
    }

    func testActorViewCodable() throws {
        let json = """
        {"did": "did:plc:actor", "handle": "bob.bsky.social", "displayName": "Bob"}
        """
        let data = json.data(using: .utf8)!
        let actor = try JSONDecoder().decode(ActorView.self, from: data)

        XCTAssertEqual(actor.did, "did:plc:actor")
        XCTAssertEqual(actor.handle, "bob.bsky.social")
        XCTAssertEqual(actor.displayName, "Bob")
        XCTAssertNil(actor.avatar)
    }
}
