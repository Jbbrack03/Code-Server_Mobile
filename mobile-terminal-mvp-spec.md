# Mobile Terminal MVP Specification

## Overview
A streamlined mobile terminal solution for iOS that provides an optimized experience for accessing Code-Server terminals remotely.

## Core Principles
- Mobile-first design
- Minimal viable features
- Simple implementation
- Fast time to market

## MVP Scope

### VS Code Extension - Terminal API Server

#### Features
1. **Multi-Terminal Management**
   - List all active terminals
   - Track terminal names and IDs
   - Switch between terminals
   - Stream output from selected terminal
   - 1000 line buffer per terminal

2. **Simple Authentication**
   - API key validation
   - Single key per installation
   - Stored in VS Code settings

3. **Core API Endpoints**
   ```
   GET  /api/health              - Server status
   GET  /api/terminals           - List all active terminals
   GET  /api/terminal/:id        - Get specific terminal info
   POST /api/terminal/:id/select - Switch active terminal
   WS   /api/terminal/stream     - Real-time output stream
   POST /api/terminal/input      - Send input to active terminal
   ```

#### Technical Implementation
- Express.js server on port 8092
- Single active terminal tracking
- Auto-start with VS Code
- Simple error responses

### iOS App - Mobile Terminal Client

#### Core Features
1. **Terminal Display & Navigation**
   - Full-screen terminal view
   - SwiftTerm for rendering
   - Pinch-to-zoom text sizing
   - Dark mode only (MVP)
   - **Terminal switcher (swipe left/right or tab bar)**
   - **Visual indicators for active terminal**

2. **Custom Command Shortcuts**
   - **Customizable shortcut buttons above keyboard**
   - **User can add/edit/delete shortcuts**
   - **Common defaults: `ls`, `cd ..`, `git status`, `clear`**
   - **Shortcuts stored locally and synced**
   - **Long press to edit shortcut**

3. **Mobile Optimizations**
   - Keyboard accessory bar: `|` `>` `<` `&` `~` `/` `Tab`
   - **Shortcut buttons row above accessory bar**
   - Swipe down to dismiss keyboard
   - Tap to position cursor
   - Long press for text selection
   - **Swipe gestures for terminal switching**

4. **Connection Management**
   - Single server connection
   - Auto-reconnect on disconnect
   - Visual connection status
   - Pull-to-refresh
   - **Terminal list refresh**

#### UI/UX Design
- Clean, minimal interface
- No tab bars or navigation (MVP)
- Settings accessed via long-press gesture
- Native iOS feel

## Implementation Plan

### Phase 1: Core Terminal Access (Weeks 1-3)
- VS Code extension with multi-terminal support
- Terminal listing and switching API
- iOS app with terminal display
- Basic connection management
- Terminal switcher UI

### Phase 2: Interactive Features (Weeks 4-5)
- Keyboard input support
- Custom command shortcuts
- Shortcut editor UI
- Local storage for shortcuts
- Swipe gestures for terminal switching

### Phase 3: Polish & Launch (Weeks 6-8)
- Performance optimization
- Error handling improvements
- Shortcut sync across devices
- Beta testing
- App Store submission

## Technical Decisions

### Simplified Architecture
```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   iOS App   │────▶│  VS Code Extension│────▶│  Terminal   │
│ (SwiftUI)   │◀────│  (Express + WS)   │◀────│  (pty)      │
└─────────────┘     └──────────────────┘     └─────────────┘
     API Key              Port 8092
```

### Data Flow
1. Terminal output → Extension captures → WebSocket → iOS App
2. User input → iOS App → HTTP POST → Extension → Terminal

### Error Handling
- Connection lost: Auto-retry with exponential backoff
- Server unreachable: Clear error message with retry button
- Invalid API key: Prompt for new key

## Deferred Features (Post-MVP)
- Multiple terminal sessions
- Command shortcuts/macros
- Terminal themes
- Landscape orientation
- File upload/download
- SSH tunneling
- Android app

## Success Metrics
- Connection establishment < 2 seconds
- Output latency < 100ms
- Zero crashes in 24-hour session
- Text selection accuracy > 95%

## Risk Mitigation
- Start with read-only to prove concept
- Use established libraries (SwiftTerm, Express)
- Test on real devices early
- Get beta user feedback quickly

## Next Steps
1. Create UI mockups for iOS app
2. Prototype VS Code extension API
3. Test WebSocket performance over cellular
4. Design keyboard accessory bar