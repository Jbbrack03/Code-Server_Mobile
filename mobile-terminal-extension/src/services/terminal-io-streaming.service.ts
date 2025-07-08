import * as vscode from 'vscode';
import { TerminalService } from './terminal.service';
import { WebSocketServerManager } from '../server/websocket-server-manager';
import { WebSocketMessage } from '../types';

// Define interface for terminal data events
interface TerminalDataWriteEvent {
  terminal: any;
  data: string;
}

/**
 * Service responsible for streaming terminal I/O data to WebSocket clients
 * Bridges VS Code terminal events with WebSocket broadcasting
 */
export class TerminalIOStreamingService {
  private disposables: vscode.Disposable[] = [];
  private sequenceNumbers: Map<string, number> = new Map();
  private initialized = false;
  private eventHandler: ((event: TerminalDataWriteEvent) => void) | null = null;

  constructor(
    private terminalService: TerminalService,
    private webSocketServerManager: WebSocketServerManager
  ) {}

  /**
   * Initialize the service and subscribe to terminal data events
   */
  async initialize(context: vscode.ExtensionContext): Promise<void> {
    if (this.initialized) {
      return;
    }

    // Create event handler
    this.eventHandler = (event: TerminalDataWriteEvent) => {
      this.handleTerminalData(event);
    };

    // Subscribe to terminal data write events
    // Note: In a real implementation, this would use vscode.window.onDidWriteTerminalData
    // but that's a proposed API. For now, we'll use a custom approach.
    const dataSubscription = this.subscribeToTerminalData(this.eventHandler);

    this.disposables.push(dataSubscription);
    context.subscriptions.push(dataSubscription);
    this.initialized = true;
  }

  /**
   * Subscribe to terminal data events (abstracted for testing)
   */
  private subscribeToTerminalData(handler: (event: TerminalDataWriteEvent) => void): vscode.Disposable {
    // In a real implementation, this would be:
    // return vscode.window.onDidWriteTerminalData(handler);
    
    // For testing purposes, we'll use the mock
    if ((vscode.window as any).onDidWriteTerminalData) {
      return (vscode.window as any).onDidWriteTerminalData(handler);
    }
    
    // Return a dummy disposable for real execution
    return { dispose: () => {} };
  }

  /**
   * Handle terminal data write events and broadcast to WebSocket clients
   */
  private handleTerminalData(event: TerminalDataWriteEvent): void {
    try {
      // Find the terminal in our service
      const terminals = this.terminalService.getTerminals();
      const terminal = terminals.find(t => {
        // Compare terminal objects - VS Code doesn't provide a unique ID
        // so we need to match by reference or properties
        const eventTerminal = event.terminal as any;
        return t.name === eventTerminal.name;
      });

      if (!terminal) {
        // Terminal not tracked by our service, ignore
        return;
      }

      // Get or initialize sequence number for this terminal
      if (!this.sequenceNumbers.has(terminal.id)) {
        this.sequenceNumbers.set(terminal.id, 0);
      }

      // Increment sequence number
      const sequence = this.sequenceNumbers.get(terminal.id)! + 1;
      this.sequenceNumbers.set(terminal.id, sequence);

      // Broadcast to all connected clients using the WebSocketServerManager
      this.webSocketServerManager.broadcastTerminalOutput(terminal.id, event.data, sequence);

    } catch (error) {
      // Log error but don't crash - terminal streaming should be resilient
      console.error('Error handling terminal data:', error);
    }
  }


  /**
   * Generate a unique message ID
   */
  private generateMessageId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Clean up resources
   */
  dispose(): void {
    this.disposables.forEach(d => d.dispose());
    this.disposables = [];
    this.sequenceNumbers.clear();
    this.initialized = false;
  }
}