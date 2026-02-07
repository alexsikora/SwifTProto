import Foundation
#if canImport(Security)
import Security
#endif

/// Keychain-based secure storage for Apple platforms.
///
/// Uses the system Keychain via `SecItem` APIs to persist sensitive data such as
/// OAuth tokens and DPoP private keys. Each item is stored as a generic password
/// identified by a service name and account (key).
///
/// On non-Apple platforms where the Security framework is unavailable, all
/// operations throw an error.
public final class KeychainStorage: SecureKeyStorage, @unchecked Sendable {
    /// The Keychain service name used to scope stored items.
    private let service: String

    /// An optional Keychain access group for sharing items across apps.
    private let accessGroup: String?

    /// Creates a Keychain storage instance.
    ///
    /// - Parameters:
    ///   - service: The Keychain service identifier. Defaults to `"com.swiftproto"`.
    ///   - accessGroup: An optional Keychain access group for app sharing.
    public init(service: String = "com.swiftproto", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func store(key: String, data: Data) async throws {
        #if canImport(Security)
        // Delete any existing item first
        let deleteQuery = buildQuery(key: key)
        SecItemDelete(deleteQuery as CFDictionary)

        var addQuery = buildQuery(key: key)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status: status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func retrieve(key: String) async throws -> Data? {
        #if canImport(Security)
        var query = buildQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status: status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    public func delete(key: String) async throws {
        #if canImport(Security)
        let query = buildQuery(key: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
        #else
        throw KeychainError.unavailable
        #endif
    }

    // MARK: - Private Helpers

    #if canImport(Security)
    private func buildQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    #endif
}

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, Sendable {
    /// The Security framework is not available on this platform.
    case unavailable
    /// A store operation failed with the given `OSStatus`.
    case storeFailed(status: Int32)
    /// A retrieve operation failed with the given `OSStatus`.
    case retrieveFailed(status: Int32)
    /// A delete operation failed with the given `OSStatus`.
    case deleteFailed(status: Int32)
}
