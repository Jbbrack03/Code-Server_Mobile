import XCTest
@testable import MobileTerminal

final class CommandShortcutTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testCommandShortcutInitialization() {
        // Given
        let id = "test-shortcut-id"
        let label = "List Files"
        let command = "ls -la"
        let position = 0
        let icon = "folder"
        let color = "#FF0000"
        let category = CommandShortcut.Category.default
        let usage = 5
        let createdAt = Date()
        
        // When
        let shortcut = CommandShortcut(
            id: id,
            label: label,
            command: command,
            position: position,
            icon: icon,
            color: color,
            category: category,
            usage: usage,
            createdAt: createdAt
        )
        
        // Then
        XCTAssertEqual(shortcut.id, id)
        XCTAssertEqual(shortcut.label, label)
        XCTAssertEqual(shortcut.command, command)
        XCTAssertEqual(shortcut.position, position)
        XCTAssertEqual(shortcut.icon, icon)
        XCTAssertEqual(shortcut.color, color)
        XCTAssertEqual(shortcut.category, category)
        XCTAssertEqual(shortcut.usage, usage)
        XCTAssertEqual(shortcut.createdAt, createdAt)
    }
    
    func testCommandShortcutInitializationWithOptionals() {
        // Given
        let id = "test-shortcut-id"
        let label = "Clear Screen"
        let command = "clear"
        let position = 1
        let category = CommandShortcut.Category.default
        let usage = 0
        let createdAt = Date()
        
        // When
        let shortcut = CommandShortcut(
            id: id,
            label: label,
            command: command,
            position: position,
            icon: nil,
            color: nil,
            category: category,
            usage: usage,
            createdAt: createdAt
        )
        
        // Then
        XCTAssertEqual(shortcut.id, id)
        XCTAssertEqual(shortcut.label, label)
        XCTAssertEqual(shortcut.command, command)
        XCTAssertEqual(shortcut.position, position)
        XCTAssertNil(shortcut.icon)
        XCTAssertNil(shortcut.color)
        XCTAssertEqual(shortcut.category, category)
        XCTAssertEqual(shortcut.usage, usage)
        XCTAssertEqual(shortcut.createdAt, createdAt)
    }
    
    // MARK: - Category Tests
    
    func testCategoryAllCases() {
        // Given
        let expectedCategories: [CommandShortcut.Category] = [
            .default, .git, .npm, .docker, .custom
        ]
        
        // When
        let allCases = CommandShortcut.Category.allCases
        
        // Then
        XCTAssertEqual(allCases.count, expectedCategories.count)
        for category in expectedCategories {
            XCTAssertTrue(allCases.contains(category))
        }
    }
    
    func testCategoryRawValues() {
        // Given & When & Then
        XCTAssertEqual(CommandShortcut.Category.default.rawValue, "default")
        XCTAssertEqual(CommandShortcut.Category.git.rawValue, "git")
        XCTAssertEqual(CommandShortcut.Category.npm.rawValue, "npm")
        XCTAssertEqual(CommandShortcut.Category.docker.rawValue, "docker")
        XCTAssertEqual(CommandShortcut.Category.custom.rawValue, "custom")
    }
    
    func testCategoryDisplayNames() {
        // Given & When & Then
        XCTAssertEqual(CommandShortcut.Category.default.displayName, "Default")
        XCTAssertEqual(CommandShortcut.Category.git.displayName, "Git")
        XCTAssertEqual(CommandShortcut.Category.npm.displayName, "NPM")
        XCTAssertEqual(CommandShortcut.Category.docker.displayName, "Docker")
        XCTAssertEqual(CommandShortcut.Category.custom.displayName, "Custom")
    }
    
    // MARK: - Codable Tests
    
    func testCommandShortcutCodable() throws {
        // Given
        let shortcut = CommandShortcut(
            id: "test-id",
            label: "Test Command",
            command: "test --verbose",
            position: 2,
            icon: "terminal",
            color: "#00FF00",
            category: .custom,
            usage: 10,
            createdAt: Date(timeIntervalSince1970: 1609459200)
        )
        
        // When
        let encoded = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(CommandShortcut.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.id, shortcut.id)
        XCTAssertEqual(decoded.label, shortcut.label)
        XCTAssertEqual(decoded.command, shortcut.command)
        XCTAssertEqual(decoded.position, shortcut.position)
        XCTAssertEqual(decoded.icon, shortcut.icon)
        XCTAssertEqual(decoded.color, shortcut.color)
        XCTAssertEqual(decoded.category, shortcut.category)
        XCTAssertEqual(decoded.usage, shortcut.usage)
        XCTAssertEqual(decoded.createdAt, shortcut.createdAt)
    }
    
    func testCommandShortcutCodableWithOptionals() throws {
        // Given
        let shortcut = CommandShortcut(
            id: "test-id",
            label: "Test Command",
            command: "test",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date(timeIntervalSince1970: 1609459200)
        )
        
        // When
        let encoded = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(CommandShortcut.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.id, shortcut.id)
        XCTAssertEqual(decoded.label, shortcut.label)
        XCTAssertEqual(decoded.command, shortcut.command)
        XCTAssertEqual(decoded.position, shortcut.position)
        XCTAssertNil(decoded.icon)
        XCTAssertNil(decoded.color)
        XCTAssertEqual(decoded.category, shortcut.category)
        XCTAssertEqual(decoded.usage, shortcut.usage)
        XCTAssertEqual(decoded.createdAt, shortcut.createdAt)
    }
    
    // MARK: - Identifiable Tests
    
    func testCommandShortcutIdentifiable() {
        // Given
        let shortcut1 = CommandShortcut(
            id: "shortcut-1",
            label: "Shortcut 1",
            command: "command1",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        let shortcut2 = CommandShortcut(
            id: "shortcut-2",
            label: "Shortcut 2",
            command: "command2",
            position: 1,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        // When & Then
        XCTAssertEqual(shortcut1.id, "shortcut-1")
        XCTAssertEqual(shortcut2.id, "shortcut-2")
        XCTAssertNotEqual(shortcut1.id, shortcut2.id)
    }
    
    // MARK: - Equatable Tests
    
    func testCommandShortcutEquatable() {
        // Given
        let date1 = Date()
        let date2 = Date()
        
        let shortcut1 = CommandShortcut(
            id: "same-id",
            label: "Shortcut 1",
            command: "command1",
            position: 0,
            icon: "icon1",
            color: "#FF0000",
            category: .default,
            usage: 5,
            createdAt: date1
        )
        
        let shortcut2 = CommandShortcut(
            id: "same-id",
            label: "Shortcut 2",
            command: "command2",
            position: 1,
            icon: "icon2",
            color: "#00FF00",
            category: .git,
            usage: 10,
            createdAt: date2
        )
        
        let shortcut3 = CommandShortcut(
            id: "different-id",
            label: "Shortcut 1",
            command: "command1",
            position: 0,
            icon: "icon1",
            color: "#FF0000",
            category: .default,
            usage: 5,
            createdAt: date1
        )
        
        // When & Then
        XCTAssertEqual(shortcut1, shortcut2) // Same ID
        XCTAssertNotEqual(shortcut1, shortcut3) // Different ID
    }
    
    // MARK: - Hashable Tests
    
    func testCommandShortcutHashable() {
        // Given
        let shortcut1 = CommandShortcut(
            id: "test-id",
            label: "Shortcut 1",
            command: "command1",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        let shortcut2 = CommandShortcut(
            id: "test-id",
            label: "Shortcut 2",
            command: "command2",
            position: 1,
            icon: "icon",
            color: "#FF0000",
            category: .git,
            usage: 10,
            createdAt: Date()
        )
        
        // When
        let set: Set<CommandShortcut> = [shortcut1, shortcut2]
        
        // Then
        XCTAssertEqual(set.count, 1) // Same ID means same hash
        XCTAssertEqual(shortcut1.hashValue, shortcut2.hashValue)
    }
    
    // MARK: - Mock Helper Tests
    
    func testMockCommandShortcut() {
        // Given & When
        let mockShortcut = CommandShortcut.mock()
        
        // Then
        XCTAssertEqual(mockShortcut.id, "mock-shortcut-id")
        XCTAssertEqual(mockShortcut.label, "ls -la")
        XCTAssertEqual(mockShortcut.command, "ls -la")
        XCTAssertEqual(mockShortcut.position, 0)
        XCTAssertEqual(mockShortcut.icon, "folder")
        XCTAssertEqual(mockShortcut.color, "#007AFF")
        XCTAssertEqual(mockShortcut.category, .default)
        XCTAssertEqual(mockShortcut.usage, 0)
    }
    
    func testMockGitShortcut() {
        // Given & When
        let mockShortcut = CommandShortcut.mockGitStatus()
        
        // Then
        XCTAssertEqual(mockShortcut.id, "mock-git-status-id")
        XCTAssertEqual(mockShortcut.label, "git status")
        XCTAssertEqual(mockShortcut.command, "git status")
        XCTAssertEqual(mockShortcut.position, 1)
        XCTAssertEqual(mockShortcut.icon, "externaldrive.badge.plus")
        XCTAssertEqual(mockShortcut.color, "#FF6B35")
        XCTAssertEqual(mockShortcut.category, .git)
        XCTAssertEqual(mockShortcut.usage, 0)
    }
    
    // MARK: - Utility Tests
    
    func testIncrementUsage() {
        // Given
        var shortcut = CommandShortcut.mock()
        let initialUsage = shortcut.usage
        
        // When
        shortcut.incrementUsage()
        
        // Then
        XCTAssertEqual(shortcut.usage, initialUsage + 1)
    }
    
    func testIsValidLabel() {
        // Given
        let validShortcut = CommandShortcut(
            id: "valid-id",
            label: "Valid Label",
            command: "valid-command",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        let invalidShortcut = CommandShortcut(
            id: "invalid-id",
            label: "This is a very long label that exceeds the maximum allowed length",
            command: "command",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        // When & Then
        XCTAssertTrue(validShortcut.isValidLabel)
        XCTAssertFalse(invalidShortcut.isValidLabel)
    }
    
    func testIsValidCommand() {
        // Given
        let validShortcut = CommandShortcut(
            id: "valid-id",
            label: "Valid",
            command: "ls -la",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        let invalidShortcut = CommandShortcut(
            id: "invalid-id",
            label: "Invalid",
            command: "",
            position: 0,
            icon: nil,
            color: nil,
            category: .default,
            usage: 0,
            createdAt: Date()
        )
        
        // When & Then
        XCTAssertTrue(validShortcut.isValidCommand)
        XCTAssertFalse(invalidShortcut.isValidCommand)
    }
    
    func testDefaultShortcuts() {
        // Given & When
        let defaultShortcuts = CommandShortcut.defaultShortcuts()
        
        // Then
        XCTAssertEqual(defaultShortcuts.count, 8)
        XCTAssertEqual(defaultShortcuts[0].label, "ls -la")
        XCTAssertEqual(defaultShortcuts[1].label, "pwd")
        XCTAssertEqual(defaultShortcuts[2].label, "clear")
        XCTAssertEqual(defaultShortcuts[3].label, "cd ..")
        XCTAssertEqual(defaultShortcuts[4].label, "git status")
        XCTAssertEqual(defaultShortcuts[5].label, "npm run")
        XCTAssertEqual(defaultShortcuts[6].label, "docker ps")
        XCTAssertEqual(defaultShortcuts[7].label, "code .")
        
        // Verify positions are set correctly
        for (index, shortcut) in defaultShortcuts.enumerated() {
            XCTAssertEqual(shortcut.position, index)
        }
    }
}