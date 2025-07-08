# iOS App Technical Specification
## Mobile Terminal Client for Code-Server

### Overview
Native iOS application providing mobile-optimized access to code-server terminal sessions with integrated Claude Code support and customizable command management.

### Technical Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS Version**: iOS 16.0
- **Architecture**: MVVM with Combine
- **Networking**: URLSession with async/await
- **Storage**: Core Data + Keychain
- **Terminal Emulation**: SwiftTerm
- **Testing**: XCTest + Swift Testing

### App Architecture

#### Core Modules

1. **Networking Module**
   ```swift
   // API Client
   protocol TerminalAPIClient {
       func fetchTerminals() async throws -> [Terminal]
       func executeCommand(terminalId: String, command: String) async throws
       func createTerminal(name: String, cwd: String?) async throws -> Terminal
   }
   
   // WebSocket Manager
   class WebSocketManager: ObservableObject {
       @Published var connectionState: ConnectionState
       @Published var terminalOutput: [String: String]
       
       func connect(to terminal: Terminal) async
       func disconnect()
       func send(command: String) async
   }
   ```

2. **Terminal Module**
   ```swift
   // Terminal View Model
   class TerminalViewModel: ObservableObject {
       @Published var terminals: [Terminal] = []
       @Published var activeTerminal: Terminal?
       @Published var output: String = ""
       @Published var isLoading = false
       
       private let apiClient: TerminalAPIClient
       private let webSocketManager: WebSocketManager
       
       func loadTerminals() async
       func selectTerminal(_ terminal: Terminal) async
       func executeCommand(_ command: String) async
   }
   ```

3. **Command Management Module**
   ```swift
   // Command Store
   class CommandStore: ObservableObject {
       @Published var commands: [CustomCommand] = []
       @Published var categories: [CommandCategory] = []
       
       func addCommand(_ command: CustomCommand)
       func updateCommand(_ command: CustomCommand)
       func deleteCommand(_ command: CustomCommand)
       func importCommands(from url: URL) async throws
       func exportCommands() async throws -> URL
   }
   ```

### User Interface Design

#### Main Views

1. **HomeView**
   ```swift
   struct HomeView: View {
       @StateObject private var viewModel = HomeViewModel()
       
       var body: some View {
           NavigationStack {
               VStack {
                   ConnectionStatusBar()
                   TerminalCarousel()
                   CommandToolbar()
                   ActiveTerminalView()
               }
           }
       }
   }
   ```

2. **TerminalCarousel**
   ```swift
   struct TerminalCarousel: View {
       @ObservedObject var viewModel: TerminalViewModel
       
       var body: some View {
           ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 16) {
                   ForEach(viewModel.terminals) { terminal in
                       TerminalCard(terminal: terminal)
                           .onTapGesture {
                               Task {
                                   await viewModel.selectTerminal(terminal)
                               }
                           }
                   }
               }
               .padding(.horizontal)
           }
       }
   }
   ```

3. **CommandToolbar**
   ```swift
   struct CommandToolbar: View {
       @ObservedObject var commandStore: CommandStore
       @State private var showCommandManager = false
       
       var body: some View {
           ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 12) {
                   ForEach(commandStore.commands.filter(\.isActive)) { command in
                       CommandButton(command: command)
                   }
                   
                   Button(action: { showCommandManager = true }) {
                       Image(systemName: "plus.circle.fill")
                   }
               }
               .padding(.horizontal)
           }
           .sheet(isPresented: $showCommandManager) {
               CommandManagerView()
           }
       }
   }
   ```

4. **TerminalView**
   ```swift
   struct TerminalView: View {
       @ObservedObject var terminal: TerminalViewModel
       @State private var inputText = ""
       
       var body: some View {
           VStack(spacing: 0) {
               // Terminal output using SwiftTerm
               TerminalEmulatorView(
                   content: terminal.output,
                   onInput: { text in
                       Task {
                           await terminal.executeCommand(text)
                       }
                   }
               )
               
               // Custom keyboard toolbar
               KeyboardToolbar(
                   text: $inputText,
                   onSubmit: {
                       Task {
                           await terminal.executeCommand(inputText)
                           inputText = ""
                       }
                   }
               )
           }
       }
   }
   ```

### Data Models

```swift
// Terminal Models
struct Terminal: Identifiable, Codable {
    let id: String
    let name: String
    let pid: Int
    let cwd: String
    let isClaudeActive: Bool
    let createdAt: Date
    let lastActivity: Date
}

// Command Models
struct CustomCommand: Identifiable, Codable {
    let id: UUID
    var name: String
    var command: String
    var category: String
    var color: String
    var icon: String
    var isActive: Bool
    var createdAt: Date
    var usageCount: Int
    
    init(name: String, command: String, category: String) {
        self.id = UUID()
        self.name = name
        self.command = command
        self.category = category
        self.color = "#007AFF"
        self.icon = "terminal"
        self.isActive = true
        self.createdAt = Date()
        self.usageCount = 0
    }
}

struct CommandCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: String
    var commands: [CustomCommand]
}

// Connection Models
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(Error)
}

struct ServerConfiguration: Codable {
    var host: String
    var port: Int
    var useSSL: Bool
    var username: String?
}
```

### Networking Implementation

#### API Client
```swift
class DefaultTerminalAPIClient: TerminalAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let authManager: AuthenticationManager
    
    func fetchTerminals() async throws -> [Terminal] {
        let request = try await authenticatedRequest(for: "/api/terminals")
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([Terminal].self, from: data)
    }
    
    func executeCommand(terminalId: String, command: String) async throws {
        var request = try await authenticatedRequest(
            for: "/api/terminals/\(terminalId)/command",
            method: "POST"
        )
        request.httpBody = try JSONEncoder().encode(["command": command])
        _ = try await session.data(for: request)
    }
    
    private func authenticatedRequest(for path: String, method: String = "GET") async throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let token = try await authManager.getValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }
}
```

#### WebSocket Implementation
```swift
class DefaultWebSocketManager: WebSocketManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    
    func connect(to terminal: Terminal) async {
        let url = websocketURL(for: terminal)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        await startReceiving()
        connectionState = .connected
    }
    
    private func startReceiving() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let message = try await webSocketTask.receive()
            switch message {
            case .string(let text):
                processMessage(text)
            case .data(let data):
                processData(data)
            @unknown default:
                break
            }
            
            // Continue receiving
            await startReceiving()
        } catch {
            connectionState = .error(error)
        }
    }
    
    func send(command: String) async {
        guard let webSocketTask = webSocketTask else { return }
        
        let message = URLSessionWebSocketTask.Message.string(command)
        do {
            try await webSocketTask.send(message)
        } catch {
            print("WebSocket send error: \(error)")
        }
    }
}
```

### Storage Implementation

#### Core Data Models
```swift
// Core Data entities for offline support
@objc(CDTerminalSession)
class CDTerminalSession: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var lastOutput: String?
    @NSManaged var lastSyncDate: Date?
}

@objc(CDCustomCommand)
class CDCustomCommand: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var command: String
    @NSManaged var category: String
    @NSManaged var usageCount: Int32
}
```

#### Keychain Manager
```swift
class KeychainManager {
    static let shared = KeychainManager()
    
    func saveCredentials(username: String, password: String, server: String) throws {
        let account = "\(username)@\(server)"
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: account,
            kSecAttrServer as String: server,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getCredentials(for server: String) throws -> (username: String, password: String) {
        // Implementation
    }
}
```

### Security Implementation

1. **Authentication**
   ```swift
   class AuthenticationManager: ObservableObject {
       @Published var isAuthenticated = false
       private var currentToken: String?
       private var tokenExpiration: Date?
       
       func login(username: String, password: String) async throws {
           // Perform login
           // Store token in keychain
           // Update authentication state
       }
       
       func getValidToken() async throws -> String {
           if let token = currentToken, 
              let expiration = tokenExpiration,
              expiration > Date() {
               return token
           }
           
           // Refresh token
           return try await refreshToken()
       }
   }
   ```

2. **Biometric Authentication**
   ```swift
   class BiometricAuthManager {
       func authenticateUser() async throws {
           let context = LAContext()
           
           guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
               throw BiometricError.notAvailable
           }
           
           let reason = "Authenticate to access your terminals"
           try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
       }
   }
   ```

### Performance Optimizations

1. **Terminal Output Management**
   ```swift
   class TerminalOutputBuffer {
       private let maxLines = 10_000
       private var buffer: CircularBuffer<String>
       
       func append(_ text: String) {
           let lines = text.components(separatedBy: .newlines)
           for line in lines {
               buffer.append(line)
           }
       }
       
       var content: String {
           buffer.joined(separator: "\n")
       }
   }
   ```

2. **Efficient Rendering**
   ```swift
   struct TerminalEmulatorView: UIViewRepresentable {
       let content: String
       let onInput: (String) -> Void
       
       func makeUIView(context: Context) -> SwiftTermView {
           let terminal = SwiftTermView()
           terminal.configureForMobile()
           return terminal
       }
       
       func updateUIView(_ uiView: SwiftTermView, context: Context) {
           // Update only changed content
           uiView.updateContent(content)
       }
   }
   ```

### Testing Strategy

1. **Unit Tests**
   ```swift
   class CommandStoreTests: XCTestCase {
       func testAddCommand() async {
           let store = CommandStore()
           let command = CustomCommand(name: "Test", command: "test", category: "General")
           
           store.addCommand(command)
           
           XCTAssertEqual(store.commands.count, 1)
           XCTAssertEqual(store.commands.first?.name, "Test")
       }
   }
   ```

2. **UI Tests**
   ```swift
   class TerminalUITests: XCTestCase {
       func testTerminalSwitching() {
           let app = XCUIApplication()
           app.launch()
           
           // Test terminal carousel interaction
           let carousel = app.scrollViews["terminalCarousel"]
           carousel.swipeLeft()
           
           let terminalCard = app.buttons["terminal-1"]
           terminalCard.tap()
           
           XCTAssertTrue(app.staticTexts["Project 1"].exists)
       }
   }
   ```

### App Configuration

```swift
struct AppConfiguration {
    static let shared = AppConfiguration()
    
    // Network timeouts
    let apiTimeout: TimeInterval = 30
    let websocketTimeout: TimeInterval = 60
    
    // UI Configuration
    let terminalFontSize: CGFloat = 14
    let terminalBackgroundColor = Color.black
    let terminalTextColor = Color.green
    
    // Storage limits
    let maxOfflineCommands = 100
    let maxTerminalHistory = 10_000
    
    // Security
    let tokenRefreshBuffer: TimeInterval = 300 // 5 minutes
    let biometricAuthenticationRequired = true
}
```

### Accessibility

```swift
extension View {
    func terminalAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// Usage
TerminalCard(terminal: terminal)
    .terminalAccessibility(
        label: "Terminal: \(terminal.name)",
        hint: "Double tap to open this terminal"
    )
```

### Localization

```swift
// Localizable.strings
"terminal.connection.error" = "Failed to connect to server";
"terminal.command.sent" = "Command sent successfully";
"command.toolbar.add" = "Add Command";
"command.manager.title" = "Manage Commands";

// Usage
Text("terminal.connection.error", bundle: .main)
```

### App Store Metadata

1. **App Information**
   - Name: Terminal Mobile for Code-Server
   - Category: Developer Tools
   - Age Rating: 4+
   - Primary Language: English

2. **Required Capabilities**
   - Network access (WiFi/Cellular)
   - Background modes (for session persistence)
   - Face ID/Touch ID

3. **Privacy Policy Requirements**
   - Data collection disclosure
   - Credential storage explanation
   - Network communication details
   - No third-party analytics