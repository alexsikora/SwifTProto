import XCTest
@testable import ATProtoEventStream
@testable import ATProtoCore

final class RepoEventTests: XCTestCase {

    // MARK: - CommitEvent Creation Tests

    func testCommitEventCreationWithAllFields() {
        let ops = [
            RepoOp(action: .create, path: "app.bsky.feed.post/abc123", cid: CIDLink("bafyreicid1")),
            RepoOp(action: .delete, path: "app.bsky.feed.like/def456", cid: nil)
        ]
        let blocksData = Data("car-file-data".utf8)

        let event = CommitEvent(
            seq: 12345678,
            tooBig: false,
            repo: "did:plc:testuser",
            commit: CIDLink("bafyreicommit"),
            prev: CIDLink("bafyreiprev"),
            rev: "3kzhqhgxthsrq",
            time: "2024-01-15T10:30:00.000Z",
            ops: ops,
            blocks: blocksData
        )

        XCTAssertEqual(event.seq, 12345678)
        XCTAssertFalse(event.tooBig)
        XCTAssertEqual(event.repo, "did:plc:testuser")
        XCTAssertEqual(event.commit?.string, "bafyreicommit")
        XCTAssertEqual(event.prev?.string, "bafyreiprev")
        XCTAssertEqual(event.rev, "3kzhqhgxthsrq")
        XCTAssertEqual(event.time, "2024-01-15T10:30:00.000Z")
        XCTAssertEqual(event.ops.count, 2)
        XCTAssertNotNil(event.blocks)
        XCTAssertEqual(event.blocks, blocksData)
    }

    func testCommitEventWithMinimalFields() {
        let event = CommitEvent(
            seq: 1,
            repo: "did:plc:minimal",
            time: "2024-01-01T00:00:00.000Z"
        )

        XCTAssertEqual(event.seq, 1)
        XCTAssertFalse(event.tooBig)
        XCTAssertEqual(event.repo, "did:plc:minimal")
        XCTAssertNil(event.commit)
        XCTAssertNil(event.prev)
        XCTAssertNil(event.rev)
        XCTAssertEqual(event.time, "2024-01-01T00:00:00.000Z")
        XCTAssertTrue(event.ops.isEmpty)
        XCTAssertNil(event.blocks)
    }

    func testCommitEventWithTooBigFlag() {
        let event = CommitEvent(
            seq: 999,
            tooBig: true,
            repo: "did:plc:bigcommit",
            time: "2024-06-15T12:00:00.000Z"
        )

        XCTAssertTrue(event.tooBig)
    }

    // MARK: - RepoOp Collection and Rkey Extraction Tests

    func testRepoOpCollectionExtraction() {
        let op = RepoOp(
            action: .create,
            path: "app.bsky.feed.post/3kzhqhgxthsrq",
            cid: CIDLink("bafyreicid")
        )

        XCTAssertEqual(op.collection, "app.bsky.feed.post")
    }

    func testRepoOpRkeyExtraction() {
        let op = RepoOp(
            action: .create,
            path: "app.bsky.feed.post/3kzhqhgxthsrq",
            cid: CIDLink("bafyreicid")
        )

        XCTAssertEqual(op.rkey, "3kzhqhgxthsrq")
    }

    func testRepoOpCollectionWithLikePath() {
        let op = RepoOp(
            action: .create,
            path: "app.bsky.feed.like/abc123",
            cid: CIDLink("bafyreiliked")
        )

        XCTAssertEqual(op.collection, "app.bsky.feed.like")
        XCTAssertEqual(op.rkey, "abc123")
    }

    func testRepoOpCollectionWithFollowPath() {
        let op = RepoOp(
            action: .create,
            path: "app.bsky.graph.follow/xyz789"
        )

        XCTAssertEqual(op.collection, "app.bsky.graph.follow")
        XCTAssertEqual(op.rkey, "xyz789")
    }

    func testRepoOpCollectionWithNoSlash() {
        let op = RepoOp(
            action: .create,
            path: "singlepart"
        )

        XCTAssertEqual(op.collection, "singlepart")
        XCTAssertNil(op.rkey)
    }

    func testRepoOpCollectionWithEmptyPath() {
        let op = RepoOp(
            action: .create,
            path: ""
        )

        XCTAssertNil(op.collection)
        XCTAssertNil(op.rkey)
    }

    // MARK: - RepoOp.Action Raw Values Tests

    func testRepoOpActionCreateRawValue() {
        XCTAssertEqual(RepoOp.Action.create.rawValue, "create")
    }

    func testRepoOpActionUpdateRawValue() {
        XCTAssertEqual(RepoOp.Action.update.rawValue, "update")
    }

    func testRepoOpActionDeleteRawValue() {
        XCTAssertEqual(RepoOp.Action.delete.rawValue, "delete")
    }

    func testRepoOpActionFromRawValue() {
        XCTAssertEqual(RepoOp.Action(rawValue: "create"), .create)
        XCTAssertEqual(RepoOp.Action(rawValue: "update"), .update)
        XCTAssertEqual(RepoOp.Action(rawValue: "delete"), .delete)
        XCTAssertNil(RepoOp.Action(rawValue: "unknown"))
    }

    func testRepoOpDeleteHasNilCID() {
        let op = RepoOp(
            action: .delete,
            path: "app.bsky.feed.post/deletethis",
            cid: nil
        )

        XCTAssertEqual(op.action, .delete)
        XCTAssertNil(op.cid)
    }

    func testRepoOpCreateHasCID() {
        let cid = CIDLink("bafyreicreated")
        let op = RepoOp(
            action: .create,
            path: "app.bsky.feed.post/newpost",
            cid: cid
        )

        XCTAssertEqual(op.action, .create)
        XCTAssertNotNil(op.cid)
        XCTAssertEqual(op.cid?.string, "bafyreicreated")
    }

    func testRepoOpUpdateHasCID() {
        let cid = CIDLink("bafyreiupdated")
        let op = RepoOp(
            action: .update,
            path: "app.bsky.actor.profile/self",
            cid: cid
        )

        XCTAssertEqual(op.action, .update)
        XCTAssertNotNil(op.cid)
        XCTAssertEqual(op.cid?.string, "bafyreiupdated")
    }

    // MARK: - IdentityEvent Tests

    func testIdentityEventCreation() {
        let event = IdentityEvent(
            seq: 100,
            did: "did:plc:identity123",
            time: "2024-03-01T08:00:00.000Z",
            handle: "alice.bsky.social"
        )

        XCTAssertEqual(event.seq, 100)
        XCTAssertEqual(event.did, "did:plc:identity123")
        XCTAssertEqual(event.time, "2024-03-01T08:00:00.000Z")
        XCTAssertEqual(event.handle, "alice.bsky.social")
    }

    func testIdentityEventWithNilHandle() {
        let event = IdentityEvent(
            seq: 200,
            did: "did:plc:nohandle",
            time: "2024-03-01T09:00:00.000Z"
        )

        XCTAssertNil(event.handle)
    }

    // MARK: - HandleEvent Tests

    func testHandleEventCreation() {
        let event = HandleEvent(
            seq: 300,
            did: "did:plc:handleuser",
            handle: "newhandle.bsky.social",
            time: "2024-04-10T15:30:00.000Z"
        )

        XCTAssertEqual(event.seq, 300)
        XCTAssertEqual(event.did, "did:plc:handleuser")
        XCTAssertEqual(event.handle, "newhandle.bsky.social")
        XCTAssertEqual(event.time, "2024-04-10T15:30:00.000Z")
    }

    // MARK: - AccountEvent Tests

    func testAccountEventCreation() {
        let event = AccountEvent(
            seq: 400,
            did: "did:plc:accountuser",
            time: "2024-05-20T18:00:00.000Z",
            active: true,
            status: "active"
        )

        XCTAssertEqual(event.seq, 400)
        XCTAssertEqual(event.did, "did:plc:accountuser")
        XCTAssertEqual(event.time, "2024-05-20T18:00:00.000Z")
        XCTAssertTrue(event.active)
        XCTAssertEqual(event.status, "active")
    }

    func testAccountEventWithInactiveStatus() {
        let event = AccountEvent(
            seq: 401,
            did: "did:plc:suspended",
            time: "2024-05-21T10:00:00.000Z",
            active: false,
            status: "suspended"
        )

        XCTAssertFalse(event.active)
        XCTAssertEqual(event.status, "suspended")
    }

    func testAccountEventWithNilStatus() {
        let event = AccountEvent(
            seq: 402,
            did: "did:plc:nostatus",
            time: "2024-05-22T12:00:00.000Z",
            active: true
        )

        XCTAssertTrue(event.active)
        XCTAssertNil(event.status)
    }

    // MARK: - InfoEvent Tests

    func testInfoEventCreation() {
        let event = InfoEvent(
            name: "OutdatedCursor",
            message: "Cursor is too old"
        )

        XCTAssertEqual(event.name, "OutdatedCursor")
        XCTAssertEqual(event.message, "Cursor is too old")
    }

    func testInfoEventWithNilMessage() {
        let event = InfoEvent(name: "StreamReady")

        XCTAssertEqual(event.name, "StreamReady")
        XCTAssertNil(event.message)
    }

    // MARK: - RepoEvent Enum Tests

    func testRepoEventCommitCase() {
        let commitEvent = CommitEvent(
            seq: 1,
            repo: "did:plc:test",
            time: "2024-01-01T00:00:00.000Z"
        )
        let event = RepoEvent.commit(commitEvent)

        if case .commit(let inner) = event {
            XCTAssertEqual(inner.seq, 1)
            XCTAssertEqual(inner.repo, "did:plc:test")
        } else {
            XCTFail("Expected .commit case")
        }
    }

    func testRepoEventIdentityCase() {
        let identityEvent = IdentityEvent(seq: 2, did: "did:plc:id", time: "2024-01-01T00:00:00.000Z")
        let event = RepoEvent.identity(identityEvent)

        if case .identity(let inner) = event {
            XCTAssertEqual(inner.seq, 2)
        } else {
            XCTFail("Expected .identity case")
        }
    }

    func testRepoEventHandleCase() {
        let handleEvent = HandleEvent(seq: 3, did: "did:plc:hd", handle: "test.bsky.social", time: "now")
        let event = RepoEvent.handle(handleEvent)

        if case .handle(let inner) = event {
            XCTAssertEqual(inner.handle, "test.bsky.social")
        } else {
            XCTFail("Expected .handle case")
        }
    }

    func testRepoEventAccountCase() {
        let accountEvent = AccountEvent(seq: 4, did: "did:plc:ac", time: "now", active: true)
        let event = RepoEvent.account(accountEvent)

        if case .account(let inner) = event {
            XCTAssertTrue(inner.active)
        } else {
            XCTFail("Expected .account case")
        }
    }

    func testRepoEventInfoCase() {
        let infoEvent = InfoEvent(name: "test", message: "info message")
        let event = RepoEvent.info(infoEvent)

        if case .info(let inner) = event {
            XCTAssertEqual(inner.name, "test")
        } else {
            XCTFail("Expected .info case")
        }
    }

    func testRepoEventUnknownCase() {
        let data = Data("unknown data".utf8)
        let event = RepoEvent.unknown(type: "com.custom.event", data: data)

        if case .unknown(let type, let innerData) = event {
            XCTAssertEqual(type, "com.custom.event")
            XCTAssertEqual(innerData, data)
        } else {
            XCTFail("Expected .unknown case")
        }
    }
}
