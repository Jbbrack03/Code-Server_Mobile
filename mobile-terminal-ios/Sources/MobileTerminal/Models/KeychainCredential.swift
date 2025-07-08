import Foundation

/// Represents a credential to be stored in the Keychain
public struct KeychainCredential {
    /// Unique identifier for the credential
    public let identifier: String
    
    /// The secret value to store
    public let value: String
    
    /// Whether biometric authentication is required to access this credential
    public let requiresBiometric: Bool
    
    /// Optional metadata for the credential
    public let metadata: [String: String]?
    
    public init(
        identifier: String,
        value: String,
        requiresBiometric: Bool = false,
        metadata: [String: String]? = nil
    ) {
        self.identifier = identifier
        self.value = value
        self.requiresBiometric = requiresBiometric
        self.metadata = metadata
    }
}

/// Keychain accessibility levels
public enum KeychainAccessibility {
    /// Item data can only be accessed while the device is unlocked by the user
    case whenUnlocked
    
    /// Item data can only be accessed while the device is unlocked and device is not backed up
    case whenUnlockedThisDeviceOnly
    
    /// Item data can be accessed after the first unlock until the device is restarted
    case afterFirstUnlock
    
    /// Item data can be accessed after the first unlock and device is not backed up
    case afterFirstUnlockThisDeviceOnly
    
    /// Item data can only be accessed when passcode is set and device is not backed up
    case whenPasscodeSetThisDeviceOnly
}

/// Keychain-related errors
public enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case storageError(OSStatus)
    case authenticationFailed
    case userCancelled
    case biometricNotAvailable
    case invalidData
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in Keychain"
        case .duplicateItem:
            return "Item already exists in Keychain"
        case .storageError(let status):
            return "Keychain storage error (status: \(status))"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .userCancelled:
            return "User cancelled authentication"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .invalidData:
            return "Invalid data format"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .itemNotFound:
            return "The requested credential was not found. Please check the identifier."
        case .duplicateItem:
            return "A credential with this identifier already exists. Use update instead."
        case .storageError:
            return "There was an error accessing the Keychain. Please try again."
        case .authenticationFailed:
            return "Please try authenticating again."
        case .userCancelled:
            return "Authentication was cancelled. Please try again when ready."
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device."
        case .invalidData:
            return "The credential data is invalid. Please check the input."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}