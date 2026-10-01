import XCTest
@testable import PrompteraKit

final class EncryptionServiceTests: XCTestCase {
    func testEncryptDecryptString() throws {
        let service = EncryptionService.shared
        let original = "Test string with special chars: áéíóú 中文 🎉"
        
        let encrypted = try service.encryptString(original)
        let decrypted = try service.decryptString(encrypted)
        
        XCTAssertEqual(original, decrypted)
    }
    
    func testEncryptDecryptData() throws {
        let service = EncryptionService.shared
        let original = "Binary data test".data(using: .utf8)!
        
        let encrypted = try service.encrypt(original)
        let decrypted = try service.decrypt(encrypted)
        
        XCTAssertEqual(original, decrypted)
    }
    
    func testEncryptionProducesDifferentCiphertext() throws {
        let service = EncryptionService.shared
        let original = "Same input"
        
        let encrypted1 = try service.encryptString(original)
        let encrypted2 = try service.encryptString(original)
        
        // AES-GCM uses random nonce, so ciphertext should be different
        XCTAssertNotEqual(encrypted1, encrypted2)
        
        // But both should decrypt to same value
        XCTAssertEqual(try service.decryptString(encrypted1), original)
        XCTAssertEqual(try service.decryptString(encrypted2), original)
    }
    
    func testEncryptDecryptPayload() throws {
        let service = EncryptionService.shared
        let original = "Payload test data".data(using: .utf8)!
        
        let payload = try service.encryptToPayload(original)
        let decrypted = try service.decryptFromPayload(payload)
        
        XCTAssertEqual(original, decrypted)
        XCTAssertEqual(payload.version, 1)
        XCTAssertEqual(payload.algorithm, "AES-256-GCM")
    }
    
    func testDecryptWrongPayloadVersion() throws {
        let service = EncryptionService.shared
        let payload = EncryptionService.EncryptedPayload(
            version: 999,
            algorithm: "AES-256-GCM",
            ciphertext: "invalid",
            timestamp: Date()
        )
        
        XCTAssertThrowsError(try service.decryptFromPayload(payload)) { error in
            XCTAssertEqual(error as? EncryptionError, .unsupportedVersion)
        }
    }
    
    func testDecryptWrongAlgorithm() throws {
        let service = EncryptionService.shared
        let payload = EncryptionService.EncryptedPayload(
            version: 1,
            algorithm: "DES",
            ciphertext: "invalid",
            timestamp: Date()
        )
        
        XCTAssertThrowsError(try service.decryptFromPayload(payload)) { error in
            XCTAssertEqual(error as? EncryptionError, .unsupportedVersion)
        }
    }
    
    func testInvalidBase64() throws {
        let service = EncryptionService.shared
        
        XCTAssertThrowsError(try service.decryptString("not valid base64!")) { error in
            XCTAssertEqual(error as? EncryptionError, .invalidBase64)
        }
    }
    
    func testKeyPersistence() throws {
        // Test that the same service instance returns the same key
        let service = EncryptionService.shared
        let original = "Key persistence test".data(using: .utf8)!
        
        let encrypted1 = try service.encrypt(original)
        let decrypted1 = try service.decrypt(encrypted1)
        
        // Create new service instance (simulating app restart)
        let service2 = EncryptionService.shared
        let decrypted2 = try service2.decrypt(encrypted1)
        
        XCTAssertEqual(original, decrypted1)
        XCTAssertEqual(original, decrypted2)
    }
}