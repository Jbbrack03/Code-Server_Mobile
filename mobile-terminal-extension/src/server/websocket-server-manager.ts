import WebSocket from 'ws';
import { Server } from 'http';
import { v4 as uuidv4 } from 'uuid';
import { TerminalService } from '../services/terminal.service';
import { ApiKeyManager } from '../services/api-key-manager';
import { WebSocketMessage, MessageType, ErrorCode } from '../types';

interface AuthenticatedWebSocket extends WebSocket {
  clientId?: string;
  isAuthenticated?: boolean;
}

interface WebSocketClient {
  id: string;
  socket: AuthenticatedWebSocket;
  lastPing: Date;
}

export class WebSocketServerManager {
  private wss: WebSocket.Server | null = null;
  private clients: Map<string, WebSocketClient> = new Map();
  private messageSequence: number = 0;
  private maxConnections: number = 50;
  private pingInterval: NodeJS.Timeout | null = null;

  constructor(
    private terminalService: TerminalService,
    private apiKeyManager: ApiKeyManager,
    maxConnections: number = 50
  ) {
    this.maxConnections = maxConnections;
  }

  /**
   * Start the WebSocket server attached to an HTTP server
   */
  async start(server: Server | null): Promise<void> {
    if (!server) {
      throw new Error('HTTP server is required to start WebSocket server');
    }

    if (this.wss) {
      throw new Error('WebSocket server is already running');
    }

    this.wss = new WebSocket.Server({
      server,
      path: '/api/terminal/stream',
      verifyClient: this.verifyClient.bind(this)
    });

    this.wss.on('connection', this.handleConnection.bind(this));
    this.startPingInterval();
  }

  /**
   * Stop the WebSocket server
   */
  async stop(): Promise<void> {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }

    if (this.wss) {
      // Close all client connections
      this.clients.forEach((client) => {
        client.socket.close();
      });
      this.clients.clear();

      // Close the WebSocket server
      return new Promise((resolve, reject) => {
        this.wss!.close((error) => {
          if (error) {
            reject(error);
          } else {
            this.wss = null;
            resolve();
          }
        });
      });
    }
  }

  /**
   * Check if WebSocket server is running
   */
  isRunning(): boolean {
    return this.wss !== null;
  }

  /**
   * Get number of connected clients
   */
  getConnectedClients(): number {
    return this.clients.size;
  }

  /**
   * Get maximum allowed connections
   */
  getMaxConnections(): number {
    return this.maxConnections;
  }

  /**
   * Broadcast terminal output to all connected clients
   */
  broadcastTerminalOutput(terminalId: string, data: string, sequence: number): void {
    const message: WebSocketMessage = {
      id: uuidv4(),
      type: 'terminal.output',
      timestamp: Date.now(),
      payload: {
        terminalId,
        data,
        sequence
      }
    };

    this.broadcastMessage(message);
  }

  /**
   * Broadcast terminal list to all connected clients
   */
  broadcastTerminalList(): void {
    const terminals = this.terminalService.getTerminals();
    const activeTerminalId = this.terminalService.getActiveTerminalId();

    const message: WebSocketMessage = {
      id: uuidv4(),
      type: 'terminal.list',
      timestamp: Date.now(),
      payload: {
        terminals,
        activeTerminalId
      }
    };

    this.broadcastMessage(message);
  }

  /**
   * Verify client connection (authentication)
   */
  private verifyClient(info: { req: any; origin: string; secure: boolean }, callback: (result: boolean, code?: number, message?: string) => void): void {
    (async () => {
      try {
        // Check connection limit
        if (this.clients.size >= this.maxConnections) {
          callback(false, 1013, 'Too many connections');
          return;
        }

        // Extract API key from headers
        const apiKey = info.req.headers['x-api-key'];
        if (!apiKey) {
          callback(false, 1008, 'Missing API key');
          return;
        }

        // Validate API key
        const isValid = await this.apiKeyManager.validateApiKeyAsync(apiKey);
        if (!isValid) {
          callback(false, 1008, 'Invalid API key');
          return;
        }

        callback(true);
      } catch (error) {
        console.error('WebSocket client verification error:', error);
        callback(false, 1011, 'Authentication error');
      }
    })();
  }

  /**
   * Handle new WebSocket connection
   */
  private handleConnection(ws: AuthenticatedWebSocket, req: any): void {
    const clientId = uuidv4();
    ws.clientId = clientId;
    ws.isAuthenticated = true; // Already authenticated via verifyClient

    const client: WebSocketClient = {
      id: clientId,
      socket: ws,
      lastPing: new Date()
    };

    this.clients.set(clientId, client);

    // Set up event handlers
    ws.on('message', (data) => this.handleMessage(clientId, data));
    ws.on('close', () => this.handleDisconnection(clientId));
    ws.on('error', (error) => this.handleError(clientId, error));
    ws.on('pong', () => this.handlePong(clientId));

    console.log(`WebSocket client connected: ${clientId}`);
  }

  /**
   * Handle WebSocket message from client
   */
  private handleMessage(clientId: string, data: WebSocket.Data): void {
    const client = this.clients.get(clientId);
    if (!client) {
      return;
    }

    try {
      const message: WebSocketMessage = JSON.parse(data.toString());
      
      switch (message.type) {
        case 'terminal.input':
          this.handleTerminalInput(message);
          break;
        case 'terminal.select':
          this.handleTerminalSelect(message);
          break;
        case 'terminal.resize':
          this.handleTerminalResize(message);
          break;
        case 'connection.ping':
          this.handlePing(clientId, message);
          break;
        default:
          this.sendErrorToClient(clientId, 'WS_MESSAGE_INVALID', 'Unknown message type');
      }
    } catch (error) {
      this.sendErrorToClient(clientId, 'WS_MESSAGE_INVALID', 'Invalid JSON message');
    }
  }

  /**
   * Handle client disconnection
   */
  private handleDisconnection(clientId: string): void {
    this.clients.delete(clientId);
    console.log(`WebSocket client disconnected: ${clientId}`);
  }

  /**
   * Handle WebSocket error
   */
  private handleError(clientId: string, error: Error): void {
    console.error(`WebSocket error for client ${clientId}:`, error);
    this.handleDisconnection(clientId);
  }

  /**
   * Handle terminal input message
   */
  private async handleTerminalInput(message: WebSocketMessage): Promise<void> {
    const { terminalId, data } = message.payload;
    
    if (!terminalId || !data) {
      return;
    }

    try {
      await this.terminalService.sendInput(terminalId, data);
    } catch (error) {
      console.error('Error handling terminal input:', error);
    }
  }

  /**
   * Handle terminal selection message
   */
  private async handleTerminalSelect(message: WebSocketMessage): Promise<void> {
    const { terminalId } = message.payload;
    
    if (!terminalId) {
      return;
    }

    try {
      await this.terminalService.selectTerminal(terminalId);
      // Broadcast updated terminal list to all clients
      this.broadcastTerminalList();
    } catch (error) {
      console.error('Error handling terminal selection:', error);
    }
  }

  /**
   * Handle terminal resize message
   */
  private async handleTerminalResize(message: WebSocketMessage): Promise<void> {
    const { terminalId, cols, rows } = message.payload;
    
    if (!terminalId || !cols || !rows) {
      return;
    }

    try {
      await this.terminalService.resizeTerminal(terminalId, cols, rows);
    } catch (error) {
      console.error('Error handling terminal resize:', error);
    }
  }

  /**
   * Handle ping message
   */
  private handlePing(clientId: string, message: WebSocketMessage): void {
    const client = this.clients.get(clientId);
    if (!client) {
      return;
    }

    client.lastPing = new Date();

    // Send pong response
    const pongMessage: WebSocketMessage = {
      id: uuidv4(),
      type: 'connection.pong',
      timestamp: Date.now(),
      payload: {}
    };

    this.sendMessageToClient(clientId, pongMessage);
  }

  /**
   * Handle pong response
   */
  private handlePong(clientId: string): void {
    const client = this.clients.get(clientId);
    if (client) {
      client.lastPing = new Date();
    }
  }

  /**
   * Broadcast message to all connected clients
   */
  private broadcastMessage(message: WebSocketMessage): void {
    const messageStr = JSON.stringify(message);
    
    this.clients.forEach((client) => {
      if (client.socket.readyState === WebSocket.OPEN) {
        try {
          client.socket.send(messageStr);
        } catch (error) {
          console.error(`Error sending message to client ${client.id}:`, error);
          this.handleDisconnection(client.id);
        }
      }
    });
  }

  /**
   * Send message to specific client
   */
  private sendMessageToClient(clientId: string, message: WebSocketMessage): void {
    const client = this.clients.get(clientId);
    if (!client || client.socket.readyState !== WebSocket.OPEN) {
      return;
    }

    try {
      client.socket.send(JSON.stringify(message));
    } catch (error) {
      console.error(`Error sending message to client ${clientId}:`, error);
      this.handleDisconnection(clientId);
    }
  }

  /**
   * Send error message to client
   */
  private sendErrorToClient(clientId: string, code: string, message: string): void {
    const errorMessage: WebSocketMessage = {
      id: uuidv4(),
      type: 'error',
      timestamp: Date.now(),
      payload: {
        code,
        message,
        details: null
      }
    };

    this.sendMessageToClient(clientId, errorMessage);
  }

  /**
   * Start ping interval to keep connections alive
   */
  private startPingInterval(): void {
    this.pingInterval = setInterval(() => {
      const now = new Date();
      
      this.clients.forEach((client) => {
        const timeSinceLastPing = now.getTime() - client.lastPing.getTime();
        
        // If no ping for more than 60 seconds, close connection
        if (timeSinceLastPing > 60000) {
          console.log(`Closing inactive client: ${client.id}`);
          client.socket.close();
          this.handleDisconnection(client.id);
        } else if (client.socket.readyState === WebSocket.OPEN) {
          // Send ping
          try {
            client.socket.ping();
          } catch (error) {
            console.error(`Error pinging client ${client.id}:`, error);
            this.handleDisconnection(client.id);
          }
        }
      });
    }, 30000); // Ping every 30 seconds
  }
}