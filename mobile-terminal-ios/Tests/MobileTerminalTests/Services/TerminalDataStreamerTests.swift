#if os(iOS)
import XCTest
import SwiftTerm
@testable import MobileTerminal

final class TerminalDataStreamerTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var sut: TerminalDataStreamer!
    var mockTerminalView: MockTerminalView!
    var mockWebSocketClient: SharedMockWebSocketClient!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        sut = TerminalDataStreamer()
        mockTerminalView = MockTerminalView()
        mockWebSocketClient = SharedMockWebSocketClient()
    }
    
    override func tearDown() {
        sut.stopStreaming()
        sut = nil
        mockTerminalView = nil
        mockWebSocketClient = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testTerminalDataStreamerInitialization() {
        // Given & When
        let streamer = TerminalDataStreamer()
        
        // Then
        XCTAssertFalse(streamer.isStreaming, "Should not be streaming initially")
        XCTAssertEqual(streamer.bytesReceived, 0, "Should have zero bytes received initially")
        XCTAssertEqual(streamer.bytesSent, 0, "Should have zero bytes sent initially")
    }
    
    // MARK: - Streaming Control Tests
    
    func testStartStreaming() {
        // Given
        XCTAssertFalse(sut.isStreaming, "Should not be streaming initially")
        
        // When
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        
        // Then
        XCTAssertTrue(sut.isStreaming, "Should be streaming after start")
    }
    
    func testStopStreaming() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        XCTAssertTrue(sut.isStreaming, "Should be streaming after start")
        
        // When
        sut.stopStreaming()
        
        // Then
        XCTAssertFalse(sut.isStreaming, "Should not be streaming after stop")
    }
    
    func testStartStreamingTwice() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        XCTAssertTrue(sut.isStreaming, "Should be streaming after first start")
        
        // When
        let secondTerminalView = MockTerminalView()
        let secondWebSocketClient = SharedMockWebSocketClient()
        sut.startStreaming(terminalView: secondTerminalView, webSocketClient: secondWebSocketClient)
        
        // Then
        XCTAssertTrue(sut.isStreaming, "Should still be streaming after second start")
    }
    
    // MARK: - Data Handling Tests
    
    func testSendDataToTerminal() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let testData = "Hello Terminal!".data(using: .utf8)!
        let initialBytesReceived = sut.bytesReceived
        
        // When
        sut.sendDataToTerminal(testData)
        
        // Then
        XCTAssertEqual(sut.bytesReceived, initialBytesReceived + testData.count, "Should update bytes received")
    }
    
    func testSendDataToTerminalWhenNotActive() {
        // Given
        let testData = "Hello Terminal!".data(using: .utf8)!
        let initialBytesReceived = sut.bytesReceived
        
        // When (not started streaming)
        sut.sendDataToTerminal(testData)
        
        // Then
        XCTAssertEqual(sut.bytesReceived, initialBytesReceived, "Should not update bytes received when not active")
    }
    
    func testSendDataToServer() async {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let testData = "Hello Server!".data(using: .utf8)!
        let initialBytesSent = sut.bytesSent
        
        // When
        await sut.sendDataToServer(testData)
        
        // Then
        XCTAssertEqual(sut.bytesSent, initialBytesSent + testData.count, "Should update bytes sent")
        XCTAssertEqual(mockWebSocketClient.receivedMessages.count, 1, "Should send one message")
    }
    
    func testSendDataToServerWhenNotActive() async {
        // Given
        let testData = "Hello Server!".data(using: .utf8)!
        let initialBytesSent = sut.bytesSent
        
        // When (not started streaming)
        await sut.sendDataToServer(testData)
        
        // Then
        XCTAssertEqual(sut.bytesSent, initialBytesSent, "Should not update bytes sent when not active")
        XCTAssertEqual(mockWebSocketClient.receivedMessages.count, 0, "Should not send any messages")
    }
    
    func testSendDataToServerWithInvalidUTF8() async {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let invalidData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8 sequence
        let initialBytesSent = sut.bytesSent
        
        // When
        await sut.sendDataToServer(invalidData)
        
        // Then
        XCTAssertEqual(sut.bytesSent, initialBytesSent, "Should not update bytes sent with invalid UTF-8")
        XCTAssertEqual(mockWebSocketClient.receivedMessages.count, 0, "Should not send any messages with invalid UTF-8")
    }
    
    // MARK: - WebSocket Message Handling Tests
    
    func testHandleTerminalOutputMessage() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let testOutput = "Terminal output"
        let message = WebSocketMessage(
            type: .terminalOutput,
            payload: [
                "terminalId": "default-terminal",
                "data": testOutput
            ]
        )
        let initialBytesReceived = sut.bytesReceived
        
        // When
        mockWebSocketClient.simulateMessage(message)
        
        // Then
        XCTAssertEqual(sut.bytesReceived, initialBytesReceived + testOutput.count, "Should update bytes received")
    }
    
    func testHandleTerminalOutputMessageWrongTerminalId() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let testOutput = "Terminal output"
        let message = WebSocketMessage(
            type: .terminalOutput,
            payload: [
                "terminalId": "wrong-terminal-id",
                "data": testOutput
            ]
        )
        let initialBytesReceived = sut.bytesReceived
        
        // When
        mockWebSocketClient.simulateMessage(message)
        
        // Then
        XCTAssertEqual(sut.bytesReceived, initialBytesReceived, "Should not update bytes received for wrong terminal ID")
    }
    
    func testHandleTerminalListMessage() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let message = WebSocketMessage(
            type: .terminalList,
            payload: [
                "terminals": []
            ]
        )
        
        // When
        mockWebSocketClient.simulateMessage(message)
        
        // Then
        // Should handle message without crashing
        XCTAssertTrue(sut.isStreaming, "Should still be streaming after terminal list message")
    }
    
    func testHandleErrorMessage() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let message = WebSocketMessage(
            type: .error,
            payload: [
                "message": "Test error"
            ]
        )
        
        // When
        mockWebSocketClient.simulateMessage(message)
        
        // Then
        // Should handle error message without crashing
        XCTAssertTrue(sut.isStreaming, "Should still be streaming after error message")
    }
    
    func testHandleUnknownMessage() {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let message = WebSocketMessage(
            type: .connectionPing,
            payload: [:]
        )
        
        // When
        mockWebSocketClient.simulateMessage(message)
        
        // Then
        // Should handle unknown message without crashing
        XCTAssertTrue(sut.isStreaming, "Should still be streaming after unknown message")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        // Given
        weak var weakStreamer: TerminalDataStreamer?
        
        // When
        autoreleasepool {
            let streamer = TerminalDataStreamer()
            weakStreamer = streamer
            streamer.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
            streamer.stopStreaming()
        }
        
        // Then
        XCTAssertNil(weakStreamer, "Streamer should be deallocated after stopping")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentDataSending() async {
        // Given
        sut.startStreaming(terminalView: mockTerminalView, webSocketClient: mockWebSocketClient)
        let testData = "Test data".data(using: .utf8)!
        
        // When
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.sut.sendDataToServer(testData)
                }
            }
        }
        
        // Then
        XCTAssertEqual(sut.bytesSent, testData.count * 10, "Should handle concurrent sends correctly")
        XCTAssertEqual(mockWebSocketClient.receivedMessages.count, 10, "Should send all messages")
    }
}

// MARK: - Mock Classes

class MockTerminalView: TerminalView {
    var feedCallCount = 0
    var lastFeedData: Data?
    
    override func feed(data: Data) {
        feedCallCount += 1
        lastFeedData = data
        // Don't call super to avoid SwiftTerm initialization
    }
    
    override func getTerminal() -> Terminal {
        // Return a mock terminal for testing
        return Terminal()
    }
}

#endif