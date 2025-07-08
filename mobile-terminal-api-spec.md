# Mobile Terminal API Specification
## REST API and WebSocket Protocol Documentation

### API Overview

Base URL: `https://code.brackinhouse.familyds.net:8092/api`

The Mobile Terminal API provides programmatic access to terminal sessions running in VS Code/code-server. All endpoints require authentication except for the health check.

### Authentication

The API uses JWT (JSON Web Token) based authentication with bearer tokens.

#### Token Lifecycle
1. Client authenticates with username/password
2. Server returns JWT token (24-hour expiration)
3. Client includes token in Authorization header
4. Client refreshes token before expiration
5. Server validates token on each request

### REST API Endpoints

#### Health Check
```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 3600,
  "terminals": {
    "active": 5,
    "max": 50
  }
}
```

#### Authentication Endpoints

##### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "user@example.com",
  "password": "secure_password"
}
```

**Success Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 86400,
  "refreshToken": "refresh_token_here",
  "user": {
    "id": "user123",
    "username": "user@example.com"
  }
}
```

**Error Response (401):**
```json
{
  "error": "INVALID_CREDENTIALS",
  "message": "Invalid username or password"
}
```

##### Refresh Token
```http
POST /api/auth/refresh
Authorization: Bearer <token>
Content-Type: application/json

{
  "refreshToken": "refresh_token_here"
}
```

**Response:**
```json
{
  "token": "new_jwt_token",
  "expiresIn": 86400
}
```

##### Logout
```http
POST /api/auth/logout
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

#### Terminal Management Endpoints

##### List All Terminals
```http
GET /api/terminals
Authorization: Bearer <token>
```

**Query Parameters:**
- `active` (boolean): Filter only active terminals
- `claude` (boolean): Filter only terminals with Claude Code running

**Response:**
```json
{
  "terminals": [
    {
      "id": "term_1234",
      "name": "Project Backend",
      "pid": 12345,
      "cwd": "/home/user/projects/backend",
      "isClaudeActive": true,
      "createdAt": "2025-01-07T10:00:00Z",
      "lastActivity": "2025-01-07T10:30:00Z",
      "status": "active"
    }
  ],
  "count": 1
}
```

##### Get Terminal Details
```http
GET /api/terminals/{terminalId}
Authorization: Bearer <token>
```

**Response:**
```json
{
  "id": "term_1234",
  "name": "Project Backend",
  "pid": 12345,
  "cwd": "/home/user/projects/backend",
  "isClaudeActive": true,
  "createdAt": "2025-01-07T10:00:00Z",
  "lastActivity": "2025-01-07T10:30:00Z",
  "status": "active",
  "env": {
    "PATH": "/usr/local/bin:/usr/bin:/bin",
    "NODE_ENV": "development"
  },
  "dimensions": {
    "cols": 80,
    "rows": 24
  },
  "processName": "bash",
  "history": {
    "available": true,
    "lines": 1000
  }
}
```

##### Create New Terminal
```http
POST /api/terminals
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "New Project Terminal",
  "cwd": "/home/user/projects/new-project",
  "env": {
    "NODE_ENV": "development"
  }
}
```

**Response (201):**
```json
{
  "id": "term_5678",
  "name": "New Project Terminal",
  "pid": 23456,
  "cwd": "/home/user/projects/new-project",
  "createdAt": "2025-01-07T11:00:00Z"
}
```

##### Execute Command
```http
POST /api/terminals/{terminalId}/command
Authorization: Bearer <token>
Content-Type: application/json

{
  "command": "npm test",
  "addNewline": true
}
```

**Response:**
```json
{
  "success": true,
  "commandId": "cmd_9876",
  "timestamp": "2025-01-07T11:05:00Z"
}
```

##### Get Terminal History
```http
GET /api/terminals/{terminalId}/history
Authorization: Bearer <token>
```

**Query Parameters:**
- `lines` (number): Number of lines to retrieve (default: 1000, max: 10000)
- `offset` (number): Offset from the end (default: 0)

**Response:**
```json
{
  "terminalId": "term_1234",
  "lines": [
    {
      "line": 1,
      "content": "$ npm install",
      "timestamp": "2025-01-07T10:00:00Z"
    },
    {
      "line": 2,
      "content": "added 150 packages in 3.2s",
      "timestamp": "2025-01-07T10:00:03Z"
    }
  ],
  "totalLines": 1000,
  "hasMore": true
}
```

##### Delete Terminal
```http
DELETE /api/terminals/{terminalId}
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true,
  "message": "Terminal closed successfully"
}
```

#### Claude Code Integration Endpoints

##### Get Claude Status
```http
GET /api/claude/status
Authorization: Bearer <token>
```

**Response:**
```json
{
  "terminals": [
    {
      "terminalId": "term_1234",
      "sessionId": "claude_sess_789",
      "mode": "chat",
      "startedAt": "2025-01-07T10:00:00Z",
      "lastInteraction": "2025-01-07T10:25:00Z",
      "stats": {
        "messagesExchanged": 15,
        "commandsExecuted": 8
      }
    }
  ]
}
```

##### Execute Claude Command
```http
POST /api/claude/commands
Authorization: Bearer <token>
Content-Type: application/json

{
  "terminalId": "term_1234",
  "command": "/explain this function",
  "type": "chat",
  "context": {
    "file": "/path/to/file.js",
    "line": 42
  }
}
```

**Response:**
```json
{
  "success": true,
  "messageId": "msg_456",
  "queuePosition": 0
}
```

##### Get Command Templates
```http
GET /api/claude/commands/templates
Authorization: Bearer <token>
```

**Response:**
```json
{
  "templates": [
    {
      "id": "tpl_001",
      "name": "Explain Code",
      "command": "/explain {selection}",
      "description": "Explain the selected code",
      "category": "Analysis",
      "placeholders": ["selection"]
    },
    {
      "id": "tpl_002",
      "name": "Fix Bug",
      "command": "/fix the bug in {function}",
      "description": "Fix bugs in the specified function",
      "category": "Debugging",
      "placeholders": ["function"]
    }
  ]
}
```

### WebSocket API

#### Connection
```
wss://code.brackinhouse.familyds.net:8092/api/terminals/{terminalId}/stream
```

**Headers:**
```
Authorization: Bearer <token>
Sec-WebSocket-Protocol: terminal.v1
```

#### Message Protocol

##### Client to Server Messages

**Subscribe to Terminal:**
```json
{
  "type": "subscribe",
  "terminalId": "term_1234"
}
```

**Unsubscribe from Terminal:**
```json
{
  "type": "unsubscribe",
  "terminalId": "term_1234"
}
```

**Send Input:**
```json
{
  "type": "input",
  "data": "ls -la\n"
}
```

**Resize Terminal:**
```json
{
  "type": "resize",
  "cols": 120,
  "rows": 40
}
```

**Heartbeat:**
```json
{
  "type": "ping",
  "timestamp": 1704625200000
}
```

##### Server to Client Messages

**Terminal Output:**
```json
{
  "type": "output",
  "data": "file1.txt\nfile2.txt\n",
  "timestamp": 1704625200000
}
```

**Terminal Status Update:**
```json
{
  "type": "status",
  "status": {
    "active": true,
    "claudeActive": true,
    "lastCommand": "npm test",
    "exitCode": null
  }
}
```

**Error Message:**
```json
{
  "type": "error",
  "code": "TERMINAL_NOT_FOUND",
  "message": "Terminal term_1234 not found"
}
```

**Connection Acknowledgment:**
```json
{
  "type": "connected",
  "terminalId": "term_1234",
  "sessionId": "ws_sess_789"
}
```

**Heartbeat Response:**
```json
{
  "type": "pong",
  "timestamp": 1704625200000
}
```

### Error Codes and Responses

#### HTTP Status Codes
- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Missing or invalid authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

#### Error Response Format
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional context"
    },
    "timestamp": "2025-01-07T12:00:00Z",
    "requestId": "req_abc123"
  }
}
```

#### Common Error Codes
- `INVALID_CREDENTIALS`: Authentication failed
- `TOKEN_EXPIRED`: JWT token has expired
- `TERMINAL_NOT_FOUND`: Terminal ID does not exist
- `COMMAND_TIMEOUT`: Command execution timed out
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `INVALID_PARAMETER`: Request parameter validation failed
- `WEBSOCKET_ERROR`: WebSocket connection error
- `CLAUDE_NOT_ACTIVE`: Claude Code is not running in terminal

### Rate Limiting

Rate limits are enforced per IP address and per authenticated user:

- **Anonymous requests**: 10 requests per minute
- **Authenticated requests**: 100 requests per minute
- **WebSocket connections**: 10 concurrent connections per user
- **Command execution**: 30 commands per minute per terminal

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1704625260
```

### Pagination

List endpoints support pagination:

**Request:**
```http
GET /api/terminals?page=2&limit=20
```

**Response Headers:**
```
X-Total-Count: 45
X-Page-Count: 3
Link: <https://api.example.com/terminals?page=3&limit=20>; rel="next",
      <https://api.example.com/terminals?page=1&limit=20>; rel="prev"
```

### Data Formats

- **Dates**: ISO 8601 format (e.g., `2025-01-07T12:00:00Z`)
- **IDs**: String format, alphanumeric with underscores
- **Encoding**: UTF-8 for all text data
- **Content-Type**: `application/json` for all requests/responses

### Security Headers

All API responses include security headers:
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'none'
```

### CORS Configuration

For web-based clients:
```
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Max-Age: 86400
```

### SDK Examples

#### JavaScript/TypeScript
```typescript
import { TerminalClient } from '@mobile-terminal/sdk';

const client = new TerminalClient({
  baseURL: 'https://code.brackinhouse.familyds.net:8092',
  auth: {
    username: 'user@example.com',
    password: 'secure_password'
  }
});

// List terminals
const terminals = await client.terminals.list();

// Execute command
await client.terminals.executeCommand('term_1234', 'npm test');

// Stream output
const stream = client.terminals.stream('term_1234');
stream.on('output', (data) => console.log(data));
```

#### Swift (iOS)
```swift
let client = TerminalAPIClient(
    baseURL: URL(string: "https://code.brackinhouse.familyds.net:8092")!
)

// Authenticate
try await client.authenticate(username: "user", password: "pass")

// List terminals
let terminals = try await client.fetchTerminals()

// Stream terminal
let stream = client.streamTerminal(id: "term_1234")
for await output in stream {
    print(output)
}
```