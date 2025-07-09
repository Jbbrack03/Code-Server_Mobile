#if os(iOS)
import SwiftUI
import SwiftTerm
import UIKit

/// Terminal view with mobile gesture support
struct GestureEnabledTerminalView: View {
    @ObservedObject var terminalViewModel: TerminalViewModel
    @State private var fontSize: CGFloat = 14
    @State private var currentTerminalIndex: Int = 0
    @State private var showingTerminalSwitcher = false
    @State private var dragOffset: CGSize = .zero
    
    // Gesture sensitivity settings
    private let minFontSize: CGFloat = 8
    private let maxFontSize: CGFloat = 24
    private let swipeThreshold: CGFloat = 100
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main terminal view
                TerminalViewRepresentable(
                    viewModel: terminalViewModel,
                    font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                )
                .background(Color.black)
                .scaleEffect(fontScaleMultiplier)
                .offset(dragOffset)
                .gesture(
                    // Pinch to zoom gesture
                    MagnificationGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                let newSize = fontSize * value
                                fontSize = min(max(newSize, minFontSize), maxFontSize)
                            }
                        }
                        .onEnded { _ in
                            hapticFeedback.impactOccurred()
                        }
                )
                .gesture(
                    // Swipe gesture for terminal switching
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleSwipeGesture(value: value, geometry: geometry)
                        }
                )
                
                // Terminal switcher overlay
                if showingTerminalSwitcher {
                    TerminalSwitcherView(
                        terminals: terminalViewModel.terminals,
                        currentIndex: currentTerminalIndex,
                        onSelect: { index in
                            selectTerminal(at: index)
                        },
                        onDismiss: {
                            showingTerminalSwitcher = false
                        }
                    )
                    .transition(.opacity)
                }
                
                // Terminal status overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        TerminalStatusView(
                            terminalCount: terminalViewModel.terminals.count,
                            currentIndex: currentTerminalIndex + 1,
                            fontSize: fontSize,
                            connectionState: terminalViewModel.connectionState
                        )
                        .opacity(0.8)
                        .padding()
                    }
                }
            }
        }
        .onReceive(terminalViewModel.$terminals) { terminals in
            // Update current terminal index when terminals change
            if let activeId = terminalViewModel.activeTerminalId,
               let index = terminals.firstIndex(where: { $0.id == activeId }) {
                currentTerminalIndex = index
            }
        }
        .onTapGesture(count: 2) {
            // Double tap to show terminal switcher
            showingTerminalSwitcher = true
            hapticFeedback.impactOccurred()
        }
    }
    
    // MARK: - Private Properties
    
    private var fontScaleMultiplier: CGFloat {
        // Scale multiplier based on font size for better visibility
        return fontSize / 14.0
    }
    
    // MARK: - Private Methods
    
    private func handleSwipeGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        let horizontalMovement = value.translation.x
        let verticalMovement = value.translation.y
        
        // Reset drag offset
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = .zero
        }
        
        // Handle horizontal swipe for terminal switching
        if abs(horizontalMovement) > abs(verticalMovement) {
            if horizontalMovement > swipeThreshold {
                // Swipe right - previous terminal
                switchToPreviousTerminal()
            } else if horizontalMovement < -swipeThreshold {
                // Swipe left - next terminal
                switchToNextTerminal()
            }
        }
        
        // Handle vertical swipe for keyboard/shortcuts
        if abs(verticalMovement) > abs(horizontalMovement) {
            if verticalMovement > swipeThreshold {
                // Swipe down - show keyboard shortcuts
                showKeyboardShortcuts()
            } else if verticalMovement < -swipeThreshold {
                // Swipe up - hide keyboard or show terminal info
                hideKeyboardOrShowInfo()
            }
        }
    }
    
    private func selectTerminal(at index: Int) {
        guard index >= 0 && index < terminalViewModel.terminals.count else { return }
        
        let terminal = terminalViewModel.terminals[index]
        Task {
            await terminalViewModel.selectTerminal(terminal)
        }
        
        currentTerminalIndex = index
        showingTerminalSwitcher = false
        hapticFeedback.impactOccurred()
    }
    
    private func switchToNextTerminal() {
        Task {
            await terminalViewModel.selectNextTerminal()
        }
        hapticFeedback.impactOccurred()
    }
    
    private func switchToPreviousTerminal() {
        Task {
            await terminalViewModel.selectPreviousTerminal()
        }
        hapticFeedback.impactOccurred()
    }
    
    private func showKeyboardShortcuts() {
        // TODO: Implement keyboard shortcuts display
        hapticFeedback.impactOccurred()
    }
    
    private func hideKeyboardOrShowInfo() {
        // TODO: Implement keyboard dismissal or terminal info display
        hapticFeedback.impactOccurred()
    }
}

/// Terminal switcher overlay view
struct TerminalSwitcherView: View {
    let terminals: [Terminal]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Terminal list
            VStack(spacing: 0) {
                Text("Select Terminal")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(terminals.enumerated()), id: \.offset) { index, terminal in
                            TerminalSwitcherRow(
                                terminal: terminal,
                                isSelected: index == currentIndex,
                                onTap: {
                                    onSelect(index)
                                }
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 400)
            }
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
            .padding()
        }
    }
}

/// Terminal switcher row view
struct TerminalSwitcherRow: View {
    let terminal: Terminal
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(terminal.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(terminal.cwd)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    HStack {
                        Image(systemName: terminal.isClaudeCode ? "brain.head.profile" : "terminal")
                            .foregroundColor(terminal.isClaudeCode ? .purple : .blue)
                        
                        Text(terminal.shellType.rawValue)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if terminal.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Terminal status overlay view
struct TerminalStatusView: View {
    let terminalCount: Int
    let currentIndex: Int
    let fontSize: CGFloat
    let connectionState: ConnectionState
    
    var body: some View {
        HStack(spacing: 12) {
            // Terminal count indicator
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption)
                Text("\(currentIndex)/\(terminalCount)")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(8)
            
            // Font size indicator
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.caption)
                Text("\(Int(fontSize))pt")
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(8)
            
            // Connection status indicator
            HStack(spacing: 4) {
                Image(systemName: connectionStatusIcon)
                    .font(.caption)
                    .foregroundColor(connectionStatusColor)
                Text(connectionState.displayName)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.8))
            .cornerRadius(8)
        }
    }
    
    private var connectionStatusIcon: String {
        switch connectionState {
        case .connected:
            return "wifi"
        case .connecting, .reconnecting:
            return "wifi.slash"
        case .disconnected:
            return "wifi.exclamationmark"
        case .failed:
            return "wifi.slash"
        }
    }
    
    private var connectionStatusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .yellow
        case .disconnected:
            return .gray
        case .failed:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    GestureEnabledTerminalView(
        terminalViewModel: TerminalViewModel(
            apiClient: APIClient(
                baseURL: URL(string: "http://localhost:8092")!,
                apiKey: "preview-key"
            ),
            webSocketManager: MobileTerminalWebSocketClient()
        )
    )
}

#endif