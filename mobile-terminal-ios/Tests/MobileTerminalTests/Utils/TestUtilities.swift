import Foundation
import XCTest
@testable import MobileTerminal

// MARK: - Test Utilities

class TestUtilities {
    static func createMockTerminal(id: String = "test-terminal") -> Terminal {
        return Terminal(
            id: id,
            name: "Test Terminal",
            pid: 1234,
            cwd: "/test",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: Date(),
            lastActivity: Date(),
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
    }
    
    static func createMockConnectionProfile() -> ConnectionProfile {
        return ConnectionProfile(
            id: "test-profile",
            name: "Test Profile",
            urls: ["ws://localhost:8092"],
            apiKey: "test-api-key",
            autoConnect: true,
            networkSSIDs: nil,
            tlsConfig: nil,
            createdAt: Date(),
            lastUsed: Date()
        )
    }
}

// MARK: - Shared Mock Classes

class SharedMockAPIClient: APIClient {
    var shouldFailHealthCheck = false
    var shouldFailTerminalList = false
    var shouldFailTerminalSelect = false
    var shouldFailSendInput = false
    var shouldFailResize = false
    var mockTerminals: [Terminal] = []
    var mockActiveTerminalId: String?
    var mockBuffer: [String] = []
    
    init() {
        super.init(baseURL: URL(string: "http://localhost:8092")!, apiKey: "test-api-key")
    }
    
    override func getHealth() async throws -> HealthResponse {
        if shouldFailHealthCheck {
            throw APIError.networkError(NSError(domain: "test", code: 1, userInfo: nil))
        }
        return HealthResponse(status: .healthy, version: "1.0.0", uptime: 3600, terminals: 1)
    }
    
    override func getTerminals() async throws -> TerminalListResponse {
        if shouldFailTerminalList {
            throw APIError.networkError(NSError(domain: "test", code: 1, userInfo: nil))
        }
        return TerminalListResponse(terminals: mockTerminals, activeTerminalId: mockActiveTerminalId)
    }
    
    override func getTerminal(id: String) async throws -> TerminalDetailsResponse {
        let terminal = mockTerminals.first { $0.id == id } ?? TestUtilities.createMockTerminal(id: id)
        return TerminalDetailsResponse(terminal: terminal, buffer: mockBuffer)
    }
    
    override func selectTerminal(id: String) async throws -> TerminalSelectResponse {
        if shouldFailTerminalSelect {
            throw APIError.networkError(NSError(domain: "test", code: 1, userInfo: nil))
        }
        mockActiveTerminalId = id
        return TerminalSelectResponse(success: true, activeTerminalId: id)
    }
    
    override func sendInput(terminalId: String, data: String) async throws -> TerminalInputResponse {
        if shouldFailSendInput {
            throw APIError.networkError(NSError(domain: "test", code: 1, userInfo: nil))
        }
        return TerminalInputResponse(success: true, sequence: 1)
    }
    
    override func resizeTerminal(terminalId: String, cols: Int, rows: Int) async throws -> TerminalResizeResponse {
        if shouldFailResize {
            throw APIError.networkError(NSError(domain: "test", code: 1, userInfo: nil))
        }
        return TerminalResizeResponse(success: true)
    }
}

class SharedMockWebSocketClient: MobileTerminalWebSocketClient {
    var mockConnectionState: ConnectionState = .disconnected
    var shouldFailConnection = false
    var receivedMessages: [WebSocketMessage] = []
    
    override init() {
        super.init()
    }
    
    override var connectionState: ConnectionState {
        return mockConnectionState
    }
    
    override func connect(to url: URL, with apiKey: String) async {
        if shouldFailConnection {
            mockConnectionState = .failed
            onError?(.connectionError(NSError(domain: "test", code: 1, userInfo: nil)))
        } else {
            mockConnectionState = .connected
            onConnectionStateChanged?(.connected)
        }
    }
    
    override func disconnect() {
        mockConnectionState = .disconnected
        onConnectionStateChanged?(.disconnected)
    }
    
    override func sendMessage(_ message: WebSocketMessage) async throws {
        receivedMessages.append(message)
    }
    
    func simulateMessage(_ message: WebSocketMessage) {
        onMessage?(message)
    }
    
    func simulateError(_ error: WebSocketError) {
        onError?(error)
    }
}