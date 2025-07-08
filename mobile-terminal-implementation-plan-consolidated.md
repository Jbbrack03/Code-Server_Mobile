# Mobile Terminal Implementation Plan - Consolidated Version

## Project Overview
Build a native iOS application with a VS Code extension backend that provides an optimized mobile terminal experience for accessing Code-Server terminals remotely.

**Reference Documents:**
- `mobile-terminal-prd.md` - Product requirements and success criteria
- `mobile-terminal-mvp-spec.md` - Simplified MVP specifications
- `mobile-terminal-ui-design.md` - Visual design and interaction patterns
- `mobile-terminal-network-guide.md` - Network configuration for all access scenarios
- `mobile-terminal-research-checklist.md` - Technical validation points

## Implementation Timeline: 8 Weeks

## Technical Architecture & Standards

### Core Technology Stack

#### VS Code Extension
- **Runtime**: Node.js 18+
- **Language**: TypeScript 5.0+
- **Framework**: VS Code Extension API 1.80+
- **HTTP Server**: Express.js 4.18+
- **WebSocket**: ws 8.14+
- **Build**: webpack 5.88+

#### iOS Application
- **Platform**: iOS 16.0+
- **Language**: Swift 5.9+
- **Framework**: SwiftUI 4.0+
- **Terminal**: SwiftTerm 1.4+
- **WebSocket**: Starscream 4.0+
- **Keychain**: KeychainAccess 4.2+
- **QR Scanning**: AVFoundation

### Data Models & API Specifications

#### Core Entity Models

**Terminal Model**
```typescript
interface Terminal {
  id: string;                    // UUID v4
  name: string;                  // Display name
  pid: number;                   // Process ID
  cwd: string;                   // Working directory
  shellType: 'bash' | 'zsh' | 'fish' | 'pwsh' | 'cmd';
  isActive: boolean;             // Currently selected
  isClaudeCode: boolean;         // Claude Code session
  createdAt: Date;
  lastActivity: Date;
  dimensions: {
    cols: number;
    rows: number;
  };
  status: 'active' | 'inactive' | 'crashed';
}
```

**Connection Profile Model**
```typescript
interface ConnectionProfile {
  id: string;                    // UUID v4
  name: string;                  // User-friendly name
  urls: string[];                // Priority-ordered endpoints
  apiKey: string;                // SHA-256 hash
  autoConnect: boolean;
  networkSSIDs?: string[];       // Auto-select by WiFi
  tlsConfig?: {
    allowSelfSigned: boolean;
    pinnedCertificates: string[];
  };
  createdAt: Date;
  lastUsed: Date;
}
```

**Command Shortcut Model**
```typescript
interface CommandShortcut {
  id: string;                    // UUID v4
  label: string;                 // Display text (max 20 chars)
  command: string;               // Shell command
  position: number;              // Sort order (0-based)
  icon?: string;                 // SF Symbol name
  color?: string;                // Hex color code
  category: 'default' | 'git' | 'npm' | 'docker' | 'custom';
  usage: number;                 // Usage counter
  createdAt: Date;
}
```

#### WebSocket Message Protocol

**Message Base Structure**
```typescript
interface WebSocketMessage {
  id: string;                    // UUID v4 for request tracking
  type: MessageType;
  timestamp: number;             // Unix timestamp
  payload: any;
}

type MessageType = 
  | 'terminal.output'            // Terminal output data
  | 'terminal.input'             // Input to terminal
  | 'terminal.resize'            // Terminal resize event
  | 'terminal.list'              // Terminal list update
  | 'terminal.select'            // Change active terminal
  | 'connection.ping'            // Keep-alive ping
  | 'connection.pong'            // Keep-alive response
  | 'error'                      // Error notification
  | 'auth.challenge'             // Authentication challenge
  | 'auth.response';             // Authentication response
```

**Specific Message Types**
```typescript
interface TerminalOutputMessage extends WebSocketMessage {
  type: 'terminal.output';
  payload: {
    terminalId: string;
    data: string;                // ANSI-encoded output
    sequence: number;            // Sequence number
  };
}

interface TerminalInputMessage extends WebSocketMessage {
  type: 'terminal.input';
  payload: {
    terminalId: string;
    data: string;                // Input text
  };
}

interface ErrorMessage extends WebSocketMessage {
  type: 'error';
  payload: {
    code: string;                // Error code
    message: string;             // Human-readable message
    details?: any;               // Additional error context
  };
}
```

### REST API Specification

#### Authentication
**Header**: `X-API-Key: <sha256-hash>`
**Rate Limiting**: 1000 requests/hour per API key

#### Endpoints

```typescript
// Health Check
GET /api/health
Response: {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  uptime: number;
  terminals: number;
}

// Terminal Management
GET /api/terminals
Response: {
  terminals: Terminal[];
  activeTerminalId: string | null;
}

GET /api/terminals/:id
Response: {
  terminal: Terminal;
  buffer: string[];              // Last 1000 lines
}

POST /api/terminals/:id/select
Request: { /* empty */ }
Response: {
  success: boolean;
  activeTerminalId: string;
}

POST /api/terminals/:id/input
Request: {
  data: string;                  // Input text
}
Response: {
  success: boolean;
  sequence: number;
}

POST /api/terminals/:id/resize
Request: {
  cols: number;
  rows: number;
}
Response: {
  success: boolean;
}
```

#### Error Response Format (RFC 9457)
```typescript
interface ErrorResponse {
  type: string;                  // Error type URI
  title: string;                 // Human-readable title
  status: number;                // HTTP status code
  detail: string;                // Specific error details
  instance: string;              // Request instance URI
  timestamp: string;             // ISO 8601 timestamp
  requestId: string;             // Unique request identifier
}
```

### Error Handling Strategy

#### HTTP Status Codes
- **200 OK**: Successful request
- **201 Created**: Resource created
- **400 Bad Request**: Invalid request format
- **401 Unauthorized**: Invalid/missing API key
- **403 Forbidden**: API key lacks permission
- **404 Not Found**: Terminal/resource not found
- **422 Unprocessable Entity**: Valid format, invalid data
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server-side error
- **502 Bad Gateway**: Terminal communication error
- **503 Service Unavailable**: Server temporarily unavailable

#### Error Categories
```typescript
enum ErrorCode {
  // Authentication
  AUTH_INVALID_KEY = 'AUTH_001',
  AUTH_EXPIRED_KEY = 'AUTH_002',
  AUTH_RATE_LIMITED = 'AUTH_003',
  
  // Terminal
  TERMINAL_NOT_FOUND = 'TERM_001',
  TERMINAL_CRASHED = 'TERM_002',
  TERMINAL_BUSY = 'TERM_003',
  
  // Network
  NETWORK_TIMEOUT = 'NET_001',
  NETWORK_DISCONNECTED = 'NET_002',
  NETWORK_UNREACHABLE = 'NET_003',
  
  // WebSocket
  WS_CONNECTION_FAILED = 'WS_001',
  WS_MESSAGE_INVALID = 'WS_002',
  WS_BUFFER_OVERFLOW = 'WS_003',
  
  // System
  INTERNAL_ERROR = 'SYS_001',
  RESOURCE_EXHAUSTED = 'SYS_002',
  SERVICE_UNAVAILABLE = 'SYS_003'
}
```

### Security Specifications

#### API Key Management
- **Generation**: Cryptographically secure random 32-byte key
- **Encoding**: Base64URL encoding for transmission
- **Storage**: SHA-256 hash stored on server
- **Rotation**: Manual rotation via VS Code command
- **Scope**: Per-workspace isolation

#### Transport Security
- **WebSocket**: WSS (TLS 1.3) for production
- **HTTP**: HTTPS with HSTS headers
- **Certificate Pinning**: Optional for iOS client
- **CORS**: Restricted to specified origins

#### Input Validation
- **Command Sanitization**: Prevent shell injection
- **Path Validation**: Restrict to safe directories
- **Size Limits**: Max 10KB per message
- **Rate Limiting**: Per-connection and per-key limits

### Performance Specifications

#### Buffer Management
- **Terminal Buffer**: Circular buffer, 1000 lines max
- **WebSocket Buffer**: 100 messages max queue
- **Memory Limit**: 50MB per terminal session
- **GC Strategy**: Automatic cleanup after 1 hour idle

#### Connection Management
- **Connection Timeout**: 30 seconds
- **Keep-alive**: 30-second ping interval
- **Reconnection**: Exponential backoff (1s, 2s, 4s, 8s)
- **Max Retries**: 5 attempts before failure

#### iOS Performance Targets
- **Memory Usage**: < 100MB resident
- **CPU Usage**: < 20% during active use
- **Battery Impact**: < 5% per hour
- **Network Usage**: < 1MB/hour idle

### Configuration Schema

#### VS Code Extension Settings
```json
{
  "mobileTerminal.server.port": 8092,
  "mobileTerminal.server.host": "0.0.0.0",
  "mobileTerminal.auth.apiKey": "<generated>",
  "mobileTerminal.auth.allowedIPs": [],
  "mobileTerminal.buffer.maxLines": 1000,
  "mobileTerminal.buffer.maxSize": 52428800,
  "mobileTerminal.connection.timeout": 30000,
  "mobileTerminal.connection.pingInterval": 30000,
  "mobileTerminal.terminal.trackClaudeCode": true,
  "mobileTerminal.security.allowSelfSigned": false,
  "mobileTerminal.logging.level": "info"
}
```

#### iOS App Configuration
```swift
struct AppConfiguration {
    static let apiVersion = "v1"
    static let maxConnections = 5
    static let connectionTimeout: TimeInterval = 30.0
    static let pingInterval: TimeInterval = 30.0
    static let maxRetries = 5
    static let bufferSize = 1000
    static let maxMessageSize = 10240  // 10KB
    static let gestureMinimumDistance: CGFloat = 50.0
    static let hapticFeedbackEnabled = true
}
```

## Detailed Implementation Specifications

### VS Code Extension Architecture

#### Core Services Implementation

**Terminal Service**
```typescript
class TerminalService {
  private terminals: Map<string, Terminal> = new Map();
  private activeTerminalId: string | null = null;
  private buffers: Map<string, CircularBuffer> = new Map();
  
  // VS Code API Integration
  onDidCreateTerminal(terminal: vscode.Terminal): void;
  onDidCloseTerminal(terminal: vscode.Terminal): void;
  onDidChangeActiveTerminal(terminal: vscode.Terminal): void;
  onDidWriteTerminalData(terminal: vscode.Terminal, data: string): void;
  
  // Terminal Management
  getTerminals(): Terminal[];
  getActiveTerminal(): Terminal | null;
  selectTerminal(id: string): Promise<boolean>;
  sendInput(id: string, data: string): Promise<boolean>;
  resizeTerminal(id: string, cols: number, rows: number): Promise<boolean>;
  
  // Claude Code Detection
  private detectClaudeCode(terminal: vscode.Terminal): boolean;
}
```

**WebSocket Server**
```typescript
class WebSocketServer {
  private wss: WebSocket.Server;
  private clients: Map<string, WebSocket> = new Map();
  private messageQueue: Map<string, WebSocketMessage[]> = new Map();
  
  // Connection Management
  handleConnection(ws: WebSocket, request: http.IncomingMessage): void;
  handleDisconnection(clientId: string): void;
  
  // Message Processing
  handleMessage(clientId: string, message: WebSocketMessage): void;
  broadcastMessage(message: WebSocketMessage): void;
  sendToClient(clientId: string, message: WebSocketMessage): void;
  
  // Authentication
  authenticateClient(request: http.IncomingMessage): boolean;
  validateApiKey(apiKey: string): boolean;
}
```

**API Key Management**
```typescript
class ApiKeyManager {
  private readonly keyLength = 32;
  private readonly hashAlgorithm = 'sha256';
  
  generateApiKey(): string;
  hashApiKey(key: string): string;
  validateApiKey(key: string, hash: string): boolean;
  rotateApiKey(): Promise<string>;
  
  // VS Code Integration
  storeApiKey(key: string): Promise<void>;
  retrieveApiKey(): Promise<string | null>;
}
```

#### Network Discovery Implementation

**mDNS/Bonjour Service**
```typescript
class NetworkDiscovery {
  private mdnsService: mdns.Advertisement;
  
  startAdvertising(port: number): void;
  stopAdvertising(): void;
  getLocalNetworkUrls(): string[];
  
  // IP Detection
  private getLocalIpAddresses(): string[];
  private getHostnames(): string[];
}
```

### iOS App Architecture

#### Core ViewModels

**Terminal ViewModel**
```swift
@MainActor
class TerminalViewModel: ObservableObject {
    @Published var terminals: [Terminal] = []
    @Published var activeTerminalId: String?
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isLoading = false
    @Published var error: TerminalError?
    
    private let apiClient: APIClient
    private let webSocketManager: WebSocketManager
    private var cancellables = Set<AnyCancellable>()
    
    // Terminal Management
    func loadTerminals() async
    func selectTerminal(_ terminal: Terminal) async
    func sendInput(_ input: String) async
    func resizeTerminal(cols: Int, rows: Int) async
    
    // Connection Management
    func connect(profile: ConnectionProfile) async
    func disconnect() async
    func reconnect() async
    
    // Error Handling
    private func handleError(_ error: Error)
    private func showError(_ error: TerminalError)
}
```

**Connection ViewModel**
```swift
@MainActor
class ConnectionViewModel: ObservableObject {
    @Published var profiles: [ConnectionProfile] = []
    @Published var currentProfile: ConnectionProfile?
    @Published var isConnecting = false
    @Published var connectionError: ConnectionError?
    
    private let keychainService: KeychainService
    private let networkMonitor: NetworkMonitor
    
    // Profile Management
    func createProfile(from qrCode: String) async -> ConnectionProfile?
    func saveProfile(_ profile: ConnectionProfile) async
    func deleteProfile(_ profile: ConnectionProfile) async
    func testConnection(_ profile: ConnectionProfile) async -> Bool
    
    // Network Detection
    func detectLocalServers() async -> [String]
    func validateUrl(_ url: String) async -> Bool
}
```

#### SwiftTerm Integration

**Terminal View Controller**
```swift
class TerminalViewController: UIViewController {
    private let terminalView = TerminalView()
    private let terminalViewModel: TerminalViewModel
    
    // Terminal Configuration
    private func configureTerminal() {
        terminalView.delegate = self
        terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        terminalView.backgroundColor = UIColor.systemBackground
        terminalView.allowsLinkPreview = false
        terminalView.blinkingCursor = true
    }
    
    // Gesture Handling
    private func setupGestures() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        
        terminalView.addGestureRecognizer(pinchGesture)
        terminalView.addGestureRecognizer(swipeLeft)
        terminalView.addGestureRecognizer(swipeRight)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer)
    @objc private func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer)
    @objc private func handleSwipeRight(_ gesture: UISwipeGestureRecognizer)
}
```

#### WebSocket Client Implementation

**WebSocket Manager**
```swift
class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionError: WebSocketError?
    
    private var socket: WebSocket?
    private let connectionTimeout: TimeInterval = 30.0
    private let pingInterval: TimeInterval = 30.0
    private var pingTimer: Timer?
    
    // Connection Management
    func connect(to url: URL, with apiKey: String) async throws
    func disconnect()
    func reconnect() async
    
    // Message Handling
    func sendMessage(_ message: WebSocketMessage) async throws
    private func handleMessage(_ message: WebSocketMessage)
    
    // Keep-alive
    private func startPingTimer()
    private func stopPingTimer()
    private func sendPing()
}
```

### Testing Strategy Implementation

#### Unit Test Structure

**VS Code Extension Tests**
```typescript
// tests/terminal.service.test.ts
describe('TerminalService', () => {
  let service: TerminalService;
  let mockTerminal: vscode.Terminal;
  
  beforeEach(() => {
    service = new TerminalService();
    mockTerminal = createMockTerminal();
  });
  
  describe('terminal detection', () => {
    it('should detect Claude Code terminals', () => {
      // Test Claude Code detection logic
    });
    
    it('should track terminal lifecycle', () => {
      // Test terminal creation/destruction
    });
  });
  
  describe('buffer management', () => {
    it('should maintain circular buffer', () => {
      // Test buffer size limits
    });
    
    it('should handle ANSI escape sequences', () => {
      // Test ANSI parsing
    });
  });
});
```

**iOS App Tests**
```swift
// Tests/TerminalViewModelTests.swift
class TerminalViewModelTests: XCTestCase {
    var viewModel: TerminalViewModel!
    var mockAPIClient: MockAPIClient!
    var mockWebSocketManager: MockWebSocketManager!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockWebSocketManager = MockWebSocketManager()
        viewModel = TerminalViewModel(
            apiClient: mockAPIClient,
            webSocketManager: mockWebSocketManager
        )
    }
    
    func testTerminalLoading() async {
        // Test terminal loading
        await viewModel.loadTerminals()
        XCTAssertFalse(viewModel.terminals.isEmpty)
    }
    
    func testTerminalSelection() async {
        // Test terminal selection
        let terminal = Terminal.mock()
        await viewModel.selectTerminal(terminal)
        XCTAssertEqual(viewModel.activeTerminalId, terminal.id)
    }
}
```

#### Integration Test Scenarios

**End-to-End Connection Test**
```typescript
describe('E2E Connection Flow', () => {
  it('should complete full connection workflow', async () => {
    // 1. Start VS Code extension
    // 2. Generate QR code
    // 3. Connect iOS app
    // 4. Authenticate
    // 5. Load terminals
    // 6. Execute command
    // 7. Verify output
  });
});
```

### Performance Optimization Implementation

#### Circular Buffer Implementation
```typescript
class CircularBuffer {
  private buffer: string[] = [];
  private readonly maxSize: number;
  private head = 0;
  private tail = 0;
  private size = 0;
  
  constructor(maxSize: number = 1000) {
    this.maxSize = maxSize;
    this.buffer = new Array(maxSize);
  }
  
  push(item: string): void {
    this.buffer[this.tail] = item;
    this.tail = (this.tail + 1) % this.maxSize;
    
    if (this.size < this.maxSize) {
      this.size++;
    } else {
      this.head = (this.head + 1) % this.maxSize;
    }
  }
  
  getLines(): string[] {
    const result: string[] = [];
    let current = this.head;
    
    for (let i = 0; i < this.size; i++) {
      result.push(this.buffer[current]);
      current = (current + 1) % this.maxSize;
    }
    
    return result;
  }
}
```

#### iOS Memory Management
```swift
class MemoryManager {
    private let memoryWarningThreshold: Int = 80_000_000  // 80MB
    private var memoryPressureObserver: NSObjectProtocol?
    
    func startMonitoring() {
        memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear terminal buffers
        // Reduce image caches
        // Pause background tasks
    }
    
    func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
```

### Week 1: Onboarding & Initial Setup
- VS Code extension first-run experience with API key generation
- Multi-URL QR code generation with local network detection
- iOS app onboarding flow with camera permissions
- Connection type selection (Local/Remote/Advanced)
- Network discovery and validation with mDNS

### Weeks 2-3: Core Infrastructure
- VS Code extension with multi-terminal support using Terminal API events
- REST API endpoints with rate limiting and authentication
- WebSocket streaming with message queuing and error recovery
- iOS app foundation with SwiftTerm integration and gesture recognition
- Secure credential storage using iOS Keychain with biometric authentication
- Basic terminal interaction with ANSI escape sequence parsing

## UI Component Specifications

### iOS App Interface Design

#### Terminal List View
```swift
struct TerminalListView: View {
    @StateObject var viewModel: TerminalViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(viewModel.terminals) { terminal in
                    TerminalCard(
                        terminal: terminal,
                        isActive: terminal.id == viewModel.activeTerminalId
                    )
                    .frame(width: 120, height: 80)
                    .onTapGesture {
                        HapticFeedback.lightImpact()
                        viewModel.selectTerminal(terminal)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 100)
    }
}
```

#### Command Shortcuts Bar
```swift
struct CommandShortcutsBar: View {
    @StateObject var shortcutViewModel: ShortcutViewModel
    @Binding var commandText: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(shortcutViewModel.shortcuts) { shortcut in
                    ShortcutButton(
                        shortcut: shortcut,
                        action: {
                            HapticFeedback.mediumImpact()
                            commandText = shortcut.command
                        }
                    )
                    .contextMenu {
                        Button("Edit", action: { 
                            shortcutViewModel.editShortcut(shortcut) 
                        })
                        Button("Delete", role: .destructive, action: { 
                            shortcutViewModel.deleteShortcut(shortcut) 
                        })
                    }
                }
                
                Button(action: { shortcutViewModel.showAddShortcut = true }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
}
```

### Gesture Recognition Implementation

#### Gesture Configuration
```swift
struct GestureConfiguration {
    static let minimumSwipeDistance: CGFloat = 50.0
    static let maximumSwipeTime: TimeInterval = 0.5
    static let pinchMinimumScale: CGFloat = 0.5
    static let pinchMaximumScale: CGFloat = 3.0
    static let longPressMinimumDuration: TimeInterval = 0.5
    static let tapTimeout: TimeInterval = 0.3
}
```

#### Gesture Handler
```swift
class GestureHandler: ObservableObject {
    @Published var fontSize: CGFloat = 14.0
    @Published var isSelecting = false
    
    private let hapticFeedback = HapticFeedback()
    private let terminalViewModel: TerminalViewModel
    
    // Pinch to Zoom
    func handlePinch(_ gesture: MagnificationGesture.Value) {
        let newSize = max(
            GestureConfiguration.pinchMinimumScale * 14,
            min(GestureConfiguration.pinchMaximumScale * 14, fontSize * gesture)
        )
        
        if abs(newSize - fontSize) > 0.5 {
            fontSize = newSize
            hapticFeedback.lightImpact()
        }
    }
    
    // Swipe Navigation
    func handleSwipe(_ direction: SwipeDirection) {
        hapticFeedback.mediumImpact()
        
        switch direction {
        case .left:
            terminalViewModel.selectNextTerminal()
        case .right:
            terminalViewModel.selectPreviousTerminal()
        default:
            break
        }
    }
    
    // Long Press Selection
    func handleLongPress(_ location: CGPoint) {
        hapticFeedback.heavyImpact()
        isSelecting = true
        // Start text selection at location
    }
}
```

### Network Resilience Implementation

#### Connection State Management
```swift
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(Error)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var canReconnect: Bool {
        switch self {
        case .disconnected, .failed:
            return true
        default:
            return false
        }
    }
}
```

#### Reconnection Strategy
```swift
class ReconnectionManager {
    private let maxRetries = 5
    private let baseDelay: TimeInterval = 1.0
    private var retryCount = 0
    private var reconnectionTask: Task<Void, Never>?
    
    func startReconnection(
        connectionProfile: ConnectionProfile,
        webSocketManager: WebSocketManager
    ) {
        reconnectionTask?.cancel()
        retryCount = 0
        
        reconnectionTask = Task {
            while retryCount < maxRetries && !Task.isCancelled {
                let delay = baseDelay * pow(2.0, Double(retryCount))
                
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                if Task.isCancelled { return }
                
                do {
                    try await webSocketManager.connect(
                        to: URL(string: connectionProfile.urls.first!)!,
                        with: connectionProfile.apiKey
                    )
                    return // Success
                } catch {
                    retryCount += 1
                    print("Reconnection attempt \(retryCount) failed: \(error)")
                }
            }
        }
    }
    
    func stopReconnection() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        retryCount = 0
    }
}
```

### Security Implementation Details

#### API Key Validation
```typescript
class SecurityManager {
  private readonly allowedIPRanges: string[] = [];
  private readonly rateLimiter = new Map<string, RateLimitInfo>();
  
  validateApiKey(key: string, clientIP: string): ValidationResult {
    // 1. Check rate limiting
    if (this.isRateLimited(clientIP)) {
      return { valid: false, reason: 'RATE_LIMITED' };
    }
    
    // 2. Validate IP whitelist
    if (!this.isIPAllowed(clientIP)) {
      return { valid: false, reason: 'IP_NOT_ALLOWED' };
    }
    
    // 3. Validate API key format
    if (!this.isValidKeyFormat(key)) {
      return { valid: false, reason: 'INVALID_FORMAT' };
    }
    
    // 4. Check key against hash
    const storedHash = this.getStoredKeyHash();
    if (!this.verifyKey(key, storedHash)) {
      return { valid: false, reason: 'INVALID_KEY' };
    }
    
    return { valid: true };
  }
  
  private verifyKey(key: string, hash: string): boolean {
    const computedHash = crypto
      .createHash('sha256')
      .update(key)
      .digest('hex');
    
    return crypto.timingSafeEqual(
      Buffer.from(computedHash),
      Buffer.from(hash)
    );
  }
}
```

#### Input Sanitization
```typescript
class InputSanitizer {
  private readonly dangerousCommands = [
    'rm -rf',
    'sudo',
    'chmod 777',
    '> /dev/sda',
    'mkfs',
    'dd if=',
    'format c:',
    ':(){:|:&};:'
  ];
  
  sanitizeCommand(command: string): SanitizationResult {
    // 1. Check for dangerous commands
    const lowerCommand = command.toLowerCase();
    for (const dangerous of this.dangerousCommands) {
      if (lowerCommand.includes(dangerous)) {
        return {
          safe: false,
          reason: `Potentially dangerous command: ${dangerous}`,
          sanitized: ''
        };
      }
    }
    
    // 2. Limit command length
    if (command.length > 1000) {
      return {
        safe: false,
        reason: 'Command too long',
        sanitized: command.substring(0, 1000)
      };
    }
    
    // 3. Remove null bytes and control characters
    const sanitized = command.replace(/[\x00-\x1F\x7F]/g, '');
    
    return {
      safe: true,
      sanitized
    };
  }
}
```

### Build and Deployment Specifications

#### VS Code Extension Package Configuration
```json
{
  "name": "mobile-terminal",
  "displayName": "Mobile Terminal",
  "description": "Access VS Code terminals from your mobile device",
  "version": "1.0.0",
  "engines": {
    "vscode": "^1.80.0"
  },
  "categories": ["Other"],
  "activationEvents": [
    "onStartupFinished"
  ],
  "main": "./dist/extension.js",
  "contributes": {
    "commands": [
      {
        "command": "mobileTerminal.start",
        "title": "Start Mobile Terminal Server"
      },
      {
        "command": "mobileTerminal.stop",
        "title": "Stop Mobile Terminal Server"
      },
      {
        "command": "mobileTerminal.showQR",
        "title": "Show Connection QR Code"
      },
      {
        "command": "mobileTerminal.rotateKey",
        "title": "Rotate API Key"
      }
    ],
    "configuration": {
      "type": "object",
      "title": "Mobile Terminal",
      "properties": {
        "mobileTerminal.server.port": {
          "type": "number",
          "default": 8092,
          "description": "Server port"
        },
        "mobileTerminal.server.host": {
          "type": "string",
          "default": "0.0.0.0",
          "description": "Server host"
        },
        "mobileTerminal.auth.allowedIPs": {
          "type": "array",
          "default": [],
          "description": "Allowed IP addresses"
        },
        "mobileTerminal.buffer.maxLines": {
          "type": "number",
          "default": 1000,
          "description": "Maximum buffer lines"
        }
      }
    }
  },
  "scripts": {
    "vscode:prepublish": "npm run build",
    "build": "webpack --mode production",
    "dev": "webpack --mode development --watch",
    "test": "jest",
    "lint": "eslint src --ext ts",
    "package": "vsce package"
  },
  "dependencies": {
    "express": "^4.18.0",
    "ws": "^8.14.0",
    "qrcode": "^1.5.0",
    "crypto": "^1.0.1",
    "mdns": "^2.7.0"
  },
  "devDependencies": {
    "@types/vscode": "^1.80.0",
    "@types/express": "^4.17.0",
    "@types/ws": "^8.5.0",
    "typescript": "^5.0.0",
    "webpack": "^5.88.0",
    "ts-loader": "^9.4.0",
    "eslint": "^8.45.0",
    "@typescript-eslint/eslint-plugin": "^6.0.0",
    "jest": "^29.6.0",
    "vsce": "^2.20.0"
  }
}
```

#### iOS App Build Configuration
```swift
// Package.swift
let package = Package(
    name: "MobileTerminal",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MobileTerminal",
            targets: ["MobileTerminal"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.4.0"),
        .package(url: "https://github.com/daltoniam/Starscream", from: "4.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "MobileTerminal",
            dependencies: [
                "SwiftTerm",
                "Starscream",
                "KeychainAccess"
            ]
        ),
        .testTarget(
            name: "MobileTerminalTests",
            dependencies: ["MobileTerminal"]
        ),
    ]
)
```

#### CI/CD Pipeline Configuration
```yaml
# .github/workflows/build.yml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test-vscode-extension:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-node@v3
      with:
        node-version: '18'
    - run: npm ci
    - run: npm run lint
    - run: npm run test
    - run: npm run build

  test-ios-app:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-swift@v1
    - run: swift test
    - run: swift build

  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: github/super-linter@v4
      env:
        DEFAULT_BRANCH: main
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Weeks 4-5: Terminal Management & Commands
- Terminal switching with gestures
- Custom command shortcuts system
- Shortcut editor interface
- Real-time output streaming
- Terminal session persistence

### Week 6: UI/UX Polish
- Gesture implementation (pinch-to-zoom, swipes)
- Keyboard integration with accessory bar
- Haptic feedback system
- Visual polish and animations
- Error state handling

### Week 7: Network & Performance
- Multi-network profile support
- Connection resilience
- Performance optimization
- Battery efficiency
- Offline handling

### Week 8: Testing & Release
- Comprehensive testing across devices
- TestFlight beta distribution
- App Store preparation
- Documentation finalization
- Launch preparation

## Phase 0: First-Time Setup & Onboarding (Week 1)

### VS Code Extension Setup

#### Initial Configuration
- **Auto-generate API key** on first run
- **Display connection panel** with:
  - All local network URLs (IPv4/IPv6)
  - Remote access instructions
  - Multi-URL QR code
  - Network setup guide links
- **Store securely** in VS Code storage
- **Port configuration** (default: 8092)

#### QR Code Generation
```typescript
interface ConnectionInfo {
  urls: {
    local: string[];      // ["192.168.1.100:8092", "terminal.local:8092"]
    remote?: string;      // "https://terminal.mydomain.com"
    custom?: string;      // User-defined URL
  };
  apiKey: string;
  version: string;
}
```

### iOS App Onboarding Flow

#### 1. Welcome Experience
- App branding and logo
- 3-slide feature overview:
  - "Access your terminals anywhere"
  - "Create custom command shortcuts"
  - "Seamless integration with Code-Server"
- "Get Started" button

#### 2. Connection Setup
**Connection Types:**
- **Local Network** - Same WiFi, direct connection
- **Remote Access** - Internet access via port forwarding/proxy
- **Advanced Setup** - VPN, tunnels, custom configurations

**Setup Methods:**
- **QR Code Scan** (recommended)
  - Camera permission request
  - Multi-URL parsing
  - Automatic best connection selection
- **Manual Entry**
  - Smart URL validation
  - Format support: IP:port, hostname, HTTPS URLs
  - API key secure entry
- **Network Discovery** (local only)
  - Scan for Code-Server instances
  - mDNS/Bonjour support
- **Demo Mode**
  - Try without setup
  - Simulated terminal experience

#### 3. Connection Validation
- Animated progress indicators
- Step-by-step feedback:
  - "Resolving hostname..."
  - "Connecting to server..."
  - "Validating credentials..."
  - "Loading terminals..."
- Error-specific troubleshooting
- Quick links to guides

#### 4. Success & Tips
- Save to Keychain
- Enable biometric auth (optional)
- Interactive gesture tutorial
- Highlight key features

## Phase 1: Core Infrastructure (Weeks 2-3)

### VS Code Extension Architecture

#### Project Structure
```
mobile-terminal-extension/
├── package.json
├── tsconfig.json
├── src/
│   ├── extension.ts          # Main activation
│   ├── server/
│   │   ├── app.ts           # Express setup
│   │   ├── routes.ts        # REST endpoints
│   │   └── websocket.ts     # WebSocket server
│   ├── services/
│   │   ├── terminal.ts      # Terminal management
│   │   ├── auth.ts          # API key validation
│   │   └── discovery.ts     # Network discovery
│   ├── utils/
│   │   ├── qrcode.ts        # QR generation
│   │   └── network.ts       # IP detection
│   └── types/
│       └── index.ts         # TypeScript types
└── resources/
    └── welcome.html         # Connection info UI
```

#### Core Services Implementation

**Terminal Service Features:**
- Monitor all VS Code terminals
- Track metadata (name, cwd, process)
- Detect Claude Code sessions
- Maintain output buffers (1000 lines)
- Handle input injection
- Support terminal switching

**API Endpoints:**
```
GET  /api/health              # Server status
GET  /api/terminals           # List all terminals
GET  /api/terminals/:id       # Terminal details
POST /api/terminals/:id/select # Switch active terminal
POST /api/terminal/input      # Send input to active
WS   /api/terminal/stream     # Real-time output
```

**Authentication:**
- API key in header: `X-API-Key`
- Rate limiting per key
- IP allowlist support
- Secure storage in VS Code

### iOS App Foundation

#### Architecture Pattern: MVVM + SwiftUI
```
MobileTerminal/
├── App/
│   ├── MobileTerminalApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── Models/
│   │   ├── Terminal.swift
│   │   ├── CommandShortcut.swift
│   │   └── ConnectionProfile.swift
│   ├── ViewModels/
│   │   ├── TerminalViewModel.swift
│   │   ├── ShortcutViewModel.swift
│   │   └── ConnectionViewModel.swift
│   ├── Services/
│   │   ├── APIClient.swift
│   │   ├── WebSocketManager.swift
│   │   ├── KeychainService.swift
│   │   └── NetworkMonitor.swift
│   └── Utils/
│       ├── HapticFeedback.swift
│       └── KeyboardObserver.swift
├── Features/
│   ├── Onboarding/
│   ├── Terminal/
│   ├── Shortcuts/
│   └── Settings/
└── Resources/
    ├── Theme.swift
    └── Assets.xcassets
```

#### Key Dependencies
- **SwiftTerm** - Terminal emulation
- **Starscream** - WebSocket client
- **KeychainAccess** - Secure storage
- **AVFoundation** - QR scanning

## Phase 2: Terminal Features (Weeks 4-5)

### Multi-Terminal Management

#### VS Code Extension
**Terminal Tracking:**
- Unique ID per terminal
- Name, working directory, process
- Active/inactive state
- Claude Code detection
- Creation/deletion events

**Output Management:**
- Separate buffers per terminal
- Circular buffer (1000 lines)
- ANSI escape sequence support
- Binary data filtering

#### iOS App Implementation
**Terminal List View:**
```swift
struct TerminalListView: View {
    @StateObject var viewModel: TerminalViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.terminals) { terminal in
                    TerminalCard(
                        terminal: terminal,
                        isActive: terminal.id == viewModel.activeTerminalId
                    )
                    .onTapGesture {
                        viewModel.selectTerminal(terminal)
                    }
                }
            }
            .padding()
        }
    }
}
```

**Terminal Switching:**
- Horizontal swipe gestures
- Visual transition animations
- State preservation
- Automatic reconnection

### Command Shortcuts System

#### Features
**Default Shortcuts:**
- `ls -la` - List files
- `pwd` - Current directory
- `git status` - Git status
- `clear` - Clear screen
- `cd ..` - Up directory
- `npm run` - NPM scripts
- `docker ps` - Docker containers
- `code .` - Open in VS Code

**Customization:**
- User-defined shortcuts
- Drag to reorder
- Categories (future)
- Import/export (future)

#### Implementation
**Shortcut Model:**
```swift
struct CommandShortcut: Identifiable, Codable {
    let id = UUID()
    var label: String       // Display text
    var command: String     // Actual command
    var position: Int       // Order in bar
    var icon: String?       // SF Symbol name
    var color: Color?       // Tint color
}
```

**Shortcut Bar UI:**
- Above keyboard placement
- Horizontal scrolling
- Long-press to edit
- Visual feedback
- Maximum 8 visible

**Editor Interface:**
- Label and command fields
- Position selector
- Icon picker (future)
- Test execution
- Delete option

## Phase 3: UI/UX Implementation (Week 6)

### Visual Design System

#### Color Palette (Dark Theme)
```swift
extension Color {
    static let terminalBackground = Color(hex: "#0C0C0C")
    static let terminalText = Color(hex: "#E0E0E0")
    static let terminalCursor = Color(hex: "#00FF00")
    static let terminalSelection = Color(hex: "#0080FF").opacity(0.3)
    static let statusBar = Color(hex: "#1A1A1A")
    static let keyboardBar = Color(hex: "#2A2A2A")
    static let accentColor = Color(hex: "#007AFF")
}
```

#### Typography
```swift
extension Font {
    static let terminalFont = Font.custom("SF Mono", size: 14)
        .monospaced()
    static let terminalFontBold = Font.custom("SF Mono", size: 14)
        .monospaced()
        .weight(.bold)
}
```

### Gesture System

#### Implementation Priority
1. **Pinch to Zoom** - Text size adjustment
2. **Swipe Left/Right** - Terminal switching
3. **Long Press** - Text selection / Shortcut editing
4. **Tap** - Cursor positioning
5. **Pull to Refresh** - Terminal list update
6. **Swipe Down** - Keyboard dismissal

#### Gesture Recognizers
```swift
extension View {
    func terminalGestures(viewModel: TerminalViewModel) -> some View {
        self
            .gesture(pinchGesture(viewModel))
            .gesture(swipeGesture(viewModel))
            .gesture(longPressGesture(viewModel))
            .onTapGesture { location in
                viewModel.handleTap(at: location)
            }
    }
}
```

### Keyboard Integration

#### Smart Keyboard Bar
**Special Characters Row:**
- Common symbols: `| > < & ~ / \`
- Tab key
- Escape key (future)
- Arrow keys (future)

**Integration Points:**
- Show with keyboard
- Smooth animations
- Adjust terminal view
- Maintain scroll position

#### Keyboard Handling
```swift
class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isVisible = false
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }
}
```

## Phase 4: Network & Performance (Week 7)

### Connection Management

#### Network Profiles
**Profile Structure:**
```swift
struct ConnectionProfile: Codable {
    let id = UUID()
    var name: String
    var urls: [String]          // Priority order
    var apiKey: String
    var autoConnect: Bool
    var networkSSIDs: [String]? // Auto-select by WiFi
}
```

**Multi-Network Support:**
- Local network (direct IP)
- Port forwarding (router NAT)
- Reverse proxy (nginx/Apache)
- Dynamic DNS (changing IPs)
- VPN access (corporate)
- Cloudflare Tunnel (zero-config)

#### Connection Resilience
**Retry Strategy:**
- Exponential backoff (1s, 2s, 4s, 8s)
- Maximum 5 retry attempts
- Network change detection
- Background reconnection
- Connection state UI

**Error Handling:**
```swift
enum ConnectionError: LocalizedError {
    case networkUnreachable
    case serverNotFound
    case authenticationFailed
    case certificateInvalid
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .networkUnreachable:
            return "No network connection"
        case .serverNotFound:
            return "Cannot reach server"
        // ... etc
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnreachable:
            return "Check your WiFi or cellular connection"
        case .serverNotFound:
            return "Verify server address and port forwarding"
        // ... etc
        }
    }
}
```

### Performance Optimization

#### Terminal Performance
**Buffer Management:**
- Circular buffer (1000 lines max)
- Virtual scrolling for large output
- Debounced updates (50ms)
- Background rendering queue
- Memory pressure handling

**Rendering Optimization:**
```swift
class TerminalRenderer {
    private let updateDebouncer = Debouncer(delay: 0.05)
    private let renderQueue = DispatchQueue(label: "terminal.render")
    
    func processOutput(_ text: String) {
        renderQueue.async { [weak self] in
            // Process ANSI codes
            // Update buffer
            self?.updateDebouncer.debounce {
                // Update UI on main thread
            }
        }
    }
}
```

#### Battery Optimization
- Pause WebSocket when backgrounded
- Reduce update frequency on low battery
- Efficient text rendering with Metal
- Minimal background CPU usage
- Smart polling intervals

## Phase 5: Testing & Deployment (Week 8)

### Testing Strategy

#### Unit Tests
**Coverage Goals:**
- Models: 100%
- ViewModels: 90%
- Services: 85%
- Overall: 80%

**Test Categories:**
- Connection handling
- Terminal parsing
- Shortcut management
- Network resilience
- Error scenarios

#### Integration Tests
- VS Code ↔ iOS communication
- WebSocket streaming
- Authentication flow
- Terminal switching
- Command execution

#### UI Tests
- Onboarding completion
- Gesture recognition
- Keyboard interaction
- Error state handling
- Settings management

#### Device Testing Matrix
- iPhone 12 mini (5.4")
- iPhone 14 (6.1")
- iPhone 14 Pro Max (6.7")
- iOS 16.0 - 17.x
- Light/Dark mode
- Various network speeds

### Beta Testing Plan

#### TestFlight Setup
- **Week 8, Day 1-2:** Internal testing (5 users)
- **Week 8, Day 3-5:** Beta group (20 users)
- **Feedback collection:** In-app + surveys
- **Crash reporting:** Firebase Crashlytics
- **Analytics:** Basic usage metrics

### App Store Release

#### Submission Checklist
- [ ] App Store Connect configuration
- [ ] Screenshots (all device sizes)
- [ ] App preview video (optional)
- [ ] Description and keywords
- [ ] Privacy policy URL
- [ ] Support documentation
- [ ] Demo mode for reviewers
- [ ] Export compliance

#### Marketing Materials
- Landing page
- Setup video tutorial
- Network configuration guides
- FAQ documentation
- Support email setup

## Success Metrics

### MVP Success Criteria (From PRD)
- ✅ Connect to code-server from iOS app
- ✅ View and switch between 5+ terminals
- ✅ Execute commands via shortcuts
- ✅ Maintain session state
- ✅ Sub-2-second terminal switching
- ✅ 95%+ command execution success

### Launch Metrics
- Onboarding completion: > 90%
- Daily active users: > 60%
- Crash-free rate: > 99.5%
- Connection success: > 95%
- User retention (7-day): > 50%

### Performance Targets
- Connection time: < 2 seconds
- Terminal latency: < 100ms
- Smooth 60fps scrolling
- Memory usage: < 100MB
- Battery drain: < 5% per hour

## Risk Mitigation

### Technical Risks
**High Priority:**
- Terminal security vulnerabilities
  - Mitigation: Input sanitization, sandboxing
- iOS App Store rejection
  - Mitigation: Follow guidelines, demo mode
- WebSocket connection issues
  - Mitigation: Fallback to polling

**Medium Priority:**
- VS Code API changes
  - Mitigation: Version checks, graceful degradation
- SwiftTerm compatibility
  - Mitigation: Fork and maintain if needed
- Network configuration complexity
  - Mitigation: Comprehensive guides, auto-detection

### Future Enhancements (Post-MVP)

**Phase 1 (3 months):**
- Command history sync
- Terminal themes
- Landscape mode
- iPad optimization
- SSH tunnel support

**Phase 2 (6 months):**
- Android version
- Command macros
- Team sharing
- Cloud backup
- Voice commands

**Phase 3 (12 months):**
- AI command suggestions
- Git integration
- File browser
- Multi-window (iPad)
- Extension marketplace

## Maintenance & Support

### Regular Updates
- Security patches: Monthly
- Feature updates: Quarterly
- iOS compatibility: As needed
- Dependency updates: Monthly
- Performance tuning: Ongoing

### Support Infrastructure
- In-app feedback system
- GitHub issue tracking
- Discord community
- Video tutorials
- Knowledge base

## Implementation Notes

### Key Decisions Made
1. **API Keys over JWT** - Simpler implementation, adequate security
2. **Single active terminal** - Reduces complexity, covers 90% use case
3. **Local shortcut storage** - No sync complexity in MVP
4. **Native iOS only** - Better experience than React Native
5. **1000 line buffer** - Balance between history and memory

### Dependencies Locked
- VS Code: 1.80+
- iOS: 16.0+
- Swift: 5.9+
- Node.js: 18+
- TypeScript: 5.0+

### Code Quality Standards
- SwiftLint for iOS
- ESLint for TypeScript
- 80% test coverage minimum
- PR reviews required
- CI/CD via GitHub Actions

---

This consolidated plan incorporates all features from the PRD and combines the best elements from both implementation plans, providing a clear 8-week roadmap to MVP launch.