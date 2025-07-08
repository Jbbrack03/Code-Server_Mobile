import * as vscode from 'vscode';
import { Terminal } from '../types';
import { v4 as uuidv4 } from 'uuid';

export class TerminalService {
  private terminals: Map<string, Terminal> = new Map();
  private activeTerminalId: string | null = null;
  private buffers: Map<string, string[]> = new Map();
  private terminalMap: Map<vscode.Terminal, string> = new Map();

  constructor() {
    // Initialize empty service
  }

  /**
   * Get all tracked terminals
   */
  getTerminals(): Terminal[] {
    return Array.from(this.terminals.values());
  }

  /**
   * Get the currently active terminal
   */
  getActiveTerminal(): Terminal | null {
    if (!this.activeTerminalId) {
      return null;
    }
    return this.terminals.get(this.activeTerminalId) || null;
  }

  /**
   * Detect if a terminal is a Claude Code session
   */
  detectClaudeCode(terminal: vscode.Terminal): boolean {
    return terminal.name.toLowerCase().includes('claude code');
  }

  /**
   * Handle terminal creation event
   */
  async onDidCreateTerminal(terminal: vscode.Terminal): Promise<void> {
    const terminalId = uuidv4();
    const processId = await terminal.processId || 0;
    
    const terminalInfo: Terminal = {
      id: terminalId,
      name: terminal.name,
      pid: processId,
      cwd: this.extractCwd(terminal.creationOptions) || process.cwd(),
      shellType: this.detectShellType(terminal),
      isActive: this.terminals.size === 0, // First terminal is active
      isClaudeCode: this.detectClaudeCode(terminal),
      createdAt: new Date(),
      lastActivity: new Date(),
      dimensions: {
        cols: 80,
        rows: 24
      },
      status: 'active'
    };

    this.terminals.set(terminalId, terminalInfo);
    this.terminalMap.set(terminal, terminalId);
    this.buffers.set(terminalId, []);

    // Set as active if it's the first terminal
    if (this.terminals.size === 1) {
      this.activeTerminalId = terminalId;
    }
  }

  /**
   * Handle terminal closure event
   */
  async onDidCloseTerminal(terminal: vscode.Terminal): Promise<void> {
    const terminalId = this.terminalMap.get(terminal);
    if (terminalId) {
      this.terminals.delete(terminalId);
      this.buffers.delete(terminalId);
      this.terminalMap.delete(terminal);

      // If this was the active terminal, clear active
      if (this.activeTerminalId === terminalId) {
        this.activeTerminalId = null;
      }
    }
  }

  /**
   * Handle active terminal change event
   */
  async onDidChangeActiveTerminal(terminal: vscode.Terminal | undefined): Promise<void> {
    // Clear all terminals as inactive first
    for (const [id, terminalInfo] of this.terminals) {
      terminalInfo.isActive = false;
      this.terminals.set(id, terminalInfo);
    }

    if (terminal) {
      const terminalId = this.terminalMap.get(terminal);
      if (terminalId) {
        const terminalInfo = this.terminals.get(terminalId);
        if (terminalInfo) {
          terminalInfo.isActive = true;
          terminalInfo.lastActivity = new Date();
          this.terminals.set(terminalId, terminalInfo);
          this.activeTerminalId = terminalId;
        }
      }
    } else {
      this.activeTerminalId = null;
    }
  }

  /**
   * Handle terminal data write event
   */
  onDidWriteTerminalData(terminal: vscode.Terminal, data: string): void {
    const terminalId = this.terminalMap.get(terminal);
    if (terminalId) {
      const buffer = this.buffers.get(terminalId) || [];
      buffer.push(data);

      // Limit buffer size to 1000 lines
      if (buffer.length > 1000) {
        buffer.shift();
      }

      this.buffers.set(terminalId, buffer);

      // Update last activity
      const terminalInfo = this.terminals.get(terminalId);
      if (terminalInfo) {
        terminalInfo.lastActivity = new Date();
        this.terminals.set(terminalId, terminalInfo);
      }
    }
  }

  /**
   * Select a terminal by ID
   */
  async selectTerminal(terminalId: string): Promise<boolean> {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) {
      return false;
    }

    // Clear all as inactive
    for (const [id, terminalInfo] of this.terminals) {
      terminalInfo.isActive = false;
      this.terminals.set(id, terminalInfo);
    }

    // Set selected as active
    terminal.isActive = true;
    terminal.lastActivity = new Date();
    this.terminals.set(terminalId, terminal);
    this.activeTerminalId = terminalId;

    return true;
  }

  /**
   * Send input to a terminal
   */
  async sendInput(terminalId: string, data: string): Promise<boolean> {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) {
      return false;
    }

    // Find the vscode terminal
    for (const [vsTerminal, id] of this.terminalMap) {
      if (id === terminalId) {
        vsTerminal.sendText(data);
        return true;
      }
    }

    return false;
  }

  /**
   * Resize a terminal
   */
  async resizeTerminal(terminalId: string, cols: number, rows: number): Promise<boolean> {
    const terminal = this.terminals.get(terminalId);
    if (!terminal) {
      return false;
    }

    terminal.dimensions.cols = cols;
    terminal.dimensions.rows = rows;
    this.terminals.set(terminalId, terminal);

    return true;
  }

  /**
   * Get terminal buffer
   */
  getTerminalBuffer(terminalId: string): string[] {
    return this.buffers.get(terminalId) || [];
  }

  /**
   * Get active terminal ID
   */
  getActiveTerminalId(): string | null {
    return this.activeTerminalId;
  }

  /**
   * Get terminal by ID
   */
  getTerminal(terminalId: string): Terminal | null {
    return this.terminals.get(terminalId) || null;
  }

  /**
   * Detect shell type from terminal creation options
   */
  private detectShellType(terminal: vscode.Terminal): Terminal['shellType'] {
    const shellPath = this.extractShellPath(terminal.creationOptions)?.toLowerCase();
    
    if (shellPath?.includes('bash')) return 'bash';
    if (shellPath?.includes('zsh')) return 'zsh';
    if (shellPath?.includes('fish')) return 'fish';
    if (shellPath?.includes('pwsh') || shellPath?.includes('powershell')) return 'pwsh';
    if (shellPath?.includes('cmd')) return 'cmd';
    
    // Default to bash
    return 'bash';
  }

  /**
   * Extract CWD from terminal creation options
   */
  private extractCwd(options: Readonly<vscode.TerminalOptions | vscode.ExtensionTerminalOptions> | undefined): string | undefined {
    if (!options) return undefined;
    
    // Handle TerminalOptions
    if ('cwd' in options) {
      if (typeof options.cwd === 'string') {
        return options.cwd;
      }
      if (options.cwd && 'fsPath' in options.cwd) {
        return options.cwd.fsPath;
      }
    }
    
    return undefined;
  }

  /**
   * Extract shell path from terminal creation options
   */
  private extractShellPath(options: Readonly<vscode.TerminalOptions | vscode.ExtensionTerminalOptions> | undefined): string | undefined {
    if (!options) return undefined;
    
    // Handle TerminalOptions
    if ('shellPath' in options) {
      return options.shellPath;
    }
    
    return undefined;
  }
}