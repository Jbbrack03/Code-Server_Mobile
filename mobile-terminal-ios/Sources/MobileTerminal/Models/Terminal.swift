import Foundation

/// Represents a terminal instance with its metadata and state
public struct Terminal: Codable, Identifiable, Equatable, Hashable {
    
    // MARK: - Properties
    
    public let id: String
    public let name: String
    public let pid: Int
    public let cwd: String
    public let shellType: ShellType
    public let isActive: Bool
    public let isClaudeCode: Bool
    public let createdAt: Date
    public let lastActivity: Date
    public let dimensions: Dimensions
    public let status: Status
    
    // MARK: - Nested Types
    
    /// Supported shell types
    public enum ShellType: String, Codable, CaseIterable {
        case bash = "bash"
        case zsh = "zsh"
        case fish = "fish"
        case pwsh = "pwsh"
        case cmd = "cmd"
    }
    
    /// Terminal status
    public enum Status: String, Codable, CaseIterable {
        case active = "active"
        case inactive = "inactive"
        case crashed = "crashed"
    }
    
    /// Terminal dimensions
    public struct Dimensions: Codable, Equatable {
        public let cols: Int
        public let rows: Int
        
        public init(cols: Int, rows: Int) {
            self.cols = cols
            self.rows = rows
        }
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        pid: Int,
        cwd: String,
        shellType: ShellType,
        isActive: Bool,
        isClaudeCode: Bool,
        createdAt: Date,
        lastActivity: Date,
        dimensions: Dimensions,
        status: Status
    ) {
        self.id = id
        self.name = name
        self.pid = pid
        self.cwd = cwd
        self.shellType = shellType
        self.isActive = isActive
        self.isClaudeCode = isClaudeCode
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.dimensions = dimensions
        self.status = status
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: Terminal, rhs: Terminal) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Mock Helper
    
    public static func mock() -> Terminal {
        return Terminal(
            id: "mock-terminal-id",
            name: "Mock Terminal",
            pid: 12345,
            cwd: "/Users/test/project",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: Date(timeIntervalSince1970: 1609459200),
            lastActivity: Date(timeIntervalSince1970: 1609459260),
            dimensions: Dimensions(cols: 80, rows: 24),
            status: .active
        )
    }
}