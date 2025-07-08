import XCTest
import Combine
@testable import MobileTerminal

// MARK: - Mock Dependencies

class MockKeychainService: KeychainService {
    var storeCallCount = 0
    var retrieveCallCount = 0
    var deleteCallCount = 0
    var listCallCount = 0
    var clearAllCallCount = 0
    
    var shouldFailStore = false
    var shouldFailRetrieve = false
    var shouldFailDelete = false
    
    var mockCredentials: [String: String] = [:]
    var mockProfiles: [ConnectionProfile] = []
    
    override func storeCredential(_ credential: KeychainCredential) async throws {
        storeCallCount += 1
        if shouldFailStore {
            throw KeychainError.duplicateItem
        }
        mockCredentials[credential.identifier] = credential.value
    }
    
    override func retrieveCredential(identifier: String) async throws -> String {
        retrieveCallCount += 1
        if shouldFailRetrieve {
            throw KeychainError.itemNotFound
        }
        guard let value = mockCredentials[identifier] else {
            throw KeychainError.itemNotFound
        }
        return value
    }
    
    override func deleteCredential(identifier: String) async throws {
        deleteCallCount += 1
        if shouldFailDelete {
            throw KeychainError.itemNotFound
        }
        mockCredentials.removeValue(forKey: identifier)
    }
    
    override func listCredentialIdentifiers() async throws -> [String] {
        listCallCount += 1
        return Array(mockCredentials.keys)
    }
    
    override func clearAllCredentials() async throws {
        clearAllCallCount += 1
        mockCredentials.removeAll()
    }
    
    // Helper method to pre-populate profiles for testing
    func setupMockProfiles(_ profiles: [ConnectionProfile]) {
        for profile in profiles {
            if let data = try? JSONEncoder().encode(profile),
               let jsonString = String(data: data, encoding: .utf8) {
                mockCredentials["profile_\(profile.id)"] = jsonString
            }
        }
    }
}

class MockNetworkMonitor: NetworkMonitor {
    var isConnected = true
    var currentSSID: String?
    
    func startMonitoring() {}
    func stopMonitoring() {}
}

class MockQRCodeParser {
    var shouldFailParsing = false
    
    func parse(_ qrCode: String) throws -> ConnectionProfile {
        if shouldFailParsing {
            throw ConnectionError.invalidQRCode
        }
        
        // Simple parsing logic for tests
        if qrCode.contains("invalid") {
            throw ConnectionError.invalidQRCode
        }
        
        return ConnectionProfile.mock()
    }
}

// MARK: - ConnectionViewModelTests

@MainActor
class ConnectionViewModelTests: XCTestCase {
    var sut: ConnectionViewModel!
    var mockKeychainService: MockKeychainService!
    var mockNetworkMonitor: MockNetworkMonitor!
    var mockQRCodeParser: MockQRCodeParser!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockKeychainService = MockKeychainService()
        mockNetworkMonitor = MockNetworkMonitor()
        mockQRCodeParser = MockQRCodeParser()
        cancellables = Set<AnyCancellable>()
        sut = ConnectionViewModel(
            keychainService: mockKeychainService,
            networkMonitor: mockNetworkMonitor
        )
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockQRCodeParser = nil
        mockNetworkMonitor = nil
        mockKeychainService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(sut.profiles.isEmpty)
        XCTAssertNil(sut.currentProfile)
        XCTAssertFalse(sut.isConnecting)
        XCTAssertNil(sut.connectionError)
        XCTAssertFalse(sut.isScanning)
        XCTAssertTrue(sut.detectedServers.isEmpty)
    }
    
    // MARK: - Profile Management Tests
    
    func testLoadProfilesSuccess() async {
        // Given
        let profile = ConnectionProfile.mock()
        mockKeychainService.setupMockProfiles([profile])
        
        // When
        await sut.loadProfiles()
        
        // Then
        XCTAssertEqual(mockKeychainService.listCallCount, 1)
        XCTAssertTrue(mockKeychainService.retrieveCallCount > 0)
        XCTAssertFalse(sut.profiles.isEmpty)
        XCTAssertEqual(sut.profiles.count, 1)
        XCTAssertEqual(sut.profiles.first?.id, profile.id)
    }
    
    func testCreateProfileFromQRCodeSuccess() async {
        // Given
        let qrCode = "valid-qr-code"
        
        // When
        let profile = await sut.createProfile(from: qrCode)
        
        // Then
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.name, "Mock Connection")
    }
    
    func testCreateProfileFromQRCodeFailure() async {
        // Given
        let qrCode = "invalid-qr-code"
        
        // When
        let profile = await sut.createProfile(from: qrCode)
        
        // Then
        XCTAssertNil(profile)
        XCTAssertNotNil(sut.connectionError)
    }
    
    func testSaveProfileSuccess() async {
        // Given
        let profile = ConnectionProfile.mock()
        
        // When
        await sut.saveProfile(profile)
        
        // Then
        XCTAssertEqual(mockKeychainService.storeCallCount, 1)
        XCTAssertTrue(sut.profiles.contains { $0.id == profile.id })
    }
    
    func testSaveProfileFailure() async {
        // Given
        let profile = ConnectionProfile.mock()
        mockKeychainService.shouldFailStore = true
        
        // When
        await sut.saveProfile(profile)
        
        // Then
        XCTAssertEqual(mockKeychainService.storeCallCount, 1)
        XCTAssertFalse(sut.profiles.contains { $0.id == profile.id })
        XCTAssertNotNil(sut.connectionError)
    }
    
    func testDeleteProfileSuccess() async {
        // Given
        let profile = ConnectionProfile.mock()
        await sut.saveProfile(profile)
        
        // When
        await sut.deleteProfile(profile)
        
        // Then
        XCTAssertEqual(mockKeychainService.deleteCallCount, 1)
        XCTAssertFalse(sut.profiles.contains { $0.id == profile.id })
    }
    
    func testDeleteProfileFailure() async {
        // Given
        let profile = ConnectionProfile.mock()
        mockKeychainService.shouldFailDelete = true
        
        // When
        await sut.deleteProfile(profile)
        
        // Then
        XCTAssertEqual(mockKeychainService.deleteCallCount, 1)
        XCTAssertNotNil(sut.connectionError)
    }
    
    func testUpdateProfileLastUsed() async {
        // Given
        let profile = ConnectionProfile.mock()
        await sut.saveProfile(profile)
        let originalLastUsed = profile.lastUsed
        
        // When
        await sut.updateProfileLastUsed(profile)
        
        // Then
        if let updatedProfile = sut.profiles.first(where: { $0.id == profile.id }) {
            XCTAssertNotEqual(updatedProfile.lastUsed, originalLastUsed)
        } else {
            XCTFail("Profile not found")
        }
    }
    
    // MARK: - Connection Tests
    
    func testTestConnectionSuccess() async {
        // Given
        let profile = ConnectionProfile.mock()
        
        // When
        let isValid = await sut.testConnection(profile)
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testTestConnectionFailure() async {
        // Given
        let profile = ConnectionProfile(
            id: "test",
            name: "Test",
            urls: ["invalid-url"],
            apiKey: "test-key",
            autoConnect: false,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When
        let isValid = await sut.testConnection(profile)
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testValidateUrlSuccess() async {
        // Given
        let url = "http://192.168.1.100:8092"
        
        // When
        let isValid = await sut.validateUrl(url)
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateUrlFailure() async {
        // Given
        let url = "not-a-valid-url"
        
        // When
        let isValid = await sut.validateUrl(url)
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Network Detection Tests
    
    func testDetectLocalServersSuccess() async {
        // When
        let servers = await sut.detectLocalServers()
        
        // Then
        XCTAssertFalse(servers.isEmpty)
        XCTAssertTrue(sut.isScanning == false)
    }
    
    func testStartNetworkScan() {
        // When
        sut.startNetworkScan()
        
        // Then
        XCTAssertTrue(sut.isScanning)
    }
    
    func testStopNetworkScan() {
        // Given
        sut.startNetworkScan()
        
        // When
        sut.stopNetworkScan()
        
        // Then
        XCTAssertFalse(sut.isScanning)
        XCTAssertTrue(sut.detectedServers.isEmpty)
    }
    
    // MARK: - Auto-connection Tests
    
    func testSelectProfileForCurrentNetwork() async {
        // Given
        let profile1 = ConnectionProfile(
            id: "1",
            name: "Home",
            urls: ["http://192.168.1.100:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: ["HomeWiFi"],
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        let profile2 = ConnectionProfile(
            id: "2",
            name: "Office",
            urls: ["http://10.0.0.100:8092"],
            apiKey: "key2",
            autoConnect: true,
            networkSSIDs: ["OfficeWiFi"],
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        await sut.saveProfile(profile1)
        await sut.saveProfile(profile2)
        mockNetworkMonitor.currentSSID = "HomeWiFi"
        
        // When
        let selectedProfile = sut.selectProfileForCurrentNetwork()
        
        // Then
        XCTAssertNotNil(selectedProfile)
        XCTAssertEqual(selectedProfile?.id, "1")
    }
    
    func testSelectProfileForCurrentNetworkNoMatch() async {
        // Given
        let profile = ConnectionProfile(
            id: "1",
            name: "Home",
            urls: ["http://192.168.1.100:8092"],
            apiKey: "key1",
            autoConnect: true,
            networkSSIDs: ["HomeWiFi"],
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        await sut.saveProfile(profile)
        mockNetworkMonitor.currentSSID = "UnknownWiFi"
        
        // When
        let selectedProfile = sut.selectProfileForCurrentNetwork()
        
        // Then
        XCTAssertNil(selectedProfile)
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleError() {
        // Given
        let error = ConnectionError.networkError(message: "Test error")
        
        // When
        sut.handleError(error)
        
        // Then
        XCTAssertNotNil(sut.connectionError)
        XCTAssertEqual(sut.connectionError, error)
    }
    
    func testClearError() {
        // Given
        sut.connectionError = ConnectionError.invalidURL
        
        // When
        sut.clearError()
        
        // Then
        XCTAssertNil(sut.connectionError)
    }
    
    // MARK: - Sorting Tests
    
    func testProfilesSortedByLastUsed() async {
        // Given
        let profile1 = ConnectionProfile(
            id: "1",
            name: "Old",
            urls: ["http://192.168.1.100:8092"],
            apiKey: "key1",
            autoConnect: false,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date().addingTimeInterval(-3600)
        )
        let profile2 = ConnectionProfile(
            id: "2",
            name: "New",
            urls: ["http://192.168.1.101:8092"],
            apiKey: "key2",
            autoConnect: false,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
        
        // When
        await sut.saveProfile(profile1)
        await sut.saveProfile(profile2)
        
        // Then
        XCTAssertEqual(sut.sortedProfiles.first?.id, "2")
        XCTAssertEqual(sut.sortedProfiles.last?.id, "1")
    }
}

