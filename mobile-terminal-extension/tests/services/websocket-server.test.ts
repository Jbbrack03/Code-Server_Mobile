import { WebSocketServer } from '../../src/services/websocket-server';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import { WebSocketMessage, MessageType, TerminalOutputMessage, TerminalInputMessage, ErrorMessage } from '../../src/types';
import * as http from 'http';
import * as WebSocket from 'ws';

// Mock WebSocket
const mockWssOn = jest.fn();
const mockWssClose = jest.fn();
const mockWsOn = jest.fn();
const mockWsSend = jest.fn();
const mockWsClose = jest.fn();

jest.mock('ws', () => {
  const WebSocketMock = jest.fn().mockImplementation(() => ({
    on: mockWsOn,
    send: mockWsSend,
    close: mockWsClose,
    readyState: 1, // OPEN
  }));
  
  // Add static constants
  (WebSocketMock as any).OPEN = 1;
  (WebSocketMock as any).CLOSED = 3;
  
  return {
    WebSocketServer: jest.fn().mockImplementation(() => ({
      on: mockWssOn,
      close: mockWssClose,
      clients: new Set(),
    })),
    WebSocket: WebSocketMock,
  };
});

describe('WebSocketServer', () => {
  let server: WebSocketServer;
  let mockTerminalService: jest.Mocked<TerminalService>;
  let mockApiKeyManager: jest.Mocked<ApiKeyManager>;
  let mockWss: any;
  let mockWs: any;

  beforeEach(() => {
    // Create mock terminal service
    mockTerminalService = {
      getTerminals: jest.fn(),
      getActiveTerminal: jest.fn(),
      selectTerminal: jest.fn(),
      sendInput: jest.fn(),
      resizeTerminal: jest.fn(),
      getTerminalBuffer: jest.fn(),
    } as any;

    // Create mock API key manager
    mockApiKeyManager = {
      validateApiKey: jest.fn(),
      retrieveApiKeyHash: jest.fn(),
    } as any;

    // Reset WebSocket mocks
    jest.clearAllMocks();
    mockWssOn.mockClear();
    mockWssClose.mockClear();
    mockWsOn.mockClear();
    mockWsSend.mockClear();
    mockWsClose.mockClear();

    mockWss = new (WebSocket as any).WebSocketServer();
    mockWs = new (WebSocket as any).WebSocket();
    
    // Ensure mock WebSocket is in OPEN state by default
    mockWs.readyState = 1; // OPEN

    server = new WebSocketServer(8092, mockTerminalService, mockApiKeyManager);
  });

  describe('initialization', () => {
    it('should initialize WebSocket server on specified port', () => {
      expect(WebSocket.WebSocketServer).toHaveBeenCalledWith({
        port: 8092,
        verifyClient: expect.any(Function),
      });
    });

    it('should set up connection event listener', () => {
      expect(mockWssOn).toHaveBeenCalledWith('connection', expect.any(Function));
    });

    it('should initialize empty client map', () => {
      expect(server.getClientCount()).toBe(0);
    });
  });

  describe('client authentication', () => {
    it('should authenticate client with valid API key', async () => {
      const mockRequest = {
        headers: {
          'x-api-key': 'valid-api-key-123',
        },
        socket: {
          remoteAddress: '127.0.0.1',
        },
      } as unknown as http.IncomingMessage;

      mockApiKeyManager.retrieveApiKeyHash.mockResolvedValue('stored-hash');
      mockApiKeyManager.validateApiKey.mockReturnValue(true);

      const isAuthenticated = await server.authenticateClient(mockRequest);

      expect(isAuthenticated).toBe(true);
      expect(mockApiKeyManager.validateApiKey).toHaveBeenCalledWith('valid-api-key-123', 'stored-hash');
    });

    it('should reject client with invalid API key', async () => {
      const mockRequest = {
        headers: {
          'x-api-key': 'invalid-api-key-123',
        },
        socket: {
          remoteAddress: '127.0.0.1',
        },
      } as unknown as http.IncomingMessage;

      mockApiKeyManager.retrieveApiKeyHash.mockResolvedValue('stored-hash');
      mockApiKeyManager.validateApiKey.mockReturnValue(false);

      const isAuthenticated = await server.authenticateClient(mockRequest);

      expect(isAuthenticated).toBe(false);
    });

    it('should reject client with missing API key', async () => {
      const mockRequest = {
        headers: {},
        socket: {
          remoteAddress: '127.0.0.1',
        },
      } as unknown as http.IncomingMessage;

      const isAuthenticated = await server.authenticateClient(mockRequest);

      expect(isAuthenticated).toBe(false);
    });

    it('should reject client when no stored API key hash exists', async () => {
      const mockRequest = {
        headers: {
          'x-api-key': 'any-api-key',
        },
        socket: {
          remoteAddress: '127.0.0.1',
        },
      } as unknown as http.IncomingMessage;

      mockApiKeyManager.retrieveApiKeyHash.mockResolvedValue(null);

      const isAuthenticated = await server.authenticateClient(mockRequest);

      expect(isAuthenticated).toBe(false);
    });
  });

  describe('connection management', () => {
    it('should handle new client connection', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);

      expect(server.getClientCount()).toBe(1);
      expect(mockWs.on).toHaveBeenCalledWith('message', expect.any(Function));
      expect(mockWs.on).toHaveBeenCalledWith('close', expect.any(Function));
      expect(mockWs.on).toHaveBeenCalledWith('error', expect.any(Function));
    });

    it('should assign unique client ID', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      const clientId1 = server.getClientIds()[0];

      const mockWs2 = new (WebSocket as any).WebSocket();
      server.handleConnection(mockWs2, {} as http.IncomingMessage);
      const clientId2 = server.getClientIds()[1];

      expect(clientId1).not.toBe(clientId2);
      expect(clientId1).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[4][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
    });

    it('should handle client disconnection', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      expect(server.getClientCount()).toBe(1);

      const clientId = server.getClientIds()[0];
      server.handleDisconnection(clientId);

      expect(server.getClientCount()).toBe(0);
    });

    it('should start ping timer on connection', () => {
      jest.useFakeTimers();
      
      // Create a new server instance with fake timers in place
      const timerServer = new WebSocketServer(8092, mockTerminalService, mockApiKeyManager);
      
      // Make sure the mock WebSocket is in OPEN state
      mockWs.readyState = (WebSocket as any).OPEN; // Use the mocked constant
      
      timerServer.handleConnection(mockWs, {} as http.IncomingMessage);

      // Verify client was added
      expect(timerServer.getClientCount()).toBe(1);

      // Fast-forward time to trigger ping
      jest.advanceTimersByTime(30000); // 30 seconds

      // Check that ping was sent (should be the second call after initial terminal list)
      expect(mockWsSend).toHaveBeenCalledTimes(2);
      expect(mockWsSend).toHaveBeenNthCalledWith(2,
        expect.stringContaining('"type":"connection.ping"')
      );

      timerServer.close();
      jest.useRealTimers();
    });
  });

  describe('message handling', () => {
    beforeEach(() => {
      // Ensure mock WebSocket is in OPEN state
      mockWs.readyState = (WebSocket as any).OPEN;
      server.handleConnection(mockWs, {} as http.IncomingMessage);
    });

    it('should handle terminal input message', async () => {
      const inputMessage: TerminalInputMessage = {
        id: 'test-message-id',
        type: 'terminal.input',
        timestamp: Date.now(),
        payload: {
          terminalId: 'terminal-123',
          data: 'ls -la\n',
        },
      };

      mockTerminalService.sendInput.mockResolvedValue(true);

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, inputMessage);

      expect(mockTerminalService.sendInput).toHaveBeenCalledWith('terminal-123', 'ls -la\n');
    });

    it('should handle terminal select message', async () => {
      const selectMessage = {
        id: 'test-message-id',
        type: 'terminal.select' as MessageType,
        timestamp: Date.now(),
        payload: {
          terminalId: 'terminal-456',
        },
      };

      mockTerminalService.selectTerminal.mockResolvedValue(true);

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, selectMessage);

      expect(mockTerminalService.selectTerminal).toHaveBeenCalledWith('terminal-456');
    });

    it('should handle terminal resize message', async () => {
      const resizeMessage = {
        id: 'test-message-id',
        type: 'terminal.resize' as MessageType,
        timestamp: Date.now(),
        payload: {
          terminalId: 'terminal-789',
          cols: 80,
          rows: 24,
        },
      };

      mockTerminalService.resizeTerminal.mockResolvedValue(true);

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, resizeMessage);

      expect(mockTerminalService.resizeTerminal).toHaveBeenCalledWith('terminal-789', 80, 24);
    });

    it('should handle terminal list request', async () => {
      const listMessage = {
        id: 'test-message-id',
        type: 'terminal.list' as MessageType,
        timestamp: Date.now(),
        payload: {},
      };

      const mockTerminals = [
        { id: 'term1', name: 'Terminal 1', isActive: true },
        { id: 'term2', name: 'Terminal 2', isActive: false },
      ];
      mockTerminalService.getTerminals.mockReturnValue(mockTerminals as any);

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, listMessage);

      expect(mockWsSend).toHaveBeenCalledWith(
        expect.stringContaining('"terminals"')
      );
    });

    it('should handle ping message', async () => {
      const pingMessage = {
        id: 'test-message-id',
        type: 'connection.ping' as MessageType,
        timestamp: Date.now(),
        payload: {},
      };

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, pingMessage);

      expect(mockWsSend).toHaveBeenCalledWith(
        expect.stringContaining('"type":"connection.pong"')
      );
    });

    it('should handle invalid message format', async () => {
      const invalidMessage = {
        // Missing required fields
        type: 'invalid',
      };

      const clientId = server.getClientIds()[0];
      await server.handleMessage(clientId, invalidMessage as any);

      expect(mockWsSend).toHaveBeenCalledWith(
        expect.stringContaining('"type":"error"')
      );
    });
  });

  describe('broadcasting', () => {
    it('should broadcast terminal output to all clients', () => {
      // Connect multiple clients
      const mockWs2Send = jest.fn();
      const mockWs2 = {
        on: jest.fn(),
        send: mockWs2Send,
        close: jest.fn(),
        readyState: (WebSocket as any).OPEN,
      };
      
      // Set readyState for both clients
      mockWs.readyState = (WebSocket as any).OPEN;
      
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      server.handleConnection(mockWs2 as any, {} as http.IncomingMessage);

      const outputMessage: TerminalOutputMessage = {
        id: 'output-message-id',
        type: 'terminal.output',
        timestamp: Date.now(),
        payload: {
          terminalId: 'terminal-123',
          data: 'Hello World\n',
          sequence: 1,
        },
      };

      server.broadcastMessage(outputMessage);

      expect(mockWsSend).toHaveBeenCalledWith(JSON.stringify(outputMessage));
      expect(mockWs2Send).toHaveBeenCalledWith(JSON.stringify(outputMessage));
    });

    it('should not send to disconnected clients', () => {
      // Set up client in OPEN state first
      mockWs.readyState = (WebSocket as any).OPEN;
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      
      // Clear the mock to ignore the initial terminal list message
      mockWsSend.mockClear();
      
      // Then set to CLOSED state (3)
      mockWs.readyState = 3; // WebSocket.CLOSED

      const outputMessage: TerminalOutputMessage = {
        id: 'output-message-id',
        type: 'terminal.output',
        timestamp: Date.now(),
        payload: {
          terminalId: 'terminal-123',
          data: 'Hello World\n',
          sequence: 1,
        },
      };

      server.broadcastMessage(outputMessage);

      expect(mockWsSend).not.toHaveBeenCalled();
    });
  });

  describe('error handling', () => {
    it('should send error message to client', () => {
      // Ensure WebSocket is in OPEN state
      mockWs.readyState = (WebSocket as any).OPEN;
      server.handleConnection(mockWs, {} as http.IncomingMessage);

      const clientId = server.getClientIds()[0];
      server.sendError(clientId, 'TERM_001', 'Terminal not found', { terminalId: 'missing' });

      expect(mockWsSend).toHaveBeenCalledWith(
        expect.stringContaining('"type":"error"')
      );
      expect(mockWsSend).toHaveBeenCalledWith(
        expect.stringContaining('"code":"TERM_001"')
      );
    });

    it('should handle WebSocket errors gracefully', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);

      const errorHandler = mockWs.on.mock.calls.find((call: any) => call[0] === 'error')[1];
      expect(() => errorHandler(new Error('Test error'))).not.toThrow();
    });
  });

  describe('message queuing', () => {
    it('should queue messages when client is not ready', () => {
      // Set up client in CONNECTING state from the beginning
      mockWs.readyState = 0; // CONNECTING
      server.handleConnection(mockWs, {} as http.IncomingMessage);

      const message: WebSocketMessage = {
        id: 'queued-message',
        type: 'terminal.output',
        timestamp: Date.now(),
        payload: { data: 'test' },
      };

      const clientId = server.getClientIds()[0];
      server.sendToClient(clientId, message);

      expect(mockWsSend).not.toHaveBeenCalled();
      expect(server.getQueueSize(clientId)).toBe(2); // Initial terminal list + test message
    });

    it('should flush queued messages when client becomes ready', () => {
      // Set up client in CONNECTING state from the beginning
      mockWs.readyState = 0; // CONNECTING
      server.handleConnection(mockWs, {} as http.IncomingMessage);

      const message: WebSocketMessage = {
        id: 'queued-message',
        type: 'terminal.output',
        timestamp: Date.now(),
        payload: { data: 'test' },
      };

      const clientId = server.getClientIds()[0];
      server.sendToClient(clientId, message);

      // Simulate client becoming ready
      mockWs.readyState = (WebSocket as any).OPEN;
      server.flushMessageQueue(clientId);

      // Should have called send with both the terminal list and the test message
      expect(mockWsSend).toHaveBeenCalledWith(JSON.stringify(message));
      expect(server.getQueueSize(clientId)).toBe(0);
    });

    it('should limit queue size to prevent memory issues', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      mockWs.readyState = 0; // CONNECTING

      const clientId = server.getClientIds()[0];

      // Send more messages than queue limit
      for (let i = 0; i < 150; i++) {
        const message: WebSocketMessage = {
          id: `message-${i}`,
          type: 'terminal.output',
          timestamp: Date.now(),
          payload: { data: `test ${i}` },
        };
        server.sendToClient(clientId, message);
      }

      // Should be limited to 100 messages
      expect(server.getQueueSize(clientId)).toBe(100);
    });
  });

  describe('server lifecycle', () => {
    it('should close WebSocket server', () => {
      server.close();
      expect(mockWss.close).toHaveBeenCalled();
    });

    it('should clear all clients on close', () => {
      server.handleConnection(mockWs, {} as http.IncomingMessage);
      expect(server.getClientCount()).toBe(1);

      server.close();
      expect(server.getClientCount()).toBe(0);
    });
  });
});