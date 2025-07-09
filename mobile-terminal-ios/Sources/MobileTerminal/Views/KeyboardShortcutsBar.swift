#if os(iOS)
import SwiftUI
import UIKit

/// Custom keyboard shortcuts bar for mobile terminal
struct KeyboardShortcutsBar: View {
    let shortcuts: [CommandShortcut]
    let onShortcutTapped: (CommandShortcut) -> Void
    let onEditTapped: () -> Void
    
    @State private var showingAllShortcuts = false
    
    // Display configuration
    private let maxVisibleShortcuts = 5
    private let shortcutHeight: CGFloat = 44
    private let shortcutSpacing: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 0) {
            // Primary shortcuts row
            HStack(spacing: shortcutSpacing) {
                ForEach(visibleShortcuts) { shortcut in
                    ShortcutButton(
                        shortcut: shortcut,
                        action: {
                            onShortcutTapped(shortcut)
                        }
                    )
                }
                
                // More button if there are additional shortcuts
                if shortcuts.count > maxVisibleShortcuts {
                    Button(action: {
                        showingAllShortcuts = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12))
                            Text("More")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(8)
                    }
                    .frame(height: shortcutHeight)
                }
                
                Spacer()
                
                // Edit button
                Button(action: onEditTapped) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
                .frame(height: shortcutHeight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9))
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .sheet(isPresented: $showingAllShortcuts) {
            AllShortcutsView(
                shortcuts: shortcuts,
                onShortcutTapped: { shortcut in
                    onShortcutTapped(shortcut)
                    showingAllShortcuts = false
                },
                onDismiss: {
                    showingAllShortcuts = false
                }
            )
        }
    }
    
    // MARK: - Private Properties
    
    private var visibleShortcuts: [CommandShortcut] {
        Array(shortcuts.prefix(maxVisibleShortcuts))
    }
}

/// Individual shortcut button
struct ShortcutButton: View {
    let shortcut: CommandShortcut
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let icon = shortcut.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                } else {
                    Text(shortcut.label.prefix(2))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(shortcut.label)
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(shortcut.category.color.opacity(0.8))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

/// All shortcuts view (modal)
struct AllShortcutsView: View {
    let shortcuts: [CommandShortcut]
    let onShortcutTapped: (CommandShortcut) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedCategory: CommandShortcut.Category = .navigation
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CommandShortcut.Category.allCases, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 16))
                                    Text(category.displayName)
                                        .font(.caption)
                                }
                                .foregroundColor(selectedCategory == category ? .white : .gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category ? 
                                    category.color.opacity(0.8) : 
                                    Color.clear
                                )
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                
                // Shortcuts grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(shortcutsForCategory(selectedCategory)) { shortcut in
                            ShortcutGridItem(
                                shortcut: shortcut,
                                onTap: {
                                    onShortcutTapped(shortcut)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
                
                Spacer()
            }
            .navigationTitle("Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func shortcutsForCategory(_ category: CommandShortcut.Category) -> [CommandShortcut] {
        shortcuts.filter { $0.category == category }
    }
}

/// Grid item for shortcuts
struct ShortcutGridItem: View {
    let shortcut: CommandShortcut
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let icon = shortcut.icon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                } else {
                    Text(shortcut.label.prefix(3))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text(shortcut.label)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let description = shortcut.description {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .background(shortcut.category.color.opacity(0.8))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Keyboard shortcuts bar manager
public class KeyboardShortcutsManager: ObservableObject {
    @Published public private(set) var shortcuts: [CommandShortcut] = []
    @Published public private(set) var isVisible = false
    
    private let terminalViewModel: TerminalViewModel
    private let maxRecentShortcuts = 10
    
    public init(terminalViewModel: TerminalViewModel) {
        self.terminalViewModel = terminalViewModel
        loadDefaultShortcuts()
    }
    
    // MARK: - Public Methods
    
    public func showKeyboard() {
        isVisible = true
    }
    
    public func hideKeyboard() {
        isVisible = false
    }
    
    public func toggleKeyboard() {
        isVisible.toggle()
    }
    
    public func executeShortcut(_ shortcut: CommandShortcut) {
        Task {
            await terminalViewModel.sendInput(shortcut.command)
        }
        
        // Update usage count
        updateShortcutUsage(shortcut)
    }
    
    public func addCustomShortcut(_ shortcut: CommandShortcut) {
        shortcuts.append(shortcut)
        sortShortcuts()
    }
    
    public func removeShortcut(_ shortcut: CommandShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
    }
    
    public func updateShortcut(_ shortcut: CommandShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        }
    }
    
    public func resetToDefaults() {
        shortcuts.removeAll()
        loadDefaultShortcuts()
    }
    
    // MARK: - Private Methods
    
    private func loadDefaultShortcuts() {
        shortcuts = [
            // Navigation shortcuts
            CommandShortcut(
                label: "Tab",
                command: "\t",
                category: .navigation,
                icon: "arrow.right.to.line"
            ),
            CommandShortcut(
                label: "Ctrl+C",
                command: "\u{03}", // ASCII ETX
                category: .control,
                icon: "stop.circle"
            ),
            CommandShortcut(
                label: "Ctrl+D",
                command: "\u{04}", // ASCII EOT
                category: .control,
                icon: "power"
            ),
            CommandShortcut(
                label: "Ctrl+Z",
                command: "\u{1A}", // ASCII SUB
                category: .control,
                icon: "pause.circle"
            ),
            CommandShortcut(
                label: "Up",
                command: "\u{1B}[A", // ANSI up arrow
                category: .navigation,
                icon: "arrow.up"
            ),
            CommandShortcut(
                label: "Down",
                command: "\u{1B}[B", // ANSI down arrow
                category: .navigation,
                icon: "arrow.down"
            ),
            CommandShortcut(
                label: "Left",
                command: "\u{1B}[D", // ANSI left arrow
                category: .navigation,
                icon: "arrow.left"
            ),
            CommandShortcut(
                label: "Right",
                command: "\u{1B}[C", // ANSI right arrow
                category: .navigation,
                icon: "arrow.right"
            ),
            CommandShortcut(
                label: "Home",
                command: "\u{1B}[H", // ANSI home
                category: .navigation,
                icon: "arrow.up.left"
            ),
            CommandShortcut(
                label: "End",
                command: "\u{1B}[F", // ANSI end
                category: .navigation,
                icon: "arrow.down.right"
            ),
            
            // Common commands
            CommandShortcut(
                label: "ls",
                command: "ls -la\n",
                category: .commands,
                icon: "list.bullet"
            ),
            CommandShortcut(
                label: "pwd",
                command: "pwd\n",
                category: .commands,
                icon: "folder"
            ),
            CommandShortcut(
                label: "cd",
                command: "cd ",
                category: .commands,
                icon: "folder.badge.plus"
            ),
            CommandShortcut(
                label: "vim",
                command: "vim ",
                category: .commands,
                icon: "doc.text"
            ),
            CommandShortcut(
                label: "nano",
                command: "nano ",
                category: .commands,
                icon: "doc.text.fill"
            ),
            CommandShortcut(
                label: "clear",
                command: "clear\n",
                category: .commands,
                icon: "clear"
            ),
            
            // Git shortcuts
            CommandShortcut(
                label: "git status",
                command: "git status\n",
                category: .git,
                icon: "questionmark.circle"
            ),
            CommandShortcut(
                label: "git add",
                command: "git add ",
                category: .git,
                icon: "plus.circle"
            ),
            CommandShortcut(
                label: "git commit",
                command: "git commit -m \"",
                category: .git,
                icon: "checkmark.circle"
            ),
            CommandShortcut(
                label: "git push",
                command: "git push\n",
                category: .git,
                icon: "arrow.up.circle"
            ),
            CommandShortcut(
                label: "git pull",
                command: "git pull\n",
                category: .git,
                icon: "arrow.down.circle"
            ),
            
            // Symbols
            CommandShortcut(
                label: "Pipe",
                command: "|",
                category: .symbols,
                icon: "line.horizontal.3"
            ),
            CommandShortcut(
                label: "Redirect",
                command: ">",
                category: .symbols,
                icon: "arrow.right"
            ),
            CommandShortcut(
                label: "Append",
                command: ">>",
                category: .symbols,
                icon: "arrow.right.doc.on.clipboard"
            ),
            CommandShortcut(
                label: "Background",
                command: "&",
                category: .symbols,
                icon: "play.circle"
            ),
            CommandShortcut(
                label: "Semicolon",
                command: ";",
                category: .symbols,
                icon: "semicolon.circle"
            )
        ]
        
        sortShortcuts()
    }
    
    private func updateShortcutUsage(_ shortcut: CommandShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut.incrementUsage()
        }
    }
    
    private func sortShortcuts() {
        shortcuts.sort { $0.usageCount > $1.usageCount }
    }
}

// MARK: - Extensions

extension CommandShortcut.Category {
    var color: Color {
        switch self {
        case .navigation: return .blue
        case .control: return .red
        case .commands: return .green
        case .git: return .orange
        case .symbols: return .purple
        case .custom: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .navigation: return "arrow.up.arrow.down"
        case .control: return "control"
        case .commands: return "terminal"
        case .git: return "arrow.triangle.branch"
        case .symbols: return "textformat.alt"
        case .custom: return "star"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        KeyboardShortcutsBar(
            shortcuts: [
                CommandShortcut(label: "Tab", command: "\t", category: .navigation, icon: "arrow.right.to.line"),
                CommandShortcut(label: "Ctrl+C", command: "\u{03}", category: .control, icon: "stop.circle"),
                CommandShortcut(label: "ls", command: "ls -la\n", category: .commands, icon: "list.bullet"),
                CommandShortcut(label: "git status", command: "git status\n", category: .git, icon: "questionmark.circle"),
                CommandShortcut(label: "Pipe", command: "|", category: .symbols, icon: "line.horizontal.3"),
                CommandShortcut(label: "More", command: "more", category: .commands, icon: "doc.text")
            ],
            onShortcutTapped: { shortcut in
                print("Tapped: \(shortcut.label)")
            },
            onEditTapped: {
                print("Edit tapped")
            }
        )
    }
    .background(Color.black)
}

#endif