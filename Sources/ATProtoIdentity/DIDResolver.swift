import Foundation
import ATProtoCore

// MARK: - DID Document

/// A resolved DID document containing identity information.
///
/// DID documents describe the public keys, service endpoints, and alternate
/// identifiers associated with a DID. In the AT Protocol, they are used to
/// discover a user's PDS and verify cryptographic signatures.
public struct DIDDocument: Codable, Sendable {
    public let id: String
    public let alsoKnownAs: [String]?
    public let verificationMethod: [VerificationMethod]?
    public let service: [Service]?

    public struct VerificationMethod: Codable, Sendable {
        public let id: String
        public let type: String
        public let controller: String
        public let publicKeyMultibase: String?
    }

    public struct Service: Codable, Sendable {
        public let id: String
        public let type: String
        public let serviceEndpoint: String
    }
}

// MARK: - DID Resolver Protocol

/// A protocol for resolving DIDs to their corresponding DID documents.
///
/// Conforming types implement the resolution logic for one or more DID methods
/// (e.g., `did:plc`, `did:web`).
public protocol DIDResolver: Sendable {
    /// Resolves a DID to its DID document.
    ///
    /// - Parameter did: The DID to resolve.
    /// - Returns: The resolved DID document.
    /// - Throws: ``ATProtoError/didResolutionFailed(_:)`` if resolution fails.
    func resolve(_ did: DID) async throws -> DIDDocument
}

// MARK: - PLC DID Resolver

/// Resolves `did:plc` identifiers via the PLC directory service.
///
/// The PLC directory is a centralized registry for `did:plc` identifiers.
/// Resolution is performed by fetching `<plcDirectoryURL>/<did>` and decoding
/// the returned JSON as a DID document.
public actor PLCDIDResolver: DIDResolver {
    /// The base URL of the PLC directory service.
    public let plcDirectoryURL: URL

    /// The HTTP executor used to perform network requests.
    private let httpExecutor: HTTPExecutor

    /// Creates a new PLC DID resolver.
    ///
    /// - Parameters:
    ///   - plcDirectoryURL: The PLC directory URL. Defaults to `https://plc.directory`.
    ///   - httpExecutor: The HTTP executor for performing network requests.
    public init(
        plcDirectoryURL: URL = URL(string: "https://plc.directory")!,
        httpExecutor: HTTPExecutor
    ) {
        self.plcDirectoryURL = plcDirectoryURL
        self.httpExecutor = httpExecutor
    }

    public func resolve(_ did: DID) async throws -> DIDDocument {
        guard did.method == .plc else {
            throw ATProtoError.didResolutionFailed("PLCDIDResolver can only resolve did:plc, got: \(did.string)")
        }

        guard let url = URL(string: "\(plcDirectoryURL.absoluteString)/\(did.string)") else {
            throw ATProtoError.invalidURL("Failed to construct PLC directory URL for \(did.string)")
        }

        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: ["Accept": "application/json"]
        )

        let response: HTTPResponse
        do {
            response = try await httpExecutor.execute(request)
        } catch {
            throw ATProtoError.didResolutionFailed("Network error resolving \(did.string): \(error.localizedDescription)")
        }

        guard response.isSuccess else {
            throw ATProtoError.didResolutionFailed(
                "PLC directory returned HTTP \(response.statusCode) for \(did.string)"
            )
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DIDDocument.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError("Failed to decode DID document for \(did.string): \(error.localizedDescription)")
        }
    }
}

// MARK: - Web DID Resolver

/// Resolves `did:web` identifiers via the `.well-known/did.json` endpoint.
///
/// For a `did:web:example.com`, the resolver fetches
/// `https://example.com/.well-known/did.json` and decodes the response as
/// a DID document. Colons in the method-specific identifier are replaced
/// with path separators per the `did:web` specification.
public actor WebDIDResolver: DIDResolver {
    /// The HTTP executor used to perform network requests.
    private let httpExecutor: HTTPExecutor

    /// Creates a new Web DID resolver.
    ///
    /// - Parameter httpExecutor: The HTTP executor for performing network requests.
    public init(httpExecutor: HTTPExecutor) {
        self.httpExecutor = httpExecutor
    }

    public func resolve(_ did: DID) async throws -> DIDDocument {
        guard did.method == .web else {
            throw ATProtoError.didResolutionFailed("WebDIDResolver can only resolve did:web, got: \(did.string)")
        }

        // The identifier for did:web is the domain, with colons representing path separators
        // e.g., did:web:example.com -> https://example.com/.well-known/did.json
        // e.g., did:web:example.com:path:to -> https://example.com/path/to/did.json
        let parts = did.identifier.split(separator: ":")
        guard let domain = parts.first else {
            throw ATProtoError.didResolutionFailed("Invalid did:web identifier: \(did.identifier)")
        }

        let urlString: String
        if parts.count > 1 {
            let path = parts.dropFirst().joined(separator: "/")
            urlString = "https://\(domain)/\(path)/did.json"
        } else {
            urlString = "https://\(domain)/.well-known/did.json"
        }

        guard let url = URL(string: urlString) else {
            throw ATProtoError.invalidURL("Failed to construct did:web URL: \(urlString)")
        }

        let request = HTTPRequest(
            method: .get,
            url: url,
            headers: ["Accept": "application/json"]
        )

        let response: HTTPResponse
        do {
            response = try await httpExecutor.execute(request)
        } catch {
            throw ATProtoError.didResolutionFailed("Network error resolving \(did.string): \(error.localizedDescription)")
        }

        guard response.isSuccess else {
            throw ATProtoError.didResolutionFailed(
                "did:web endpoint returned HTTP \(response.statusCode) for \(did.string)"
            )
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(DIDDocument.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError("Failed to decode DID document for \(did.string): \(error.localizedDescription)")
        }
    }
}

// MARK: - Composite DID Resolver

/// A composite resolver that delegates to the appropriate method-specific resolver.
///
/// This resolver inspects the DID method and dispatches to either the PLC or Web
/// resolver accordingly. It is the recommended resolver for general use since it
/// transparently handles both `did:plc` and `did:web` identifiers.
public actor CompositeDIDResolver: DIDResolver {
    private let plcResolver: PLCDIDResolver
    private let webResolver: WebDIDResolver

    /// Creates a new composite DID resolver.
    ///
    /// - Parameters:
    ///   - plcResolver: The resolver for `did:plc` identifiers.
    ///   - webResolver: The resolver for `did:web` identifiers.
    public init(plcResolver: PLCDIDResolver, webResolver: WebDIDResolver) {
        self.plcResolver = plcResolver
        self.webResolver = webResolver
    }

    /// Creates a new composite DID resolver with default sub-resolvers.
    ///
    /// - Parameters:
    ///   - httpExecutor: The HTTP executor for performing network requests.
    ///   - plcDirectoryURL: The PLC directory URL. Defaults to `https://plc.directory`.
    public init(
        httpExecutor: HTTPExecutor,
        plcDirectoryURL: URL = URL(string: "https://plc.directory")!
    ) {
        self.plcResolver = PLCDIDResolver(plcDirectoryURL: plcDirectoryURL, httpExecutor: httpExecutor)
        self.webResolver = WebDIDResolver(httpExecutor: httpExecutor)
    }

    public func resolve(_ did: DID) async throws -> DIDDocument {
        switch did.method {
        case .plc:
            return try await plcResolver.resolve(did)
        case .web:
            return try await webResolver.resolve(did)
        case .key, .other:
            throw ATProtoError.didResolutionFailed("Unsupported DID method: \(did.method) for \(did.string)")
        }
    }
}
