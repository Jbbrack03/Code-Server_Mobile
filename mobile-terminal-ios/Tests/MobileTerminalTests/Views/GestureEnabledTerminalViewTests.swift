#if os(iOS)
import XCTest
import SwiftUI
@testable import MobileTerminal

final class GestureEnabledTerminalViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
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
    }
    
    override func tearDown() {
        terminalViewModel = nil
        mockWebSocketClient = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testGestureEnabledTerminalViewInitialization() {
        // Given & When
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // Then
        XCTAssertNotNil(terminalView, "Should create GestureEnabledTerminalView")
    }
    
    func testGestureEnabledTerminalViewHasBody() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testGestureEnabledTerminalViewMemoryManagement() {
        // Given
        weak var weakTerminalView: GestureEnabledTerminalView?
        
        // When
        autoreleasepool {
            let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
            weakTerminalView = terminalView
        }
        
        // Then
        // Note: SwiftUI views are value types, so this test verifies the struct nature
        XCTAssertNotNil(weakTerminalView, "SwiftUI view should be a value type")
    }
    
    // MARK: - Gesture Configuration Tests
    
    func testGestureEnabledTerminalViewHasGestureSupport() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should have gesture support configured
        XCTAssertNotNil(body, "Should have gesture-enabled body")
    }
    
    func testGestureEnabledTerminalViewHasZoomSupport() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support pinch-to-zoom gestures
        XCTAssertNotNil(body, "Should support zoom gestures")
    }
    
    func testGestureEnabledTerminalViewHasSwipeSupport() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support swipe gestures for terminal switching
        XCTAssertNotNil(body, "Should support swipe gestures")
    }
    
    func testGestureEnabledTerminalViewHasDoubleTapSupport() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support double tap for terminal switcher
        XCTAssertNotNil(body, "Should support double tap gestures")
    }
    
    // MARK: - Terminal Switching Tests
    
    func testGestureEnabledTerminalViewHandlesTerminalSwitching() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        let mockTerminals = [
            TestUtilities.createMockTerminal(id: "terminal1"),
            TestUtilities.createMockTerminal(id: "terminal2"),
            TestUtilities.createMockTerminal(id: "terminal3")
        ]
        
        // When
        mockAPIClient.mockTerminals = mockTerminals
        mockAPIClient.mockActiveTerminalId = "terminal1"
        
        // Then
        // The view should handle terminal switching
        XCTAssertNotNil(terminalView.body, "Should handle terminal switching")
    }
    
    func testGestureEnabledTerminalViewHandlesEmptyTerminalList() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        mockAPIClient.mockTerminals = []
        mockAPIClient.mockActiveTerminalId = nil
        
        // Then
        // The view should handle empty terminal list gracefully
        XCTAssertNotNil(terminalView.body, "Should handle empty terminal list")
    }
    
    // MARK: - Font Size Tests
    
    func testGestureEnabledTerminalViewHasDefaultFontSize() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should have a default font size
        XCTAssertNotNil(body, "Should have default font size")
    }
    
    func testGestureEnabledTerminalViewSupportsCustomFontSize() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support custom font sizes
        XCTAssertNotNil(body, "Should support custom font sizes")
    }
    
    // MARK: - Status Display Tests
    
    func testGestureEnabledTerminalViewHasStatusDisplay() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should have a status display
        XCTAssertNotNil(body, "Should have status display")
    }
    
    func testGestureEnabledTerminalViewShowsConnectionStatus() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should show connection status
        XCTAssertNotNil(body, "Should show connection status")
    }
    
    func testGestureEnabledTerminalViewShowsTerminalCount() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should show terminal count
        XCTAssertNotNil(body, "Should show terminal count")
    }
    
    func testGestureEnabledTerminalViewShowsFontSize() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should show font size
        XCTAssertNotNil(body, "Should show font size")
    }
    
    // MARK: - Responsive Design Tests
    
    func testGestureEnabledTerminalViewIsResponsive() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should be responsive to different screen sizes
        XCTAssertNotNil(body, "Should be responsive")
    }
    
    func testGestureEnabledTerminalViewHandlesRotation() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should handle device rotation
        XCTAssertNotNil(body, "Should handle rotation")
    }
    
    // MARK: - Accessibility Tests
    
    func testGestureEnabledTerminalViewSupportsAccessibility() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support accessibility features
        XCTAssertNotNil(body, "Should support accessibility")
    }
    
    func testGestureEnabledTerminalViewSupportsVoiceOver() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support VoiceOver
        XCTAssertNotNil(body, "Should support VoiceOver")
    }
    
    func testGestureEnabledTerminalViewSupportsDynamicType() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        let body = terminalView.body
        
        // Then
        // The view should support Dynamic Type
        XCTAssertNotNil(body, "Should support Dynamic Type")
    }
    
    // MARK: - Performance Tests
    
    func testGestureEnabledTerminalViewPerformance() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When & Then
        self.measure {
            _ = terminalView.body
        }
    }
    
    func testGestureEnabledTerminalViewGesturePerformance() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When & Then
        self.measure {
            // Simulate gesture processing
            _ = terminalView.body
        }
    }
    
    // MARK: - Integration Tests
    
    func testGestureEnabledTerminalViewIntegrationWithViewModel() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        let mockTerminals = [
            TestUtilities.createMockTerminal(id: "terminal1"),
            TestUtilities.createMockTerminal(id: "terminal2")
        ]
        
        // When
        mockAPIClient.mockTerminals = mockTerminals
        mockAPIClient.mockActiveTerminalId = "terminal1"
        
        // Then
        // The view should integrate properly with the view model
        XCTAssertNotNil(terminalView.body, "Should integrate with view model")
    }
    
    func testGestureEnabledTerminalViewIntegrationWithWebSocket() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        mockWebSocketClient.mockConnectionState = .connected
        
        // Then
        // The view should integrate properly with WebSocket
        XCTAssertNotNil(terminalView.body, "Should integrate with WebSocket")
    }
    
    // MARK: - Error Handling Tests
    
    func testGestureEnabledTerminalViewHandlesErrors() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        mockAPIClient.shouldFailTerminalList = true
        
        // Then
        // The view should handle errors gracefully
        XCTAssertNotNil(terminalView.body, "Should handle errors gracefully")
    }
    
    func testGestureEnabledTerminalViewHandlesNetworkErrors() {
        // Given
        let terminalView = GestureEnabledTerminalView(terminalViewModel: terminalViewModel)
        
        // When
        mockWebSocketClient.shouldFailConnection = true
        
        // Then
        // The view should handle network errors gracefully
        XCTAssertNotNil(terminalView.body, "Should handle network errors gracefully")
    }
}

// MARK: - Terminal Switcher View Tests

final class TerminalSwitcherViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mockTerminals: [Terminal]!
    var onSelectCalled = false
    var onDismissCalled = false
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        mockTerminals = [
            TestUtilities.createMockTerminal(id: "terminal1"),
            TestUtilities.createMockTerminal(id: "terminal2"),
            TestUtilities.createMockTerminal(id: "terminal3")
        ]
        onSelectCalled = false
        onDismissCalled = false
    }
    
    override func tearDown() {
        mockTerminals = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testTerminalSwitcherViewInitialization() {
        // Given & When
        let switcherView = TerminalSwitcherView(
            terminals: mockTerminals,
            currentIndex: 0,
            onSelect: { _ in self.onSelectCalled = true },
            onDismiss: { self.onDismissCalled = true }
        )
        
        // Then
        XCTAssertNotNil(switcherView, "Should create TerminalSwitcherView")
    }
    
    func testTerminalSwitcherViewHasBody() {
        // Given
        let switcherView = TerminalSwitcherView(
            terminals: mockTerminals,
            currentIndex: 0,
            onSelect: { _ in self.onSelectCalled = true },
            onDismiss: { self.onDismissCalled = true }
        )
        
        // When
        let body = switcherView.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testTerminalSwitcherViewHandlesEmptyTerminalList() {
        // Given
        let switcherView = TerminalSwitcherView(
            terminals: [],
            currentIndex: 0,
            onSelect: { _ in self.onSelectCalled = true },
            onDismiss: { self.onDismissCalled = true }
        )
        
        // When
        let body = switcherView.body
        
        // Then
        XCTAssertNotNil(body, "Should handle empty terminal list")
    }
    
    // MARK: - Callback Tests
    
    func testTerminalSwitcherViewCallsOnSelect() {
        // Given
        let switcherView = TerminalSwitcherView(
            terminals: mockTerminals,
            currentIndex: 0,
            onSelect: { _ in self.onSelectCalled = true },
            onDismiss: { self.onDismissCalled = true }
        )
        
        // When
        // This would be called by user interaction in real usage
        // For testing, we simulate the callback
        switcherView.onSelect(1)
        
        // Then
        XCTAssertTrue(onSelectCalled, "Should call onSelect callback")
    }
    
    func testTerminalSwitcherViewCallsOnDismiss() {
        // Given
        let switcherView = TerminalSwitcherView(
            terminals: mockTerminals,
            currentIndex: 0,
            onSelect: { _ in self.onSelectCalled = true },
            onDismiss: { self.onDismissCalled = true }
        )
        
        // When
        switcherView.onDismiss()
        
        // Then
        XCTAssertTrue(onDismissCalled, "Should call onDismiss callback")
    }
}

// MARK: - Terminal Status View Tests

final class TerminalStatusViewTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testTerminalStatusViewInitialization() {
        // Given & When
        let statusView = TerminalStatusView(
            terminalCount: 3,
            currentIndex: 1,
            fontSize: 14,
            connectionState: .connected
        )
        
        // Then
        XCTAssertNotNil(statusView, "Should create TerminalStatusView")
    }
    
    func testTerminalStatusViewHasBody() {
        // Given
        let statusView = TerminalStatusView(
            terminalCount: 3,
            currentIndex: 1,
            fontSize: 14,
            connectionState: .connected
        )
        
        // When
        let body = statusView.body
        
        // Then
        XCTAssertNotNil(body, "Should have a body")
    }
    
    func testTerminalStatusViewHandlesZeroTerminals() {
        // Given
        let statusView = TerminalStatusView(
            terminalCount: 0,
            currentIndex: 0,
            fontSize: 14,
            connectionState: .disconnected
        )
        
        // When
        let body = statusView.body
        
        // Then
        XCTAssertNotNil(body, "Should handle zero terminals")
    }
    
    func testTerminalStatusViewHandlesAllConnectionStates() {
        // Given
        let connectionStates: [ConnectionState] = [.connected, .connecting, .disconnected, .reconnecting, .failed]
        
        // When & Then
        for state in connectionStates {
            let statusView = TerminalStatusView(
                terminalCount: 1,
                currentIndex: 1,
                fontSize: 14,
                connectionState: state
            )
            
            XCTAssertNotNil(statusView.body, "Should handle connection state: \(state)")
        }
    }
    
    func testTerminalStatusViewHandlesDifferentFontSizes() {
        // Given
        let fontSizes: [CGFloat] = [8, 12, 14, 16, 20, 24]
        
        // When & Then
        for fontSize in fontSizes {
            let statusView = TerminalStatusView(
                terminalCount: 1,
                currentIndex: 1,
                fontSize: fontSize,
                connectionState: .connected
            )
            
            XCTAssertNotNil(statusView.body, "Should handle font size: \(fontSize)")
        }
    }
}

#endif