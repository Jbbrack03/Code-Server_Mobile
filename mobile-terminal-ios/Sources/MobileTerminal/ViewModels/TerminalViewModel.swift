import Foundation
import Combine

/// ViewModel responsible for managing terminal state and operations
@MainActor
public class TerminalViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var terminals: [Terminal] = []
    @Published public private(set) var activeTerminalId: String?
    @Published public var connectionState: ConnectionState = .disconnected
    @Published public private(set) var isLoading = false
    @Published public var error: TerminalError?
    @Published public private(set) var terminalBuffer: [String] = []
    
    // MARK: - Properties
    
    public var currentProfile: ConnectionProfile?
    private let apiClient: APIClient
    private let webSocketManager: MobileTerminalWebSocketClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    public var activeTerminal: Terminal? {
        guard let activeTerminalId = activeTerminalId else { return nil }
        return terminals.first { $0.id == activeTerminalId }
    }
    
    // MARK: - Initialization
    
    public init(apiClient: APIClient, webSocketManager: MobileTerminalWebSocketClient) {
        self.apiClient = apiClient
        self.webSocketManager = webSocketManager
        
        setupWebSocketHandlers()
        setupConnectionStateObserver()
    }
    
    // MARK: - Setup
    
    private func setupWebSocketHandlers() {
        webSocketManager.onMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleWebSocketMessage(message)
            }
        }
        
        webSocketManager.onConnectionStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
            }
        }
        
        webSocketManager.onError = { [weak self] error in
            Task { @MainActor in
                self?.handleError(.webSocketError(error))
            }
        }
    }
    
    private func setupConnectionStateObserver() {
        webSocketManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection Management
    
    public func connect(profile: ConnectionProfile) async {
        currentProfile = profile
        
        guard let urlString = profile.urls.first,
              let url = URL(string: urlString) else {
            handleError(.invalidInput(message: "Invalid URL in connection profile"))
            return
        }
        
        await webSocketManager.connect(to: url, with: profile.apiKey)
    }
    
    public func disconnect() async {
        webSocketManager.disconnect()
        terminals.removeAll()
        activeTerminalId = nil
        terminalBuffer.removeAll()
        connectionState = .disconnected
    }
    
    public func reconnect() async {
        guard let profile = currentProfile else {
            handleError(.noConnectionProfile)
            return
        }
        
        await connect(profile: profile)
    }
    
    // MARK: - Server Health
    
    public func checkServerHealth() async -> Bool {
        do {
            let health = try await apiClient.getHealth()
            return health.status == .healthy
        } catch {
            return false
        }
    }
    
    // MARK: - Terminal Management
    
    public func loadTerminals() async {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiClient.getTerminals()
            terminals = response.terminals
            activeTerminalId = response.activeTerminalId
            
            // Load buffer for active terminal
            if activeTerminalId != nil {
                await loadTerminalBuffer()
            }
        } catch {
            handleError(.apiError(error as? APIError ?? .unknown(error)))
        }
        
        isLoading = false
    }
    
    public func selectTerminal(_ terminal: Terminal) async {
        error = nil
        
        do {
            let response = try await apiClient.selectTerminal(id: terminal.id)
            if response.success {
                activeTerminalId = response.activeTerminalId
                
                // Update terminal state locally
                terminals = terminals.map { terminal in
                    if terminal.id == activeTerminalId {
                        return Terminal(
                            id: terminal.id,
                            name: terminal.name,
                            pid: terminal.pid,
                            cwd: terminal.cwd,
                            shellType: terminal.shellType,
                            isActive: true,
                            isClaudeCode: terminal.isClaudeCode,
                            createdAt: terminal.createdAt,
                            lastActivity: terminal.lastActivity,
                            dimensions: terminal.dimensions,
                            status: terminal.status
                        )
                    } else if terminal.isActive {
                        return Terminal(
                            id: terminal.id,
                            name: terminal.name,
                            pid: terminal.pid,
                            cwd: terminal.cwd,
                            shellType: terminal.shellType,
                            isActive: false,
                            isClaudeCode: terminal.isClaudeCode,
                            createdAt: terminal.createdAt,
                            lastActivity: terminal.lastActivity,
                            dimensions: terminal.dimensions,
                            status: terminal.status
                        )
                    }
                    return terminal
                }
                
                // Clear and reload buffer for new terminal
                terminalBuffer.removeAll()
                await loadTerminalBuffer()
                
                // Send WebSocket message
                let message = WebSocketMessage.terminalSelect(terminalId: terminal.id)
                try? await webSocketManager.sendMessage(message)
            }
        } catch {
            handleError(.apiError(error as? APIError ?? .unknown(error)))
        }
    }
    
    public func selectNextTerminal() async {
        guard !terminals.isEmpty else { return }
        
        let currentIndex = terminals.firstIndex { $0.id == activeTerminalId } ?? -1
        let nextIndex = (currentIndex + 1) % terminals.count
        
        await selectTerminal(terminals[nextIndex])
    }
    
    public func selectPreviousTerminal() async {
        guard !terminals.isEmpty else { return }
        
        let currentIndex = terminals.firstIndex { $0.id == activeTerminalId } ?? 0
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : terminals.count - 1
        
        await selectTerminal(terminals[previousIndex])
    }
    
    // MARK: - Terminal Interaction
    
    public func sendInput(_ input: String) async {
        guard let activeTerminalId = activeTerminalId else {
            handleError(.noActiveTerminal)
            return
        }
        
        error = nil
        
        do {
            // Send via API
            let response = try await apiClient.sendInput(terminalId: activeTerminalId, data: input)
            
            if response.success {
                // Send via WebSocket for real-time update
                let message = WebSocketMessage.terminalInput(terminalId: activeTerminalId, data: input)
                try await webSocketManager.sendMessage(message)
            }
        } catch {
            handleError(.apiError(error as? APIError ?? .unknown(error)))
        }
    }
    
    public func resizeTerminal(cols: Int, rows: Int) async {
        guard let activeTerminalId = activeTerminalId else {
            handleError(.noActiveTerminal)
            return
        }
        
        error = nil
        
        do {
            // Send via API
            let response = try await apiClient.resizeTerminal(terminalId: activeTerminalId, cols: cols, rows: rows)
            
            if response.success {
                // Send via WebSocket for real-time update
                let message = WebSocketMessage.terminalResize(terminalId: activeTerminalId, cols: cols, rows: rows)
                try await webSocketManager.sendMessage(message)
                
                // Update local terminal dimensions
                if let index = terminals.firstIndex(where: { $0.id == activeTerminalId }) {
                    let terminal = terminals[index]
                    terminals[index] = Terminal(
                        id: terminal.id,
                        name: terminal.name,
                        pid: terminal.pid,
                        cwd: terminal.cwd,
                        shellType: terminal.shellType,
                        isActive: terminal.isActive,
                        isClaudeCode: terminal.isClaudeCode,
                        createdAt: terminal.createdAt,
                        lastActivity: terminal.lastActivity,
                        dimensions: Terminal.Dimensions(cols: cols, rows: rows),
                        status: terminal.status
                    )
                }
            }
        } catch {
            handleError(.apiError(error as? APIError ?? .unknown(error)))
        }
    }
    
    // MARK: - Terminal Buffer
    
    public func loadTerminalBuffer() async {
        guard let activeTerminalId = activeTerminalId else { return }
        
        do {
            let response = try await apiClient.getTerminal(id: activeTerminalId)
            terminalBuffer = response.buffer
        } catch {
            // Don't show error for buffer loading failures
            print("Failed to load terminal buffer: \(error)")
        }
    }
    
    public func appendToBuffer(_ output: String) {
        terminalBuffer.append(output)
        
        // Limit buffer size to prevent memory issues
        let maxBufferSize = 1000
        if terminalBuffer.count > maxBufferSize {
            terminalBuffer.removeFirst(terminalBuffer.count - maxBufferSize)
        }
    }
    
    public func clearBuffer() {
        terminalBuffer.removeAll()
    }
    
    // MARK: - WebSocket Message Handling
    
    public func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case .terminalOutput:
            handleTerminalOutput(message)
            
        case .terminalList:
            handleTerminalList(message)
            
        case .error:
            handleErrorMessage(message)
            
        case .connectionPong:
            // Handle pong to maintain connection
            break
            
        default:
            break
        }
    }
    
    private func handleTerminalOutput(_ message: WebSocketMessage) {
        guard let terminalId = message.payload["terminalId"] as? String,
              let data = message.payload["data"] as? String,
              terminalId == activeTerminalId else {
            return
        }
        
        appendToBuffer(data)
    }
    
    private func handleTerminalList(_ message: WebSocketMessage) {
        // Update terminal list from WebSocket if needed
        // This could be used for real-time terminal updates
    }
    
    private func handleErrorMessage(_ message: WebSocketMessage) {
        if message.payload["code"] != nil,
           message.payload["message"] != nil {
            let wsError = WebSocketError.invalidMessage
            handleError(.webSocketError(wsError))
        }
    }
    
    // MARK: - Error Handling
    
    public func handleError(_ error: TerminalError) {
        self.error = error
    }
    
    public func showError(_ error: TerminalError) {
        self.error = error
    }
}

// MARK: - TerminalError

public enum TerminalError: Error, Equatable, LocalizedError {
    case networkError(message: String)
    case terminalNotFound(id: String)
    case noActiveTerminal
    case noConnectionProfile
    case invalidInput(message: String)
    case webSocketError(WebSocketError)
    case apiError(APIError)
    
    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .terminalNotFound(let id):
            return "Terminal not found: \(id)"
        case .noActiveTerminal:
            return "No active terminal selected"
        case .noConnectionProfile:
            return "No connection profile available"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .webSocketError(let error):
            return "WebSocket error: \(error.localizedDescription)"
        case .apiError(let error):
            return "API error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .terminalNotFound:
            return "The terminal may have been closed. Refresh the terminal list."
        case .noActiveTerminal:
            return "Select a terminal from the list."
        case .noConnectionProfile:
            return "Configure a connection profile first."
        case .invalidInput:
            return "Check your input and try again."
        case .webSocketError:
            return "Check your connection and try reconnecting."
        case .apiError(let error):
            return error.recoverySuggestion
        }
    }
}