import Foundation

/// WebSocket-specific errors
public enum WebSocketError: Error, Equatable {
    case notConnected
    case invalidMessage
    case unsupportedMessage
    case connectionError(Error)
    case authenticationFailed
    case timeout
    case invalidURL
    case encodingError
    case decodingError
    
    // MARK: - Equatable Implementation
    
    public static func == (lhs: WebSocketError, rhs: WebSocketError) -> Bool {
        switch (lhs, rhs) {
        case (.notConnected, .notConnected),
             (.invalidMessage, .invalidMessage),
             (.unsupportedMessage, .unsupportedMessage),
             (.authenticationFailed, .authenticationFailed),
             (.timeout, .timeout),
             (.invalidURL, .invalidURL),
             (.encodingError, .encodingError),
             (.decodingError, .decodingError):
            return true
        case (.connectionError(let error1), .connectionError(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - LocalizedError

extension WebSocketError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .invalidMessage:
            return "Invalid WebSocket message format"
        case .unsupportedMessage:
            return "Unsupported WebSocket message type"
        case .connectionError(let error):
            return "WebSocket connection error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "WebSocket authentication failed"
        case .timeout:
            return "WebSocket connection timeout"
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .encodingError:
            return "Message encoding error"
        case .decodingError:
            return "Message decoding error"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .notConnected:
            return "Ensure WebSocket connection is established before sending messages"
        case .invalidMessage:
            return "Check message format and try again"
        case .unsupportedMessage:
            return "Use supported message types only"
        case .connectionError:
            return "Check network connectivity and server availability"
        case .authenticationFailed:
            return "Verify API key and server configuration"
        case .timeout:
            return "Check network connectivity and try again"
        case .invalidURL:
            return "Verify the WebSocket URL format"
        case .encodingError:
            return "Check message payload for invalid data"
        case .decodingError:
            return "Verify message format matches expected structure"
        }
    }
}

// MARK: - Connection State

/// WebSocket connection state
public enum ConnectionState: String, Codable, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"
    
    public var isConnected: Bool {
        return self == .connected
    }
    
    public var canReconnect: Bool {
        switch self {
        case .disconnected, .failed:
            return true
        default:
            return false
        }
    }
    
    public var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting:
            return "Reconnecting..."
        case .failed:
            return "Connection Failed"
        }
    }
}