import XCTest
@testable import ATProtoCrypto
@testable import ATProtoCore

final class JWKTests: XCTestCase {

    // MARK: - JWK Codable Roundtrip

    func testJWKCodableRoundtrip() throws {
        let jwk = JWK(
            kty: "EC",
            crv: "P-256",
            x: "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
            y: "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
            d: "jpsQnnGQmL-YBIffS1BSyVKhrlRhVRtM5-yTmKmNvh4",
            kid: "test-key-1",
            use: "sig",
            alg: "ES256"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(jwk)
        let decoded = try JSONDecoder().decode(JWK.self, from: data)

        XCTAssertEqual(decoded.kty, "EC")
        XCTAssertEqual(decoded.crv, "P-256")
        XCTAssertEqual(decoded.x, "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU")
        XCTAssertEqual(decoded.y, "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0")
        XCTAssertEqual(decoded.d, "jpsQnnGQmL-YBIffS1BSyVKhrlRhVRtM5-yTmKmNvh4")
        XCTAssertEqual(decoded.kid, "test-key-1")
        XCTAssertEqual(decoded.use, "sig")
        XCTAssertEqual(decoded.alg, "ES256")
    }

    func testJWKPublicOnlyCodableRoundtrip() throws {
        let jwk = JWK(
            kty: "EC",
            crv: "P-256",
            x: "f83OJ3D2xF1Bg8vub9tLe1gHMzV76e8Tus9uPHvRVEU",
            y: "x_FEzRu9m36HLN_tue659LNpXW6pCyStikYjKIWI5a0",
            alg: "ES256"
        )

        let data = try JSONEncoder().encode(jwk)
        let decoded = try JSONDecoder().decode(JWK.self, from: data)

        XCTAssertEqual(decoded.kty, "EC")
        XCTAssertEqual(decoded.crv, "P-256")
        XCTAssertEqual(decoded.x, jwk.x)
        XCTAssertEqual(decoded.y, jwk.y)
        XCTAssertNil(decoded.d, "Public-only JWK should not have d")
        XCTAssertNil(decoded.kid)
        XCTAssertNil(decoded.use)
    }

    func testJWKMinimalCodableRoundtrip() throws {
        let jwk = JWK(kty: "EC")
        let data = try JSONEncoder().encode(jwk)
        let decoded = try JSONDecoder().decode(JWK.self, from: data)
        XCTAssertEqual(decoded.kty, "EC")
        XCTAssertNil(decoded.crv)
        XCTAssertNil(decoded.x)
        XCTAssertNil(decoded.y)
    }

    // MARK: - Base64URL Encoding / Decoding

    func testBase64URLEncodeEmpty() {
        let data = Data()
        let encoded = JWK.base64urlEncode(data)
        XCTAssertEqual(encoded, "")
    }

    func testBase64URLEncodeKnownValue() {
        // "Hello" in base64 is "SGVsbG8=" in standard, "SGVsbG8" in base64url (no padding)
        let data = "Hello".data(using: .utf8)!
        let encoded = JWK.base64urlEncode(data)
        XCTAssertEqual(encoded, "SGVsbG8")
        XCTAssertFalse(encoded.contains("="), "base64url should not contain padding")
        XCTAssertFalse(encoded.contains("+"), "base64url should not contain +")
        XCTAssertFalse(encoded.contains("/"), "base64url should not contain /")
    }

    func testBase64URLEncodeWithSpecialChars() {
        // Data that produces + and / in standard base64
        let data = Data([0xFB, 0xEF, 0xBE]) // standard base64: "+++" (approximately)
        let encoded = JWK.base64urlEncode(data)
        XCTAssertFalse(encoded.contains("+"), "base64url should replace + with -")
        XCTAssertFalse(encoded.contains("/"), "base64url should replace / with _")
    }

    func testBase64URLDecodeKnownValue() {
        let decoded = JWK.base64urlDecode("SGVsbG8")
        XCTAssertNotNil(decoded)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), "Hello")
    }

    func testBase64URLDecodeWithPadding() {
        // Should handle both padded and unpadded
        let decoded = JWK.base64urlDecode("SGVsbG8=")
        XCTAssertNotNil(decoded)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), "Hello")
    }

    func testBase64URLRoundtrip() {
        let original = Data([0x00, 0x01, 0x02, 0xFE, 0xFF, 0x80, 0x7F])
        let encoded = JWK.base64urlEncode(original)
        let decoded = JWK.base64urlDecode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testBase64URLRoundtripLargeData() {
        // 256 random-ish bytes
        var data = Data()
        for i: UInt8 in 0..<255 {
            data.append(i)
        }
        data.append(255)

        let encoded = JWK.base64urlEncode(data)
        let decoded = JWK.base64urlDecode(encoded)
        XCTAssertEqual(decoded, data)
    }

    func testBase64URLDecodeWithURLSafeChars() {
        // "-" should be treated as "+" and "_" as "/"
        let standardBase64 = "SGVsbG8" // "Hello"
        let urlSafe = standardBase64 // no special chars in this case but test the path
        let decoded = JWK.base64urlDecode(urlSafe)
        XCTAssertNotNil(decoded)
    }

    // MARK: - JWK from P-256 Key Pair

    func testJWKFromP256PrivateKey() throws {
        let crypto = DefaultCryptoProvider()
        let keyPair = crypto.generateP256KeyPair()

        let jwk = try JWK.fromP256PrivateKey(keyPair.privateKey)

        XCTAssertEqual(jwk.kty, "EC")
        XCTAssertEqual(jwk.crv, "P-256")
        XCTAssertEqual(jwk.alg, "ES256")
        XCTAssertNotNil(jwk.x, "JWK from private key should have x coordinate")
        XCTAssertNotNil(jwk.y, "JWK from private key should have y coordinate")
        XCTAssertNotNil(jwk.d, "JWK from private key should have d (private key)")

        // x and y should be 32 bytes base64url-encoded (43 chars without padding)
        XCTAssertEqual(jwk.x?.count, 43, "x coordinate should be 43 base64url chars (32 bytes)")
        XCTAssertEqual(jwk.y?.count, 43, "y coordinate should be 43 base64url chars (32 bytes)")
        XCTAssertEqual(jwk.d?.count, 43, "d value should be 43 base64url chars (32 bytes)")
    }

    func testJWKFromP256PublicKey() throws {
        let crypto = DefaultCryptoProvider()
        let keyPair = crypto.generateP256KeyPair()

        let jwk = try JWK.fromP256PublicKey(keyPair.publicKey)

        XCTAssertEqual(jwk.kty, "EC")
        XCTAssertEqual(jwk.crv, "P-256")
        XCTAssertEqual(jwk.alg, "ES256")
        XCTAssertNotNil(jwk.x)
        XCTAssertNotNil(jwk.y)
        XCTAssertNil(jwk.d, "JWK from public key should NOT have d")
    }

    func testJWKFromInvalidPrivateKeyThrows() {
        let invalidKey = Data(repeating: 0x00, count: 10)
        XCTAssertThrowsError(try JWK.fromP256PrivateKey(invalidKey)) { error in
            if case ATProtoError.cryptoError(_) = error {
                // expected
            } else {
                XCTFail("Expected ATProtoError.cryptoError, got \(error)")
            }
        }
    }

    func testJWKFromInvalidPublicKeyThrows() {
        let invalidKey = Data(repeating: 0x00, count: 10)
        XCTAssertThrowsError(try JWK.fromP256PublicKey(invalidKey)) { error in
            if case ATProtoError.cryptoError(_) = error {
                // expected
            } else {
                XCTFail("Expected ATProtoError.cryptoError, got \(error)")
            }
        }
    }

    // MARK: - JWK Thumbprint

    func testJWKThumbprintComputation() throws {
        let crypto = DefaultCryptoProvider()
        let keyPair = crypto.generateP256KeyPair()
        let jwk = try JWK.fromP256PrivateKey(keyPair.privateKey)

        let thumbprint = try jwk.thumbprint()

        // SHA-256 hash is 32 bytes, base64url encoded = 43 chars
        XCTAssertEqual(thumbprint.count, 43, "Thumbprint should be 43 base64url chars (SHA-256)")
        XCTAssertFalse(thumbprint.contains("="), "Thumbprint should not have padding")
        XCTAssertFalse(thumbprint.contains("+"), "Thumbprint should use base64url chars")
        XCTAssertFalse(thumbprint.contains("/"), "Thumbprint should use base64url chars")
    }

    func testJWKThumbprintIsDeterministic() throws {
        let crypto = DefaultCryptoProvider()
        let keyPair = crypto.generateP256KeyPair()
        let jwk = try JWK.fromP256PrivateKey(keyPair.privateKey)

        let thumbprint1 = try jwk.thumbprint()
        let thumbprint2 = try jwk.thumbprint()

        XCTAssertEqual(thumbprint1, thumbprint2, "Thumbprint should be deterministic")
    }

    func testJWKThumbprintDifferentKeysProduceDifferentThumbprints() throws {
        let crypto = DefaultCryptoProvider()

        let keyPair1 = crypto.generateP256KeyPair()
        let jwk1 = try JWK.fromP256PrivateKey(keyPair1.privateKey)

        let keyPair2 = crypto.generateP256KeyPair()
        let jwk2 = try JWK.fromP256PrivateKey(keyPair2.privateKey)

        let thumbprint1 = try jwk1.thumbprint()
        let thumbprint2 = try jwk2.thumbprint()

        XCTAssertNotEqual(thumbprint1, thumbprint2, "Different keys should produce different thumbprints")
    }

    func testJWKThumbprintRequiresCrvXY() {
        // A JWK without crv/x/y should fail thumbprint computation
        let jwk = JWK(kty: "EC")
        XCTAssertThrowsError(try jwk.thumbprint()) { error in
            if case ATProtoError.cryptoError(let msg) = error {
                XCTAssertTrue(msg.contains("missing required fields"),
                              "Error should mention missing fields")
            } else {
                XCTFail("Expected ATProtoError.cryptoError, got \(error)")
            }
        }
    }

    func testJWKThumbprintUnsupportedKeyType() {
        let jwk = JWK(kty: "RSA")
        XCTAssertThrowsError(try jwk.thumbprint()) { error in
            if case ATProtoError.cryptoError(let msg) = error {
                XCTAssertTrue(msg.contains("not supported"), "Error should mention unsupported key type")
            } else {
                XCTFail("Expected ATProtoError.cryptoError, got \(error)")
            }
        }
    }

    // MARK: - Hashable / Equatable

    func testJWKEquatable() {
        let a = JWK(kty: "EC", crv: "P-256", x: "abc", y: "def")
        let b = JWK(kty: "EC", crv: "P-256", x: "abc", y: "def")
        let c = JWK(kty: "EC", crv: "P-256", x: "xyz", y: "uvw")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testJWKHashable() {
        let a = JWK(kty: "EC", crv: "P-256", x: "abc", y: "def")
        let b = JWK(kty: "EC", crv: "P-256", x: "abc", y: "def")

        var set = Set<JWK>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - JSON Encoding Details

    func testJWKJSONContainsAllFields() throws {
        let jwk = JWK(
            kty: "EC",
            crv: "P-256",
            x: "xcoord",
            y: "ycoord",
            d: "dvalue",
            kid: "mykey",
            use: "sig",
            alg: "ES256"
        )

        let data = try JSONEncoder().encode(jwk)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["kty"] as? String, "EC")
        XCTAssertEqual(json?["crv"] as? String, "P-256")
        XCTAssertEqual(json?["x"] as? String, "xcoord")
        XCTAssertEqual(json?["y"] as? String, "ycoord")
        XCTAssertEqual(json?["d"] as? String, "dvalue")
        XCTAssertEqual(json?["kid"] as? String, "mykey")
        XCTAssertEqual(json?["use"] as? String, "sig")
        XCTAssertEqual(json?["alg"] as? String, "ES256")
    }

    func testJWKJSONOmitsNilFields() throws {
        let jwk = JWK(kty: "EC")
        let data = try JSONEncoder().encode(jwk)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["kty"] as? String, "EC")
        XCTAssertNil(json?["crv"])
        XCTAssertNil(json?["x"])
        XCTAssertNil(json?["y"])
        XCTAssertNil(json?["d"])
        XCTAssertNil(json?["kid"])
        XCTAssertNil(json?["use"])
        XCTAssertNil(json?["alg"])
    }
}
