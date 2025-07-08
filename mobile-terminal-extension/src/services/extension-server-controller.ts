import * as vscode from 'vscode';
import { TerminalService } from './terminal.service';
import { ApiKeyManager } from './api-key-manager';
import { ExpressServer } from '../server/express-server';
import { WebSocketServerManager } from '../server/websocket-server-manager';

export interface ConnectionInfo {
  host: string;
  port: number;
  apiKey: string;
  isRunning: boolean;
}

/**
 * ExtensionServerController coordinates the lifecycle of the mobile terminal server.
 * It manages the Express HTTP server and WebSocket server as a unit.
 */
export class ExtensionServerController {
  private running = false;
  private readonly defaultHost = '0.0.0.0';
  private readonly defaultPort = 8092;

  constructor(
    private readonly context: vscode.ExtensionContext,
    private readonly terminalService: TerminalService,
    private readonly apiKeyManager: ApiKeyManager,
    private readonly expressServer: ExpressServer,
    private readonly webSocketManager: WebSocketServerManager
  ) {}

  /**
   * Start the mobile terminal server (Express + WebSocket)
   */
  async start(): Promise<void> {
    if (this.running) {
      return;
    }

    try {
      // Start Express server first
      await this.expressServer.start(this.defaultPort, this.defaultHost);

      try {
        // Get the HTTP server instance from Express server
        const httpServer = this.expressServer.getServer();
        // Then start WebSocket server
        await this.webSocketManager.start(httpServer);
        this.running = true;
      } catch (error) {
        // If WebSocket fails, stop Express server
        await this.expressServer.stop();
        throw error;
      }
    } catch (error) {
      this.running = false;
      throw error;
    }
  }

  /**
   * Stop the mobile terminal server
   */
  async stop(): Promise<void> {
    if (!this.running) {
      return;
    }

    let errors: Error[] = [];

    try {
      // Stop WebSocket server first
      await this.webSocketManager.stop();
    } catch (error) {
      errors.push(error as Error);
    }

    try {
      // Then stop Express server
      await this.expressServer.stop();
    } catch (error) {
      errors.push(error as Error);
    }

    this.running = false;

    // If any errors occurred, throw the first one
    if (errors.length > 0) {
      throw errors[0];
    }
  }

  /**
   * Restart the mobile terminal server
   */
  async restart(): Promise<void> {
    if (this.running) {
      await this.stop();
    }
    await this.start();
  }

  /**
   * Check if the server is currently running
   */
  isRunning(): boolean {
    return this.running;
  }

  /**
   * Get the server URL
   */
  getServerUrl(): string {
    return `http://localhost:${this.defaultPort}`;
  }

  /**
   * Get connection information for clients
   */
  async getConnectionInfo(): Promise<ConnectionInfo | null> {
    if (!this.running) {
      return null;
    }

    const apiKey = await this.apiKeyManager.retrieveApiKey();
    if (!apiKey) {
      return null;
    }

    return {
      host: this.defaultHost,
      port: this.defaultPort,
      apiKey,
      isRunning: this.running
    };
  }
}