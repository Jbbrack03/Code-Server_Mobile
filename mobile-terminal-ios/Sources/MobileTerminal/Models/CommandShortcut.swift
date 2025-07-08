import Foundation

/// Represents a custom command shortcut for quick terminal access
public struct CommandShortcut: Codable, Identifiable, Equatable, Hashable {
    
    // MARK: - Properties
    
    public let id: String
    public let label: String
    public let command: String
    public let position: Int
    public let icon: String?
    public let color: String?
    public let category: Category
    public private(set) var usage: Int
    public let createdAt: Date
    
    // MARK: - Constants
    
    private static let maxLabelLength = 20
    
    // MARK: - Nested Types
    
    /// Command shortcut categories
    public enum Category: String, Codable, CaseIterable {
        case `default` = "default"
        case git = "git"
        case npm = "npm"
        case docker = "docker"
        case custom = "custom"
        
        public var displayName: String {
            switch self {
            case .default: return "Default"
            case .git: return "Git"
            case .npm: return "NPM"
            case .docker: return "Docker"
            case .custom: return "Custom"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        label: String,
        command: String,
        position: Int,
        icon: String? = nil,
        color: String? = nil,
        category: Category,
        usage: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.label = label
        self.command = command
        self.position = position
        self.icon = icon
        self.color = color
        self.category = category
        self.usage = usage
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if the label is within the maximum allowed length
    public var isValidLabel: Bool {
        return label.count <= Self.maxLabelLength
    }
    
    /// Returns true if the command is not empty
    public var isValidCommand: Bool {
        return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Mutating Methods
    
    /// Increments the usage counter
    public mutating func incrementUsage() {
        usage += 1
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: CommandShortcut, rhs: CommandShortcut) -> Bool {
        return lhs.id == rhs.id
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Mock Helpers
    
    public static func mock() -> CommandShortcut {
        return CommandShortcut(
            id: "mock-shortcut-id",
            label: "ls -la",
            command: "ls -la",
            position: 0,
            icon: "folder",
            color: "#007AFF",
            category: .default,
            usage: 0,
            createdAt: Date(timeIntervalSince1970: 1609459200)
        )
    }
    
    public static func mockGitStatus() -> CommandShortcut {
        return CommandShortcut(
            id: "mock-git-status-id",
            label: "git status",
            command: "git status",
            position: 1,
            icon: "externaldrive.badge.plus",
            color: "#FF6B35",
            category: .git,
            usage: 0,
            createdAt: Date(timeIntervalSince1970: 1609459200)
        )
    }
    
    // MARK: - Default Shortcuts
    
    public static func defaultShortcuts() -> [CommandShortcut] {
        let baseDate = Date(timeIntervalSince1970: 1609459200)
        
        return [
            CommandShortcut(
                id: "default-ls",
                label: "ls -la",
                command: "ls -la",
                position: 0,
                icon: "folder",
                color: "#007AFF",
                category: .default,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "default-pwd",
                label: "pwd",
                command: "pwd",
                position: 1,
                icon: "location",
                color: "#34C759",
                category: .default,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "default-clear",
                label: "clear",
                command: "clear",
                position: 2,
                icon: "trash",
                color: "#FF3B30",
                category: .default,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "default-cd-up",
                label: "cd ..",
                command: "cd ..",
                position: 3,
                icon: "arrow.up",
                color: "#FF9500",
                category: .default,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "git-status",
                label: "git status",
                command: "git status",
                position: 4,
                icon: "externaldrive.badge.plus",
                color: "#FF6B35",
                category: .git,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "npm-run",
                label: "npm run",
                command: "npm run",
                position: 5,
                icon: "shippingbox",
                color: "#AF52DE",
                category: .npm,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "docker-ps",
                label: "docker ps",
                command: "docker ps",
                position: 6,
                icon: "cube.box",
                color: "#0099DD",
                category: .docker,
                usage: 0,
                createdAt: baseDate
            ),
            CommandShortcut(
                id: "code-current",
                label: "code .",
                command: "code .",
                position: 7,
                icon: "curlybraces",
                color: "#5AC8FA",
                category: .default,
                usage: 0,
                createdAt: baseDate
            )
        ]
    }
}