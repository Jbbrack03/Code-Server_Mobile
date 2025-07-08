import XCTest
import Foundation
import LocalAuthentication
@testable import MobileTerminal

final class KeychainServiceTests: XCTestCase {
    var keychainService: KeychainService!
    var mockKeychain: MockKeychain!
    var mockBiometricContext: MockBiometricContext!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychain()
        mockBiometricContext = MockBiometricContext()
        keychainService = KeychainService(
            keychain: mockKeychain,
            biometricContext: mockBiometricContext
        )
    }
    
    override func tearDown() {
        keychainService = nil
        mockKeychain = nil
        mockBiometricContext = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(keychainService)
    }
    
    func testInitializationWithDefaultDependencies() {
        let service = KeychainService()
        XCTAssertNotNil(service)
    }
    
    // MARK: - Biometric Availability Tests
    
    func testIsBiometricAvailableWithFaceID() {
        // Arrange
        mockBiometricContext.biometryType = .faceID
        mockBiometricContext.canEvaluateError = nil
        
        // Act
        let isAvailable = keychainService.isBiometricAvailable
        
        // Assert
        XCTAssertTrue(isAvailable)
    }
    
    func testIsBiometricAvailableWithTouchID() {
        // Arrange
        mockBiometricContext.biometryType = .touchID
        mockBiometricContext.canEvaluateError = nil
        
        // Act
        let isAvailable = keychainService.isBiometricAvailable
        
        // Assert
        XCTAssertTrue(isAvailable)
    }
    
    func testIsBiometricAvailableWithNone() {
        // Arrange
        mockBiometricContext.biometryType = .none
        mockBiometricContext.canEvaluateError = nil
        
        // Act
        let isAvailable = keychainService.isBiometricAvailable
        
        // Assert
        XCTAssertFalse(isAvailable)
    }
    
    func testIsBiometricAvailableWithError() {
        // Arrange
        mockBiometricContext.biometryType = .faceID
        mockBiometricContext.canEvaluateError = NSError(domain: LAErrorDomain, code: LAError.Code.biometryNotAvailable.rawValue)
        
        // Act
        let isAvailable = keychainService.isBiometricAvailable
        
        // Assert
        XCTAssertFalse(isAvailable)
    }
    
    func testBiometricTypeDescription() {
        // Test Face ID
        mockBiometricContext.biometryType = .faceID
        XCTAssertEqual(keychainService.biometricTypeDescription, "Face ID")
        
        // Test Touch ID
        mockBiometricContext.biometryType = .touchID
        XCTAssertEqual(keychainService.biometricTypeDescription, "Touch ID")
        
        // Test None
        mockBiometricContext.biometryType = .none
        XCTAssertEqual(keychainService.biometricTypeDescription, "None")
    }
    
    // MARK: - Store Credential Tests
    
    func testStoreCredentialSuccess() async throws {
        // Arrange
        let credential = KeychainCredential(
            identifier: "test-credential",
            value: "secret-value",
            requiresBiometric: false
        )
        mockKeychain.shouldSucceed = true
        
        // Act
        try await keychainService.storeCredential(credential)
        
        // Assert
        XCTAssertEqual(mockKeychain.storedItems.count, 1)
        XCTAssertEqual(mockKeychain.storedItems[credential.identifier], credential.value)
        XCTAssertEqual(mockKeychain.lastAccessibilityLevel, .whenUnlockedThisDeviceOnly)
        XCTAssertFalse(mockKeychain.lastRequiredBiometric)
    }
    
    func testStoreCredentialWithBiometricSuccess() async throws {
        // Arrange
        let credential = KeychainCredential(
            identifier: "biometric-credential",
            value: "secure-token",
            requiresBiometric: true
        )
        mockKeychain.shouldSucceed = true
        mockBiometricContext.biometryType = .faceID
        mockBiometricContext.canEvaluateError = nil
        
        // Act
        try await keychainService.storeCredential(credential)
        
        // Assert
        XCTAssertEqual(mockKeychain.storedItems.count, 1)
        XCTAssertEqual(mockKeychain.storedItems[credential.identifier], credential.value)
        XCTAssertEqual(mockKeychain.lastAccessibilityLevel, .whenPasscodeSetThisDeviceOnly)
        XCTAssertTrue(mockKeychain.lastRequiredBiometric)
    }
    
    func testStoreCredentialBiometricNotAvailable() async {
        // Arrange
        let credential = KeychainCredential(
            identifier: "biometric-credential",
            value: "secure-token",
            requiresBiometric: true
        )
        mockBiometricContext.biometryType = .none
        mockBiometricContext.canEvaluateError = NSError(domain: LAErrorDomain, code: LAError.Code.biometryNotAvailable.rawValue)
        
        // Act & Assert
        do {
            try await keychainService.storeCredential(credential)
            XCTFail("Expected KeychainError.biometricNotAvailable")
        } catch {
            if case KeychainError.biometricNotAvailable = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.biometricNotAvailable, got: \(error)")
            }
        }
        
        XCTAssertEqual(mockKeychain.storedItems.count, 0)
    }
    
    func testStoreCredentialKeychainFailure() async {
        // Arrange
        let credential = KeychainCredential(
            identifier: "test-credential",
            value: "secret-value",
            requiresBiometric: false
        )
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDuplicateItem))
        
        // Act & Assert
        do {
            try await keychainService.storeCredential(credential)
            XCTFail("Expected KeychainError.storageError")
        } catch {
            if case KeychainError.storageError(let osStatus) = error {
                XCTAssertEqual(osStatus, errSecDuplicateItem)
            } else {
                XCTFail("Expected KeychainError.storageError, got: \(error)")
            }
        }
        
        XCTAssertEqual(mockKeychain.storedItems.count, 0)
    }
    
    // MARK: - Retrieve Credential Tests
    
    func testRetrieveCredentialSuccess() async throws {
        // Arrange
        let identifier = "test-credential"
        let expectedValue = "secret-value"
        mockKeychain.storedItems[identifier] = expectedValue
        mockKeychain.shouldSucceed = true
        
        // Act
        let value = try await keychainService.retrieveCredential(identifier: identifier)
        
        // Assert
        XCTAssertEqual(value, expectedValue)
        XCTAssertEqual(mockKeychain.lastRetrievedIdentifier, identifier)
    }
    
    func testRetrieveCredentialWithBiometricSuccess() async throws {
        // Arrange
        let identifier = "biometric-credential"
        let expectedValue = "secure-token"
        mockKeychain.storedItems[identifier] = expectedValue
        mockKeychain.shouldSucceed = true
        mockKeychain.requiresBiometric = true
        mockBiometricContext.shouldSucceedAuthentication = true
        
        // Act
        let value = try await keychainService.retrieveCredential(identifier: identifier)
        
        // Assert
        XCTAssertEqual(value, expectedValue)
        XCTAssertEqual(mockKeychain.lastRetrievedIdentifier, identifier)
        XCTAssertTrue(mockBiometricContext.didAttemptAuthentication)
    }
    
    func testRetrieveCredentialNotFound() async {
        // Arrange
        let identifier = "non-existent-credential"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        
        // Act & Assert
        do {
            _ = try await keychainService.retrieveCredential(identifier: identifier)
            XCTFail("Expected KeychainError.itemNotFound")
        } catch {
            if case KeychainError.itemNotFound = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.itemNotFound, got: \(error)")
            }
        }
    }
    
    func testRetrieveCredentialBiometricAuthenticationFailed() async {
        // Arrange
        let identifier = "biometric-credential"
        mockKeychain.storedItems[identifier] = "secure-token"
        mockKeychain.requiresBiometric = true
        mockBiometricContext.shouldSucceedAuthentication = false
        mockBiometricContext.authenticationError = NSError(domain: LAErrorDomain, code: LAError.Code.authenticationFailed.rawValue)
        
        // Act & Assert
        do {
            _ = try await keychainService.retrieveCredential(identifier: identifier)
            XCTFail("Expected KeychainError.authenticationFailed")
        } catch {
            if case KeychainError.authenticationFailed = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.authenticationFailed, got: \(error)")
            }
        }
        
        XCTAssertTrue(mockBiometricContext.didAttemptAuthentication)
    }
    
    func testRetrieveCredentialUserCancel() async {
        // Arrange
        let identifier = "biometric-credential"
        mockKeychain.storedItems[identifier] = "secure-token"
        mockKeychain.requiresBiometric = true
        mockBiometricContext.shouldSucceedAuthentication = false
        mockBiometricContext.authenticationError = NSError(domain: LAErrorDomain, code: LAError.Code.userCancel.rawValue)
        
        // Act & Assert
        do {
            _ = try await keychainService.retrieveCredential(identifier: identifier)
            XCTFail("Expected KeychainError.userCancelled")
        } catch {
            if case KeychainError.userCancelled = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.userCancelled, got: \(error)")
            }
        }
    }
    
    // MARK: - Delete Credential Tests
    
    func testDeleteCredentialSuccess() async throws {
        // Arrange
        let identifier = "test-credential"
        mockKeychain.storedItems[identifier] = "secret-value"
        mockKeychain.shouldSucceed = true
        
        // Act
        try await keychainService.deleteCredential(identifier: identifier)
        
        // Assert
        XCTAssertFalse(mockKeychain.storedItems.keys.contains(identifier))
        XCTAssertEqual(mockKeychain.lastDeletedIdentifier, identifier)
    }
    
    func testDeleteCredentialNotFound() async {
        // Arrange
        let identifier = "non-existent-credential"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        
        // Act & Assert
        do {
            try await keychainService.deleteCredential(identifier: identifier)
            XCTFail("Expected KeychainError.itemNotFound")
        } catch {
            if case KeychainError.itemNotFound = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.itemNotFound, got: \(error)")
            }
        }
    }
    
    func testDeleteCredentialKeychainError() async {
        // Arrange
        let identifier = "test-credential"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        
        // Act & Assert
        do {
            try await keychainService.deleteCredential(identifier: identifier)
            XCTFail("Expected KeychainError.storageError")
        } catch {
            if case KeychainError.storageError(let osStatus) = error {
                XCTAssertEqual(osStatus, errSecInternalError)
            } else {
                XCTFail("Expected KeychainError.storageError, got: \(error)")
            }
        }
    }
    
    // MARK: - List Credentials Tests
    
    func testListCredentialsSuccess() async throws {
        // Arrange
        mockKeychain.storedItems = [
            "credential1": "value1",
            "credential2": "value2",
            "credential3": "value3"
        ]
        mockKeychain.shouldSucceed = true
        
        // Act
        let identifiers = try await keychainService.listCredentialIdentifiers()
        
        // Assert
        XCTAssertEqual(identifiers.count, 3)
        XCTAssertTrue(identifiers.contains("credential1"))
        XCTAssertTrue(identifiers.contains("credential2"))
        XCTAssertTrue(identifiers.contains("credential3"))
    }
    
    func testListCredentialsEmpty() async throws {
        // Arrange
        mockKeychain.storedItems = [:]
        mockKeychain.shouldSucceed = true
        
        // Act
        let identifiers = try await keychainService.listCredentialIdentifiers()
        
        // Assert
        XCTAssertEqual(identifiers.count, 0)
    }
    
    func testListCredentialsKeychainError() async {
        // Arrange
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        
        // Act & Assert
        do {
            _ = try await keychainService.listCredentialIdentifiers()
            XCTFail("Expected KeychainError.storageError")
        } catch {
            if case KeychainError.storageError(let osStatus) = error {
                XCTAssertEqual(osStatus, errSecInternalError)
            } else {
                XCTFail("Expected KeychainError.storageError, got: \(error)")
            }
        }
    }
    
    // MARK: - Clear All Credentials Tests
    
    func testClearAllCredentialsSuccess() async throws {
        // Arrange
        mockKeychain.storedItems = [
            "credential1": "value1",
            "credential2": "value2"
        ]
        mockKeychain.shouldSucceed = true
        
        // Act
        try await keychainService.clearAllCredentials()
        
        // Assert
        XCTAssertEqual(mockKeychain.storedItems.count, 0)
        XCTAssertTrue(mockKeychain.didClearAll)
    }
    
    func testClearAllCredentialsKeychainError() async {
        // Arrange
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        
        // Act & Assert
        do {
            try await keychainService.clearAllCredentials()
            XCTFail("Expected KeychainError.storageError")
        } catch {
            if case KeychainError.storageError(let osStatus) = error {
                XCTAssertEqual(osStatus, errSecInternalError)
            } else {
                XCTFail("Expected KeychainError.storageError, got: \(error)")
            }
        }
    }
    
    // MARK: - Credential Exists Tests
    
    func testCredentialExistsTrue() async throws {
        // Arrange
        let identifier = "existing-credential"
        mockKeychain.storedItems[identifier] = "value"
        mockKeychain.shouldSucceed = true
        
        // Act
        let exists = try await keychainService.credentialExists(identifier: identifier)
        
        // Assert
        XCTAssertTrue(exists)
    }
    
    func testCredentialExistsFalse() async throws {
        // Arrange
        let identifier = "non-existent-credential"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        
        // Act
        let exists = try await keychainService.credentialExists(identifier: identifier)
        
        // Assert
        XCTAssertFalse(exists)
    }
    
    func testCredentialExistsKeychainError() async {
        // Arrange
        let identifier = "test-credential"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        
        // Act & Assert
        do {
            _ = try await keychainService.credentialExists(identifier: identifier)
            XCTFail("Expected KeychainError.storageError")
        } catch {
            if case KeychainError.storageError(let osStatus) = error {
                XCTAssertEqual(osStatus, errSecInternalError)
            } else {
                XCTFail("Expected KeychainError.storageError, got: \(error)")
            }
        }
    }
    
    // MARK: - Update Credential Tests
    
    func testUpdateCredentialSuccess() async throws {
        // Arrange
        let identifier = "existing-credential"
        let newValue = "updated-value"
        mockKeychain.storedItems[identifier] = "old-value"
        mockKeychain.shouldSucceed = true
        
        // Act
        try await keychainService.updateCredential(identifier: identifier, value: newValue)
        
        // Assert
        XCTAssertEqual(mockKeychain.storedItems[identifier], newValue)
        XCTAssertEqual(mockKeychain.lastUpdatedIdentifier, identifier)
        XCTAssertEqual(mockKeychain.lastUpdatedValue, newValue)
    }
    
    func testUpdateCredentialNotFound() async {
        // Arrange
        let identifier = "non-existent-credential"
        let newValue = "new-value"
        mockKeychain.shouldSucceed = false
        mockKeychain.error = NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        
        // Act & Assert
        do {
            try await keychainService.updateCredential(identifier: identifier, value: newValue)
            XCTFail("Expected KeychainError.itemNotFound")
        } catch {
            if case KeychainError.itemNotFound = error {
                // Expected
            } else {
                XCTFail("Expected KeychainError.itemNotFound, got: \(error)")
            }
        }
    }
}

// MARK: - Mock Classes

class MockKeychain: KeychainProtocol {
    var storedItems: [String: String] = [:]
    var shouldSucceed = true
    var error: Error?
    var requiresBiometric = false
    var didClearAll = false
    
    // Tracking properties
    var lastAccessibilityLevel: KeychainAccessibility?
    var lastRequiredBiometric = false
    var lastRetrievedIdentifier: String?
    var lastDeletedIdentifier: String?
    var lastUpdatedIdentifier: String?
    var lastUpdatedValue: String?
    
    func store(identifier: String, value: String, accessibility: KeychainAccessibility, requiresBiometric: Bool) async throws {
        lastAccessibilityLevel = accessibility
        lastRequiredBiometric = requiresBiometric
        
        if shouldSucceed {
            storedItems[identifier] = value
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        }
    }
    
    func retrieve(identifier: String) async throws -> String {
        lastRetrievedIdentifier = identifier
        
        if shouldSucceed {
            guard let value = storedItems[identifier] else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
            }
            return value
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        }
    }
    
    func delete(identifier: String) async throws {
        lastDeletedIdentifier = identifier
        
        if shouldSucceed {
            storedItems.removeValue(forKey: identifier)
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        }
    }
    
    func listIdentifiers() async throws -> [String] {
        if shouldSucceed {
            return Array(storedItems.keys)
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        }
    }
    
    func clearAll() async throws {
        if shouldSucceed {
            storedItems.removeAll()
            didClearAll = true
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        }
    }
    
    func exists(identifier: String) async throws -> Bool {
        if shouldSucceed {
            return storedItems.keys.contains(identifier)
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        }
    }
    
    func update(identifier: String, value: String) async throws {
        lastUpdatedIdentifier = identifier
        lastUpdatedValue = value
        
        if shouldSucceed {
            guard storedItems.keys.contains(identifier) else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
            }
            storedItems[identifier] = value
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        }
    }
    
    func requiresBiometric(identifier: String) async throws -> Bool {
        if shouldSucceed {
            return requiresBiometric
        } else {
            throw error ?? NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalError))
        }
    }
}

class MockBiometricContext: BiometricContextProtocol {
    var biometryType: LABiometryType = .none
    var canEvaluateError: Error?
    var shouldSucceedAuthentication = true
    var authenticationError: Error?
    var didAttemptAuthentication = false
    
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        if let canEvaluateError = canEvaluateError {
            error?.pointee = canEvaluateError as NSError
            return false
        }
        return biometryType != .none
    }
    
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        didAttemptAuthentication = true
        
        if shouldSucceedAuthentication {
            return true
        } else {
            throw authenticationError ?? NSError(domain: LAErrorDomain, code: LAError.Code.authenticationFailed.rawValue)
        }
    }
}