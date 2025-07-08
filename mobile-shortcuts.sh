#!/bin/bash

# Add these aliases to your shell for mobile-friendly commands
# Source this file in Code-Server terminal: source /Users/jbbrack03/Code-Server/mobile-shortcuts.sh

# Short aliases for mobile typing
alias cs="/Users/jbbrack03/Code-Server/claude-sessions.sh"
alias cq="/Users/jbbrack03/Code-Server/claude-sessions.sh quick"
alias cl="/Users/jbbrack03/Code-Server/claude-sessions.sh list"
alias cn="/Users/jbbrack03/Code-Server/claude-sessions.sh new"
alias ca="/Users/jbbrack03/Code-Server/claude-sessions.sh attach"
alias css="/Users/jbbrack03/Code-Server/claude-sessions.sh status"

# Even shorter - single letter after c
alias c="/Users/jbbrack03/Code-Server/claude-sessions.sh quick"

echo "Mobile shortcuts loaded!"
echo ""
echo "Quick commands:"
echo "  c     - Connect to Claude (quick attach/create)"
echo "  cl    - List sessions"
echo "  cn    - New session"
echo "  css   - Status of all sessions"
echo "  cq    - Quick connect"
echo ""
echo "Just type 'c' to connect to Claude!"