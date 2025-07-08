import XCTest
import Combine
@testable import MobileTerminal

// MARK: - Mock Dependencies

class MockAPIClient: APIClient {
    var shouldFailHealthCheck = false
    var shouldFailTerminalList = false
    var shouldFailTerminalSelect = false
    var shouldFailTerminalDetails = false
    var shouldFailSendInput = false
    var shouldFailResize = false
    
    var healthCheckCallCount = 0
    var getTerminalsCallCount = 0
    var selectTerminalCallCount = 0
    var getTerminalCallCount = 0
    var sendInputCallCount = 0
    var resizeTerminalCallCount = 0
    
    var mockHealthResponse = HealthResponse(status: .healthy, version: "1.0.0", uptime: 3600, terminals: 2)
    var mockTerminals = [
        Terminal.mock(id: "1", name: "Terminal 1", isActive: true),
        Terminal.mock(id: "2", name: "Terminal 2", isActive: false)
    ]
    var mockActiveTerminalId: String? = "1"
    var mockTerminalBuffer = ["Line 1", "Line 2", "Line 3"]
    
    init() {
        super.init(baseURL: URL(string: "http://localhost:8092")!, apiKey: "test-api-key")
    }
    
    override func getHealth() async throws -> HealthResponse {
        healthCheckCallCount += 1
        if shouldFailHealthCheck {
            throw APIError.serverError(statusCode: 500, message: "Server error")
        }
        return mockHealthResponse
    }
    
    override func getTerminals() async throws -> TerminalListResponse {
        getTerminalsCallCount += 1
        if shouldFailTerminalList {
            throw APIError.networkError(URLError(.notConnectedToInternet))
        }
        return TerminalListResponse(terminals: mockTerminals, activeTerminalId: mockActiveTerminalId)
    }
    
    override func selectTerminal(id: String) async throws -> TerminalSelectResponse {
        selectTerminalCallCount += 1
        if shouldFailTerminalSelect {
            throw APIError.notFound(message: "Terminal not found")
        }
        mockActiveTerminalId = id
        return TerminalSelectResponse(success: true, activeTerminalId: id)
    }
    
    override func getTerminal(id: String) async throws -> TerminalDetailsResponse {
        getTerminalCallCount += 1
        if shouldFailTerminalDetails {
            throw APIError.notFound(message: "Terminal not found")
        }
        guard let terminal = mockTerminals.first(where: { $0.id == id }) else {
            throw APIError.notFound(message: "Terminal not found")
        }
        return TerminalDetailsResponse(terminal: terminal, buffer: mockTerminalBuffer)
    }
    
    override func sendInput(terminalId: String, data: String) async throws -> TerminalInputResponse {
        sendInputCallCount += 1
        if shouldFailSendInput {
            throw APIError.badRequest(message: "Invalid input")
        }
        return TerminalInputResponse(success: true, sequence: 1)
    }
    
    override func resizeTerminal(terminalId: String, cols: Int, rows: Int) async throws -> TerminalResizeResponse {
        resizeTerminalCallCount += 1
        if shouldFailResize {
            throw APIError.badRequest(message: "Invalid dimensions")
        }
        return TerminalResizeResponse(success: true)
    }
}

class MockWebSocketManager: MobileTerminalWebSocketClient {
    var connectCallCount = 0
    var disconnectCallCount = 0
    var sendMessageCallCount = 0
    var startReconnectionCallCount = 0
    var stopReconnectionCallCount = 0
    
    var shouldFailConnection = false
    var shouldFailSendMessage = false
    
    var mockLastError: WebSocketError?
    
    override func connect(to url: URL, with apiKey: String) async {
        connectCallCount += 1
        
        if shouldFailConnection {
            mockLastError = .connectionError(URLError(.notConnectedToInternet))
            await MainActor.run {
                self.setConnectionState(.failed)
            }
            onConnectionStateChanged?(.failed)
            onError?(.connectionError(URLError(.notConnectedToInternet)))
        } else {
            await MainActor.run {
                self.setConnectionState(.connected)
            }
            onConnectionStateChanged?(.connected)
        }
    }
    
    override func disconnect() {
        disconnectCallCount += 1
        setConnectionState(.disconnected)
        onConnectionStateChanged?(.disconnected)
    }
    
    override func sendMessage(_ message: WebSocketMessage) async throws {
        sendMessageCallCount += 1
        if shouldFailSendMessage {
            throw WebSocketError.notConnected
        }
    }
    
    override func startReconnection(to url: URL, with apiKey: String) {
        startReconnectionCallCount += 1
        setConnectionState(.reconnecting)
        onConnectionStateChanged?(.reconnecting)
    }
    
    override func stopReconnection() {
        stopReconnectionCallCount += 1
    }
}

// MARK: - TerminalViewModelTests

@MainActor
class TerminalViewModelTests: XCTestCase {
    var sut: TerminalViewModel!
    var mockAPIClient: MockAPIClient!
    var mockWebSocketManager: MockWebSocketManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockWebSocketManager = MockWebSocketManager()
        cancellables = Set<AnyCancellable>()
        sut = TerminalViewModel(apiClient: mockAPIClient, webSocketManager: mockWebSocketManager)
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockWebSocketManager = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertTrue(sut.terminals.isEmpty)
        XCTAssertNil(sut.activeTerminalId)
        XCTAssertNil(sut.activeTerminal)
        XCTAssertEqual(sut.connectionState, .disconnected)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertTrue(sut.terminalBuffer.isEmpty)
    }
    
    // MARK: - Connection Tests
    
    func testConnectSuccess() async {
        // Given
        let profile = ConnectionProfile.mock()
        
        // When
        await sut.connect(profile: profile)
        
        // Then
        XCTAssertEqual(mockWebSocketManager.connectCallCount, 1)
        XCTAssertEqual(sut.connectionState, .connected)
        XCTAssertNil(sut.error)
    }
    
    func testConnectFailure() async {
        // Given
        let profile = ConnectionProfile.mock()
        mockWebSocketManager.shouldFailConnection = true
        
        // When
        await sut.connect(profile: profile)
        
        // Then
        XCTAssertEqual(mockWebSocketManager.connectCallCount, 1)
        XCTAssertEqual(sut.connectionState, .failed)
        XCTAssertNotNil(sut.error)
    }
    
    func testDisconnect() async {
        // Given
        let profile = ConnectionProfile.mock()
        await sut.connect(profile: profile)
        
        // When
        await sut.disconnect()
        
        // Then
        XCTAssertEqual(mockWebSocketManager.disconnectCallCount, 1)
        XCTAssertEqual(sut.connectionState, .disconnected)
    }
    
    func testReconnect() async {
        // Given
        let profile = ConnectionProfile.mock()
        sut.currentProfile = profile
        sut.connectionState = .failed
        
        // When
        await sut.reconnect()
        
        // Then
        XCTAssertEqual(mockWebSocketManager.connectCallCount, 1)
    }
    
    func testReconnectWithoutProfile() async {
        // Given
        sut.connectionState = .failed
        
        // When
        await sut.reconnect()
        
        // Then
        XCTAssertEqual(mockWebSocketManager.connectCallCount, 0)
        XCTAssertNotNil(sut.error)
    }
    
    // MARK: - Terminal Management Tests
    
    func testLoadTerminalsSuccess() async {
        // When
        await sut.loadTerminals()
        
        // Then
        XCTAssertEqual(mockAPIClient.getTerminalsCallCount, 1)
        XCTAssertEqual(sut.terminals.count, 2)
        XCTAssertEqual(sut.activeTerminalId, "1")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }
    
    func testLoadTerminalsFailure() async {
        // Given
        mockAPIClient.shouldFailTerminalList = true
        
        // When
        await sut.loadTerminals()
        
        // Then
        XCTAssertEqual(mockAPIClient.getTerminalsCallCount, 1)
        XCTAssertTrue(sut.terminals.isEmpty)
        XCTAssertNil(sut.activeTerminalId)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.error)
    }
    
    func testSelectTerminalSuccess() async {
        // Given
        await sut.loadTerminals()
        let terminal = sut.terminals[1]
        
        // When
        await sut.selectTerminal(terminal)
        
        // Then
        XCTAssertEqual(mockAPIClient.selectTerminalCallCount, 1)
        XCTAssertEqual(sut.activeTerminalId, terminal.id)
        XCTAssertEqual(sut.activeTerminal?.id, terminal.id)
    }
    
    func testSelectTerminalFailure() async {
        // Given
        await sut.loadTerminals()
        let terminal = sut.terminals[1]
        mockAPIClient.shouldFailTerminalSelect = true
        
        // When
        await sut.selectTerminal(terminal)
        
        // Then
        XCTAssertEqual(mockAPIClient.selectTerminalCallCount, 1)
        XCTAssertNotEqual(sut.activeTerminalId, terminal.id)
        XCTAssertNotNil(sut.error)
    }
    
    func testSelectNextTerminal() async {
        // Given
        await sut.loadTerminals()
        
        // When
        await sut.selectNextTerminal()
        
        // Then
        XCTAssertEqual(sut.activeTerminalId, "2")
        XCTAssertEqual(mockAPIClient.selectTerminalCallCount, 1)
    }
    
    func testSelectPreviousTerminal() async {
        // Given
        await sut.loadTerminals()
        await sut.selectTerminal(sut.terminals[1])
        
        // When
        await sut.selectPreviousTerminal()
        
        // Then
        XCTAssertEqual(sut.activeTerminalId, "1")
        XCTAssertEqual(mockAPIClient.selectTerminalCallCount, 2)
    }
    
    // MARK: - Terminal Interaction Tests
    
    func testSendInputSuccess() async {
        // Given
        await sut.loadTerminals()
        let input = "ls -la"
        
        // When
        await sut.sendInput(input)
        
        // Then
        XCTAssertEqual(mockAPIClient.sendInputCallCount, 1)
        XCTAssertEqual(mockWebSocketManager.sendMessageCallCount, 1)
        XCTAssertNil(sut.error)
    }
    
    func testSendInputFailure() async {
        // Given
        await sut.loadTerminals()
        let input = "ls -la"
        mockAPIClient.shouldFailSendInput = true
        
        // When
        await sut.sendInput(input)
        
        // Then
        XCTAssertEqual(mockAPIClient.sendInputCallCount, 1)
        XCTAssertNotNil(sut.error)
    }
    
    func testSendInputWithoutActiveTerminal() async {
        // Given
        let input = "ls -la"
        
        // When
        await sut.sendInput(input)
        
        // Then
        XCTAssertEqual(mockAPIClient.sendInputCallCount, 0)
        XCTAssertNotNil(sut.error)
    }
    
    func testResizeTerminalSuccess() async {
        // Given
        await sut.loadTerminals()
        
        // When
        await sut.resizeTerminal(cols: 100, rows: 30)
        
        // Then
        XCTAssertEqual(mockAPIClient.resizeTerminalCallCount, 1)
        XCTAssertEqual(mockWebSocketManager.sendMessageCallCount, 1)
        XCTAssertNil(sut.error)
    }
    
    func testResizeTerminalFailure() async {
        // Given
        await sut.loadTerminals()
        mockAPIClient.shouldFailResize = true
        
        // When
        await sut.resizeTerminal(cols: 100, rows: 30)
        
        // Then
        XCTAssertEqual(mockAPIClient.resizeTerminalCallCount, 1)
        XCTAssertNotNil(sut.error)
    }
    
    // MARK: - Terminal Buffer Tests
    
    func testLoadTerminalBuffer() async {
        // Given
        await sut.loadTerminals()
        let initialCallCount = mockAPIClient.getTerminalCallCount
        
        // When
        await sut.loadTerminalBuffer()
        
        // Then
        XCTAssertEqual(mockAPIClient.getTerminalCallCount, initialCallCount + 1)
        XCTAssertEqual(sut.terminalBuffer.count, 3)
        XCTAssertEqual(sut.terminalBuffer, ["Line 1", "Line 2", "Line 3"])
    }
    
    func testAppendToBuffer() {
        // Given
        let output = "New output line"
        
        // When
        sut.appendToBuffer(output)
        
        // Then
        XCTAssertEqual(sut.terminalBuffer.count, 1)
        XCTAssertEqual(sut.terminalBuffer.first, output)
    }
    
    func testClearBuffer() {
        // Given
        sut.appendToBuffer("Line 1")
        sut.appendToBuffer("Line 2")
        
        // When
        sut.clearBuffer()
        
        // Then
        XCTAssertTrue(sut.terminalBuffer.isEmpty)
    }
    
    // MARK: - WebSocket Message Handling Tests
    
    func testHandleTerminalOutputMessage() async {
        // Given
        await sut.loadTerminals()
        sut.clearBuffer() // Clear buffer from loadTerminals
        let outputPayload: [String: Any] = [
            "terminalId": "1",
            "data": "Terminal output",
            "sequence": 1
        ]
        let message = WebSocketMessage(id: "1", type: .terminalOutput, timestamp: Date().timeIntervalSince1970, payload: outputPayload)
        
        // When
        sut.handleWebSocketMessage(message)
        
        // Then
        XCTAssertEqual(sut.terminalBuffer.count, 1)
        XCTAssertEqual(sut.terminalBuffer.first, "Terminal output")
    }
    
    func testHandleTerminalListMessage() {
        // Given
        let listPayload: [String: Any] = [
            "terminals": [
                ["id": "3", "name": "New Terminal", "pid": 999, "cwd": "/", "shellType": "bash", "isActive": false, "isClaudeCode": false, "createdAt": Date().timeIntervalSince1970, "lastActivity": Date().timeIntervalSince1970, "dimensions": ["cols": 80, "rows": 24], "status": "active"]
            ],
            "activeTerminalId": "3"
        ]
        let message = WebSocketMessage(id: "2", type: .terminalList, timestamp: Date().timeIntervalSince1970, payload: listPayload)
        
        // When
        sut.handleWebSocketMessage(message)
        
        // Then
        // This test would check if terminals are updated from WebSocket messages
        // Implementation depends on how the ViewModel handles terminal list updates
    }
    
    func testHandleErrorMessage() {
        // Given
        let errorPayload: [String: Any] = [
            "code": "TERM_001",
            "message": "Terminal not found"
        ]
        let message = WebSocketMessage(id: "3", type: .error, timestamp: Date().timeIntervalSince1970, payload: errorPayload)
        
        // When
        sut.handleWebSocketMessage(message)
        
        // Then
        XCTAssertNotNil(sut.error)
    }
    
    // MARK: - State Management Tests
    
    func testConnectionStateUpdates() {
        // Given
        let expectation = XCTestExpectation(description: "Connection state updates")
        var receivedStates: [ConnectionState] = []
        
        sut.$connectionState
            .dropFirst()
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        sut.connectionState = .connecting
        sut.connectionState = .connected
        sut.connectionState = .disconnected
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStates, [.connecting, .connected, .disconnected])
    }
    
    func testErrorHandling() {
        // Given
        let error = TerminalError.networkError(message: "Connection failed")
        
        // When
        sut.handleError(error)
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.error, error)
    }
    
    func testShowError() {
        // Given
        let error = TerminalError.terminalNotFound(id: "unknown")
        
        // When
        sut.showError(error)
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.error, error)
    }
    
    // MARK: - Health Check Tests
    
    func testCheckServerHealthSuccess() async {
        // When
        let isHealthy = await sut.checkServerHealth()
        
        // Then
        XCTAssertTrue(isHealthy)
        XCTAssertEqual(mockAPIClient.healthCheckCallCount, 1)
    }
    
    func testCheckServerHealthFailure() async {
        // Given
        mockAPIClient.shouldFailHealthCheck = true
        
        // When
        let isHealthy = await sut.checkServerHealth()
        
        // Then
        XCTAssertFalse(isHealthy)
        XCTAssertEqual(mockAPIClient.healthCheckCallCount, 1)
    }
}

