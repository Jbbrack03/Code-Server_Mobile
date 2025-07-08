# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code-Server Setup and Access

### Local and Remote Access
- **Local URL**: http://127.0.0.1:8091
- **Remote URL**: https://code.brackinhouse.familyds.net
- **Password**: a1544904J$
- **Configuration**: `~/.config/code-server/config.yaml`

### Service Management Commands
```bash
brew services start code-server    # Start service
brew services stop code-server     # Stop service
brew services restart code-server  # Restart service
```

### Logs and Debugging
- Service logs: `/opt/homebrew/var/log/code-server.log`
- Configuration issues: Check `~/.config/code-server/config.yaml` for proper YAML formatting

## Claude Code Integration

### Running Claude Code
```bash
# Direct execution
/Users/jbbrack03/.claude/local/claude

# With autonomous mode
claude --dangerously-skip-permissions
```

### Session Management System

The repository includes a custom session management system for mobile-friendly access:

```bash
# Quick commands (after sourcing mobile-shortcuts.sh)
c     # Quick connect to Claude (attach/create)
cl    # List all Claude sessions
cn    # Create new Claude session
css   # Show status of all sessions
ca    # Attach to specific session

# Full commands
./claude-sessions.sh list      # List sessions
./claude-sessions.sh new       # Create new session
./claude-sessions.sh quick     # Quick connect
./claude-sessions.sh status    # Show all session status
```

### Mobile Shortcuts
To enable mobile shortcuts in any Code-Server terminal:
```bash
source /Users/jbbrack03/Code-Server/mobile-shortcuts.sh
```

## Repository Architecture

### Key Files and Scripts
- `claude-code-integration.sh` - Main integration script for Claude Code setup
- `claude-sessions.sh` - tmux-based session management for persistent terminals
- `mobile-shortcuts.sh` - Shell aliases for mobile-friendly commands
- `synology-reverse-proxy-config.md` - WebSocket configuration for remote access
- `mobile-terminal-prd.md` - Product requirements for mobile terminal solution

### Mobile Terminal Solution

The repository contains a mobile terminal access solution that addresses the limitations of the tmux-based approach by providing a native mobile experience.

#### Current Status
- **Planning Phase**: ✅ Complete - All documentation finalized
- **Implementation**: 🚀 **IN PROGRESS** - Core VS Code extension services implemented using TDD
- **Goal**: Replace clunky tmux solution with optimized mobile UI

#### TDD Implementation Progress (January 2025)
- ✅ **TerminalService** - Terminal lifecycle, detection, buffering (16 tests passing)
- ✅ **ApiKeyManager** - Secure key generation, validation, storage (18 tests passing)
- ✅ **WebSocketServer** - Real-time streaming, authentication, broadcasting (30 tests passing)
- ✅ **Extension Entry Point** - Command registration, service initialization (9 tests passing)
- ✅ **Express REST API** - HTTP endpoints, authentication, error handling (24 tests passing)
- ✅ **WebSocket Server Manager** - Connection management, message broadcasting (15 tests passing)
- ✅ **QR Code Service** - Connection profile encoding, multiple formats (19 tests passing)
- ✅ **WebSocket Authentication** - verifyClient handshake validation, connection limits (17 tests passing)
- ✅ **ExtensionServerController** - Server lifecycle coordination, service orchestration (15 tests passing)
- ✅ **QRWebviewService** - VS Code webview QR code display, theming support (12 tests passing)
- ✅ **NetworkDiscoveryService** - Local network URL detection, mDNS preparation (21 tests passing)
- ✅ **Extension Commands** - VS Code commands implementation with status bar (21 tests passing)
- ✅ **Terminal I/O Streaming** - WebSocket terminal data streaming service (11 tests passing)
- ✅ **Test Coverage** - 253 tests passing total (100% success rate), strict TDD methodology followed

#### Project Documentation
- `mobile-terminal-prd.md` - Original product requirements document
- `mobile-terminal-mvp-spec.md` - **Simplified MVP specification** ✨
- `mobile-terminal-ui-design.md` - Mobile-first UI/UX design guide
- `mobile-terminal-research-checklist.md` - Technical validation checklist
- `mobile-terminal-implementation-plan-consolidated.md` - **FINAL consolidated implementation plan** 🎯
- `mobile-terminal-network-guide.md` - **Network configuration for all scenarios** 🌐
- Additional specs for future phases (extension, iOS app, API, security)

#### Recent Progress (January 2025)
- ✅ Simplified authentication from JWT to API keys
- ✅ Added comprehensive onboarding flow design
- ✅ Included multi-terminal support and switching
- ✅ Designed custom command shortcuts system
- ✅ Created network configuration guide for all access types
- ✅ Removed code snippets for Claude-driven implementation
- ✅ Added support for port forwarding, reverse proxy, DDNS, VPN, and tunnels
- ✅ **Consolidated implementation plans into single comprehensive document**
- ✅ **Extension Entry Point Implementation** - Commands registered with proper TDD approach
- ✅ **Express Server Implementation** - Complete REST API with health, terminals, authentication
- ✅ **WebSocket Integration** - Server manager with connection tracking and message broadcasting
- ✅ **QR Code Generation** - Multi-format connection profile encoding with compression and validation
- ✅ **Extension Server Controller** - Unified server lifecycle management with error handling
- ✅ **QR Code Webview** - Native VS Code webview for displaying connection QR codes with theming
- ✅ **Network Discovery** - Local network interface detection and URL generation for easy connection
- ✅ **VS Code Extension Commands** - Complete implementation of start/stop/showQR/rotateKey commands
- ✅ **Status Bar Integration** - Real-time server status display with quick command access

#### MVP Architecture (Simplified)

1. **VS Code Extension (Minimal Terminal Server)**
   - Simple Express.js server on port 8092
   - WebSocket for real-time terminal streaming
   - API key authentication (no JWT complexity)
   - Single active terminal tracking
   - 1000 line output buffer

2. **iOS App (Mobile Terminal Client)**
   - Native SwiftUI app for iOS 16+
   - SwiftTerm for terminal rendering
   - Full-screen terminal view
   - Mobile-optimized gestures and keyboard
   - Simple connection management

#### Key Simplifications from Original Plan

**Authentication**:
- API keys instead of JWT tokens
- Single key stored in iOS Keychain
- No complex refresh token flows

**Features**:
- Multiple terminal support with switching
- Custom command shortcuts (user-definable)
- Interactive terminal with input/output
- Terminal list with visual indicators

**UI/UX Focus**:
- Pinch-to-zoom for text sizing
- Smart keyboard bar with common symbols
- Customizable shortcut buttons row
- Native iOS text selection
- Swipe gestures for terminal switching
- Long press to edit shortcuts

#### Implementation Roadmap
- **Week 1**: Onboarding flows and network setup
- **Weeks 2-3**: VS Code extension with multi-terminal support
- **Weeks 4-5**: iOS app with terminal switching and shortcuts
- **Week 6**: UI/UX polish and gesture implementation
- **Week 7**: Network resilience and performance optimization
- **Week 8**: Testing, beta feedback, and App Store submission

#### Mobile Terminal Extension (Current Implementation)

**Location**: `/Users/jbbrack03/Code-Server/mobile-terminal-extension/`

**Architecture**:
```
mobile-terminal-extension/
├── package.json              # VS Code extension configuration
├── tsconfig.json             # TypeScript configuration
├── jest.config.js            # Jest testing setup
├── src/
│   ├── types/index.ts        # TypeScript type definitions
│   └── services/
│       ├── terminal.service.ts      # Terminal lifecycle management
│       ├── api-key-manager.ts       # Secure API key handling
│       └── websocket-server.ts      # Real-time communication
└── tests/
    ├── setup.ts              # Jest test configuration
    ├── __mocks__/vscode.ts   # VS Code API mocking
    └── services/             # Service test suites
```

**Key Implementation Features**:
- **Terminal Management**: Multi-terminal tracking, Claude Code detection, buffer management
- **Security**: Cryptographic API keys, secure storage, timing-safe validation
- **Real-time Communication**: WebSocket streaming, message queuing, connection management
- **Type Safety**: Comprehensive TypeScript interfaces and error handling
- **Testing**: 186 tests with Jest, full TDD methodology (100% success rate)
- **Server Orchestration**: Unified Express + WebSocket server lifecycle management
- **QR Code Display**: VS Code webview with theming support for connection profiles
- **Network Discovery**: Automatic local network interface detection and URL generation

**Development Commands**:
```bash
cd mobile-terminal-extension
npm install                   # Install dependencies
npm test                      # Run test suite
npm run build                 # Build extension
npm run dev                   # Watch mode development
```

#### Next Steps for Development
1. ✅ VS Code Extension Core Services - Terminal API integration complete
2. ✅ Main Extension Entry Point - Commands and services wired together
3. ✅ Express Server Integration - HTTP endpoints for terminal management complete
4. ✅ WebSocket Server Integration - Real-time communication layer implemented
5. ✅ QR Code Generation - Connection string display with multiple formats
6. ✅ WebSocket Authentication Fix - verifyClient implementation with connection limits
7. ✅ Extension Server Controller - Unified server lifecycle management
8. ✅ QR Code Webview - VS Code integrated QR display
9. ✅ Network Discovery Service - Local network detection
10. ✅ VS Code Extension Commands - Start/stop server, show QR commands with status bar
11. ✅ Terminal I/O Streaming - WebSocket terminal data streaming
12. 📋 iOS App Development - SwiftUI terminal client
13. 📋 Integration Testing - End-to-end validation
14. 📋 Network Configuration Testing - Multi-environment validation

#### Current Implementation Status

**Completed Components (TDD-driven):**
- ✅ **Express REST API Server** - Full HTTP endpoint implementation with authentication middleware
  - Health check endpoint (`/api/health`)
  - Terminal management endpoints (`/api/terminals/*`)
  - Proper error handling with RFC 9457 format
  - CORS configuration and request ID tracking
- ✅ **QR Code Generation Service** - Multi-format connection profile encoding
  - PNG, SVG, and UTF8 output formats
  - Data compression and validation
  - Unicode and special character support
  - Comprehensive error handling
- ✅ **WebSocket Server Manager** - Connection management and message broadcasting
  - Client connection tracking
  - Message broadcasting capabilities
  - Integration with terminal and API key services
  - Ping/pong keep-alive implementation

**Recently Completed (TDD-driven):**
- ✅ **WebSocket Authentication** - Complete verifyClient implementation with proper handshake validation
  - API key authentication during WebSocket upgrade process
  - Connection limit enforcement (configurable, defaults to 50, test uses 3)
  - Proper error codes and rejection handling (1008 for auth, 1013 for limits, 1011 for errors)

**Test Coverage:**
- **242 tests passing** out of 242 total (100% success rate) ✅
- **14 test suites passing** out of 14 total
- All core services have comprehensive test coverage
- WebSocket authentication and connection management fully implemented
- Server orchestration and lifecycle management complete
- QR code webview display with full VS Code integration
- Network discovery for automatic connection URL generation
- VS Code extension commands with status bar fully implemented

## Development in This Repository

### Working with Shell Scripts
All shell scripts should be made executable:
```bash
chmod +x script-name.sh
```

### Testing Session Management
```bash
# Create test session
tmux new -s test-session -d "echo 'Test running'"

# Verify session exists
tmux ls | grep test-session

# Clean up
tmux kill-session -t test-session
```

### Network Configuration
For remote access troubleshooting:
- Ensure port 8091 is forwarded in router
- WebSocket headers must be configured in reverse proxy
- Code-Server must bind to 0.0.0.0:8091 (not 127.0.0.1)

## Important Notes

- The `.bashrc` file is configured to auto-load mobile shortcuts when in Code-Server
- tmux is installed via Homebrew for session persistence
- All session names prefixed with "claude-" are managed by the session system
- The repository is actively used for Claude Code development workflows