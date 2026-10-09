import Foundation
import CryptoKit
import Security

public final class EncryptionService: @unchecked Sendable {
    public static let shared = EncryptionService()
    
    private let keychainService = "com.promptera.encryption"
    private let keychainAccount = "master-key"
    private let saltKey = "promptera_encryption_salt"
    
    // Guards `symmetricKey`: the service is used from the main thread and from the
    // clipboard persistence queue.
    private let keyLock = NSLock()
    private var symmetricKey: SymmetricKey?
    
    private init() {}
    
    private func getOrCreateKey() throws -> SymmetricKey {
        keyLock.lock()
        defer { keyLock.unlock() }
        if let cached = symmetricKey {
            return cached
        }
        let key = try loadOrCreateMasterKey()
        symmetricKey = key
        return key
    }
    
    private func loadOrCreateMasterKey() throws -> SymmetricKey {
        // Try to load existing key from Keychain
        if let existingKey = try loadKeyFromKeychain() {
            return existingKey
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        return newKey
    }
    
    private func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data,
              keyData.count == 32 else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        // Delete any existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainSaveFailed(status)
        }
    }
    
    public func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    public func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    public func encryptString(_ string: String) throws -> String {
        let data = string.data(using: .utf8)!
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }
    
    public func decryptString(_ base64String: String) throws -> String {
        guard let data = Data(base64Encoded: base64String) else {
            throw EncryptionError.invalidBase64
        }
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        return string
    }
    
    // For exporting encrypted data with version info
    public struct EncryptedPayload: Codable {
        let version: Int
        let algorithm: String
        let ciphertext: String // base64
        let timestamp: Date
    }
    
    public func encryptToPayload(_ data: Data) throws -> EncryptedPayload {
        let encrypted = try encrypt(data)
        return EncryptedPayload(
            version: 1,
            algorithm: "AES-256-GCM",
            ciphertext: encrypted.base64EncodedString(),
            timestamp: Date()
        )
    }
    
    public func decryptFromPayload(_ payload: EncryptedPayload) throws -> Data {
        guard payload.version == 1,
              payload.algorithm == "AES-256-GCM" else {
            throw EncryptionError.unsupportedVersion
        }
        guard let data = Data(base64Encoded: payload.ciphertext) else {
            throw EncryptionError.invalidBase64
        }
        return try decrypt(data)
    }
}

public enum EncryptionError: LocalizedError, Equatable {
    case keychainSaveFailed(OSStatus)
    case invalidBase64
    case decodingFailed
    case unsupportedVersion
    
    public var errorDescription: String? {
        switch self {
        case .keychainSaveFailed(let status):
            return "Failed to save encryption key to Keychain: \(status)"
        case .invalidBase64:
            return "Invalid base64 encoding"
        case .decodingFailed:
            return "Failed to decode decrypted data"
        case .unsupportedVersion:
            return "Unsupported encryption payload version"
        }
    }
    
    public static func == (lhs: EncryptionError, rhs: EncryptionError) -> Bool {
        switch (lhs, rhs) {
        case (.keychainSaveFailed(let a), .keychainSaveFailed(let b)):
            return a == b
        case (.invalidBase64, .invalidBase64),
             (.decodingFailed, .decodingFailed),
             (.unsupportedVersion, .unsupportedVersion):
            return true
        default:
            return false
        }
    }
}