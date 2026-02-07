import Foundation
import ATProtoCore
import ATProtoCrypto
import ATProtoIdentity

/// Main OAuth 2.1 client for AT Protocol authentication.
///
/// Implements the full OAuth 2.1 flow as required by the AT Protocol specification,
/// including:
/// - **PAR** (Pushed Authorization Requests) to submit authorization parameters
///   securely to the authorization server.
/// - **PKCE** (Proof Key for Code Exchange) with S256 to protect the authorization
///   code exchange.
/// - **DPoP** (Demonstration of Proof-of-Possession) to bind tokens to a client
///   key pair, preventing token theft.
///
/// ## Usage
///
/// ```swift
/// let client = try OAuthClient(
///     clientID: "https://myapp.example.com/client-metadata.json",
///     redirectURI: "https://myapp.example.com/callback",
///     httpExecutor: myHTTPExecutor
/// )
///
/// // 1. Start authorization
/// let authURL = try await client.authorize(authServerURL: serverURL)
/// // 2. Present authURL to user in browser
/// // 3. Handle callback
/// let session = try await client.handleCallback(url: callbackURL)
/// ```
public actor OAuthClient {
    private let clientID: String
    private let redirectURI: String
    private let httpExecutor: HTTPExecutor
    private let crypto: CryptoProvider
    private let dpopManager: DPoPManager
    private let tokenManager: TokenManager
    private let authServerDiscovery: AuthServerDiscovery

    private var currentPKCE: PKCE?
    private var currentState: String?
    private var authServerMetadata: AuthServerMetadata?

    /// Creates a new OAuth client.
    ///
    /// - Parameters:
    ///   - clientID: The OAuth client identifier. For AT Protocol, this is typically
    ///     a URL pointing to the client metadata document.
    ///   - redirectURI: The redirect URI registered with the authorization server.
    ///   - httpExecutor: The HTTP executor for making network requests.
    ///   - crypto: The cryptographic provider. Defaults to ``DefaultCryptoProvider``.
    ///   - storage: An optional secure storage backend for persisting tokens.
    /// - Throws: ``ATProtoError/cryptoError(_:)`` if the DPoP key pair cannot be generated.
    public init(
        clientID: String,
        redirectURI: String,
        httpExecutor: HTTPExecutor,
        crypto: CryptoProvider = DefaultCryptoProvider(),
        storage: SecureKeyStorage? = nil
    ) throws {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.httpExecutor = httpExecutor
        self.crypto = crypto
        self.dpopManager = try DPoPManager(crypto: crypto)
        self.tokenManager = TokenManager(storage: storage)
        self.authServerDiscovery = AuthServerDiscovery(httpExecutor: httpExecutor)
    }

    /// Starts the OAuth authorization flow.
    ///
    /// This method performs the following steps:
    /// 1. Discovers authorization server metadata from the well-known endpoint.
    /// 2. Generates a PKCE code verifier and challenge.
    /// 3. Generates a cryptographic state parameter.
    /// 4. Submits a Pushed Authorization Request (PAR) to obtain a `request_uri`.
    /// 5. Constructs the authorization URL for the user to visit.
    ///
    /// - Parameters:
    ///   - authServerURL: The base URL of the authorization server.
    ///   - scope: The requested OAuth scope. Defaults to `"atproto transition:generic"`.
    /// - Returns: The authorization URL to present to the user (e.g., in a web view or browser).
    /// - Throws: ``ATProtoError/oauthError(_:)`` if the PAR request fails,
    ///   ``ATProtoError/networkError(underlying:)`` if a network request fails, or
    ///   ``ATProtoError/invalidURL(_:)`` if endpoint URLs are malformed.
    public func authorize(
        authServerURL: URL,
        scope: String = "atproto transition:generic"
    ) async throws -> URL {
        // 1. Discover auth server metadata
        let metadata = try await authServerDiscovery.discover(issuer: authServerURL)
        self.authServerMetadata = metadata

        // 2. Generate PKCE
        let pkce = PKCE(crypto: crypto)
        self.currentPKCE = pkce

        // 3. Generate state parameter
        let stateBytes = crypto.generateRandomBytes(count: 16)
        let state = JWK.base64urlEncode(stateBytes)
        self.currentState = state

        // 4. Push authorization request (PAR)
        guard let parEndpoint = metadata.pushedAuthorizationRequestEndpoint,
              let parURL = URL(string: parEndpoint) else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_server_metadata",
                errorDescription: "Authorization server does not support pushed authorization requests"
            ))
        }

        let parBody = buildFormBody([
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "response_type": "code",
            "scope": scope,
            "state": state,
            "code_challenge": pkce.codeChallenge,
            "code_challenge_method": pkce.codeChallengeMethod,
        ])

        let dpopProof = try await dpopManager.generateProof(httpMethod: "POST", url: parURL)

        var parRequest = HTTPRequest(
            method: .post,
            url: parURL,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "DPoP": dpopProof,
            ],
            body: parBody.data(using: .utf8)
        )

        var parResponse = try await httpExecutor.execute(parRequest)

        // Handle DPoP nonce requirement (use_dpop_nonce)
        if parResponse.statusCode == 400,
           let nonce = parResponse.headers["dpop-nonce"] ?? parResponse.headers["DPoP-Nonce"] {
            await dpopManager.updateNonce(nonce)
            let retryProof = try await dpopManager.generateProof(httpMethod: "POST", url: parURL)
            parRequest.headers["DPoP"] = retryProof
            parResponse = try await httpExecutor.execute(parRequest)
        }

        guard parResponse.isSuccess else {
            let errorDetail = try? JSONDecoder().decode(OAuthErrorResponse.self, from: parResponse.body)
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: errorDetail?.error ?? "par_request_failed",
                errorDescription: errorDetail?.errorDescription ?? "PAR request failed with status \(parResponse.statusCode)"
            ))
        }

        let parResult = try JSONDecoder().decode(PARResponse.self, from: parResponse.body)

        // 5. Build authorization URL
        guard let authEndpoint = URL(string: metadata.authorizationEndpoint) else {
            throw ATProtoError.invalidURL(metadata.authorizationEndpoint)
        }

        guard var components = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false) else {
            throw ATProtoError.invalidURL(metadata.authorizationEndpoint)
        }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "request_uri", value: parResult.requestURI),
        ]

        guard let authorizationURL = components.url else {
            throw ATProtoError.invalidURL("Failed to construct authorization URL")
        }

        return authorizationURL
    }

    /// Handles the OAuth callback after user authorization.
    ///
    /// Parses the authorization code from the callback URL, verifies the state
    /// parameter, and exchanges the code for tokens at the token endpoint using
    /// DPoP-bound requests.
    ///
    /// - Parameter url: The callback URL received after the user authorizes.
    /// - Returns: An ``OAuthSession`` representing the authenticated state.
    /// - Throws: ``ATProtoError/oauthError(_:)`` if the state does not match or the
    ///   token exchange fails, ``ATProtoError/sessionRequired`` if no authorization
    ///   flow is in progress.
    public func handleCallback(url: URL) async throws -> OAuthSession {
        // 1. Parse code and state from callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ATProtoError.invalidURL("Invalid callback URL")
        }

        let queryItems = components.queryItems ?? []

        // Check for error response
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: error,
                errorDescription: errorDescription
            ))
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_callback",
                errorDescription: "Authorization code not found in callback URL"
            ))
        }

        guard let state = queryItems.first(where: { $0.name == "state" })?.value else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_callback",
                errorDescription: "State parameter not found in callback URL"
            ))
        }

        // 2. Verify state matches
        guard state == currentState else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_state",
                errorDescription: "State parameter does not match expected value"
            ))
        }

        // 3. Verify we have PKCE and metadata
        guard let pkce = currentPKCE else {
            throw ATProtoError.sessionRequired
        }

        guard let metadata = authServerMetadata,
              let tokenURL = URL(string: metadata.tokenEndpoint) else {
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: "invalid_state",
                errorDescription: "Authorization server metadata not available"
            ))
        }

        // 4. Exchange code for tokens
        let tokenBody = buildFormBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": pkce.codeVerifier,
        ])

        let session = try await performTokenRequest(
            url: tokenURL,
            body: tokenBody
        )

        // Clear authorization state
        self.currentPKCE = nil
        self.currentState = nil

        return session
    }

    /// Refreshes the access token using the stored refresh token.
    ///
    /// - Returns: An ``OAuthSession`` with the new tokens.
    /// - Throws: ``ATProtoError/tokenRefreshFailed(_:)`` if no refresh token is available,
    ///   ``ATProtoError/oauthError(_:)`` if the refresh request fails.
    public func refreshTokens() async throws -> OAuthSession {
        guard let tokens = await tokenManager.getTokens() else {
            throw ATProtoError.tokenRefreshFailed("No tokens available for refresh")
        }

        guard let refreshToken = tokens.refreshToken else {
            throw ATProtoError.tokenRefreshFailed("No refresh token available")
        }

        guard let metadata = authServerMetadata,
              let tokenURL = URL(string: metadata.tokenEndpoint) else {
            throw ATProtoError.tokenRefreshFailed("Authorization server metadata not available")
        }

        let tokenBody = buildFormBody([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])

        return try await performTokenRequest(url: tokenURL, body: tokenBody)
    }

    /// Returns a valid access token, refreshing if necessary.
    ///
    /// If the current access token has expired or is about to expire (within 60 seconds),
    /// a refresh is performed automatically before returning the new token.
    ///
    /// - Returns: A valid access token string.
    /// - Throws: ``ATProtoError/sessionRequired`` if no tokens are stored,
    ///   ``ATProtoError/tokenRefreshFailed(_:)`` if refreshing fails.
    public func getAccessToken() async throws -> String {
        if await tokenManager.needsRefresh() {
            let _ = try await refreshTokens()
        }

        guard let tokens = await tokenManager.getTokens() else {
            throw ATProtoError.sessionRequired
        }

        return tokens.accessToken
    }

    /// Returns the current session state.
    ///
    /// - Returns: An ``OAuthSession`` representing the current state.
    public func getSession() async -> OAuthSession {
        if let state = currentState {
            return OAuthSession(state: .authorizing(state: state))
        }

        guard let tokens = await tokenManager.getTokens() else {
            return OAuthSession(state: .unauthenticated)
        }

        if await tokenManager.isExpired() {
            guard let did = DID(tokens.sub) else {
                return OAuthSession(state: .expired)
            }
            return OAuthSession(did: did, state: .expired)
        }

        guard let did = DID(tokens.sub) else {
            return OAuthSession(state: .failed(
                ATProtoError.invalidDID(tokens.sub)
            ))
        }

        return OAuthSession(did: did, state: .authenticated(did: did))
    }

    // MARK: - Private Helpers

    /// Performs a token request with DPoP proof and handles nonce retry.
    private func performTokenRequest(url: URL, body: String) async throws -> OAuthSession {
        let dpopProof = try await dpopManager.generateProof(httpMethod: "POST", url: url)

        var request = HTTPRequest(
            method: .post,
            url: url,
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "DPoP": dpopProof,
            ],
            body: body.data(using: .utf8)
        )

        var response = try await httpExecutor.execute(request)

        // Handle DPoP nonce requirement
        if response.statusCode == 400,
           let nonce = response.headers["dpop-nonce"] ?? response.headers["DPoP-Nonce"] {
            await dpopManager.updateNonce(nonce)
            let retryProof = try await dpopManager.generateProof(httpMethod: "POST", url: url)
            request.headers["DPoP"] = retryProof
            response = try await httpExecutor.execute(request)
        }

        guard response.isSuccess else {
            let errorDetail = try? JSONDecoder().decode(OAuthErrorResponse.self, from: response.body)
            throw ATProtoError.oauthError(OAuthErrorDetail(
                error: errorDetail?.error ?? "token_request_failed",
                errorDescription: errorDetail?.errorDescription ?? "Token request failed with status \(response.statusCode)"
            ))
        }

        // Update DPoP nonce from successful response if present
        if let nonce = response.headers["dpop-nonce"] ?? response.headers["DPoP-Nonce"] {
            await dpopManager.updateNonce(nonce)
        }

        let tokenSet: TokenManager.TokenSet
        do {
            tokenSet = try JSONDecoder().decode(TokenManager.TokenSet.self, from: response.body)
        } catch {
            throw ATProtoError.decodingError("Failed to decode token response: \(error)")
        }

        try await tokenManager.storeTokens(tokenSet)

        guard let did = DID(tokenSet.sub) else {
            throw ATProtoError.invalidDID(tokenSet.sub)
        }

        return OAuthSession(did: did, state: .authenticated(did: did))
    }

    /// Encodes a dictionary as an application/x-www-form-urlencoded body string.
    private func buildFormBody(_ parameters: [String: String]) -> String {
        return parameters
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                let encodedKey = formURLEncode(key)
                let encodedValue = formURLEncode(value)
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
    }

    /// Percent-encodes a string for use in form URL encoding.
    private func formURLEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

// MARK: - Internal Response Types

/// Response from a Pushed Authorization Request (PAR).
struct PARResponse: Codable {
    let requestURI: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case requestURI = "request_uri"
        case expiresIn = "expires_in"
    }
}

/// OAuth error response body.
struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    let errorURI: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case errorURI = "error_uri"
    }
}
