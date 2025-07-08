import WebSocket from 'ws';
import { ExpressServer } from '../../src/server/express-server';
import { WebSocketServerManager } from '../../src/server/websocket-server-manager';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import { WebSocketMessage, MessageType } from '../../src/types';

// Mock the VS Code module
jest.mock('vscode', () => ({
  window: { terminals: [] },
  ExtensionContext: jest.fn(),
  Terminal: jest.fn(),
  Disposable: { from: jest.fn() }
}), { virtual: true });

// WebSocket test utilities
class WebSocketTestUtils {
  static async waitForConnection(ws: WebSocket, timeout = 5000): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`WebSocket connection timeout after ${timeout}ms`));
      }, timeout);

      ws.on('open', () => {
        clearTimeout(timer);
        resolve();
      });

      ws.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });

      ws.on('close', (code, reason) => {
        if (code === 1008 || code === 1011 || code === 1013) {
          clearTimeout(timer);
          reject(new Error(`WebSocket connection rejected: ${code} ${reason}`));
        }
      });
    });
  }

  static async waitForMessage(ws: WebSocket, timeout = 5000): Promise<any> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`WebSocket message timeout after ${timeout}ms`));
      }, timeout);

      ws.on('message', (data) => {
        clearTimeout(timer);
        try {
          const message = JSON.parse(data.toString());
          resolve(message);
        } catch (error) {
          reject(new Error('Invalid JSON message received'));
        }
      });

      ws.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  static async waitForClose(ws: WebSocket, timeout = 5000): Promise<void> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error(`WebSocket close timeout after ${timeout}ms`));
      }, timeout);

      ws.on('close', () => {
        clearTimeout(timer);
        resolve();
      });

      ws.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  static createTestMessage(type: MessageType, payload: any): WebSocketMessage {
    return {
      id: `test-${Date.now()}`,
      type,
      timestamp: Date.now(),
      payload
    };
  }
}

describe('WebSocket Integration with Express Server', () => {
  let expressServer: ExpressServer;
  let webSocketManager: WebSocketServerManager;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockExtensionContext: any;
  let testPort: number;
  let validApiKey: string;

  beforeEach(async () => {
    // Calculate dynamic port to avoid conflicts
    testPort = 8100 + Math.floor(Math.random() * 100);

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

    // Initialize services
    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockExtensionContext);
    expressServer = new ExpressServer(terminalService, apiKeyManager);
    webSocketManager = new WebSocketServerManager(terminalService, apiKeyManager);

    // Set up a valid API key for testing
    validApiKey = 'test-api-key-123';
    jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
    jest.spyOn(apiKeyManager, 'retrieveApiKey').mockResolvedValue(validApiKey);

    // Start Express server
    await expressServer.start(testPort, '0.0.0.0');
  });

  afterEach(async () => {
    if (webSocketManager) {
      await webSocketManager.stop();
    }
    if (expressServer) {
      await expressServer.stop();
    }
  });

  describe('WebSocket Server Initialization', () => {
    it('should start WebSocket server alongside Express server', async () => {
      await webSocketManager.start(expressServer.getServer());
      
      expect(webSocketManager.isRunning()).toBe(true);
      expect(webSocketManager.getConnectedClients()).toBe(0);
    });

    it('should accept WebSocket connections on the same port as Express', async () => {
      await webSocketManager.start(expressServer.getServer());
      
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      await WebSocketTestUtils.waitForConnection(ws);
      
      expect(ws.readyState).toBe(WebSocket.OPEN);
      expect(webSocketManager.getConnectedClients()).toBe(1);
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle multiple concurrent WebSocket connections', async () => {
      await webSocketManager.start(expressServer.getServer());
      
      const ws1 = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      const ws2 = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      const ws3 = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      
      await Promise.all([
        WebSocketTestUtils.waitForConnection(ws1),
        WebSocketTestUtils.waitForConnection(ws2),
        WebSocketTestUtils.waitForConnection(ws3)
      ]);
      
      expect(webSocketManager.getConnectedClients()).toBe(3);
      
      ws1.close();
      ws2.close();
      ws3.close();
      
      await Promise.all([
        WebSocketTestUtils.waitForClose(ws1),
        WebSocketTestUtils.waitForClose(ws2),
        WebSocketTestUtils.waitForClose(ws3)
      ]);
    });
  });

  describe('WebSocket Authentication', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should authenticate WebSocket connections with valid API key', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);
      expect(ws.readyState).toBe(WebSocket.OPEN);
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should reject WebSocket connections without API key', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`);
      
      await expect(WebSocketTestUtils.waitForConnection(ws)).rejects.toThrow();
    });

    it('should reject WebSocket connections with invalid API key', async () => {
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(false);
      
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': 'invalid-key'
        }
      });
      
      await expect(WebSocketTestUtils.waitForConnection(ws)).rejects.toThrow();
    });
  });

  describe('Terminal Output Streaming', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should stream terminal output to connected clients', async () => {
      // Create a mock terminal
      const mockTerminal = {
        id: 'test-terminal-1',
        name: 'bash',
        pid: 1234,
        cwd: '/home/user',
        shellType: 'bash' as const,
        isActive: true,
        isClaudeCode: false,
        createdAt: new Date(),
        lastActivity: new Date(),
        dimensions: { cols: 80, rows: 24 },
        status: 'active' as const
      };

      jest.spyOn(terminalService, 'getTerminals').mockReturnValue([mockTerminal]);
      jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue('test-terminal-1');

      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      // Simulate terminal output
      const outputData = 'Hello from terminal!\n';
      webSocketManager.broadcastTerminalOutput('test-terminal-1', outputData, 1);

      const message = await WebSocketTestUtils.waitForMessage(ws);
      
      expect(message.type).toBe('terminal.output');
      expect(message.payload.terminalId).toBe('test-terminal-1');
      expect(message.payload.data).toBe(outputData);
      expect(message.payload.sequence).toBe(1);
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle terminal list updates', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const mockTerminals = [
        {
          id: 'terminal-1',
          name: 'bash',
          pid: 1234,
          cwd: '/home/user',
          shellType: 'bash' as const,
          isActive: true,
          isClaudeCode: false,
          createdAt: new Date(),
          lastActivity: new Date(),
          dimensions: { cols: 80, rows: 24 },
          status: 'active' as const
        },
        {
          id: 'terminal-2',
          name: 'zsh',
          pid: 5678,
          cwd: '/home/user',
          shellType: 'zsh' as const,
          isActive: false,
          isClaudeCode: true,
          createdAt: new Date(),
          lastActivity: new Date(),
          dimensions: { cols: 120, rows: 30 },
          status: 'active' as const
        }
      ];

      jest.spyOn(terminalService, 'getTerminals').mockReturnValue(mockTerminals);
      jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue('terminal-1');

      webSocketManager.broadcastTerminalList();

      const message = await WebSocketTestUtils.waitForMessage(ws);
      
      expect(message.type).toBe('terminal.list');
      expect(message.payload.terminals).toHaveLength(2);
      expect(message.payload.activeTerminalId).toBe('terminal-1');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });
  });

  describe('Client to Server Communication', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should handle terminal input messages from clients', async () => {
      jest.spyOn(terminalService, 'sendInput').mockResolvedValue(true);

      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const inputMessage = WebSocketTestUtils.createTestMessage('terminal.input', {
        terminalId: 'test-terminal-1',
        data: 'ls -la\n'
      });

      ws.send(JSON.stringify(inputMessage));

      // Verify the terminal service received the input
      await new Promise(resolve => setTimeout(resolve, 100)); // Small delay for processing
      
      expect(terminalService.sendInput).toHaveBeenCalledWith('test-terminal-1', 'ls -la\n');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle terminal selection messages from clients', async () => {
      jest.spyOn(terminalService, 'selectTerminal').mockResolvedValue(true);
      jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue('test-terminal-2');

      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const selectMessage = WebSocketTestUtils.createTestMessage('terminal.select', {
        terminalId: 'test-terminal-2'
      });

      ws.send(JSON.stringify(selectMessage));

      // Verify the terminal service selected the terminal
      await new Promise(resolve => setTimeout(resolve, 100)); // Small delay for processing
      
      expect(terminalService.selectTerminal).toHaveBeenCalledWith('test-terminal-2');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle terminal resize messages from clients', async () => {
      jest.spyOn(terminalService, 'resizeTerminal').mockResolvedValue(true);

      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const resizeMessage = WebSocketTestUtils.createTestMessage('terminal.resize', {
        terminalId: 'test-terminal-1',
        cols: 120,
        rows: 30
      });

      ws.send(JSON.stringify(resizeMessage));

      // Verify the terminal service resized the terminal
      await new Promise(resolve => setTimeout(resolve, 100)); // Small delay for processing
      
      expect(terminalService.resizeTerminal).toHaveBeenCalledWith('test-terminal-1', 120, 30);
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle ping/pong messages for keep-alive', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const pingMessage = WebSocketTestUtils.createTestMessage('connection.ping', {});
      ws.send(JSON.stringify(pingMessage));

      const pongMessage = await WebSocketTestUtils.waitForMessage(ws);
      
      expect(pongMessage.type).toBe('connection.pong');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should handle invalid JSON messages gracefully', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      // Send invalid JSON
      ws.send('invalid json message');

      const errorMessage = await WebSocketTestUtils.waitForMessage(ws);
      
      expect(errorMessage.type).toBe('error');
      expect(errorMessage.payload.code).toBe('WS_MESSAGE_INVALID');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle unknown message types', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);

      const invalidMessage = {
        id: 'test-123',
        type: 'unknown.type',
        timestamp: Date.now(),
        payload: {}
      };

      ws.send(JSON.stringify(invalidMessage));

      const errorMessage = await WebSocketTestUtils.waitForMessage(ws);
      
      expect(errorMessage.type).toBe('error');
      expect(errorMessage.payload.code).toBe('WS_MESSAGE_INVALID');
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
    });

    it('should handle client disconnections gracefully', async () => {
      const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: {
          'X-API-Key': validApiKey
        }
      });
      
      await WebSocketTestUtils.waitForConnection(ws);
      expect(webSocketManager.getConnectedClients()).toBe(1);
      
      ws.close();
      await WebSocketTestUtils.waitForClose(ws);
      
      // Small delay for cleanup
      await new Promise(resolve => setTimeout(resolve, 100));
      expect(webSocketManager.getConnectedClients()).toBe(0);
    });
  });

  describe('Message Broadcasting', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should broadcast messages to all connected clients', async () => {
      const ws1 = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      const ws2 = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      
      await Promise.all([
        WebSocketTestUtils.waitForConnection(ws1),
        WebSocketTestUtils.waitForConnection(ws2)
      ]);

      // Broadcast a terminal output message
      webSocketManager.broadcastTerminalOutput('test-terminal', 'broadcast test', 1);

      const [message1, message2] = await Promise.all([
        WebSocketTestUtils.waitForMessage(ws1),
        WebSocketTestUtils.waitForMessage(ws2)
      ]);
      
      expect(message1.type).toBe('terminal.output');
      expect(message1.payload.data).toBe('broadcast test');
      expect(message2.type).toBe('terminal.output');
      expect(message2.payload.data).toBe('broadcast test');
      
      ws1.close();
      ws2.close();
      
      await Promise.all([
        WebSocketTestUtils.waitForClose(ws1),
        WebSocketTestUtils.waitForClose(ws2)
      ]);
    });
  });

  describe('Connection Limits and Performance', () => {
    beforeEach(async () => {
      await webSocketManager.start(expressServer.getServer());
    });

    it('should handle connection limit enforcement', async () => {
      const maxConnections = webSocketManager.getMaxConnections();
      const connections: WebSocket[] = [];
      
      // Create connections up to the limit
      for (let i = 0; i < maxConnections; i++) {
        const ws = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
          headers: { 'X-API-Key': validApiKey }
        });
        await WebSocketTestUtils.waitForConnection(ws);
        connections.push(ws);
      }
      
      expect(webSocketManager.getConnectedClients()).toBe(maxConnections);
      
      // Try to create one more connection (should be rejected)
      const extraWs = new WebSocket(`ws://localhost:${testPort}/api/terminal/stream`, {
        headers: { 'X-API-Key': validApiKey }
      });
      
      await expect(WebSocketTestUtils.waitForConnection(extraWs)).rejects.toThrow();
      
      // Clean up all connections
      for (const ws of connections) {
        ws.close();
      }
      
      await Promise.all(connections.map(ws => WebSocketTestUtils.waitForClose(ws)));
    });
  });
});