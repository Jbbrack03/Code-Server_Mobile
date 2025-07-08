import Foundation

/// Represents a connection profile for connecting to a Mobile Terminal server
public struct ConnectionProfile: Codable, Identifiable, Equatable, Hashable {
    
    // MARK: - Properties
    
    public let id: String
    public let name: String
    public let urls: [String]
    public let apiKey: String
    public let autoConnect: Bool
    public let networkSSIDs: [String]?
    public let tlsConfig: TLSConfig?
    public let createdAt: Date
    public let lastUsed: Date
    
    // MARK: - Nested Types
    
    /// TLS configuration for secure connections
    public struct TLSConfig: Codable, Equatable {
        public let allowSelfSigned: Bool
        public let pinnedCertificates: [String]
        
        public init(allowSelfSigned: Bool, pinnedCertificates: [String]) {
            self.allowSelfSigned = allowSelfSigned
            self.pinnedCertificates = pinnedCertificates
        }
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        urls: [String],
        apiKey: String,
        autoConnect: Bool,
        networkSSIDs: [String]? = nil,
        tlsConfig: TLSConfig? = nil,
        createdAt: Date,
        lastUsed: Date
    ) {
        self.id = id
        self.name = name
        self.urls = urls
        self.apiKey = apiKey
        self.autoConnect = autoConnect
        self.networkSSIDs = networkSSIDs
        self.tlsConfig = tlsConfig
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
    
    // MARK: - Computed Properties
    
    /// Returns the primary URL from the list of URLs
    public var primaryURL: String? {
        return urls.first
    }
    
    /// Returns true if the primary URL uses HTTPS
    public var hasSecureConnection: Bool {
        guard let primaryURL = primaryURL else { return false }
        return primaryURL.lowercased().hasPrefix("https://")
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: ConnectionProfile, rhs: ConnectionProfile) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Mock Helper
    
    public static func mock() -> ConnectionProfile {
        return ConnectionProfile(
            id: "mock-profile-id",
            name: "Mock Connection",
            urls: ["http://192.168.1.100:8092", "https://terminal.example.com"],
            apiKey: "mock-api-key",
            autoConnect: true,
            networkSSIDs: ["Home-WiFi", "Office-WiFi"],
            tlsConfig: TLSConfig(allowSelfSigned: false, pinnedCertificates: []),
            createdAt: Date(timeIntervalSince1970: 1609459200),
            lastUsed: Date(timeIntervalSince1970: 1609459260)
        )
    }
}