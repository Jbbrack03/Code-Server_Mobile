import Foundation
import LocalAuthentication
import KeychainAccess

/// Service for securely storing and retrieving credentials using iOS Keychain
public class KeychainService: ObservableObject {
    // MARK: - Properties
    
    private let keychain: KeychainProtocol
    private let biometricContext: BiometricContextProtocol
    private let serviceName: String
    
    // MARK: - Initialization
    
    public init(
        serviceName: String = "MobileTerminal",
        keychain: KeychainProtocol? = nil,
        biometricContext: BiometricContextProtocol? = nil
    ) {
        self.serviceName = serviceName
        self.keychain = keychain ?? KeychainWrapper(serviceName: serviceName)
        self.biometricContext = biometricContext ?? LAContext()
    }
    
    // MARK: - Biometric Support
    
    /// Whether biometric authentication is available on this device
    public var isBiometricAvailable: Bool {
        var error: NSError?
        let canEvaluate = biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return canEvaluate && error == nil && biometricContext.biometryType != .none
    }
    
    /// Description of the available biometric type
    public var biometricTypeDescription: String {
        switch biometricContext.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Credential Management
    
    /// Store a credential in the Keychain
    /// - Parameter credential: The credential to store
    /// - Throws: KeychainError if storage fails
    public func storeCredential(_ credential: KeychainCredential) async throws {
        // Check biometric availability if required
        if credential.requiresBiometric && !isBiometricAvailable {
            throw KeychainError.biometricNotAvailable
        }
        
        let accessibility: KeychainAccessibility = credential.requiresBiometric
            ? .whenPasscodeSetThisDeviceOnly
            : .whenUnlockedThisDeviceOnly
        
        do {
            try await keychain.store(
                identifier: credential.identifier,
                value: credential.value,
                accessibility: accessibility,
                requiresBiometric: credential.requiresBiometric
            )
        } catch {
            if let nsError = error as NSError?,
               nsError.domain == NSOSStatusErrorDomain {
                let osStatus = OSStatus(nsError.code)
                throw KeychainError.storageError(osStatus)
            }
            throw KeychainError.unknown(error)
        }
    }
    
    /// Retrieve a credential from the Keychain
    /// - Parameter identifier: The identifier of the credential to retrieve
    /// - Returns: The credential value
    /// - Throws: KeychainError if retrieval fails
    public func retrieveCredential(identifier: String) async throws -> String {
        // Check if this credential requires biometric authentication
        // This is a design choice: we check for biometric requirement before attempting retrieval
        if await doesCredentialRequireBiometric(identifier: identifier) {
            // Perform biometric authentication first
            do {
                let success = try await biometricContext.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Authenticate to access your secure credential"
                )
                if !success {
                    throw KeychainError.authenticationFailed
                }
            } catch let biometricError {
                throw mapBiometricError(biometricError)
            }
        }
        
        // Now retrieve the credential
        do {
            return try await keychain.retrieve(identifier: identifier)
        } catch {
            throw mapKeychainError(error)
        }
    }
    
    /// Check if a credential requires biometric authentication
    /// - Parameter identifier: The credential identifier
    /// - Returns: True if biometric authentication is required
    private func doesCredentialRequireBiometric(identifier: String) async -> Bool {
        do {
            return try await keychain.requiresBiometric(identifier: identifier)
        } catch {
            return false
        }
    }
    
    /// Update an existing credential value
    /// - Parameters:
    ///   - identifier: The identifier of the credential to update
    ///   - value: The new value
    /// - Throws: KeychainError if update fails
    public func updateCredential(identifier: String, value: String) async throws {
        do {
            try await keychain.update(identifier: identifier, value: value)
        } catch {
            throw mapKeychainError(error)
        }
    }
    
    /// Delete a credential from the Keychain
    /// - Parameter identifier: The identifier of the credential to delete
    /// - Throws: KeychainError if deletion fails
    public func deleteCredential(identifier: String) async throws {
        do {
            try await keychain.delete(identifier: identifier)
        } catch {
            throw mapKeychainError(error)
        }
    }
    
    /// Check if a credential exists in the Keychain
    /// - Parameter identifier: The identifier to check
    /// - Returns: True if the credential exists, false otherwise
    /// - Throws: KeychainError for storage errors (not for item not found)
    public func credentialExists(identifier: String) async throws -> Bool {
        do {
            return try await keychain.exists(identifier: identifier)
        } catch {
            if let nsError = error as NSError?,
               nsError.domain == NSOSStatusErrorDomain,
               nsError.code == errSecItemNotFound {
                return false
            }
            throw mapKeychainError(error)
        }
    }
    
    /// List all credential identifiers
    /// - Returns: Array of credential identifiers
    /// - Throws: KeychainError if listing fails
    public func listCredentialIdentifiers() async throws -> [String] {
        do {
            return try await keychain.listIdentifiers()
        } catch {
            throw mapKeychainError(error)
        }
    }
    
    /// Clear all credentials from the Keychain
    /// - Throws: KeychainError if clearing fails
    public func clearAllCredentials() async throws {
        do {
            try await keychain.clearAll()
        } catch {
            throw mapKeychainError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func mapBiometricError(_ error: Error) -> KeychainError {
        if let laError = error as? LAError {
            switch laError.code {
            case .authenticationFailed:
                return .authenticationFailed
            case .userCancel:
                return .userCancelled
            case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout:
                return .biometricNotAvailable
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }
    
    private func mapKeychainError(_ error: Error) -> KeychainError {
        if let laError = error as? LAError {
            switch laError.code {
            case .authenticationFailed:
                return .authenticationFailed
            case .userCancel:
                return .userCancelled
            case .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout:
                return .biometricNotAvailable
            default:
                return .unknown(error)
            }
        }
        
        if let nsError = error as NSError?,
           nsError.domain == NSOSStatusErrorDomain {
            let osStatus = OSStatus(nsError.code)
            switch osStatus {
            case errSecItemNotFound:
                return .itemNotFound
            case errSecDuplicateItem:
                return .duplicateItem
            default:
                return .storageError(osStatus)
            }
        }
        
        return .unknown(error)
    }
}

// MARK: - Keychain Wrapper

/// Wrapper around KeychainAccess library to conform to KeychainProtocol
private class KeychainWrapper: KeychainProtocol {
    private let keychain: Keychain
    
    init(serviceName: String) {
        self.keychain = Keychain(service: serviceName)
    }
    
    func store(identifier: String, value: String, accessibility: KeychainAccessibility, requiresBiometric: Bool) async throws {
        let keychainInstance: Keychain
        
        if requiresBiometric {
            keychainInstance = keychain
                .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: [.biometryAny])
                .authenticationPrompt("Authenticate to store secure credential")
        } else {
            let keychainAccessibility: Accessibility = convertAccessibility(accessibility)
            keychainInstance = keychain.accessibility(keychainAccessibility)
        }
        
        try keychainInstance.set(value, key: identifier)
    }
    
    private func convertAccessibility(_ accessibility: KeychainAccessibility) -> Accessibility {
        switch accessibility {
        case .whenUnlocked:
            return .whenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return .whenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            return .afterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return .afterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return .whenPasscodeSetThisDeviceOnly
        }
    }
    
    func retrieve(identifier: String) async throws -> String {
        guard let value = try keychain.get(identifier) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        }
        return value
    }
    
    func delete(identifier: String) async throws {
        try keychain.remove(identifier)
    }
    
    func listIdentifiers() async throws -> [String] {
        return Array(keychain.allKeys())
    }
    
    func clearAll() async throws {
        try keychain.removeAll()
    }
    
    func exists(identifier: String) async throws -> Bool {
        return try keychain.contains(identifier)
    }
    
    func update(identifier: String, value: String) async throws {
        // KeychainAccess doesn't have a dedicated update method, 
        // so we use set which will update if the item exists
        if try !keychain.contains(identifier) {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound))
        }
        try keychain.set(value, key: identifier)
    }
    
    func requiresBiometric(identifier: String) async throws -> Bool {
        // In a real implementation, this would check the keychain item's accessibility attributes
        // For now, we'll return false as the KeychainAccess library handles biometric authentication internally
        return false
    }
}