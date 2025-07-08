# Persistent Terminal Sessions in Code-Server

## Using tmux for Persistent Sessions

Since Code-Server creates new terminal instances for each connection, use tmux to maintain persistent sessions across devices.

## Quick Start Commands:

### On your Mac (first session):
1. Open terminal in Code-Server
2. Start a new tmux session:
   ```bash
   tmux new -s claude-session
   ```
3. Run your Claude Code command:
   ```bash
   /Users/jbbrack03/.claude/local/claude
   ```

### On your iPhone (or any other device):
1. Open terminal in Code-Server
2. Reattach to existing session:
   ```bash
   tmux attach -t claude-session
   ```

## Essential tmux Commands:

- **Create named session**: `tmux new -s session-name`
- **List sessions**: `tmux ls`
- **Attach to session**: `tmux attach -t session-name`
- **Detach from session**: `Ctrl+b` then `d`
- **Kill session**: `tmux kill-session -t session-name`

## Multiple Sessions:

You can have multiple named sessions:
```bash
tmux new -s claude-work
tmux new -s project-dev
tmux new -s monitoring
```

## Auto-attach Script:

Create this script to automatically attach or create a session:

```bash
#!/bin/bash
SESSION="claude-session"
tmux attach-session -t $SESSION || tmux new-session -s $SESSION
```

## Tips:

1. Sessions persist even when you disconnect
2. You can see the same terminal output from any device
3. Commands continue running in the background
4. Perfect for long-running Claude Code sessions

## Alternative: GNU Screen

If you prefer screen over tmux:
```bash
brew install screen
screen -S claude-session  # Create
screen -r claude-session  # Resume
```