import XCTest
import Starscream
@testable import MobileTerminal

final class WebSocketClientTests: XCTestCase {
    
    var webSocketClient: MobileTerminalWebSocketClient!
    
    override func setUp() {
        super.setUp()
        webSocketClient = MobileTerminalWebSocketClient()
    }
    
    override func tearDown() {
        webSocketClient?.cleanup()
        webSocketClient = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Given & When
        let client = MobileTerminalWebSocketClient()
        
        // Then
        XCTAssertEqual(client.connectionState, .disconnected)
        XCTAssertNil(client.lastError)
        XCTAssertFalse(client.isConnected)
    }
    
    // MARK: - Connection State Tests
    
    func testConnectionStateTransitions() {
        // Given
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
        
        // When - Connecting
        webSocketClient.setConnectionState(.connecting)
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .connecting)
        XCTAssertFalse(webSocketClient.isConnected)
        
        // When - Connected
        webSocketClient.setConnectionState(.connected)
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .connected)
        XCTAssertTrue(webSocketClient.isConnected)
        
        // When - Disconnected
        webSocketClient.setConnectionState(.disconnected)
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
        XCTAssertFalse(webSocketClient.isConnected)
    }
    
    // MARK: - Connect Tests
    
    func testConnectSetsConnectingState() async {
        // Given
        let url = URL(string: "ws://localhost:8092")!
        let apiKey = "test-api-key"
        
        // When
        await webSocketClient.connect(to: url, with: apiKey)
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .connecting)
    }
    
    func testConnectWhileAlreadyConnected() async {
        // Given
        let url = URL(string: "ws://localhost:8092")!
        let apiKey = "test-api-key"
        
        // Manually set connected state
        webSocketClient.setConnectionState(.connected)
        
        // When
        await webSocketClient.connect(to: url, with: apiKey)
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .connected) // Should remain connected
    }
    
    // MARK: - Disconnect Tests
    
    func testDisconnect() {
        // Given
        webSocketClient.setConnectionState(.connected)
        
        // When
        webSocketClient.disconnect()
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
    }
    
    func testDisconnectWhenNotConnected() {
        // Given
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
        
        // When
        webSocketClient.disconnect()
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
    }
    
    // MARK: - Send Message Tests
    
    func testSendMessage() async throws {
        // Given
        webSocketClient.setConnectionState(.connected)
        let message = WebSocketMessage(
            id: "test-id",
            type: .terminalInput,
            timestamp: Date().timeIntervalSince1970,
            payload: ["terminalId": "test-terminal", "data": "ls -la"]
        )
        
        // When & Then
        // This test primarily checks that the method doesn't throw when connected
        // The actual sending would require a real WebSocket connection
        try await webSocketClient.sendMessage(message)
    }
    
    func testSendMessageWhileDisconnected() async {
        // Given
        webSocketClient.setConnectionState(.disconnected)
        let message = WebSocketMessage(
            id: "test-id",
            type: .terminalInput,
            timestamp: Date().timeIntervalSince1970,
            payload: ["terminalId": "test-terminal", "data": "ls -la"]
        )
        
        // When & Then
        do {
            try await webSocketClient.sendMessage(message)
            XCTFail("Should throw error when not connected")
        } catch {
            XCTAssertTrue(error is WebSocketError)
            if let wsError = error as? WebSocketError {
                XCTAssertEqual(wsError, .notConnected)
            }
        }
    }
    
    func testSendMessageWithValidJSON() async {
        // Given
        webSocketClient.setConnectionState(.connected)
        let message = WebSocketMessage(
            id: "test-id",
            type: .terminalInput,
            timestamp: Date().timeIntervalSince1970,
            payload: ["terminalId": "test-terminal", "data": "valid command"]
        )
        
        // When & Then
        // This should not throw an error
        do {
            try await webSocketClient.sendMessage(message)
            // Test passes if no error is thrown
        } catch {
            XCTFail("Should not throw error for valid JSON: \(error)")
        }
    }
    
    // MARK: - Callback Tests
    
    func testCallbacksAreSet() {
        // Given
        var messageReceived = false
        var stateChanged = false
        var errorReceived = false
        var pongReceived = false
        
        // When
        webSocketClient.onMessage = { _ in messageReceived = true }
        webSocketClient.onConnectionStateChanged = { _ in stateChanged = true }
        webSocketClient.onError = { _ in errorReceived = true }
        webSocketClient.onPong = { pongReceived = true }
        
        // Then
        XCTAssertNotNil(webSocketClient.onMessage)
        XCTAssertNotNil(webSocketClient.onConnectionStateChanged)
        XCTAssertNotNil(webSocketClient.onError)
        XCTAssertNotNil(webSocketClient.onPong)
    }
    
    // MARK: - Reconnection Tests
    
    func testStartReconnection() {
        // Given
        let url = URL(string: "ws://localhost:8092")!
        let apiKey = "test-api-key"
        
        // When
        webSocketClient.startReconnection(to: url, with: apiKey)
        
        // Then
        // This test verifies that the method can be called without throwing
        // Actual reconnection behavior requires timer scheduling
        XCTAssertTrue(true) // Basic test that method executes
    }
    
    func testStopReconnection() {
        // Given
        let url = URL(string: "ws://localhost:8092")!
        let apiKey = "test-api-key"
        
        // When
        webSocketClient.startReconnection(to: url, with: apiKey)
        webSocketClient.stopReconnection()
        
        // Then
        // This test verifies that the method can be called without throwing
        XCTAssertTrue(true) // Basic test that method executes
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanup() {
        // Given
        webSocketClient.setConnectionState(.connected)
        
        // When
        webSocketClient.cleanup()
        
        // Then
        XCTAssertEqual(webSocketClient.connectionState, .disconnected)
    }
}