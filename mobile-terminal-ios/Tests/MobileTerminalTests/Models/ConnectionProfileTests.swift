import XCTest
@testable import MobileTerminal

final class ConnectionProfileTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testConnectionProfileInitialization() {
        // Given
        let id = "test-profile-id"
        let name = "Test Profile"
        let urls = ["https://example.com:8092", "http://192.168.1.100:8092"]
        let apiKey = "test-api-key"
        let autoConnect = true
        let networkSSIDs = ["WiFi-Network", "Home-Network"]
        let tlsConfig = ConnectionProfile.TLSConfig(
            allowSelfSigned: true,
            pinnedCertificates: ["cert-fingerprint"]
        )
        let createdAt = Date()
        let lastUsed = Date()
        
        // When
        let profile = ConnectionProfile(
            id: id,
            name: name,
            urls: urls,
            apiKey: apiKey,
            autoConnect: autoConnect,
            networkSSIDs: networkSSIDs,
            tlsConfig: tlsConfig,
            createdAt: createdAt,
            lastUsed: lastUsed
        )
        
        // Then
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.name, name)
        XCTAssertEqual(profile.urls, urls)
        XCTAssertEqual(profile.apiKey, apiKey)
        XCTAssertEqual(profile.autoConnect, autoConnect)
        XCTAssertEqual(profile.networkSSIDs, networkSSIDs)
        XCTAssertEqual(profile.tlsConfig?.allowSelfSigned, tlsConfig.allowSelfSigned)
        XCTAssertEqual(profile.tlsConfig?.pinnedCertificates, tlsConfig.pinnedCertificates)
        XCTAssertEqual(profile.createdAt, createdAt)
        XCTAssertEqual(profile.lastUsed, lastUsed)
    }
    
    func testConnectionProfileInitializationWithOptionals() {
        // Given
        let id = "test-profile-id"
        let name = "Test Profile"
        let urls = ["https://example.com:8092"]
        let apiKey = "test-api-key"
        let autoConnect = false
        let createdAt = Date()
        let lastUsed = Date()
        
        // When
        let profile = ConnectionProfile(
            id: id,
            name: name,
            urls: urls,
            apiKey: apiKey,
            autoConnect: autoConnect,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: createdAt,
            lastUsed: lastUsed
        )
        
        // Then
        XCTAssertEqual(profile.id, id)
        XCTAssertEqual(profile.name, name)
        XCTAssertEqual(profile.urls, urls)
        XCTAssertEqual(profile.apiKey, apiKey)
        XCTAssertEqual(profile.autoConnect, autoConnect)
        XCTAssertNil(profile.networkSSIDs)
        XCTAssertNil(profile.tlsConfig)
        XCTAssertEqual(profile.createdAt, createdAt)
        XCTAssertEqual(profile.lastUsed, lastUsed)
    }
    
    // MARK: - TLS Configuration Tests
    
    func testTLSConfigInitialization() {
        // Given
        let allowSelfSigned = true
        let pinnedCertificates = ["cert1", "cert2"]
        
        // When
        let tlsConfig = ConnectionProfile.TLSConfig(
            allowSelfSigned: allowSelfSigned,
            pinnedCertificates: pinnedCertificates
        )
        
        // Then
        XCTAssertEqual(tlsConfig.allowSelfSigned, allowSelfSigned)
        XCTAssertEqual(tlsConfig.pinnedCertificates, pinnedCertificates)
    }
    
    func testTLSConfigEquality() {
        // Given
        let tlsConfig1 = ConnectionProfile.TLSConfig(
            allowSelfSigned: true,
            pinnedCertificates: ["cert1"]
        )
        let tlsConfig2 = ConnectionProfile.TLSConfig(
            allowSelfSigned: true,
            pinnedCertificates: ["cert1"]
        )
        let tlsConfig3 = ConnectionProfile.TLSConfig(
            allowSelfSigned: false,
            pinnedCertificates: ["cert2"]
        )
        
        // When & Then
        XCTAssertEqual(tlsConfig1, tlsConfig2)
        XCTAssertNotEqual(tlsConfig1, tlsConfig3)
    }
    
    // MARK: - Codable Tests
    
    func testConnectionProfileCodable() throws {
        // Given
        let profile = ConnectionProfile(
            id: "test-id",
            name: "Test Profile",
            urls: ["https://example.com:8092"],
            apiKey: "test-key",
            autoConnect: true,
            networkSSIDs: ["WiFi-Network"],
            tlsConfig: ConnectionProfile.TLSConfig(
                allowSelfSigned: true,
                pinnedCertificates: ["cert1"]
            ),
            createdAt: Date(timeIntervalSince1970: 1609459200),
            lastUsed: Date(timeIntervalSince1970: 1609459260)
        )
        
        // When
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ConnectionProfile.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.urls, profile.urls)
        XCTAssertEqual(decoded.apiKey, profile.apiKey)
        XCTAssertEqual(decoded.autoConnect, profile.autoConnect)
        XCTAssertEqual(decoded.networkSSIDs, profile.networkSSIDs)
        XCTAssertEqual(decoded.tlsConfig, profile.tlsConfig)
        XCTAssertEqual(decoded.createdAt, profile.createdAt)
        XCTAssertEqual(decoded.lastUsed, profile.lastUsed)
    }
    
    func testConnectionProfileCodableWithOptionals() throws {
        // Given
        let profile = ConnectionProfile(
            id: "test-id",
            name: "Test Profile",
            urls: ["https://example.com:8092"],
            apiKey: "test-key",
            autoConnect: false,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(timeIntervalSince1970: 1609459200),
            lastUsed: Date(timeIntervalSince1970: 1609459260)
        )
        
        // When
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ConnectionProfile.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.urls, profile.urls)
        XCTAssertEqual(decoded.apiKey, profile.apiKey)
        XCTAssertEqual(decoded.autoConnect, profile.autoConnect)
        XCTAssertNil(decoded.networkSSIDs)
        XCTAssertNil(decoded.tlsConfig)
        XCTAssertEqual(decoded.createdAt, profile.createdAt)
        XCTAssertEqual(decoded.lastUsed, profile.lastUsed)
    }
    
    // MARK: - Identifiable Tests
    
    func testConnectionProfileIdentifiable() {
        // Given
        let profile1 = ConnectionProfile(
            id: "profile-1",
            name: "Profile 1",
            urls: ["https://example.com:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        let profile2 = ConnectionProfile(
            id: "profile-2",
            name: "Profile 2",
            urls: ["https://example.com:8092"],
            apiKey: "key2",
            autoConnect: false,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When & Then
        XCTAssertEqual(profile1.id, "profile-1")
        XCTAssertEqual(profile2.id, "profile-2")
        XCTAssertNotEqual(profile1.id, profile2.id)
    }
    
    // MARK: - Equatable Tests
    
    func testConnectionProfileEquatable() {
        // Given
        let date1 = Date()
        let date2 = Date()
        
        let profile1 = ConnectionProfile(
            id: "same-id",
            name: "Profile 1",
            urls: ["https://example.com:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: date1,
            lastUsed: date1
        )
        
        let profile2 = ConnectionProfile(
            id: "same-id",
            name: "Profile 2",
            urls: ["https://different.com:8092"],
            apiKey: "key2",
            autoConnect: false,
            networkSSIDs: ["WiFi"],
            tlsConfig: ConnectionProfile.TLSConfig(allowSelfSigned: true, pinnedCertificates: []),
            createdAt: date2,
            lastUsed: date2
        )
        
        let profile3 = ConnectionProfile(
            id: "different-id",
            name: "Profile 1",
            urls: ["https://example.com:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: date1,
            lastUsed: date1
        )
        
        // When & Then
        XCTAssertEqual(profile1, profile2) // Same ID
        XCTAssertNotEqual(profile1, profile3) // Different ID
    }
    
    // MARK: - Hashable Tests
    
    func testConnectionProfileHashable() {
        // Given
        let profile1 = ConnectionProfile(
            id: "test-id",
            name: "Profile 1",
            urls: ["https://example.com:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        let profile2 = ConnectionProfile(
            id: "test-id",
            name: "Profile 2",
            urls: ["https://different.com:8092"],
            apiKey: "key2",
            autoConnect: false,
            networkSSIDs: ["WiFi"],
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When
        let set: Set<ConnectionProfile> = [profile1, profile2]
        
        // Then
        XCTAssertEqual(set.count, 1) // Same ID means same hash
        XCTAssertEqual(profile1.hashValue, profile2.hashValue)
    }
    
    // MARK: - Mock Helper Tests
    
    func testMockConnectionProfile() {
        // Given & When
        let mockProfile = ConnectionProfile.mock()
        
        // Then
        XCTAssertEqual(mockProfile.id, "mock-profile-id")
        XCTAssertEqual(mockProfile.name, "Mock Connection")
        XCTAssertEqual(mockProfile.urls, ["http://192.168.1.100:8092", "https://terminal.example.com"])
        XCTAssertEqual(mockProfile.apiKey, "mock-api-key")
        XCTAssertEqual(mockProfile.autoConnect, true)
        XCTAssertEqual(mockProfile.networkSSIDs, ["Home-WiFi", "Office-WiFi"])
        XCTAssertEqual(mockProfile.tlsConfig?.allowSelfSigned, false)
        XCTAssertEqual(mockProfile.tlsConfig?.pinnedCertificates, [])
    }
    
    // MARK: - URL Validation Tests
    
    func testPrimaryURL() {
        // Given
        let profile = ConnectionProfile(
            id: "test-id",
            name: "Test Profile",
            urls: ["https://primary.com:8092", "https://secondary.com:8092"],
            apiKey: "key",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When
        let primaryURL = profile.primaryURL
        
        // Then
        XCTAssertEqual(primaryURL, "https://primary.com:8092")
    }
    
    func testPrimaryURLWithEmptyList() {
        // Given
        let profile = ConnectionProfile(
            id: "test-id",
            name: "Test Profile",
            urls: [],
            apiKey: "key",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When
        let primaryURL = profile.primaryURL
        
        // Then
        XCTAssertNil(primaryURL)
    }
    
    func testHasSecureConnection() {
        // Given
        let secureProfile = ConnectionProfile(
            id: "secure-id",
            name: "Secure Profile",
            urls: ["https://example.com:8092"],
            apiKey: "key",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        let insecureProfile = ConnectionProfile(
            id: "insecure-id",
            name: "Insecure Profile",
            urls: ["http://example.com:8092"],
            apiKey: "key",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When & Then
        XCTAssertTrue(secureProfile.hasSecureConnection)
        XCTAssertFalse(insecureProfile.hasSecureConnection)
    }
}