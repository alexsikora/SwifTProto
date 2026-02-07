import Foundation

/// Protocol for secure storage of keys and tokens.
///
/// Implementations must be safe to use from concurrent contexts. Platform-specific
/// backends (e.g., Keychain on Apple platforms) should conform to this protocol
/// to provide persistent, encrypted storage of sensitive OAuth material such as
/// tokens and DPoP private keys.
public protocol SecureKeyStorage: Sendable {
    /// Stores data under the given key, overwriting any existing value.
    ///
    /// - Parameters:
    ///   - key: The identifier for the stored item.
    ///   - data: The data to store securely.
    /// - Throws: An error if the storage operation fails.
    func store(key: String, data: Data) async throws

    /// Retrieves data previously stored under the given key.
    ///
    /// - Parameter key: The identifier for the stored item.
    /// - Returns: The stored data, or `nil` if no item exists for the key.
    /// - Throws: An error if the retrieval operation fails.
    func retrieve(key: String) async throws -> Data?

    /// Deletes the item stored under the given key.
    ///
    /// No error is thrown if the key does not exist.
    ///
    /// - Parameter key: The identifier for the stored item.
    /// - Throws: An error if the deletion operation fails.
    func delete(key: String) async throws
}
