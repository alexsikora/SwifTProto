// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwifTProto",
    platforms: [
        .iOS(.v14),
        .macOS(.v13),
        .tvOS(.v14),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ATProtoCore", targets: ["ATProtoCore"]),
        .library(name: "ATProtoCrypto", targets: ["ATProtoCrypto"]),
        .library(name: "ATProtoXRPC", targets: ["ATProtoXRPC"]),
        .library(name: "ATProtoIdentity", targets: ["ATProtoIdentity"]),
        .library(name: "ATProtoOAuth", targets: ["ATProtoOAuth"]),
        .library(name: "ATProtoRepo", targets: ["ATProtoRepo"]),
        .library(name: "ATProtoEventStream", targets: ["ATProtoEventStream"]),
        .library(name: "ATProtoAPI", targets: ["ATProtoAPI"]),
        .executable(name: "lexigen", targets: ["LexiconCodegen"]),
        .plugin(name: "GenerateLexiconPlugin", targets: ["GenerateLexiconPlugin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/valpackett/SwiftCBOR.git", from: "0.4.7"),
    ],
    targets: [
        // MARK: - Core Types
        .target(
            name: "ATProtoCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),

        // MARK: - Cryptography
        .target(
            name: "ATProtoCrypto",
            dependencies: [
                "ATProtoCore",
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),

        // MARK: - XRPC Client
        .target(
            name: "ATProtoXRPC",
            dependencies: [
                "ATProtoCore",
            ]
        ),

        // MARK: - Identity Resolution
        .target(
            name: "ATProtoIdentity",
            dependencies: [
                "ATProtoCore",
                "ATProtoXRPC",
            ]
        ),

        // MARK: - OAuth 2.1
        .target(
            name: "ATProtoOAuth",
            dependencies: [
                "ATProtoCore",
                "ATProtoCrypto",
                "ATProtoXRPC",
                "ATProtoIdentity",
            ]
        ),

        // MARK: - Repository Operations
        .target(
            name: "ATProtoRepo",
            dependencies: [
                "ATProtoCore",
                "ATProtoCrypto",
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
            ]
        ),

        // MARK: - Event Stream
        .target(
            name: "ATProtoEventStream",
            dependencies: [
                "ATProtoCore",
                .product(name: "SwiftCBOR", package: "SwiftCBOR"),
            ]
        ),

        // MARK: - High-Level API
        .target(
            name: "ATProtoAPI",
            dependencies: [
                "ATProtoCore",
                "ATProtoXRPC",
                "ATProtoIdentity",
                "ATProtoOAuth",
                "ATProtoRepo",
                "ATProtoEventStream",
            ]
        ),

        // MARK: - Code Generation
        .executableTarget(
            name: "LexiconCodegen",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - Plugins
        .plugin(
            name: "GenerateLexiconPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "LexiconCodegen"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "TestMocks",
            dependencies: ["ATProtoCore"],
            path: "Tests/Mocks"
        ),

        // MARK: - Tests
        .testTarget(
            name: "ATProtoCoreTests",
            dependencies: ["ATProtoCore"]
        ),
        .testTarget(
            name: "ATProtoCryptoTests",
            dependencies: ["ATProtoCrypto", "ATProtoCore"]
        ),
        .testTarget(
            name: "ATProtoXRPCTests",
            dependencies: ["ATProtoXRPC", "ATProtoCore", "TestMocks"]
        ),
        .testTarget(
            name: "ATProtoOAuthTests",
            dependencies: ["ATProtoOAuth", "ATProtoCrypto", "ATProtoCore"]
        ),
        .testTarget(
            name: "ATProtoRepoTests",
            dependencies: ["ATProtoRepo", "ATProtoCore"]
        ),
        .testTarget(
            name: "ATProtoEventStreamTests",
            dependencies: ["ATProtoEventStream", "ATProtoCore"]
        ),
        .testTarget(
            name: "ATProtoAPITests",
            dependencies: ["ATProtoAPI", "ATProtoCore", "TestMocks"]
        ),
    ]
)
