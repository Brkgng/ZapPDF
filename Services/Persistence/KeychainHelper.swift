//
//  KeychainHelper.swift
//  ZapPDF
//
//  Secure storage wrapper using the iOS/macOS Keychain.
//

import Foundation
import Security

// MARK: - Keychain Errors

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, LocalizedError, Sendable {
    /// Item already exists (should use update instead)
    case duplicateItem
    
    /// Item not found in Keychain
    case itemNotFound
    
    /// Unexpected Keychain status code
    case unexpectedStatus(OSStatus)
    
    /// Failed to encode data for storage
    case encodingFailed
    
    /// Failed to decode data from storage
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .duplicateItem:
            return "Item already exists in secure storage."
        case .itemNotFound:
            return "Item not found in secure storage."
        case .unexpectedStatus(let status):
            return "Secure storage error: \(status)"
        case .encodingFailed:
            return "Failed to prepare data for secure storage."
        case .decodingFailed:
            return "Failed to read data from secure storage."
        }
    }
}

// MARK: - KeychainHelper

/// Stateless enum providing secure storage operations using the Keychain.
///
/// `KeychainHelper` provides a simple interface for storing, retrieving, and
/// deleting data in the device Keychain. Data persists across app reinstalls
/// and is protected by the device's security mechanisms.
///
/// Example:
/// ```swift
/// // Save data
/// let data = Data("secret".utf8)
/// try KeychainHelper.save(data, for: .actionsRemaining)
///
/// // Load data
/// if let loaded = try KeychainHelper.load(for: .actionsRemaining) {
///     print("Loaded: \(String(data: loaded, encoding: .utf8)!)")
/// }
///
/// // Delete
/// try KeychainHelper.delete(for: .actionsRemaining)
/// ```
enum KeychainHelper {
    
    // MARK: - Keys
    
    /// Keys for stored items in the Keychain.
    enum Key: String, Sendable {
        /// Remaining free actions count
        case actionsRemaining = "com.zappdf.actionsRemaining"
        
        /// Pro subscription receipt data
        case proSubscriptionReceipt = "com.zappdf.proReceipt"
        
        /// Last usage reset timestamp
        case lastUsageReset = "com.zappdf.lastReset"
        
        /// Pro subscription status (cached for offline support)
        case proStatus = "com.zappdf.proStatus"
    }
    
    // MARK: - Private Constants
    
    /// Service identifier for all Keychain items
    private static let serviceIdentifier = "com.zappdf.keychain"
    
    // MARK: - Public Methods
    
    /// Save data to Keychain.
    ///
    /// If an item with the same key already exists, it will be updated.
    ///
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: The key to store data under
    /// - Throws: `KeychainError` if the operation fails
    static func save(_ data: Data, for key: Key) throws {
        // Build query for adding
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Try to add
        var status = SecItemAdd(query as CFDictionary, nil)
        
        // If duplicate, update instead
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceIdentifier,
                kSecAttrAccount as String: key.rawValue
            ]
            
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        }
        
        // Check final status
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Load data from Keychain.
    ///
    /// - Parameter key: The key to load data for
    /// - Returns: The stored data, or nil if not found
    /// - Throws: `KeychainError` for errors other than "not found"
    static func load(for key: Key) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.decodingFailed
            }
            return data
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Delete item from Keychain.
    ///
    /// This method does not throw if the item doesn't exist.
    ///
    /// - Parameter key: The key to delete
    /// - Throws: `KeychainError` for unexpected errors
    static func delete(for key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Success or not found are both acceptable
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Check if an item exists in Keychain.
    ///
    /// - Parameter key: The key to check
    /// - Returns: true if item exists, false otherwise
    static func exists(for key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Convenience Methods
    
    /// Save an integer value to Keychain.
    ///
    /// - Parameters:
    ///   - value: The integer to store
    ///   - key: The key to store under
    /// - Throws: `KeychainError` if the operation fails
    static func saveInt(_ value: Int, for key: Key) throws {
        var mutableValue = value
        let data = Data(bytes: &mutableValue, count: MemoryLayout<Int>.size)
        try save(data, for: key)
    }
    
    /// Load an integer value from Keychain.
    ///
    /// - Parameter key: The key to load
    /// - Returns: The stored integer, or nil if not found
    /// - Throws: `KeychainError` for errors other than "not found"
    static func loadInt(for key: Key) throws -> Int? {
        guard let data = try load(for: key) else {
            return nil
        }
        
        guard data.count == MemoryLayout<Int>.size else {
            throw KeychainError.decodingFailed
        }
        
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }
    
    /// Save a boolean value to Keychain.
    ///
    /// - Parameters:
    ///   - value: The boolean to store
    ///   - key: The key to store under
    /// - Throws: `KeychainError` if the operation fails
    static func saveBool(_ value: Bool, for key: Key) throws {
        let data = Data([value ? 1 : 0])
        try save(data, for: key)
    }
    
    /// Load a boolean value from Keychain.
    ///
    /// - Parameter key: The key to load
    /// - Returns: The stored boolean, or nil if not found
    /// - Throws: `KeychainError` for errors other than "not found"
    static func loadBool(for key: Key) throws -> Bool? {
        guard let data = try load(for: key), data.count == 1 else {
            return nil
        }
        return data[0] == 1
    }
}
