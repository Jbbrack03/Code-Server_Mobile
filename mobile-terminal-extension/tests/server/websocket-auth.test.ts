import WebSocket from 'ws';
import { createServer, Server } from 'http';
import { WebSocketServerManager } from '../../src/server/websocket-server-manager';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';

// Mock the VS Code module
jest.mock('vscode', () => ({
  window: { terminals: [] },
  ExtensionContext: jest.fn(),
  Terminal: jest.fn(),
  Disposable: { from: jest.fn() }
}), { virtual: true });

describe('WebSocket Authentication', () => {
  let webSocketManager: WebSocketServerManager;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockExtensionContext: any;
  let httpServer: Server;
  let port: number;

  beforeEach(async () => {
    // Mock extension context
    mockExtensionContext = {
      globalState: {
        get: jest.fn(),
        update: jest.fn()
      },
      secrets: {
        get: jest.fn(),
        store: jest.fn()
      }
    };

    // Create real HTTP server for testing
    httpServer = createServer();
    
    await new Promise<void>((resolve) => {
      httpServer.listen(0, () => {
        const address = httpServer.address();
        port = typeof address === 'object' && address ? address.port : 0;
        resolve();
      });
    });

    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockExtensionContext);
    webSocketManager = new WebSocketServerManager(terminalService, apiKeyManager, 3); // Set low limit for testing
  });

  afterEach(async () => {
    if (webSocketManager && webSocketManager.isRunning()) {
      await webSocketManager.stop();
    }
    if (httpServer) {
      await new Promise<void>((resolve) => {
        httpServer.close(() => resolve());
      });
    }
  });

  it('should reject connections without API key in headers', async () => {
    await webSocketManager.start(httpServer);
    
    // Mock API key validation to return false for missing key
    jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockRejectedValue(new Error('No API key'));

    const ws = new WebSocket(`ws://localhost:${port}/api/terminal/stream`);
    
    // Wait for connection to be rejected
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Connection should have been rejected'));
      }, 1000);

      ws.on('error', () => {
        clearTimeout(timeout);
        resolve();
      });

      ws.on('close', (code) => {
        clearTimeout(timeout);
        if (code === 1008 || code === 1011) {
          resolve(); // Expected rejection
        } else {
          reject(new Error(`Unexpected close code: ${code}`));
        }
      });

      ws.on('open', () => {
        clearTimeout(timeout);
        ws.close();
        reject(new Error('Connection should not have opened'));
      });
    });
  });

  it('should reject connections with invalid API key', async () => {
    await webSocketManager.start(httpServer);
    
    // Mock API key validation to return false
    jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(false);

    const ws = new WebSocket(`ws://localhost:${port}/api/terminal/stream`, {
      headers: {
        'X-API-Key': 'invalid-key'
      }
    });
    
    // Wait for connection to be rejected
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Connection should have been rejected'));
      }, 1000);

      ws.on('error', () => {
        clearTimeout(timeout);
        resolve();
      });

      ws.on('close', (code) => {
        clearTimeout(timeout);
        if (code === 1008 || code === 1011) {
          resolve(); // Expected rejection
        } else {
          reject(new Error(`Unexpected close code: ${code}`));
        }
      });

      ws.on('open', () => {
        clearTimeout(timeout);
        ws.close();
        reject(new Error('Connection should not have opened'));
      });
    });
  });

  it('should accept connections with valid API key', async () => {
    await webSocketManager.start(httpServer);
    
    // Mock API key validation to return true
    jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);

    const ws = new WebSocket(`ws://localhost:${port}/api/terminal/stream`, {
      headers: {
        'X-API-Key': 'valid-key'
      }
    });
    
    // Wait for successful connection
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Connection should have been accepted'));
      }, 1000);

      ws.on('error', (error) => {
        clearTimeout(timeout);
        reject(error);
      });

      ws.on('close', (code) => {
        clearTimeout(timeout);
        if (code !== 1000) {
          reject(new Error(`Unexpected close code: ${code}`));
        }
      });

      ws.on('open', () => {
        clearTimeout(timeout);
        expect(ws.readyState).toBe(WebSocket.OPEN);
        expect(webSocketManager.getConnectedClients()).toBe(1);
        ws.close();
        resolve();
      });
    });
  });

  it('should enforce connection limits', async () => {
    await webSocketManager.start(httpServer);
    
    // Mock API key validation to return true
    jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
    
    const maxConnections = webSocketManager.getMaxConnections();
    const connections: WebSocket[] = [];
    
    // Create connections up to the limit
    for (let i = 0; i < maxConnections; i++) {
      const ws = new WebSocket(`ws://localhost:${port}/api/terminal/stream`, {
        headers: {
          'X-API-Key': 'valid-key'
        }
      });
      
      await new Promise<void>((resolve, reject) => {
        ws.on('open', () => resolve());
        ws.on('error', reject);
      });
      
      connections.push(ws);
    }
    
    expect(webSocketManager.getConnectedClients()).toBe(maxConnections);
    
    // Try to create one more connection beyond the limit
    const extraWs = new WebSocket(`ws://localhost:${port}/api/terminal/stream`, {
      headers: {
        'X-API-Key': 'valid-key'
      }
    });
    
    // This connection should be rejected
    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Connection should have been rejected due to limit'));
      }, 1000);

      extraWs.on('error', () => {
        clearTimeout(timeout);
        resolve();
      });

      extraWs.on('close', (code) => {
        clearTimeout(timeout);
        if (code === 1013) { // Too many connections
          resolve();
        } else {
          reject(new Error(`Unexpected close code: ${code}`));
        }
      });

      extraWs.on('open', () => {
        clearTimeout(timeout);
        extraWs.close();
        reject(new Error('Connection should not have opened'));
      });
    });
    
    // Clean up connections
    for (const ws of connections) {
      ws.close();
    }
  });
});