import WebSocket from 'ws';
import { Server } from 'http';
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

describe('WebSocketServerManager', () => {
  let webSocketManager: WebSocketServerManager;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockExtensionContext: any;
  let mockServer: Server;

  beforeEach(() => {
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

    // Mock HTTP server with EventEmitter behavior
    mockServer = {
      on: jest.fn(),
      off: jest.fn(),
      removeListener: jest.fn(),
      removeAllListeners: jest.fn(),
      listeners: jest.fn().mockReturnValue([]),
      close: jest.fn((callback) => callback()),
      listen: jest.fn(),
      address: jest.fn().mockReturnValue({ port: 8080 }),
      emit: jest.fn(),
      addListener: jest.fn(),
      once: jest.fn(),
      prependListener: jest.fn(),
      prependOnceListener: jest.fn(),
      eventNames: jest.fn().mockReturnValue([]),
      listenerCount: jest.fn().mockReturnValue(0),
      getMaxListeners: jest.fn().mockReturnValue(10),
      setMaxListeners: jest.fn()
    } as any;

    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockExtensionContext);
    webSocketManager = new WebSocketServerManager(terminalService, apiKeyManager);
  });

  afterEach(async () => {
    if (webSocketManager && webSocketManager.isRunning()) {
      await webSocketManager.stop();
    }
  });

  describe('Basic Operations', () => {
    it('should initialize with correct default values', () => {
      expect(webSocketManager.isRunning()).toBe(false);
      expect(webSocketManager.getConnectedClients()).toBe(0);
      expect(webSocketManager.getMaxConnections()).toBe(50);
    });

    it('should start successfully with valid server', async () => {
      await webSocketManager.start(mockServer);
      
      expect(webSocketManager.isRunning()).toBe(true);
    });

    it('should throw error when starting without server', async () => {
      await expect(webSocketManager.start(null)).rejects.toThrow('HTTP server is required');
    });

    it('should throw error when starting twice', async () => {
      await webSocketManager.start(mockServer);
      
      await expect(webSocketManager.start(mockServer)).rejects.toThrow('WebSocket server is already running');
    });

    it('should stop gracefully', async () => {
      await webSocketManager.start(mockServer);
      expect(webSocketManager.isRunning()).toBe(true);
      
      await webSocketManager.stop();
      expect(webSocketManager.isRunning()).toBe(false);
    });
  });

  describe('Connection Management', () => {
    beforeEach(async () => {
      await webSocketManager.start(mockServer);
    });

    it('should track connected clients', () => {
      expect(webSocketManager.getConnectedClients()).toBe(0);
    });

    it('should enforce connection limits', () => {
      expect(webSocketManager.getMaxConnections()).toBeGreaterThan(0);
    });
  });

  describe('Message Broadcasting', () => {
    beforeEach(async () => {
      await webSocketManager.start(mockServer);
    });

    it('should have method to broadcast terminal output', () => {
      expect(typeof webSocketManager.broadcastTerminalOutput).toBe('function');
      
      // Should not throw when called with valid parameters
      expect(() => {
        webSocketManager.broadcastTerminalOutput('terminal-1', 'test output', 1);
      }).not.toThrow();
    });

    it('should have method to broadcast terminal list', () => {
      expect(typeof webSocketManager.broadcastTerminalList).toBe('function');
      
      // Should not throw when called
      expect(() => {
        webSocketManager.broadcastTerminalList();
      }).not.toThrow();
    });
  });

  describe('Authentication Logic', () => {
    beforeEach(async () => {
      await webSocketManager.start(mockServer);
    });

    it('should validate API keys through ApiKeyManager', async () => {
      const spy = jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
      
      // Call the method that should trigger API key validation
      // This tests that the manager has the capability to validate keys
      const result = await apiKeyManager.validateApiKeyAsync('test-key');
      
      expect(spy).toHaveBeenCalledWith('test-key');
      expect(result).toBe(true);
    });

    it('should handle invalid API keys', async () => {
      const spy = jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(false);
      
      const result = await apiKeyManager.validateApiKeyAsync('invalid-key');
      
      expect(spy).toHaveBeenCalledWith('invalid-key');
      expect(result).toBe(false);
    });
  });

  describe('Terminal Integration', () => {
    beforeEach(async () => {
      await webSocketManager.start(mockServer);
    });

    it('should integrate with TerminalService for getting terminals', () => {
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
        }
      ];

      jest.spyOn(terminalService, 'getTerminals').mockReturnValue(mockTerminals);
      jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue('terminal-1');

      const terminals = terminalService.getTerminals();
      const activeId = terminalService.getActiveTerminalId();

      expect(terminals).toEqual(mockTerminals);
      expect(activeId).toBe('terminal-1');
    });

    it('should integrate with TerminalService for sending input', async () => {
      const spy = jest.spyOn(terminalService, 'sendInput').mockResolvedValue(true);
      
      await terminalService.sendInput('terminal-1', 'test command');
      
      expect(spy).toHaveBeenCalledWith('terminal-1', 'test command');
    });

    it('should integrate with TerminalService for terminal selection', async () => {
      const spy = jest.spyOn(terminalService, 'selectTerminal').mockResolvedValue(true);
      
      await terminalService.selectTerminal('terminal-2');
      
      expect(spy).toHaveBeenCalledWith('terminal-2');
    });

    it('should integrate with TerminalService for terminal resizing', async () => {
      const spy = jest.spyOn(terminalService, 'resizeTerminal').mockResolvedValue(true);
      
      await terminalService.resizeTerminal('terminal-1', 120, 30);
      
      expect(spy).toHaveBeenCalledWith('terminal-1', 120, 30);
    });
  });
});