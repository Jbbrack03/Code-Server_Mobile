#if os(iOS)
import SwiftUI
import SwiftTerm
import Foundation

/// Service that streams data between WebSocket and SwiftTerm
public class TerminalDataStreamer: ObservableObject {
    
    // MARK: - Properties
    
    private var terminalView: TerminalView?
    private var webSocketClient: MobileTerminalWebSocketClient?
    private var isActive = false
    
    @Published public private(set) var isStreaming = false
    @Published public private(set) var bytesReceived: Int = 0
    @Published public private(set) var bytesSent: Int = 0
    
    // MARK: - Initialization
    
    public init() {
        // Initialize streamer
    }
    
    // MARK: - Public Methods
    
    /// Start streaming data between WebSocket and terminal
    public func startStreaming(terminalView: TerminalView, webSocketClient: MobileTerminalWebSocketClient) {
        self.terminalView = terminalView
        self.webSocketClient = webSocketClient
        
        setupWebSocketHandlers()
        isActive = true
        isStreaming = true
    }
    
    /// Stop streaming data
    public func stopStreaming() {
        isActive = false
        isStreaming = false
        terminalView = nil
        webSocketClient = nil
    }
    
    /// Send data to terminal for display
    public func sendDataToTerminal(_ data: Data) {
        guard isActive, let terminalView = terminalView else { return }
        
        // Send data to SwiftTerm for display
        terminalView.feed(data: data)
        
        // Update metrics
        bytesReceived += data.count
    }
    
    /// Send data to server via WebSocket
    public func sendDataToServer(_ data: Data) async {
        guard isActive, let webSocketClient = webSocketClient else { return }
        
        // Convert data to string for WebSocket message
        guard let string = String(data: data, encoding: .utf8) else {
            print("Warning: Could not convert data to UTF-8 string")
            return
        }
        
        // Create terminal input message
        let message = WebSocketMessage.terminalInput(
            terminalId: getCurrentTerminalId(),
            data: string
        )
        
        do {
            try await webSocketClient.sendMessage(message)
            
            // Update metrics
            bytesSent += data.count
        } catch {
            print("Error sending data to server: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWebSocketHandlers() {
        webSocketClient?.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleWebSocketMessage(message)
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case .terminalOutput:
            handleTerminalOutput(message)
        case .terminalList:
            handleTerminalList(message)
        case .error:
            handleError(message)
        default:
            break
        }
    }
    
    private func handleTerminalOutput(_ message: WebSocketMessage) {
        guard let terminalId = message.payload["terminalId"] as? String,
              let data = message.payload["data"] as? String,
              terminalId == getCurrentTerminalId() else {
            return
        }
        
        // Convert string to data and send to terminal
        if let outputData = data.data(using: .utf8) {
            sendDataToTerminal(outputData)
        }
    }
    
    private func handleTerminalList(_ message: WebSocketMessage) {
        // Handle terminal list updates
        // This could be used to update the terminal list in real-time
    }
    
    private func handleError(_ message: WebSocketMessage) {
        if let errorMessage = message.payload["message"] as? String {
            print("Terminal error: \(errorMessage)")
        }
    }
    
    private func getCurrentTerminalId() -> String {
        // Get the current terminal ID from the view model
        // This is a simplified implementation
        return "default-terminal"
    }
}

// MARK: - TerminalView Extension

extension TerminalView {
    /// Feed data to the terminal for display
    func feed(data: Data) {
        // Convert data to the format expected by SwiftTerm
        let bytes = Array(data)
        getTerminal().feed(byteArray: bytes)
    }
    
    /// Get the underlying terminal instance
    func getTerminal() -> Terminal {
        // This would need to be implemented to return the actual Terminal instance
        // For now, we'll use a placeholder
        fatalError("getTerminal() needs to be implemented")
    }
}

// MARK: - WebSocketMessage Extension

extension WebSocketMessage {
    /// Create a terminal input message
    static func terminalInput(terminalId: String, data: String) -> WebSocketMessage {
        return WebSocketMessage(
            type: .terminalInput,
            payload: [
                "terminalId": terminalId,
                "data": data
            ]
        )
    }
}

#endif