# Integration Test Specification

This document defines the exact behavior we expect from our Mobile Terminal extension integration tests following TDD principles.

## Test Coverage Requirements

### 1. Server Lifecycle Management
- **Starting the server** should:
  - Initialize Express server on specified port
  - Initialize WebSocket server on HTTP server
  - Generate and store API key if none exists
  - Return server status with URLs and API key
  - Fail if port is already in use

- **Stopping the server** should:
  - Close all WebSocket connections gracefully
  - Stop the HTTP server
  - Clean up resources
  - Return success status

### 2. HTTP API Endpoints
- **Health endpoint** (`GET /api/health`) should:
  - Return 200 status
  - Include server health status
  - Include uptime information
  - Include terminal count
  - Not require authentication

- **Terminal endpoints** should:
  - `GET /api/terminals` - return list of terminals with authentication
  - `GET /api/terminals/:id` - return specific terminal with authentication
  - `POST /api/terminals/:id/select` - select terminal with authentication
  - `POST /api/terminals/:id/input` - send input to terminal with authentication
  - `POST /api/terminals/:id/resize` - resize terminal with authentication
  - Return 401 for missing/invalid API key
  - Return 404 for non-existent terminals

### 3. WebSocket Communication
- **Connection establishment** should:
  - Accept connections with valid API key in headers
  - Reject connections with missing API key (code 1008)
  - Reject connections with invalid API key (code 1008)
  - Reject connections when limit exceeded (code 1013)
  - Assign unique client ID to each connection

- **Message broadcasting** should:
  - Send terminal output to all connected clients
  - Include terminal ID, data, and sequence number
  - Handle client disconnections gracefully
  - Maintain connection state

### 4. Authentication & Security
- **API key management** should:
  - Generate cryptographically secure keys
  - Store keys securely using VS Code secrets API
  - Validate keys using timing-safe comparison
  - Support key rotation
  - Hash keys for validation

### 5. Terminal Management
- **Terminal detection** should:
  - Track VS Code terminals automatically
  - Identify Claude Code sessions
  - Maintain terminal metadata (PID, CWD, status)
  - Support terminal selection and input

### 6. Error Handling
- **Network errors** should:
  - Handle connection failures gracefully
  - Return proper HTTP status codes
  - Include error details in responses
  - Log errors appropriately

## Test Organization

### Unit Tests (existing)
- Individual service functionality
- Mocked dependencies
- Fast execution

### Integration Tests (to be implemented)
- End-to-end workflows
- Real network connections
- Database/file system interactions
- Cross-service communication

## Success Criteria

Each test must:
1. **Be written before implementation** (TDD)
2. **Fail initially** (red phase)
3. **Pass after minimal implementation** (green phase)
4. **Be refactored for clarity** (refactor phase)
5. **Test one specific behavior**
6. **Be independent and repeatable**
7. **Have clear assertions**
8. **Clean up after execution**

## Test Implementation Strategy

1. **Start with failing tests** for each feature
2. **Write minimal code** to make tests pass
3. **Refactor** for better design
4. **Add more specific test cases**
5. **Repeat** for each feature

This specification will guide our TDD implementation process.