import * as WebSocket from 'ws';
import * as http from 'http';
import { v4 as uuidv4 } from 'uuid';
import { TerminalService } from './terminal.service';
import { ApiKeyManager } from './api-key-manager';
import { WebSocketMessage, MessageType, TerminalOutputMessage, TerminalInputMessage, ErrorMessage } from '../types';

interface ClientInfo {
  socket: WebSocket;
  id: string;
  lastPing: number;
  messageQueue: WebSocketMessage[];
}

export class WebSocketServer {
  private wss: WebSocket.WebSocketServer;
  private clients: Map<string, ClientInfo> = new Map();
  private pingInterval: NodeJS.Timeout | null = null;
  private readonly maxQueueSize = 100;
  private readonly pingIntervalMs = 30000; // 30 seconds

  constructor(
    private port: number,
    private terminalService: TerminalService,
    private apiKeyManager: ApiKeyManager
  ) {
    this.wss = new WebSocket.WebSocketServer({
      port: this.port,
      verifyClient: this.verifyClient.bind(this),
    });

    this.wss.on('connection', this.handleConnection.bind(this));
    this.startPingInterval();
  }

  /**
   * Verify client during WebSocket handshake
   */
  private async verifyClient(info: { req: http.IncomingMessage }): Promise<boolean> {
    return await this.authenticateClient(info.req);
  }

  /**
   * Authenticate client using API key
   */
  async authenticateClient(request: http.IncomingMessage): Promise<boolean> {
    const apiKey = request.headers['x-api-key'];
    
    if (!apiKey || typeof apiKey !== 'string') {
      return false;
    }

    const storedHash = await this.apiKeyManager.retrieveApiKeyHash();
    if (!storedHash) {
      return false;
    }

    return this.apiKeyManager.validateApiKey(apiKey, storedHash);
  }

  /**
   * Handle new WebSocket connection
   */
  handleConnection(ws: WebSocket, request: http.IncomingMessage): void {
    const clientId = uuidv4();
    const clientInfo: ClientInfo = {
      socket: ws,
      id: clientId,
      lastPing: Date.now(),
      messageQueue: [],
    };

    this.clients.set(clientId, clientInfo);

    // Set up event listeners
    ws.on('message', (data: WebSocket.RawData) => {
      try {
        const message = JSON.parse(data.toString()) as WebSocketMessage;
        this.handleMessage(clientId, message);
      } catch (error) {
        this.sendError(clientId, 'WS_002', 'Invalid message format', { error: error instanceof Error ? error.message : String(error) });
      }
    });

    ws.on('close', () => {
      this.handleDisconnection(clientId);
    });

    ws.on('error', (error: Error) => {
      console.error(`WebSocket error for client ${clientId}:`, error);
      this.handleDisconnection(clientId);
    });

    // Send initial terminal list
    this.sendTerminalList(clientId);
  }

  /**
   * Handle client disconnection
   */
  handleDisconnection(clientId: string): void {
    this.clients.delete(clientId);
  }

  /**
   * Handle incoming WebSocket message
   */
  async handleMessage(clientId: string, message: WebSocketMessage): Promise<void> {
    try {
      // Validate message structure
      if (!message.id || !message.type || !message.timestamp) {
        this.sendError(clientId, 'WS_002', 'Invalid message format', { message });
        return;
      }

      switch (message.type) {
        case 'terminal.input':
          await this.handleTerminalInput(clientId, message as TerminalInputMessage);
          break;

        case 'terminal.select':
          await this.handleTerminalSelect(clientId, message);
          break;

        case 'terminal.resize':
          await this.handleTerminalResize(clientId, message);
          break;

        case 'terminal.list':
          this.sendTerminalList(clientId);
          break;

        case 'connection.ping':
          this.handlePing(clientId, message);
          break;

        default:
          this.sendError(clientId, 'WS_002', 'Unknown message type', { type: message.type });
      }
    } catch (error) {
      this.sendError(clientId, 'SYS_001', 'Internal server error', { error: error instanceof Error ? error.message : String(error) });
    }
  }

  /**
   * Handle terminal input message
   */
  private async handleTerminalInput(clientId: string, message: TerminalInputMessage): Promise<void> {
    const { terminalId, data } = message.payload;
    const success = await this.terminalService.sendInput(terminalId, data);
    
    if (!success) {
      this.sendError(clientId, 'TERM_001', 'Terminal not found', { terminalId });
    }
  }

  /**
   * Handle terminal selection message
   */
  private async handleTerminalSelect(clientId: string, message: WebSocketMessage): Promise<void> {
    const { terminalId } = message.payload;
    const success = await this.terminalService.selectTerminal(terminalId);
    
    if (!success) {
      this.sendError(clientId, 'TERM_001', 'Terminal not found', { terminalId });
    } else {
      // Broadcast terminal list update to all clients
      this.broadcastTerminalList();
    }
  }

  /**
   * Handle terminal resize message
   */
  private async handleTerminalResize(clientId: string, message: WebSocketMessage): Promise<void> {
    const { terminalId, cols, rows } = message.payload;
    const success = await this.terminalService.resizeTerminal(terminalId, cols, rows);
    
    if (!success) {
      this.sendError(clientId, 'TERM_001', 'Terminal not found', { terminalId });
    }
  }

  /**
   * Handle ping message
   */
  private handlePing(clientId: string, message: WebSocketMessage): void {
    const client = this.clients.get(clientId);
    if (client) {
      client.lastPing = Date.now();
      
      const pongMessage: WebSocketMessage = {
        id: uuidv4(),
        type: 'connection.pong',
        timestamp: Date.now(),
        payload: { originalId: message.id },
      };
      
      this.sendToClient(clientId, pongMessage);
    }
  }

  /**
   * Send terminal list to specific client
   */
  private sendTerminalList(clientId: string): void {
    const terminals = this.terminalService.getTerminals();
    const activeTerminal = this.terminalService.getActiveTerminal();
    
    const message: WebSocketMessage = {
      id: uuidv4(),
      type: 'terminal.list',
      timestamp: Date.now(),
      payload: {
        terminals,
        activeTerminalId: activeTerminal?.id || null,
      },
    };
    
    this.sendToClient(clientId, message);
  }

  /**
   * Broadcast terminal list to all clients
   */
  private broadcastTerminalList(): void {
    const terminals = this.terminalService.getTerminals();
    const activeTerminal = this.terminalService.getActiveTerminal();
    
    const message: WebSocketMessage = {
      id: uuidv4(),
      type: 'terminal.list',
      timestamp: Date.now(),
      payload: {
        terminals,
        activeTerminalId: activeTerminal?.id || null,
      },
    };
    
    this.broadcastMessage(message);
  }

  /**
   * Broadcast message to all connected clients
   */
  broadcastMessage(message: WebSocketMessage): void {
    for (const [clientId, client] of this.clients) {
      if (client.socket.readyState === WebSocket.OPEN) {
        try {
          client.socket.send(JSON.stringify(message));
        } catch (error) {
          console.error(`Failed to send message to client ${clientId}:`, error);
          this.handleDisconnection(clientId);
        }
      }
    }
  }

  /**
   * Send message to specific client
   */
  sendToClient(clientId: string, message: WebSocketMessage): void {
    const client = this.clients.get(clientId);
    if (!client) {
      return;
    }

    if (client.socket.readyState === WebSocket.OPEN) {
      try {
        client.socket.send(JSON.stringify(message));
      } catch (error) {
        console.error(`Failed to send message to client ${clientId}:`, error);
        this.handleDisconnection(clientId);
      }
    } else {
      // Queue message if client is not ready
      this.queueMessage(clientId, message);
    }
  }

  /**
   * Queue message for later delivery
   */
  private queueMessage(clientId: string, message: WebSocketMessage): void {
    const client = this.clients.get(clientId);
    if (client) {
      client.messageQueue.push(message);
      
      // Limit queue size to prevent memory issues
      if (client.messageQueue.length > this.maxQueueSize) {
        client.messageQueue.shift(); // Remove oldest message
      }
    }
  }

  /**
   * Flush queued messages for a client
   */
  flushMessageQueue(clientId: string): void {
    const client = this.clients.get(clientId);
    if (client && client.socket.readyState === WebSocket.OPEN) {
      while (client.messageQueue.length > 0) {
        const message = client.messageQueue.shift();
        if (message) {
          try {
            client.socket.send(JSON.stringify(message));
          } catch (error) {
            console.error(`Failed to flush message to client ${clientId}:`, error);
            break;
          }
        }
      }
    }
  }

  /**
   * Send error message to client
   */
  sendError(clientId: string, code: string, message: string, details?: any): void {
    const errorMessage: ErrorMessage = {
      id: uuidv4(),
      type: 'error',
      timestamp: Date.now(),
      payload: {
        code,
        message,
        details,
      },
    };
    
    this.sendToClient(clientId, errorMessage);
  }

  /**
   * Start ping interval to keep connections alive
   */
  private startPingInterval(): void {
    this.pingInterval = setInterval(() => {
      for (const [clientId, client] of this.clients) {
        if (client.socket.readyState === WebSocket.OPEN) {
          const pingMessage: WebSocketMessage = {
            id: uuidv4(),
            type: 'connection.ping',
            timestamp: Date.now(),
            payload: {},
          };
          
          this.sendToClient(clientId, pingMessage);
        }
      }
    }, this.pingIntervalMs);
  }

  /**
   * Handle terminal output from TerminalService
   */
  onTerminalOutput(terminalId: string, data: string, sequence: number): void {
    const outputMessage: TerminalOutputMessage = {
      id: uuidv4(),
      type: 'terminal.output',
      timestamp: Date.now(),
      payload: {
        terminalId,
        data,
        sequence,
      },
    };
    
    this.broadcastMessage(outputMessage);
  }

  /**
   * Get client count
   */
  getClientCount(): number {
    return this.clients.size;
  }

  /**
   * Get client IDs
   */
  getClientIds(): string[] {
    return Array.from(this.clients.keys());
  }

  /**
   * Get queue size for a client
   */
  getQueueSize(clientId: string): number {
    const client = this.clients.get(clientId);
    return client ? client.messageQueue.length : 0;
  }

  /**
   * Close WebSocket server
   */
  close(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }

    // Close all client connections
    for (const [clientId, client] of this.clients) {
      client.socket.close();
    }
    this.clients.clear();

    // Close the server
    this.wss.close();
  }
}