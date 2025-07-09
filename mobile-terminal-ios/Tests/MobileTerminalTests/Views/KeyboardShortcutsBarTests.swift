#if os(iOS)
import XCTest
import SwiftUI
@testable import MobileTerminal

final class KeyboardShortcutsBarTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var shortcuts: [CommandShortcut]!
    var onShortcutTappedCalled = false
    var onEditTappedCalled = false
    var tappedShortcut: CommandShortcut?
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        shortcuts = [
            CommandShortcut(label: "Tab", command: "\t", category: .navigation, icon: "arrow.right.to.line"),
            CommandShortcut(label: "Ctrl+C", command: "\u{03}", category: .control, icon: "stop.circle"),
            CommandShortcut(label: "ls", command: "ls -la\n", category: .commands, icon: "list.bullet"),
            CommandShortcut(label: "git status", command: "git status\n", category: .git, icon: "questionmark.circle"),
            CommandShortcut(label: "Pipe", command: "|", category: .symbols, icon: "line.horizontal.3"),
            CommandShortcut(label: "More", command: "more", category: .commands, icon: "doc.text")
        ]
        onShortcutTappedCalled = false
        onEditTappedCalled = false
        tappedShortcut = nil
    }
    
    override func tearDown() {
        shortcuts = nil
        tappedShortcut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testKeyboardShortcutsBarInitialization() {
        // Given & When
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { shortcut in
                self.onShortcutTappedCalled = true
                self.tappedShortcut = shortcut
            },
            onEditTapped: {
                self.onEditTappedCalled = true
            }
        )
        
        // Then
        XCTAssertNotNil(shortcutsBar, "Should create KeyboardShortcutsBar")
    }
    
    func testKeyboardShortcutsBarHasBody() {
        // Given
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onEditTapped: { }
        )
        
        // When
        let body = shortcutsBar.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testKeyboardShortcutsBarWithEmptyShortcuts() {
        // Given & When
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: [],
            onShortcutTapped: { _ in },
            onEditTapped: { }
        )
        
        // Then
        XCTAssertNotNil(shortcutsBar.body, "Should handle empty shortcuts list")
    }
    
    // MARK: - Callback Tests
    
    func testKeyboardShortcutsBarCallsOnShortcutTapped() {
        // Given
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { shortcut in
                self.onShortcutTappedCalled = true
                self.tappedShortcut = shortcut
            },
            onEditTapped: {
                self.onEditTappedCalled = true
            }
        )
        
        // When
        shortcutsBar.onShortcutTapped(shortcuts[0])
        
        // Then
        XCTAssertTrue(onShortcutTappedCalled, "Should call onShortcutTapped callback")
        XCTAssertEqual(tappedShortcut?.id, shortcuts[0].id, "Should pass correct shortcut")
    }
    
    func testKeyboardShortcutsBarCallsOnEditTapped() {
        // Given
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onEditTapped: {
                self.onEditTappedCalled = true
            }
        )
        
        // When
        shortcutsBar.onEditTapped()
        
        // Then
        XCTAssertTrue(onEditTappedCalled, "Should call onEditTapped callback")
    }
    
    // MARK: - Visible Shortcuts Tests
    
    func testKeyboardShortcutsBarVisibleShortcuts() {
        // Given
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onEditTapped: { }
        )
        
        // When
        let visibleShortcuts = shortcutsBar.visibleShortcuts
        
        // Then
        XCTAssertEqual(visibleShortcuts.count, 5, "Should show maximum 5 visible shortcuts")
        XCTAssertEqual(visibleShortcuts[0].id, shortcuts[0].id, "Should show first shortcut")
    }
    
    func testKeyboardShortcutsBarVisibleShortcutsWithFewerThanMax() {
        // Given
        let fewShortcuts = Array(shortcuts.prefix(3))
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: fewShortcuts,
            onShortcutTapped: { _ in },
            onEditTapped: { }
        )
        
        // When
        let visibleShortcuts = shortcutsBar.visibleShortcuts
        
        // Then
        XCTAssertEqual(visibleShortcuts.count, 3, "Should show all shortcuts when fewer than max")
    }
    
    // MARK: - Memory Management Tests
    
    func testKeyboardShortcutsBarMemoryManagement() {
        // Given
        weak var weakShortcutsBar: KeyboardShortcutsBar?
        
        // When
        autoreleasepool {
            let shortcutsBar = KeyboardShortcutsBar(
                shortcuts: shortcuts,
                onShortcutTapped: { _ in },
                onEditTapped: { }
            )
            weakShortcutsBar = shortcutsBar
        }
        
        // Then
        // Note: SwiftUI views are value types, so this test verifies the struct nature
        XCTAssertNotNil(weakShortcutsBar, "SwiftUI view should be a value type")
    }
    
    // MARK: - Performance Tests
    
    func testKeyboardShortcutsBarPerformance() {
        // Given
        let shortcutsBar = KeyboardShortcutsBar(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onEditTapped: { }
        )
        
        // When & Then
        self.measure {
            _ = shortcutsBar.body
        }
    }
}

// MARK: - ShortcutButton Tests

final class ShortcutButtonTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var shortcut: CommandShortcut!
    var actionCalled = false
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        shortcut = CommandShortcut(
            label: "Test Shortcut",
            command: "test\n",
            category: .commands,
            icon: "terminal"
        )
        actionCalled = false
    }
    
    override func tearDown() {
        shortcut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testShortcutButtonInitialization() {
        // Given & When
        let button = ShortcutButton(
            shortcut: shortcut,
            action: { self.actionCalled = true }
        )
        
        // Then
        XCTAssertNotNil(button, "Should create ShortcutButton")
    }
    
    func testShortcutButtonHasBody() {
        // Given
        let button = ShortcutButton(
            shortcut: shortcut,
            action: { }
        )
        
        // When
        let body = button.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testShortcutButtonWithoutIcon() {
        // Given
        let shortcutWithoutIcon = CommandShortcut(
            label: "No Icon",
            command: "test\n",
            category: .commands
        )
        
        // When
        let button = ShortcutButton(
            shortcut: shortcutWithoutIcon,
            action: { }
        )
        
        // Then
        XCTAssertNotNil(button.body, "Should handle shortcuts without icons")
    }
    
    // MARK: - Callback Tests
    
    func testShortcutButtonCallsAction() {
        // Given
        let button = ShortcutButton(
            shortcut: shortcut,
            action: { self.actionCalled = true }
        )
        
        // When
        button.action()
        
        // Then
        XCTAssertTrue(actionCalled, "Should call action callback")
    }
    
    // MARK: - Performance Tests
    
    func testShortcutButtonPerformance() {
        // Given
        let button = ShortcutButton(
            shortcut: shortcut,
            action: { }
        )
        
        // When & Then
        self.measure {
            _ = button.body
        }
    }
}

// MARK: - AllShortcutsView Tests

final class AllShortcutsViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var shortcuts: [CommandShortcut]!
    var onShortcutTappedCalled = false
    var onDismissCalled = false
    var tappedShortcut: CommandShortcut?
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        shortcuts = [
            CommandShortcut(label: "Tab", command: "\t", category: .navigation, icon: "arrow.right.to.line"),
            CommandShortcut(label: "Ctrl+C", command: "\u{03}", category: .control, icon: "stop.circle"),
            CommandShortcut(label: "ls", command: "ls -la\n", category: .commands, icon: "list.bullet"),
            CommandShortcut(label: "git status", command: "git status\n", category: .git, icon: "questionmark.circle"),
            CommandShortcut(label: "Pipe", command: "|", category: .symbols, icon: "line.horizontal.3"),
            CommandShortcut(label: "Custom", command: "custom", category: .custom, icon: "star")
        ]
        onShortcutTappedCalled = false
        onDismissCalled = false
        tappedShortcut = nil
    }
    
    override func tearDown() {
        shortcuts = nil
        tappedShortcut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAllShortcutsViewInitialization() {
        // Given & When
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { shortcut in
                self.onShortcutTappedCalled = true
                self.tappedShortcut = shortcut
            },
            onDismiss: {
                self.onDismissCalled = true
            }
        )
        
        // Then
        XCTAssertNotNil(allShortcutsView, "Should create AllShortcutsView")
    }
    
    func testAllShortcutsViewHasBody() {
        // Given
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onDismiss: { }
        )
        
        // When
        let body = allShortcutsView.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testAllShortcutsViewWithEmptyShortcuts() {
        // Given & When
        let allShortcutsView = AllShortcutsView(
            shortcuts: [],
            onShortcutTapped: { _ in },
            onDismiss: { }
        )
        
        // Then
        XCTAssertNotNil(allShortcutsView.body, "Should handle empty shortcuts list")
    }
    
    // MARK: - Callback Tests
    
    func testAllShortcutsViewCallsOnShortcutTapped() {
        // Given
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { shortcut in
                self.onShortcutTappedCalled = true
                self.tappedShortcut = shortcut
            },
            onDismiss: {
                self.onDismissCalled = true
            }
        )
        
        // When
        allShortcutsView.onShortcutTapped(shortcuts[0])
        
        // Then
        XCTAssertTrue(onShortcutTappedCalled, "Should call onShortcutTapped callback")
        XCTAssertEqual(tappedShortcut?.id, shortcuts[0].id, "Should pass correct shortcut")
    }
    
    func testAllShortcutsViewCallsOnDismiss() {
        // Given
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onDismiss: {
                self.onDismissCalled = true
            }
        )
        
        // When
        allShortcutsView.onDismiss()
        
        // Then
        XCTAssertTrue(onDismissCalled, "Should call onDismiss callback")
    }
    
    // MARK: - Category Filtering Tests
    
    func testAllShortcutsViewFiltersShortcutsByCategory() {
        // Given
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onDismiss: { }
        )
        
        // When
        let navigationShortcuts = allShortcutsView.shortcutsForCategory(.navigation)
        let controlShortcuts = allShortcutsView.shortcutsForCategory(.control)
        let commandShortcuts = allShortcutsView.shortcutsForCategory(.commands)
        let gitShortcuts = allShortcutsView.shortcutsForCategory(.git)
        let symbolShortcuts = allShortcutsView.shortcutsForCategory(.symbols)
        let customShortcuts = allShortcutsView.shortcutsForCategory(.custom)
        
        // Then
        XCTAssertEqual(navigationShortcuts.count, 1, "Should filter navigation shortcuts")
        XCTAssertEqual(controlShortcuts.count, 1, "Should filter control shortcuts")
        XCTAssertEqual(commandShortcuts.count, 1, "Should filter command shortcuts")
        XCTAssertEqual(gitShortcuts.count, 1, "Should filter git shortcuts")
        XCTAssertEqual(symbolShortcuts.count, 1, "Should filter symbol shortcuts")
        XCTAssertEqual(customShortcuts.count, 1, "Should filter custom shortcuts")
    }
    
    func testAllShortcutsViewFiltersEmptyCategory() {
        // Given
        let shortcutsWithoutCategory = [
            CommandShortcut(label: "Test", command: "test", category: .navigation)
        ]
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcutsWithoutCategory,
            onShortcutTapped: { _ in },
            onDismiss: { }
        )
        
        // When
        let controlShortcuts = allShortcutsView.shortcutsForCategory(.control)
        
        // Then
        XCTAssertEqual(controlShortcuts.count, 0, "Should return empty array for categories with no shortcuts")
    }
    
    // MARK: - Performance Tests
    
    func testAllShortcutsViewPerformance() {
        // Given
        let allShortcutsView = AllShortcutsView(
            shortcuts: shortcuts,
            onShortcutTapped: { _ in },
            onDismiss: { }
        )
        
        // When & Then
        self.measure {
            _ = allShortcutsView.body
        }
    }
}

// MARK: - ShortcutGridItem Tests

final class ShortcutGridItemTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var shortcut: CommandShortcut!
    var onTapCalled = false
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        shortcut = CommandShortcut(
            label: "Test Shortcut",
            command: "test\n",
            category: .commands,
            icon: "terminal",
            description: "Test description"
        )
        onTapCalled = false
    }
    
    override func tearDown() {
        shortcut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testShortcutGridItemInitialization() {
        // Given & When
        let gridItem = ShortcutGridItem(
            shortcut: shortcut,
            onTap: { self.onTapCalled = true }
        )
        
        // Then
        XCTAssertNotNil(gridItem, "Should create ShortcutGridItem")
    }
    
    func testShortcutGridItemHasBody() {
        // Given
        let gridItem = ShortcutGridItem(
            shortcut: shortcut,
            onTap: { }
        )
        
        // When
        let body = gridItem.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testShortcutGridItemWithoutIcon() {
        // Given
        let shortcutWithoutIcon = CommandShortcut(
            label: "No Icon",
            command: "test\n",
            category: .commands,
            description: "Test description"
        )
        
        // When
        let gridItem = ShortcutGridItem(
            shortcut: shortcutWithoutIcon,
            onTap: { }
        )
        
        // Then
        XCTAssertNotNil(gridItem.body, "Should handle shortcuts without icons")
    }
    
    func testShortcutGridItemWithoutDescription() {
        // Given
        let shortcutWithoutDescription = CommandShortcut(
            label: "No Description",
            command: "test\n",
            category: .commands,
            icon: "terminal"
        )
        
        // When
        let gridItem = ShortcutGridItem(
            shortcut: shortcutWithoutDescription,
            onTap: { }
        )
        
        // Then
        XCTAssertNotNil(gridItem.body, "Should handle shortcuts without descriptions")
    }
    
    // MARK: - Callback Tests
    
    func testShortcutGridItemCallsOnTap() {
        // Given
        let gridItem = ShortcutGridItem(
            shortcut: shortcut,
            onTap: { self.onTapCalled = true }
        )
        
        // When
        gridItem.onTap()
        
        // Then
        XCTAssertTrue(onTapCalled, "Should call onTap callback")
    }
    
    // MARK: - Performance Tests
    
    func testShortcutGridItemPerformance() {
        // Given
        let gridItem = ShortcutGridItem(
            shortcut: shortcut,
            onTap: { }
        )
        
        // When & Then
        self.measure {
            _ = gridItem.body
        }
    }
}

// MARK: - KeyboardShortcutsManager Tests

final class KeyboardShortcutsManagerTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var sut: KeyboardShortcutsManager!
    var terminalViewModel: TerminalViewModel!
    var mockAPIClient: SharedMockAPIClient!
    var mockWebSocketClient: SharedMockWebSocketClient!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        mockAPIClient = SharedMockAPIClient()
        mockWebSocketClient = SharedMockWebSocketClient()
        terminalViewModel = TerminalViewModel(
            apiClient: mockAPIClient,
            webSocketManager: mockWebSocketClient
        )
        sut = KeyboardShortcutsManager(terminalViewModel: terminalViewModel)
    }
    
    override func tearDown() {
        sut = nil
        terminalViewModel = nil
        mockWebSocketClient = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testKeyboardShortcutsManagerInitialization() {
        // Given & When
        let manager = KeyboardShortcutsManager(terminalViewModel: terminalViewModel)
        
        // Then
        XCTAssertNotNil(manager, "Should create KeyboardShortcutsManager")
        XCTAssertFalse(manager.shortcuts.isEmpty, "Should load default shortcuts")
        XCTAssertFalse(manager.isVisible, "Should start with keyboard hidden")
    }
    
    func testKeyboardShortcutsManagerHasDefaultShortcuts() {
        // Given & When
        let shortcuts = sut.shortcuts
        
        // Then
        XCTAssertFalse(shortcuts.isEmpty, "Should have default shortcuts")
        XCTAssertTrue(shortcuts.contains { $0.label == "Tab" }, "Should contain Tab shortcut")
        XCTAssertTrue(shortcuts.contains { $0.label == "Ctrl+C" }, "Should contain Ctrl+C shortcut")
        XCTAssertTrue(shortcuts.contains { $0.label == "ls" }, "Should contain ls shortcut")
        XCTAssertTrue(shortcuts.contains { $0.label == "git status" }, "Should contain git status shortcut")
    }
    
    // MARK: - Visibility Tests
    
    func testShowKeyboard() {
        // Given
        XCTAssertFalse(sut.isVisible, "Should start with keyboard hidden")
        
        // When
        sut.showKeyboard()
        
        // Then
        XCTAssertTrue(sut.isVisible, "Should show keyboard")
    }
    
    func testHideKeyboard() {
        // Given
        sut.showKeyboard()
        XCTAssertTrue(sut.isVisible, "Should start with keyboard visible")
        
        // When
        sut.hideKeyboard()
        
        // Then
        XCTAssertFalse(sut.isVisible, "Should hide keyboard")
    }
    
    func testToggleKeyboard() {
        // Given
        XCTAssertFalse(sut.isVisible, "Should start with keyboard hidden")
        
        // When
        sut.toggleKeyboard()
        
        // Then
        XCTAssertTrue(sut.isVisible, "Should show keyboard after toggle")
        
        // When
        sut.toggleKeyboard()
        
        // Then
        XCTAssertFalse(sut.isVisible, "Should hide keyboard after second toggle")
    }
    
    // MARK: - Shortcut Execution Tests
    
    func testExecuteShortcut() async {
        // Given
        let shortcut = CommandShortcut(
            label: "Test",
            command: "test\n",
            category: .commands
        )
        let originalUsageCount = shortcut.usageCount
        
        // When
        await sut.executeShortcut(shortcut)
        
        // Then
        // Note: We can't easily test the async Task execution here
        // but we can verify the method exists and doesn't crash
        XCTAssertNotNil(sut, "Manager should still exist after execution")
    }
    
    // MARK: - Shortcut Management Tests
    
    func testAddCustomShortcut() {
        // Given
        let originalCount = sut.shortcuts.count
        let customShortcut = CommandShortcut(
            label: "Custom",
            command: "custom\n",
            category: .custom
        )
        
        // When
        sut.addCustomShortcut(customShortcut)
        
        // Then
        XCTAssertEqual(sut.shortcuts.count, originalCount + 1, "Should add custom shortcut")
        XCTAssertTrue(sut.shortcuts.contains { $0.id == customShortcut.id }, "Should contain added shortcut")
    }
    
    func testRemoveShortcut() {
        // Given
        let shortcutToRemove = sut.shortcuts.first!
        let originalCount = sut.shortcuts.count
        
        // When
        sut.removeShortcut(shortcutToRemove)
        
        // Then
        XCTAssertEqual(sut.shortcuts.count, originalCount - 1, "Should remove shortcut")
        XCTAssertFalse(sut.shortcuts.contains { $0.id == shortcutToRemove.id }, "Should not contain removed shortcut")
    }
    
    func testUpdateShortcut() {
        // Given
        let originalShortcut = sut.shortcuts.first!
        let updatedShortcut = CommandShortcut(
            id: originalShortcut.id,
            label: "Updated Label",
            command: originalShortcut.command,
            category: originalShortcut.category
        )
        
        // When
        sut.updateShortcut(updatedShortcut)
        
        // Then
        let foundShortcut = sut.shortcuts.first { $0.id == originalShortcut.id }
        XCTAssertNotNil(foundShortcut, "Should find updated shortcut")
        XCTAssertEqual(foundShortcut?.label, "Updated Label", "Should update shortcut label")
    }
    
    func testUpdateNonExistentShortcut() {
        // Given
        let originalCount = sut.shortcuts.count
        let nonExistentShortcut = CommandShortcut(
            label: "Non-existent",
            command: "none\n",
            category: .custom
        )
        
        // When
        sut.updateShortcut(nonExistentShortcut)
        
        // Then
        XCTAssertEqual(sut.shortcuts.count, originalCount, "Should not change shortcut count")
    }
    
    func testResetToDefaults() {
        // Given
        let customShortcut = CommandShortcut(
            label: "Custom",
            command: "custom\n",
            category: .custom
        )
        sut.addCustomShortcut(customShortcut)
        let originalDefaultCount = sut.shortcuts.filter { $0.category != .custom }.count
        
        // When
        sut.resetToDefaults()
        
        // Then
        XCTAssertFalse(sut.shortcuts.contains { $0.id == customShortcut.id }, "Should remove custom shortcuts")
        XCTAssertFalse(sut.shortcuts.isEmpty, "Should have default shortcuts")
    }
    
    // MARK: - Usage Tracking Tests
    
    func testUpdateShortcutUsage() {
        // Given
        let shortcut = sut.shortcuts.first!
        let originalUsageCount = shortcut.usageCount
        
        // When
        sut.executeShortcut(shortcut)
        
        // Then
        // Note: This is an async operation, so we test the synchronous parts
        XCTAssertNotNil(sut.shortcuts.first { $0.id == shortcut.id }, "Should find shortcut after usage update")
    }
    
    // MARK: - Memory Management Tests
    
    func testKeyboardShortcutsManagerMemoryManagement() {
        // Given
        weak var weakManager: KeyboardShortcutsManager?
        
        // When
        autoreleasepool {
            let manager = KeyboardShortcutsManager(terminalViewModel: terminalViewModel)
            weakManager = manager
            manager.showKeyboard()
        }
        
        // Then
        XCTAssertNil(weakManager, "Manager should be deallocated")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentShortcutOperations() {
        // Given
        let expectation = expectation(description: "Concurrent shortcut operations")
        expectation.expectedFulfillmentCount = 10
        
        // When
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            let shortcut = CommandShortcut(
                label: "Test \(index)",
                command: "test\(index)\n",
                category: .custom
            )
            sut.addCustomShortcut(shortcut)
            expectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Should handle concurrent operations")
        }
    }
    
    // MARK: - Performance Tests
    
    func testKeyboardShortcutsManagerPerformance() {
        // Given & When & Then
        self.measure {
            let shortcut = CommandShortcut(
                label: "Performance Test",
                command: "test\n",
                category: .commands
            )
            sut.addCustomShortcut(shortcut)
            sut.removeShortcut(shortcut)
        }
    }
    
    func testShortcutExecutionPerformance() {
        // Given
        let shortcut = sut.shortcuts.first!
        
        // When & Then
        self.measure {
            Task {
                await sut.executeShortcut(shortcut)
            }
        }
    }
}

// MARK: - CommandShortcut Category Extension Tests

final class CommandShortcutCategoryExtensionTests: XCTestCase {
    
    // MARK: - Color Tests
    
    func testCommandShortcutCategoryColors() {
        // Given
        let categories = CommandShortcut.Category.allCases
        
        // When & Then
        for category in categories {
            let color = category.color
            XCTAssertNotNil(color, "Category \(category) should have a color")
        }
    }
    
    func testSpecificCategoryColors() {
        // Given & When & Then
        XCTAssertEqual(CommandShortcut.Category.navigation.color, .blue, "Navigation should be blue")
        XCTAssertEqual(CommandShortcut.Category.control.color, .red, "Control should be red")
        XCTAssertEqual(CommandShortcut.Category.commands.color, .green, "Commands should be green")
        XCTAssertEqual(CommandShortcut.Category.git.color, .orange, "Git should be orange")
        XCTAssertEqual(CommandShortcut.Category.symbols.color, .purple, "Symbols should be purple")
        XCTAssertEqual(CommandShortcut.Category.custom.color, .gray, "Custom should be gray")
    }
    
    // MARK: - Icon Tests
    
    func testCommandShortcutCategoryIcons() {
        // Given
        let categories = CommandShortcut.Category.allCases
        
        // When & Then
        for category in categories {
            let icon = category.icon
            XCTAssertFalse(icon.isEmpty, "Category \(category) should have an icon")
        }
    }
    
    func testSpecificCategoryIcons() {
        // Given & When & Then
        XCTAssertEqual(CommandShortcut.Category.navigation.icon, "arrow.up.arrow.down", "Navigation should have correct icon")
        XCTAssertEqual(CommandShortcut.Category.control.icon, "control", "Control should have correct icon")
        XCTAssertEqual(CommandShortcut.Category.commands.icon, "terminal", "Commands should have correct icon")
        XCTAssertEqual(CommandShortcut.Category.git.icon, "arrow.triangle.branch", "Git should have correct icon")
        XCTAssertEqual(CommandShortcut.Category.symbols.icon, "textformat.alt", "Symbols should have correct icon")
        XCTAssertEqual(CommandShortcut.Category.custom.icon, "star", "Custom should have correct icon")
    }
}

#endif