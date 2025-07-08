import Foundation
import LocalAuthentication

/// Protocol for Keychain operations to enable testing
public protocol KeychainProtocol {
    func store(identifier: String, value: String, accessibility: KeychainAccessibility, requiresBiometric: Bool) async throws
    func retrieve(identifier: String) async throws -> String
    func delete(identifier: String) async throws
    func listIdentifiers() async throws -> [String]
    func clearAll() async throws
    func exists(identifier: String) async throws -> Bool
    func update(identifier: String, value: String) async throws
    func requiresBiometric(identifier: String) async throws -> Bool
}

/// Protocol for biometric authentication context to enable testing
public protocol BiometricContextProtocol {
    var biometryType: LABiometryType { get }
    func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool
    func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool
}

/// Extension to make LAContext conform to BiometricContextProtocol
extension LAContext: BiometricContextProtocol {
    // LAContext already implements these methods, so no additional implementation needed
}