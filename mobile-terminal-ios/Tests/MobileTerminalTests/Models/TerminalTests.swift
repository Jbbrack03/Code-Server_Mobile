import XCTest
@testable import MobileTerminal

final class TerminalTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testTerminalInitialization() {
        // Given
        let id = "test-terminal-id"
        let name = "Test Terminal"
        let pid = 12345
        let cwd = "/Users/test/project"
        let shellType = Terminal.ShellType.bash
        let isActive = true
        let isClaudeCode = false
        let createdAt = Date()
        let lastActivity = Date()
        let dimensions = Terminal.Dimensions(cols: 80, rows: 24)
        let status = Terminal.Status.active
        
        // When
        let terminal = Terminal(
            id: id,
            name: name,
            pid: pid,
            cwd: cwd,
            shellType: shellType,
            isActive: isActive,
            isClaudeCode: isClaudeCode,
            createdAt: createdAt,
            lastActivity: lastActivity,
            dimensions: dimensions,
            status: status
        )
        
        // Then
        XCTAssertEqual(terminal.id, id)
        XCTAssertEqual(terminal.name, name)
        XCTAssertEqual(terminal.pid, pid)
        XCTAssertEqual(terminal.cwd, cwd)
        XCTAssertEqual(terminal.shellType, shellType)
        XCTAssertEqual(terminal.isActive, isActive)
        XCTAssertEqual(terminal.isClaudeCode, isClaudeCode)
        XCTAssertEqual(terminal.createdAt, createdAt)
        XCTAssertEqual(terminal.lastActivity, lastActivity)
        XCTAssertEqual(terminal.dimensions.cols, dimensions.cols)
        XCTAssertEqual(terminal.dimensions.rows, dimensions.rows)
        XCTAssertEqual(terminal.status, status)
    }
    
    // MARK: - Shell Type Tests
    
    func testShellTypeAllCases() {
        // Given
        let expectedShellTypes: [Terminal.ShellType] = [.bash, .zsh, .fish, .pwsh, .cmd]
        
        // When
        let allCases = Terminal.ShellType.allCases
        
        // Then
        XCTAssertEqual(allCases.count, expectedShellTypes.count)
        for shellType in expectedShellTypes {
            XCTAssertTrue(allCases.contains(shellType))
        }
    }
    
    func testShellTypeRawValues() {
        // Given & When & Then
        XCTAssertEqual(Terminal.ShellType.bash.rawValue, "bash")
        XCTAssertEqual(Terminal.ShellType.zsh.rawValue, "zsh")
        XCTAssertEqual(Terminal.ShellType.fish.rawValue, "fish")
        XCTAssertEqual(Terminal.ShellType.pwsh.rawValue, "pwsh")
        XCTAssertEqual(Terminal.ShellType.cmd.rawValue, "cmd")
    }
    
    // MARK: - Status Tests
    
    func testStatusAllCases() {
        // Given
        let expectedStatuses: [Terminal.Status] = [.active, .inactive, .crashed]
        
        // When
        let allCases = Terminal.Status.allCases
        
        // Then
        XCTAssertEqual(allCases.count, expectedStatuses.count)
        for status in expectedStatuses {
            XCTAssertTrue(allCases.contains(status))
        }
    }
    
    func testStatusRawValues() {
        // Given & When & Then
        XCTAssertEqual(Terminal.Status.active.rawValue, "active")
        XCTAssertEqual(Terminal.Status.inactive.rawValue, "inactive")
        XCTAssertEqual(Terminal.Status.crashed.rawValue, "crashed")
    }
    
    // MARK: - Dimensions Tests
    
    func testDimensionsInitialization() {
        // Given
        let cols = 120
        let rows = 30
        
        // When
        let dimensions = Terminal.Dimensions(cols: cols, rows: rows)
        
        // Then
        XCTAssertEqual(dimensions.cols, cols)
        XCTAssertEqual(dimensions.rows, rows)
    }
    
    func testDimensionsEquality() {
        // Given
        let dimensions1 = Terminal.Dimensions(cols: 80, rows: 24)
        let dimensions2 = Terminal.Dimensions(cols: 80, rows: 24)
        let dimensions3 = Terminal.Dimensions(cols: 100, rows: 30)
        
        // When & Then
        XCTAssertEqual(dimensions1, dimensions2)
        XCTAssertNotEqual(dimensions1, dimensions3)
    }
    
    // MARK: - Codable Tests
    
    func testTerminalCodable() throws {
        // Given
        let terminal = Terminal(
            id: "test-id",
            name: "Test Terminal",
            pid: 12345,
            cwd: "/Users/test",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: Date(timeIntervalSince1970: 1609459200), // 2021-01-01
            lastActivity: Date(timeIntervalSince1970: 1609459260), // 2021-01-01 + 1 minute
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        // When
        let encoded = try JSONEncoder().encode(terminal)
        let decoded = try JSONDecoder().decode(Terminal.self, from: encoded)
        
        // Then
        XCTAssertEqual(decoded.id, terminal.id)
        XCTAssertEqual(decoded.name, terminal.name)
        XCTAssertEqual(decoded.pid, terminal.pid)
        XCTAssertEqual(decoded.cwd, terminal.cwd)
        XCTAssertEqual(decoded.shellType, terminal.shellType)
        XCTAssertEqual(decoded.isActive, terminal.isActive)
        XCTAssertEqual(decoded.isClaudeCode, terminal.isClaudeCode)
        XCTAssertEqual(decoded.createdAt, terminal.createdAt)
        XCTAssertEqual(decoded.lastActivity, terminal.lastActivity)
        XCTAssertEqual(decoded.dimensions, terminal.dimensions)
        XCTAssertEqual(decoded.status, terminal.status)
    }
    
    // MARK: - Identifiable Tests
    
    func testTerminalIdentifiable() {
        // Given
        let terminal1 = Terminal(
            id: "terminal-1",
            name: "Terminal 1",
            pid: 1001,
            cwd: "/",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: Date(),
            lastActivity: Date(),
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        let terminal2 = Terminal(
            id: "terminal-2",
            name: "Terminal 2",
            pid: 1002,
            cwd: "/",
            shellType: .bash,
            isActive: false,
            isClaudeCode: false,
            createdAt: Date(),
            lastActivity: Date(),
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        // When & Then
        XCTAssertEqual(terminal1.id, "terminal-1")
        XCTAssertEqual(terminal2.id, "terminal-2")
        XCTAssertNotEqual(terminal1.id, terminal2.id)
    }
    
    // MARK: - Equatable Tests
    
    func testTerminalEquatable() {
        // Given
        let date1 = Date()
        let date2 = Date()
        
        let terminal1 = Terminal(
            id: "same-id",
            name: "Terminal 1",
            pid: 1001,
            cwd: "/",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: date1,
            lastActivity: date1,
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        let terminal2 = Terminal(
            id: "same-id",
            name: "Terminal 2",
            pid: 1002,
            cwd: "/home",
            shellType: .zsh,
            isActive: false,
            isClaudeCode: true,
            createdAt: date2,
            lastActivity: date2,
            dimensions: Terminal.Dimensions(cols: 100, rows: 30),
            status: .inactive
        )
        
        let terminal3 = Terminal(
            id: "different-id",
            name: "Terminal 1",
            pid: 1001,
            cwd: "/",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: date1,
            lastActivity: date1,
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        // When & Then
        XCTAssertEqual(terminal1, terminal2) // Same ID
        XCTAssertNotEqual(terminal1, terminal3) // Different ID
    }
    
    // MARK: - Hashable Tests
    
    func testTerminalHashable() {
        // Given
        let terminal1 = Terminal(
            id: "test-id",
            name: "Terminal 1",
            pid: 1001,
            cwd: "/",
            shellType: .bash,
            isActive: true,
            isClaudeCode: false,
            createdAt: Date(),
            lastActivity: Date(),
            dimensions: Terminal.Dimensions(cols: 80, rows: 24),
            status: .active
        )
        
        let terminal2 = Terminal(
            id: "test-id",
            name: "Terminal 2",
            pid: 1002,
            cwd: "/home",
            shellType: .zsh,
            isActive: false,
            isClaudeCode: true,
            createdAt: Date(),
            lastActivity: Date(),
            dimensions: Terminal.Dimensions(cols: 100, rows: 30),
            status: .inactive
        )
        
        // When
        let set: Set<Terminal> = [terminal1, terminal2]
        
        // Then
        XCTAssertEqual(set.count, 1) // Same ID means same hash
        XCTAssertEqual(terminal1.hashValue, terminal2.hashValue)
    }
    
    // MARK: - Mock Helper Tests
    
    func testMockTerminal() {
        // Given & When
        let mockTerminal = Terminal.mock()
        
        // Then
        XCTAssertEqual(mockTerminal.id, "mock-terminal-id")
        XCTAssertEqual(mockTerminal.name, "Mock Terminal")
        XCTAssertEqual(mockTerminal.pid, 12345)
        XCTAssertEqual(mockTerminal.cwd, "/Users/test/project")
        XCTAssertEqual(mockTerminal.shellType, .bash)
        XCTAssertEqual(mockTerminal.isActive, true)
        XCTAssertEqual(mockTerminal.isClaudeCode, false)
        XCTAssertEqual(mockTerminal.dimensions.cols, 80)
        XCTAssertEqual(mockTerminal.dimensions.rows, 24)
        XCTAssertEqual(mockTerminal.status, .active)
    }
}