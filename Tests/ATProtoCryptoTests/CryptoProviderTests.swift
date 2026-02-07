import XCTest
@testable import ATProtoCrypto
@testable import ATProtoCore

final class CryptoProviderTests: XCTestCase {

    private let provider = DefaultCryptoProvider()

    // MARK: - Key Pair Generation

    func testGenerateP256KeyPairProducesNonEmptyKeys() {
        let keyPair = provider.generateP256KeyPair()
        XCTAssertFalse(keyPair.privateKey.isEmpty, "Private key should not be empty")
        XCTAssertFalse(keyPair.publicKey.isEmpty, "Public key should not be empty")
    }

    func testGenerateP256KeyPairPrivateKeyLength() {
        let keyPair = provider.generateP256KeyPair()
        // P-256 raw private key is 32 bytes
        XCTAssertEqual(keyPair.privateKey.count, 32, "P-256 private key should be 32 bytes")
    }

    func testGenerateP256KeyPairPublicKeyLength() {
        let keyPair = provider.generateP256KeyPair()
        // Compressed P-256 public key is 33 bytes (1 prefix byte + 32 coordinate bytes)
        XCTAssertEqual(keyPair.publicKey.count, 33, "Compressed P-256 public key should be 33 bytes")
    }

    func testGenerateP256KeyPairProducesUniqueKeys() {
        let keyPair1 = provider.generateP256KeyPair()
        let keyPair2 = provider.generateP256KeyPair()

        XCTAssertNotEqual(keyPair1.privateKey, keyPair2.privateKey,
                          "Two generated key pairs should have different private keys")
        XCTAssertNotEqual(keyPair1.publicKey, keyPair2.publicKey,
                          "Two generated key pairs should have different public keys")
    }

    // MARK: - SHA-256 Hashing

    func testSHA256ProducesCorrectHash() {
        // Known test vector: SHA-256("abc")
        // Expected: ba7816bf 8f01cfea 414140de 5dae2223 b00361a3 96177a9c b410ff61 f20015ad
        let data = "abc".data(using: .utf8)!
        let hash = provider.sha256(data: data)

        XCTAssertEqual(hash.count, 32, "SHA-256 digest should be 32 bytes")

        let expectedHex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let actualHex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(actualHex, expectedHex)
    }

    func testSHA256EmptyString() {
        // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        let data = Data()
        let hash = provider.sha256(data: data)

        let expectedHex = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        let actualHex = hash.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(actualHex, expectedHex)
    }

    func testSHA256DeterministicOutput() {
        let data = "hello world".data(using: .utf8)!
        let hash1 = provider.sha256(data: data)
        let hash2 = provider.sha256(data: data)
        XCTAssertEqual(hash1, hash2, "Same input should produce same hash")
    }

    func testSHA256DifferentInputsDifferentOutputs() {
        let hash1 = provider.sha256(data: "hello".data(using: .utf8)!)
        let hash2 = provider.sha256(data: "world".data(using: .utf8)!)
        XCTAssertNotEqual(hash1, hash2, "Different inputs should produce different hashes")
    }

    // MARK: - Sign / Verify Roundtrip

    func testSignVerifyRoundtrip() throws {
        let keyPair = provider.generateP256KeyPair()
        let message = "Hello, AT Protocol!".data(using: .utf8)!

        let signature = try provider.sign(data: message, privateKey: keyPair.privateKey)
        XCTAssertFalse(signature.isEmpty, "Signature should not be empty")

        let isValid = try provider.verify(
            signature: signature,
            data: message,
            publicKey: keyPair.publicKey
        )
        XCTAssertTrue(isValid, "Signature should verify against the correct public key and data")
    }

    func testSignProducesNonEmptySignature() throws {
        let keyPair = provider.generateP256KeyPair()
        let data = "test data".data(using: .utf8)!
        let signature = try provider.sign(data: data, privateKey: keyPair.privateKey)
        XCTAssertFalse(signature.isEmpty)
        // DER-encoded ECDSA signatures are typically 70-72 bytes for P-256
        XCTAssertGreaterThan(signature.count, 60)
        XCTAssertLessThan(signature.count, 80)
    }

    func testSignDifferentMessagesProduceDifferentSignatures() throws {
        let keyPair = provider.generateP256KeyPair()
        let sig1 = try provider.sign(data: "message 1".data(using: .utf8)!, privateKey: keyPair.privateKey)
        let sig2 = try provider.sign(data: "message 2".data(using: .utf8)!, privateKey: keyPair.privateKey)
        // ECDSA includes randomness, so even the same message produces different sigs
        // but different messages should definitely produce different sigs
        XCTAssertNotEqual(sig1, sig2)
    }

    // MARK: - Verify Fails With Wrong Data

    func testVerifyFailsWithWrongData() throws {
        let keyPair = provider.generateP256KeyPair()
        let originalData = "original message".data(using: .utf8)!
        let tamperedData = "tampered message".data(using: .utf8)!

        let signature = try provider.sign(data: originalData, privateKey: keyPair.privateKey)

        let isValid = try provider.verify(
            signature: signature,
            data: tamperedData,
            publicKey: keyPair.publicKey
        )
        XCTAssertFalse(isValid, "Signature should not verify against different data")
    }

    func testVerifyFailsWithWrongPublicKey() throws {
        let keyPair1 = provider.generateP256KeyPair()
        let keyPair2 = provider.generateP256KeyPair()
        let data = "test message".data(using: .utf8)!

        let signature = try provider.sign(data: data, privateKey: keyPair1.privateKey)

        let isValid = try provider.verify(
            signature: signature,
            data: data,
            publicKey: keyPair2.publicKey
        )
        XCTAssertFalse(isValid, "Signature should not verify against a different public key")
    }

    // MARK: - Sign With Invalid Key

    func testSignWithTooShortKeyThrows() {
        let shortKey = Data([0x01, 0x02, 0x03])
        let data = "test".data(using: .utf8)!

        XCTAssertThrowsError(try provider.sign(data: data, privateKey: shortKey)) { error in
            if case ATProtoError.cryptoError(let msg) = error {
                XCTAssertTrue(msg.contains("private key"), "Error should mention private key")
            } else {
                XCTFail("Expected ATProtoError.cryptoError, got \(error)")
            }
        }
    }

    func testSignWithEmptyKeyThrows() {
        let emptyKey = Data()
        let data = "test".data(using: .utf8)!

        XCTAssertThrowsError(try provider.sign(data: data, privateKey: emptyKey))
    }

    // MARK: - Random Bytes Generation

    func testGenerateRandomBytesProducesExpectedLength() {
        for count in [0, 1, 16, 32, 64, 256] {
            let bytes = provider.generateRandomBytes(count: count)
            XCTAssertEqual(bytes.count, count,
                           "generateRandomBytes(\(count)) should return exactly \(count) bytes")
        }
    }

    func testGenerateRandomBytesProducesNonTrivialOutput() {
        // Generate 32 bytes and check it's not all zeros (astronomically unlikely for random bytes)
        let bytes = provider.generateRandomBytes(count: 32)
        let allZero = bytes.allSatisfy { $0 == 0 }
        XCTAssertFalse(allZero, "32 random bytes should not all be zero")
    }

    func testGenerateRandomBytesDifferentCalls() {
        let bytes1 = provider.generateRandomBytes(count: 32)
        let bytes2 = provider.generateRandomBytes(count: 32)
        // Two separate calls with 32 random bytes should be different
        // (probability of collision is negligible: 1/2^256)
        XCTAssertNotEqual(bytes1, bytes2, "Two calls to generateRandomBytes should produce different results")
    }

    func testGenerateZeroRandomBytes() {
        let bytes = provider.generateRandomBytes(count: 0)
        XCTAssertTrue(bytes.isEmpty)
    }
}
