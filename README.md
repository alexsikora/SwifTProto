# SwifTProto

A comprehensive Swift SDK for the [AT Protocol](https://atproto.com), the decentralized social networking protocol powering [Bluesky](https://bsky.social).

## Features

- **Full AT Protocol coverage** -- XRPC client, identity resolution, OAuth 2.1, repository operations, event streaming
- **Modern Swift concurrency** -- Built with `actor`, `async/await`, and `Sendable` throughout
- **Modular architecture** -- Import only the modules you need
- **Type-safe identifiers** -- `DID`, `Handle`, `NSID`, `ATURI`, `TID` with validation and `Codable` support
- **OAuth 2.1 authentication** -- PAR, PKCE (S256), DPoP with automatic token refresh
- **Firehose streaming** -- WebSocket-based event stream with CBOR frame decoding
- **Lexicon code generation** -- CLI tool and SPM plugin for generating Swift types from Lexicon schemas
- **384 tests** across 7 test targets

## Requirements

- Swift 5.10+
- iOS 14+ / macOS 13+ / tvOS 14+ / watchOS 9+ / visionOS 1+

## Installation

Add SwifTProto to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/alexsikora/SwifTProto.git", from: "0.1.0")
]
```

Then add the modules you need:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "ATProtoAPI", package: "SwifTProto"),
    ]
)
```

## Quick Start

```swift
import ATProtoAPI

// Create an agent
let agent = try ATProtoAgent(serviceURL: URL(string: "https://bsky.social")!)

// Authenticate with OAuth
let authURL = try await agent.authorize(handle: Handle("alice.bsky.social")!)
// Present authURL to user, then handle the callback:
try await agent.handleCallback(url: callbackURL)

// Fetch a profile
let profile = try await agent.getProfile(actor: "alice.bsky.social")
print(profile.displayName ?? "No display name")

// Create a post
let post = try await agent.post(text: "Hello from SwifTProto!")

// Get your timeline
let timeline = try await agent.getTimeline(limit: 50)
for item in timeline.feed {
    print("\(item.post.author.handle): \(item.post.uri)")
}
```

## Namespace API

The SDK organizes AT Protocol methods into Swift namespaces that mirror the lexicon structure:

```swift
// app.bsky.actor.getProfile
let profile = try await agent.app.bsky.actor.getProfile(actor: "alice.bsky.social")

// app.bsky.feed.getTimeline
let timeline = try await agent.app.bsky.feed.getTimeline(limit: 30)

// app.bsky.graph.getFollowers
let followers = try await agent.app.bsky.graph.getFollowers(actor: "alice.bsky.social")

// com.atproto.repo.createRecord
let response = try await agent.com.atproto.repo.createRecord(
    repo: did, collection: "app.bsky.feed.post", record: record
)

// com.atproto.identity.resolveHandle
let resolved = try await agent.com.atproto.identity.resolveHandle(handle: "alice.bsky.social")
```

## Firehose Streaming

Subscribe to the AT Protocol relay firehose for real-time events:

```swift
for try await event in agent.firehose.subscribeRepos() {
    switch event {
    case .commit(let commit):
        for op in commit.ops {
            print("\(op.action): \(op.path)")
        }
    case .identity(let identity):
        print("Identity update: \(identity.did)")
    default:
        break
    }
}
```

## Core Types

All identifier types include validation, `Codable` conformance, and `ExpressibleByStringLiteral` support:

```swift
// Decentralized Identifiers
let did: DID = "did:plc:z72i7hdynmk6r22z27h6tvur"
did.method      // .plc
did.isPLC       // true

// Handles
let handle: Handle = "alice.bsky.social"
handle.tld      // "social"

// Namespace Identifiers
let nsid: NSID = "app.bsky.feed.post"
nsid.authority  // "app.bsky.feed"
nsid.name       // "post"

// AT URIs
let uri: ATURI = "at://alice.bsky.social/app.bsky.feed.post/abc123"
uri.authority   // "alice.bsky.social"
uri.collection  // NSID("app.bsky.feed.post")
uri.recordKey   // "abc123"

// Timestamp IDs
let tid = TID.now()
tid.timestamp   // microseconds since epoch
```

## Modules

| Module | Description |
|--------|-------------|
| **ATProtoCore** | Core types (`DID`, `Handle`, `NSID`, `ATURI`, `TID`, `CIDLink`, `BlobRef`), protocols, and error types |
| **ATProtoCrypto** | P-256 signing/verification, multikey encoding, JWK support |
| **ATProtoXRPC** | XRPC client with type-safe query/procedure methods and blob uploads |
| **ATProtoIdentity** | DID resolution (`did:plc`, `did:web`), handle resolution, PDS discovery |
| **ATProtoOAuth** | OAuth 2.1 with PAR, PKCE (S256), DPoP (ES256), token management, keychain storage |
| **ATProtoRepo** | Merkle Search Tree, repository operations, CAR file serialization, block storage |
| **ATProtoEventStream** | WebSocket firehose client, CBOR frame decoding, typed repo events |
| **ATProtoAPI** | High-level `ATProtoAgent` combining all modules with namespace-organized API |
| **LexiconCodegen** | CLI tool for generating Swift types from AT Protocol Lexicon JSON schemas |

## Direct XRPC Access

For endpoints not covered by the namespace API, use the XRPC client directly:

```swift
// Query (GET)
let result = try await agent.xrpc.query(
    "app.bsky.feed.searchPosts",
    parameters: ["q": "swift", "limit": "10"],
    output: SearchPostsResponse.self
)

// Procedure (POST)
let response = try await agent.xrpc.procedure(
    "com.atproto.repo.createRecord",
    input: CreateRecordInput(repo: repo, collection: collection, record: record),
    output: CreateRecordResponse.self
)

// Blob upload
let blob = try await agent.xrpc.uploadBlob(data: imageData, mimeType: "image/jpeg")
```

## Lexicon Code Generation

Generate Swift types from AT Protocol Lexicon schemas:

```bash
swift run lexigen --input ./Lexicons --output ./Sources/Generated --module-name ATProtoGenerated
```

Or use the SPM build plugin by placing Lexicon JSON files in a `Lexicons/` directory at your package root.

## Dependencies

- [swift-crypto](https://github.com/apple/swift-crypto) -- Cryptographic operations
- [SwiftCBOR](https://github.com/valpackett/SwiftCBOR) -- CBOR decoding for event streams and repo operations
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) -- CLI for the lexicon code generator
- [swift-log](https://github.com/apple/swift-log) -- Structured logging

## License

MIT
