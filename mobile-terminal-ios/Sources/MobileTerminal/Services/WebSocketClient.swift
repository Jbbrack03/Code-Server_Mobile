import Foundation
import Starscream

/// WebSocket client for real-time communication with the Mobile Terminal server
public class MobileTerminalWebSocketClient: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var lastError: WebSocketError?
    
    // MARK: - Properties
    
    private var socket: WebSocket?
    private let connectionTimeout: TimeInterval = 30.0
    private let maxReconnectionAttempts = 5
    private let baseReconnectionDelay: TimeInterval = 1.0
    
    private var reconnectionTimer: Timer?
    private var reconnectionAttempts = 0
    private var isReconnecting = false
    
    // MARK: - Callbacks
    
    public var onMessage: ((WebSocketMessage) -> Void)?
    public var onConnectionStateChanged: ((ConnectionState) -> Void)?
    public var onError: ((WebSocketError) -> Void)?
    public var onPong: (() -> Void)?
    
    // MARK: - Computed Properties
    
    public var isConnected: Bool {
        return connectionState.isConnected
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Connect to the WebSocket server
    public func connect(to url: URL, with apiKey: String) async {
        guard connectionState != .connected && connectionState != .connecting else {
            return
        }
        
        await MainActor.run {
            self.connectionState = .connecting
            self.lastError = nil
            self.onConnectionStateChanged?(self.connectionState)
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = connectionTimeout
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    /// Disconnect from the WebSocket server
    public func disconnect() {
        guard connectionState != .disconnected else {
            return
        }
        
        stopReconnection()
        socket?.disconnect()
        socket = nil
        
        connectionState = .disconnected
        onConnectionStateChanged?(connectionState)
    }
    
    /// Send a message to the server
    public func sendMessage(_ message: WebSocketMessage) async throws {
        guard isConnected else {
            throw WebSocketError.notConnected
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let jsonString = String(data: data, encoding: .utf8)!
            
            socket?.write(string: jsonString)
        } catch {
            throw WebSocketError.encodingError
        }
    }
    
    /// Start reconnection attempts
    public func startReconnection(to url: URL, with apiKey: String) {
        guard !isReconnecting else { return }
        
        isReconnecting = true
        reconnectionAttempts = 0
        
        scheduleReconnection(to: url, with: apiKey)
    }
    
    /// Stop reconnection attempts
    public func stopReconnection() {
        isReconnecting = false
        reconnectionAttempts = 0
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
    
    /// Clean up resources
    public func cleanup() {
        stopReconnection()
        socket?.disconnect()
        socket = nil
        connectionState = .disconnected
    }
    
    // MARK: - Test Helper Methods
    
    #if DEBUG
    internal func setConnectionState(_ state: ConnectionState) {
        connectionState = state
    }
    #endif
    
    // MARK: - Private Methods
    
    private func scheduleReconnection(to url: URL, with apiKey: String) {
        guard isReconnecting && reconnectionAttempts < maxReconnectionAttempts else {
            isReconnecting = false
            connectionState = .failed
            lastError = .timeout
            onConnectionStateChanged?(connectionState)
            onError?(WebSocketError.timeout)
            return
        }
        
        let delay = baseReconnectionDelay * pow(2.0, Double(reconnectionAttempts))
        reconnectionAttempts += 1
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task {
                await self?.connect(to: url, with: apiKey)
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        do {
            guard let data = text.data(using: .utf8) else {
                throw WebSocketError.decodingError
            }
            
            let message = try JSONDecoder().decode(WebSocketMessage.self, from: data)
            onMessage?(message)
        } catch {
            let wsError = WebSocketError.invalidMessage
            lastError = wsError
            onError?(wsError)
        }
    }
    
    private func handleError(_ error: Error) {
        let wsError = WebSocketError.connectionError(error)
        lastError = wsError
        connectionState = .failed
        onConnectionStateChanged?(connectionState)
        onError?(wsError)
    }
}

// MARK: - WebSocketDelegate

extension MobileTerminalWebSocketClient: WebSocketDelegate {
    
    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            connectionState = .connected
            reconnectionAttempts = 0
            isReconnecting = false
            onConnectionStateChanged?(connectionState)
            
        case .disconnected(let reason, let code):
            connectionState = .disconnected
            onConnectionStateChanged?(connectionState)
            
        case .text(let text):
            handleMessage(text)
            
        case .binary(let data):
            let wsError = WebSocketError.unsupportedMessage
            lastError = wsError
            onError?(wsError)
            
        case .ping(let data):
            socket?.write(pong: data ?? Data())
            
        case .pong(let data):
            onPong?()
            
        case .viabilityChanged(let isViable):
            if !isViable && connectionState == .connected {
                connectionState = .reconnecting
                onConnectionStateChanged?(connectionState)
            }
            
        case .reconnectSuggested(let shouldReconnect):
            if shouldReconnect && connectionState.canReconnect {
                // Handle reconnection suggestion
                connectionState = .reconnecting
                onConnectionStateChanged?(connectionState)
            }
            
        case .cancelled:
            connectionState = .disconnected
            onConnectionStateChanged?(connectionState)
            
        case .error(let error):
            if let error = error {
                handleError(error)
            }
            
        case .peerClosed:
            connectionState = .disconnected
            onConnectionStateChanged?(connectionState)
        }
    }
}