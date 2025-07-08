# VS Code Extension Technical Specification
## Mobile Terminal Manager Extension

### Overview
This VS Code extension exposes terminal session management capabilities through REST APIs and WebSocket connections, enabling mobile devices to interact with code-server terminal sessions.

### Technical Stack
- **Language**: TypeScript 5.x
- **Runtime**: Node.js 18+
- **Framework**: VS Code Extension API
- **HTTP Server**: Express.js 4.x
- **WebSocket**: ws 8.x
- **Authentication**: JSON Web Tokens (JWT)
- **Build Tool**: esbuild
- **Testing**: Jest + VS Code Extension Test Framework

### Architecture

#### Core Components

1. **Extension Activation**
   ```typescript
   export function activate(context: vscode.ExtensionContext) {
     // Initialize terminal manager
     const terminalManager = new TerminalManager();
     
     // Start API server
     const apiServer = new ApiServer(terminalManager);
     
     // Register commands
     registerCommands(context, terminalManager);
     
     // Start monitoring terminals
     terminalManager.startMonitoring();
   }
   ```

2. **Terminal Manager**
   - Tracks all active terminal instances
   - Monitors terminal lifecycle events
   - Detects Claude Code processes
   - Maintains terminal metadata
   - Handles command injection

3. **API Server**
   - Express.js server on configurable port (default: 8092)
   - JWT-based authentication middleware
   - CORS configuration for mobile access
   - Rate limiting for security
   - Request validation using express-validator

4. **WebSocket Manager**
   - Real-time terminal output streaming
   - Connection pooling
   - Heartbeat mechanism
   - Automatic reconnection handling
   - Message queuing for offline clients

### API Endpoints

#### Authentication
```typescript
POST /api/auth/login
Body: { username: string, password: string }
Response: { token: string, expiresIn: number }

POST /api/auth/refresh
Headers: { Authorization: "Bearer <token>" }
Response: { token: string, expiresIn: number }

POST /api/auth/logout
Headers: { Authorization: "Bearer <token>" }
Response: { success: boolean }
```

#### Terminal Management
```typescript
GET /api/terminals
Headers: { Authorization: "Bearer <token>" }
Response: Terminal[]

GET /api/terminals/:id
Headers: { Authorization: "Bearer <token>" }
Response: TerminalDetails

POST /api/terminals
Headers: { Authorization: "Bearer <token>" }
Body: { name: string, cwd?: string }
Response: Terminal

POST /api/terminals/:id/command
Headers: { Authorization: "Bearer <token>" }
Body: { command: string, addNewline?: boolean }
Response: { success: boolean }

DELETE /api/terminals/:id
Headers: { Authorization: "Bearer <token>" }
Response: { success: boolean }

GET /api/terminals/:id/status
Headers: { Authorization: "Bearer <token>" }
Response: TerminalStatus
```

#### Claude Code Integration
```typescript
GET /api/claude/status
Headers: { Authorization: "Bearer <token>" }
Response: { terminals: ClaudeTerminal[] }

POST /api/claude/commands
Headers: { Authorization: "Bearer <token>" }
Body: { terminalId: string, command: string, type: ClaudeCommandType }
Response: { success: boolean, messageId: string }

GET /api/claude/commands/templates
Headers: { Authorization: "Bearer <token>" }
Response: CommandTemplate[]
```

#### WebSocket Endpoints
```typescript
WS /api/terminals/:id/stream
Headers: { Authorization: "Bearer <token>" }
Messages:
  - Client → Server: { type: "subscribe" | "unsubscribe" }
  - Server → Client: { type: "output", data: string, timestamp: number }
  - Server → Client: { type: "status", status: TerminalStatus }
  - Server → Client: { type: "error", message: string }
```

### Data Models

```typescript
interface Terminal {
  id: string;
  name: string;
  pid: number;
  cwd: string;
  isClaudeActive: boolean;
  createdAt: Date;
  lastActivity: Date;
}

interface TerminalDetails extends Terminal {
  env: Record<string, string>;
  dimensions: { cols: number; rows: number };
  processName: string;
  exitCode?: number;
}

interface TerminalStatus {
  id: string;
  isActive: boolean;
  isClaudeActive: boolean;
  lastCommand?: string;
  lastActivity: Date;
}

interface ClaudeTerminal {
  terminalId: string;
  sessionId: string;
  mode: "chat" | "autonomous";
  startedAt: Date;
}

interface CommandTemplate {
  id: string;
  name: string;
  command: string;
  description: string;
  category: string;
  placeholders?: string[];
}
```

### Security Implementation

1. **Authentication Flow**
   - Initial authentication via username/password
   - JWT tokens with 24-hour expiration
   - Refresh tokens stored in VS Code SecretStorage
   - Token rotation on each refresh

2. **Authorization**
   - All endpoints require valid JWT token
   - Terminal access scoped to authenticated user
   - Command injection validated and sanitized
   - Rate limiting: 100 requests per minute per IP

3. **Data Protection**
   - HTTPS required for production
   - WebSocket Secure (WSS) for streaming
   - Input sanitization for command injection
   - Output filtering for sensitive data

### Terminal Monitoring

```typescript
class TerminalManager {
  private terminals: Map<string, TerminalInfo> = new Map();
  
  startMonitoring() {
    // Monitor existing terminals
    vscode.window.terminals.forEach(term => this.trackTerminal(term));
    
    // Listen for new terminals
    vscode.window.onDidOpenTerminal(term => this.trackTerminal(term));
    
    // Listen for closed terminals
    vscode.window.onDidCloseTerminal(term => this.untrackTerminal(term));
    
    // Monitor terminal data changes
    vscode.window.onDidWriteTerminalData(event => this.handleTerminalData(event));
  }
  
  private detectClaudeCode(terminal: vscode.Terminal): boolean {
    // Implementation to detect Claude Code process
    // Check process name, environment variables, etc.
  }
}
```

### Configuration

```json
{
  "mobileTerminal.server.port": 8092,
  "mobileTerminal.server.host": "0.0.0.0",
  "mobileTerminal.auth.enabled": true,
  "mobileTerminal.auth.tokenExpiration": "24h",
  "mobileTerminal.cors.allowedOrigins": ["*"],
  "mobileTerminal.rateLimit.windowMs": 60000,
  "mobileTerminal.rateLimit.max": 100,
  "mobileTerminal.terminal.outputBufferSize": 10000,
  "mobileTerminal.terminal.commandTimeout": 30000
}
```

### Error Handling

1. **API Errors**
   - Consistent error response format
   - Proper HTTP status codes
   - Detailed error messages in development
   - Generic messages in production

2. **Terminal Errors**
   - Graceful handling of terminal crashes
   - Automatic cleanup of dead terminals
   - Error notifications to connected clients
   - Retry logic for recoverable errors

### Performance Considerations

1. **Terminal Output Buffering**
   - Ring buffer for terminal output (10k lines default)
   - Debounced output streaming (50ms)
   - Compression for large outputs
   - Pagination for history requests

2. **Resource Management**
   - Maximum 50 concurrent WebSocket connections
   - Connection pooling with LRU eviction
   - Memory monitoring and cleanup
   - CPU throttling for intensive operations

### Testing Strategy

1. **Unit Tests**
   - Terminal manager logic
   - API endpoint handlers
   - Authentication/authorization
   - Data validation

2. **Integration Tests**
   - VS Code Extension API interactions
   - Terminal command execution
   - WebSocket streaming
   - End-to-end authentication flow

3. **Performance Tests**
   - Load testing with multiple terminals
   - WebSocket connection stress testing
   - Memory leak detection
   - Response time benchmarking

### Deployment

1. **Extension Package**
   - Bundle with esbuild
   - Minimize dependencies
   - Include only production code
   - Sign extension for marketplace

2. **Configuration**
   - Environment-specific settings
   - Secure credential storage
   - Logging configuration
   - Performance monitoring setup

### Monitoring and Logging

1. **Logging**
   - Structured logging with winston
   - Log levels: error, warn, info, debug
   - Rotating log files
   - Remote log aggregation support

2. **Metrics**
   - API request counts and latency
   - WebSocket connection metrics
   - Terminal operation statistics
   - Error rates and types

### Future Enhancements

1. **Advanced Features**
   - Terminal session recording
   - Collaborative terminal sharing
   - AI-powered command suggestions
   - Terminal multiplexing

2. **Performance Optimizations**
   - WebRTC for lower latency
   - Binary protocol for efficiency
   - Edge caching for static data
   - Predictive command loading