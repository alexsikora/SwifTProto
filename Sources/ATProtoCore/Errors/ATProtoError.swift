import Foundation

/// Errors that can occur during AT Protocol operations.
public enum ATProtoError: Error, Sendable {
    // MARK: - Validation Errors
    case invalidDID(String)
    case invalidHandle(String)
    case invalidNSID(String)
    case invalidATURI(String)
    case invalidTID(String)

    // MARK: - Network Errors
    case networkError(underlying: String)
    case timeout
    case invalidURL(String)

    // MARK: - XRPC Errors
    case xrpcError(status: Int, error: String?, message: String?)
    case invalidResponse
    case decodingError(String)
    case encodingError(String)

    // MARK: - Authentication Errors
    case unauthorized
    case tokenExpired
    case tokenRefreshFailed(String)
    case oauthError(OAuthErrorDetail)
    case sessionRequired

    // MARK: - Identity Errors
    case didResolutionFailed(String)
    case handleResolutionFailed(String)
    case pdsNotFound(String)

    // MARK: - Repository Errors
    case invalidRecord
    case recordNotFound(collection: String, rkey: String)
    case repositoryError(String)
    case mstError(String)

    // MARK: - Cryptographic Errors
    case cryptoError(String)
    case invalidSignature
    case unsupportedAlgorithm(String)

    // MARK: - Event Stream Errors
    case connectionClosed(reason: String?)
    case frameDecodingError(String)

    // MARK: - General
    case internalError(String)
}

/// Detailed OAuth error information
public struct OAuthErrorDetail: Sendable, Hashable {
    public let error: String
    public let errorDescription: String?
    public let errorURI: String?

    public init(error: String, errorDescription: String? = nil, errorURI: String? = nil) {
        self.error = error
        self.errorDescription = errorDescription
        self.errorURI = errorURI
    }
}

extension ATProtoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidDID(let s): return "Invalid DID: \(s)"
        case .invalidHandle(let s): return "Invalid handle: \(s)"
        case .invalidNSID(let s): return "Invalid NSID: \(s)"
        case .invalidATURI(let s): return "Invalid AT URI: \(s)"
        case .invalidTID(let s): return "Invalid TID: \(s)"
        case .networkError(let s): return "Network error: \(s)"
        case .timeout: return "Request timed out"
        case .invalidURL(let s): return "Invalid URL: \(s)"
        case .xrpcError(let status, let error, let message):
            var desc = "XRPC error \(status)"
            if let error = error { desc += " (\(error))" }
            if let message = message { desc += ": \(message)" }
            return desc
        case .invalidResponse: return "Invalid response from server"
        case .decodingError(let s): return "Decoding error: \(s)"
        case .encodingError(let s): return "Encoding error: \(s)"
        case .unauthorized: return "Unauthorized"
        case .tokenExpired: return "Authentication token expired"
        case .tokenRefreshFailed(let s): return "Token refresh failed: \(s)"
        case .oauthError(let detail):
            var desc = "OAuth error: \(detail.error)"
            if let d = detail.errorDescription { desc += " - \(d)" }
            return desc
        case .sessionRequired: return "An active session is required"
        case .didResolutionFailed(let s): return "DID resolution failed: \(s)"
        case .handleResolutionFailed(let s): return "Handle resolution failed: \(s)"
        case .pdsNotFound(let s): return "PDS not found for: \(s)"
        case .invalidRecord: return "Invalid record"
        case .recordNotFound(let c, let r): return "Record not found: \(c)/\(r)"
        case .repositoryError(let s): return "Repository error: \(s)"
        case .mstError(let s): return "MST error: \(s)"
        case .cryptoError(let s): return "Cryptographic error: \(s)"
        case .invalidSignature: return "Invalid signature"
        case .unsupportedAlgorithm(let s): return "Unsupported algorithm: \(s)"
        case .connectionClosed(let r): return "Connection closed\(r.map { ": \($0)" } ?? "")"
        case .frameDecodingError(let s): return "Frame decoding error: \(s)"
        case .internalError(let s): return "Internal error: \(s)"
        }
    }
}

/// An XRPC error response body from the server.
public struct XRPCErrorResponse: Codable, Sendable {
    public let error: String?
    public let message: String?

    public init(error: String?, message: String?) {
        self.error = error
        self.message = message
    }
}
