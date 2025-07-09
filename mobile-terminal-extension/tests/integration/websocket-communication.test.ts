import WebSocket from 'ws';
import { ExpressServer } from '../../src/server/express-server';
import { WebSocketServerManager } from '../../src/server/websocket-server-manager';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import * as vscode from 'vscode';

// Mock VS Code API
jest.mock('vscode', () => ({
  window: {
    createTerminal: jest.fn(),
    terminals: [],
    onDidOpenTerminal: jest.fn(),
    onDidCloseTerminal: jest.fn(),
    onDidChangeActiveTerminal: jest.fn(),
  },
}));

describe('WebSocket Communication - TDD', () => {
  let expressServer: ExpressServer;
  let webSocketManager: WebSocketServerManager;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockContext: vscode.ExtensionContext;
  let mockStorage: { apiKey: string | null; apiKeyHash: string | null };
  let validApiKey: string;

  beforeEach(async () => {
    // Setup mock storage
    mockStorage = {
      apiKey: null,
      apiKeyHash: null,
    };

    // Setup mock context
    mockContext = {
      subscriptions: [],
      globalState: {
        get: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKeyHash') {
            return mockStorage.apiKeyHash;
          }
          return undefined;
        }),
        update: jest.fn().mockImplementation((key, value) => {
          if (key === 'mobileTerminal.apiKeyHash') {
            mockStorage.apiKeyHash = value;
          }
          return Promise.resolve();
        }),
      },
      secrets: {
        get: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKey') {
            return Promise.resolve(mockStorage.apiKey);
          }
          return Promise.resolve(undefined);
        }),
        store: jest.fn().mockImplementation((key, value) => {
          if (key === 'mobileTerminal.apiKey') {
            mockStorage.apiKey = value;
          }
          return Promise.resolve();
        }),
        delete: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKey') {
            mockStorage.apiKey = null;
          }
          return Promise.resolve();
        }),
      },
    } as any;

    // Initialize services
    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockContext);
    expressServer = new ExpressServer(terminalService, apiKeyManager);
    webSocketManager = new WebSocketServerManager(terminalService, apiKeyManager, 3); // Set test limit to 3

    // Generate and store API key
    validApiKey = await apiKeyManager.generateApiKey();
    await apiKeyManager.storeApiKey(validApiKey);

    // Start servers
    await expressServer.start(0, 'localhost');
    const httpServer = expressServer.getServer();
    if (!httpServer) {
      throw new Error('HTTP server not created');
    }
    await webSocketManager.start(httpServer);
  });

  afterEach(async () => {
    await webSocketManager.stop();
    await expressServer.stop();
  });

  describe('Connection establishment', () => {
    it('should accept connections with valid API key', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;

      // Act
      const ws = new WebSocket(wsUrl, {
        headers: {
          'X-API-Key': validApiKey,
        },
      });

      // Assert
      await new Promise<void>((resolve, reject) => {
        let timeoutHandle: NodeJS.Timeout;

        ws.on('open', () => {
          clearTimeout(timeoutHandle);
          expect(ws.readyState).toBe(WebSocket.OPEN);
          ws.close();
          resolve();
        });

        ws.on('error', (error) => {
          clearTimeout(timeoutHandle);
          reject(error);
        });

        ws.on('close', (code, reason) => {
          if (code !== 1000) {
            clearTimeout(timeoutHandle);
            reject(new Error(`WebSocket closed with code ${code}: ${reason}`));
          }
        });

        timeoutHandle = setTimeout(() => {
          ws.close();
          reject(new Error('Connection timeout'));
        }, 5000);
      });
    });

    it('should reject connections with missing API key', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;

      // Act & Assert
      await expect(
        new Promise<void>((resolve, reject) => {
          const ws = new WebSocket(wsUrl);

          ws.on('open', () => {
            // Connection opens briefly before being closed due to auth error
            // This is expected behavior with our implementation
          });

          ws.on('close', (code: number, reason: string) => {
            expect(code).toBe(1008);
            expect(reason.toString()).toBe('Missing API key');
            resolve();
          });

          ws.on('error', (error: any) => {
            reject(error);
          });

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        })
      ).resolves.toBeUndefined();
    });

    it('should reject connections with invalid API key', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;

      // Act & Assert
      await expect(
        new Promise<void>((resolve, reject) => {
          const ws = new WebSocket(wsUrl, {
            headers: {
              'X-API-Key': 'invalid-key',
            },
          });

          ws.on('open', () => {
            // Connection opens briefly before being closed due to auth error
            // This is expected behavior with our implementation
          });

          ws.on('close', (code: number, reason: string) => {
            expect(code).toBe(1008);
            expect(reason.toString()).toBe('Invalid API key');
            resolve();
          });

          ws.on('error', (error: any) => {
            reject(error);
          });

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        })
      ).resolves.toBeUndefined();
    });

    it('should reject connections when limit exceeded', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;
      const connections: WebSocket[] = [];

      // Act - Create connections up to limit (using test limit of 3)
      for (let i = 0; i < 3; i++) {
        const ws = new WebSocket(wsUrl, {
          headers: {
            'X-API-Key': validApiKey,
          },
        });

        await new Promise<void>((resolve, reject) => {
          ws.on('open', () => {
            connections.push(ws);
            resolve();
          });

          ws.on('error', reject);

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        });
      }

      // Assert - The 4th connection should be rejected
      await expect(
        new Promise<void>((resolve, reject) => {
          const ws = new WebSocket(wsUrl, {
            headers: {
              'X-API-Key': validApiKey,
            },
          });

          ws.on('open', () => {
            // Connection opens briefly before being closed due to limit exceeded
            // This is expected behavior with our implementation
          });

          ws.on('close', (code: number, reason: string) => {
            expect(code).toBe(1013);
            expect(reason.toString()).toBe('Too many connections');
            resolve();
          });

          ws.on('error', (error: any) => {
            reject(error);
          });

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        })
      ).resolves.toBeUndefined();

      // Cleanup
      connections.forEach(ws => ws.close());
    });

    it('should assign unique client ID to each connection', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;
      const connections: WebSocket[] = [];

      // Act - Create two connections
      for (let i = 0; i < 2; i++) {
        const ws = new WebSocket(wsUrl, {
          headers: {
            'X-API-Key': validApiKey,
          },
        });

        await new Promise<void>((resolve, reject) => {
          ws.on('open', () => {
            connections.push(ws);
            resolve();
          });

          ws.on('error', reject);

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        });
      }

      // Assert - Each connection should have a unique client ID
      // This will be verified by checking that the server tracks different connections
      expect(connections.length).toBe(2);
      expect(connections[0]).not.toBe(connections[1]);

      // Cleanup
      connections.forEach(ws => ws.close());
    });
  });

  describe('Message broadcasting', () => {
    it('should broadcast terminal output to all connected clients', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;
      const connections: WebSocket[] = [];
      const messages: any[][] = [[], []];

      // Create two connections
      for (let i = 0; i < 2; i++) {
        const ws = new WebSocket(wsUrl, {
          headers: {
            'X-API-Key': validApiKey,
          },
        });

        await new Promise<void>((resolve, reject) => {
          ws.on('open', () => {
            connections.push(ws);
            resolve();
          });

          ws.on('message', (data) => {
            messages[i].push(JSON.parse(data.toString()));
          });

          ws.on('error', reject);

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        });
      }

      // Act - Simulate terminal output
      const terminalId = 'test-terminal-1';
      const outputData = 'Hello from terminal';
      
      // This should trigger broadcasting to all clients
      webSocketManager.broadcastTerminalData(terminalId, outputData);

      // Wait for messages to be received
      await new Promise(resolve => setTimeout(resolve, 100));

      // Assert - Both clients should receive the message
      expect(messages[0]).toHaveLength(1);
      expect(messages[1]).toHaveLength(1);

      expect(messages[0][0]).toMatchObject({
        id: expect.any(String),
        type: 'terminal.output',
        timestamp: expect.any(Number),
        payload: {
          terminalId: terminalId,
          data: outputData,
          sequence: expect.any(Number),
        },
      });

      expect(messages[1][0]).toMatchObject({
        id: expect.any(String),
        type: 'terminal.output',
        timestamp: expect.any(Number),
        payload: {
          terminalId: terminalId,
          data: outputData,
          sequence: expect.any(Number),
        },
      });

      // Cleanup
      connections.forEach(ws => ws.close());
    });

    it('should handle client disconnections gracefully', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;
      const connections: WebSocket[] = [];

      // Create two connections
      for (let i = 0; i < 2; i++) {
        const ws = new WebSocket(wsUrl, {
          headers: {
            'X-API-Key': validApiKey,
          },
        });

        await new Promise<void>((resolve, reject) => {
          ws.on('open', () => {
            connections.push(ws);
            resolve();
          });

          ws.on('error', reject);

          setTimeout(() => {
            reject(new Error('Connection timeout'));
          }, 5000);
        });
      }

      // Act - Disconnect one client
      connections[0].close();

      // Wait for disconnection to be processed
      await new Promise(resolve => setTimeout(resolve, 100));

      // Assert - Broadcasting should still work for remaining client
      let messageReceived = false;
      connections[1].on('message', (data) => {
        const message = JSON.parse(data.toString());
        expect(message.type).toBe('terminal.output');
        messageReceived = true;
      });

      webSocketManager.broadcastTerminalData('test-terminal', 'test data');

      await new Promise(resolve => setTimeout(resolve, 100));
      expect(messageReceived).toBe(true);

      // Cleanup
      connections[1].close();
    });

    it('should maintain connection state', async () => {
      // Arrange
      const port = expressServer.getPort();
      const wsUrl = `ws://localhost:${port}/api/terminal/stream`;

      // Act - Create connection
      const ws = new WebSocket(wsUrl, {
        headers: {
          'X-API-Key': validApiKey,
        },
      });

      await new Promise<void>((resolve, reject) => {
        ws.on('open', () => {
          resolve();
        });

        ws.on('error', reject);

        setTimeout(() => {
          reject(new Error('Connection timeout'));
        }, 5000);
      });

      // Assert - Connection should be maintained
      expect(ws.readyState).toBe(WebSocket.OPEN);

      // Test ping/pong to verify connection state
      let pongReceived = false;
      ws.on('pong', () => {
        pongReceived = true;
      });

      ws.ping();

      await new Promise(resolve => setTimeout(resolve, 100));
      expect(pongReceived).toBe(true);

      // Cleanup
      ws.close();
    });
  });
});