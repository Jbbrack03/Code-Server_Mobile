import Foundation

/// WebSocket message types for communication with the Mobile Terminal server
public struct WebSocketMessage: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    public let id: String
    public let type: MessageType
    public let timestamp: TimeInterval
    public let payload: [String: Any]
    
    // MARK: - Initialization
    
    public init(id: String, type: MessageType, timestamp: TimeInterval, payload: [String: Any]) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id, type, timestamp, payload
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(MessageType.self, forKey: .type)
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        
        // Decode payload as JSON object
        let payloadData = try container.decode(Data.self, forKey: .payload)
        let jsonObject = try JSONSerialization.jsonObject(with: payloadData, options: [])
        
        if let dictionary = jsonObject as? [String: Any] {
            payload = dictionary
        } else {
            payload = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode payload as JSON data
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        try container.encode(payloadData, forKey: .payload)
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: WebSocketMessage, rhs: WebSocketMessage) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.timestamp == rhs.timestamp &&
               NSDictionary(dictionary: lhs.payload).isEqual(to: rhs.payload)
    }
}

// MARK: - Message Types

/// WebSocket message types
public enum MessageType: String, Codable, CaseIterable {
    case terminalOutput = "terminal.output"
    case terminalInput = "terminal.input"
    case terminalResize = "terminal.resize"
    case terminalList = "terminal.list"
    case terminalSelect = "terminal.select"
    case connectionPing = "connection.ping"
    case connectionPong = "connection.pong"
    case error = "error"
    case authChallenge = "auth.challenge"
    case authResponse = "auth.response"
}

// MARK: - Specific Message Types

/// Terminal output message payload
public struct TerminalOutputPayload: Codable {
    public let terminalId: String
    public let data: String
    public let sequence: Int
    
    public init(terminalId: String, data: String, sequence: Int) {
        self.terminalId = terminalId
        self.data = data
        self.sequence = sequence
    }
}

/// Terminal input message payload
public struct TerminalInputPayload: Codable {
    public let terminalId: String
    public let data: String
    
    public init(terminalId: String, data: String) {
        self.terminalId = terminalId
        self.data = data
    }
}

/// Terminal resize message payload
public struct TerminalResizePayload: Codable {
    public let terminalId: String
    public let cols: Int
    public let rows: Int
    
    public init(terminalId: String, cols: Int, rows: Int) {
        self.terminalId = terminalId
        self.cols = cols
        self.rows = rows
    }
}

/// Error message payload
public struct ErrorPayload: Codable {
    public let code: String
    public let message: String
    public let details: [String: Any]?
    
    public init(code: String, message: String, details: [String: Any]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case code, message, details
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        
        if let detailsData = try container.decodeIfPresent(Data.self, forKey: .details) {
            let jsonObject = try JSONSerialization.jsonObject(with: detailsData, options: [])
            details = jsonObject as? [String: Any]
        } else {
            details = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        
        if let details = details {
            let detailsData = try JSONSerialization.data(withJSONObject: details, options: [])
            try container.encode(detailsData, forKey: .details)
        }
    }
}

// MARK: - Message Factory

extension WebSocketMessage {
    
    /// Creates a terminal input message
    public static func terminalInput(terminalId: String, data: String) -> WebSocketMessage {
        return WebSocketMessage(
            id: UUID().uuidString,
            type: .terminalInput,
            timestamp: Date().timeIntervalSince1970,
            payload: [
                "terminalId": terminalId,
                "data": data
            ]
        )
    }
    
    /// Creates a terminal resize message
    public static func terminalResize(terminalId: String, cols: Int, rows: Int) -> WebSocketMessage {
        return WebSocketMessage(
            id: UUID().uuidString,
            type: .terminalResize,
            timestamp: Date().timeIntervalSince1970,
            payload: [
                "terminalId": terminalId,
                "cols": cols,
                "rows": rows
            ]
        )
    }
    
    /// Creates a terminal select message
    public static func terminalSelect(terminalId: String) -> WebSocketMessage {
        return WebSocketMessage(
            id: UUID().uuidString,
            type: .terminalSelect,
            timestamp: Date().timeIntervalSince1970,
            payload: [
                "terminalId": terminalId
            ]
        )
    }
    
    /// Creates a connection ping message
    public static func connectionPing() -> WebSocketMessage {
        return WebSocketMessage(
            id: UUID().uuidString,
            type: .connectionPing,
            timestamp: Date().timeIntervalSince1970,
            payload: [:]
        )
    }
    
    /// Creates a connection pong message
    public static func connectionPong() -> WebSocketMessage {
        return WebSocketMessage(
            id: UUID().uuidString,
            type: .connectionPong,
            timestamp: Date().timeIntervalSince1970,
            payload: [:]
        )
    }
}