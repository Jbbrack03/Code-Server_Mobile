#!/bin/bash

# Claude Code Session Manager
# Mobile-friendly tmux session management

case "$1" in
    "list"|"ls")
        echo "=== Active Claude Sessions ==="
        tmux ls 2>/dev/null | grep claude || echo "No active sessions"
        ;;
    
    "new")
        SESSION_NAME="${2:-claude-$(date +%H%M%S)}"
        echo "Starting new session: $SESSION_NAME"
        tmux new -s "$SESSION_NAME" -d "claude --dangerously-skip-permissions"
        sleep 1
        tmux attach -t "$SESSION_NAME"
        ;;
    
    "attach"|"a")
        if [ -z "$2" ]; then
            # Auto-attach to most recent claude session
            SESSION=$(tmux ls 2>/dev/null | grep claude | head -1 | cut -d: -f1)
            if [ -n "$SESSION" ]; then
                tmux attach -t "$SESSION"
            else
                echo "No claude sessions found. Creating new one..."
                $0 new
            fi
        else
            tmux attach -t "$2"
        fi
        ;;
    
    "quick"|"q")
        # Quick access - attach to existing or create new
        SESSION=$(tmux ls 2>/dev/null | grep claude | head -1 | cut -d: -f1)
        if [ -n "$SESSION" ]; then
            tmux attach -t "$SESSION"
        else
            tmux new -s claude-main "claude --dangerously-skip-permissions"
        fi
        ;;
    
    "status"|"s")
        echo "=== Claude Sessions Status ==="
        for session in $(tmux ls 2>/dev/null | grep claude | cut -d: -f1); do
            echo "--- Session: $session ---"
            tmux capture-pane -t "$session" -p | tail -20
            echo ""
        done
        ;;
    
    *)
        echo "Claude Session Manager"
        echo "Usage:"
        echo "  $0 list    - List all sessions"
        echo "  $0 new     - Start new Claude session"
        echo "  $0 attach  - Attach to session"
        echo "  $0 quick   - Quick access (attach or create)"
        echo "  $0 status  - Show last 20 lines of each session"
        echo ""
        echo "Shortcuts:"
        echo "  cs ls     - List sessions"
        echo "  cs q      - Quick connect"
        echo "  cs s      - Status check"
        ;;
esac