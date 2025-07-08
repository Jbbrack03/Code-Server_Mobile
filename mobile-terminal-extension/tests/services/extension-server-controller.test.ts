import * as vscode from 'vscode';
import { ExtensionServerController } from '../../src/services/extension-server-controller';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import { ExpressServer } from '../../src/server/express-server';
import { WebSocketServerManager } from '../../src/server/websocket-server-manager';

// Mock dependencies
jest.mock('../../src/services/terminal.service');
jest.mock('../../src/services/api-key-manager');
jest.mock('../../src/server/express-server');
jest.mock('../../src/server/websocket-server-manager');

describe('ExtensionServerController', () => {
  let controller: ExtensionServerController;
  let mockContext: vscode.ExtensionContext;
  let mockTerminalService: jest.Mocked<TerminalService>;
  let mockApiKeyManager: jest.Mocked<ApiKeyManager>;
  let mockExpressServer: jest.Mocked<ExpressServer>;
  let mockWebSocketManager: jest.Mocked<WebSocketServerManager>;

  beforeEach(() => {
    // Mock ExtensionContext
    mockContext = {
      subscriptions: [],
      workspaceState: {
        get: jest.fn(),
        update: jest.fn(),
        keys: jest.fn().mockReturnValue([])
      },
      globalState: {
        get: jest.fn(),
        update: jest.fn(),
        keys: jest.fn().mockReturnValue([]),
        setKeysForSync: jest.fn()
      },
      secrets: {
        get: jest.fn(),
        store: jest.fn(),
        delete: jest.fn(),
        onDidChange: jest.fn()
      },
      extensionPath: '/mock/extension/path',
      storagePath: '/mock/storage/path',
      globalStoragePath: '/mock/global/storage/path',
      logPath: '/mock/log/path',
      asAbsolutePath: jest.fn((relativePath: string) => `/mock/extension/path/${relativePath}`),
      environmentVariableCollection: {} as any,
      extensionUri: {} as any,
      extensionMode: 3, // ExtensionMode.Test
      globalStorageUri: {} as any,
      logUri: {} as any,
      storageUri: {} as any,
      extension: {} as any,
      languageModelAccessInformation: {} as any
    } as vscode.ExtensionContext;

    // Mock service instances
    mockTerminalService = new (TerminalService as jest.MockedClass<typeof TerminalService>)() as jest.Mocked<TerminalService>;
    mockApiKeyManager = new (ApiKeyManager as jest.MockedClass<typeof ApiKeyManager>)(mockContext) as jest.Mocked<ApiKeyManager>;
    mockExpressServer = new (ExpressServer as jest.MockedClass<typeof ExpressServer>)(
      mockTerminalService,
      mockApiKeyManager
    ) as jest.Mocked<ExpressServer>;
    mockWebSocketManager = new (WebSocketServerManager as jest.MockedClass<typeof WebSocketServerManager>)(
      mockTerminalService,
      mockApiKeyManager
    ) as jest.Mocked<WebSocketServerManager>;

    // Setup default mock returns
    mockExpressServer.start = jest.fn().mockResolvedValue(undefined);
    mockExpressServer.stop = jest.fn().mockResolvedValue(undefined);
    mockExpressServer.isRunning = jest.fn().mockReturnValue(false);
    mockExpressServer.getServer = jest.fn().mockReturnValue({} as any);
    mockWebSocketManager.start = jest.fn().mockResolvedValue(undefined);
    mockWebSocketManager.stop = jest.fn().mockResolvedValue(undefined);
    mockWebSocketManager.isRunning = jest.fn().mockReturnValue(false);
    mockApiKeyManager.retrieveApiKey = jest.fn().mockResolvedValue('mock-api-key');
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should create extension server controller with required dependencies', () => {
      expect(() => {
        controller = new ExtensionServerController(
          mockContext,
          mockTerminalService,
          mockApiKeyManager,
          mockExpressServer,
          mockWebSocketManager
        );
      }).not.toThrow();
    });

    it('should initialize with server stopped', () => {
      controller = new ExtensionServerController(
        mockContext,
        mockTerminalService,
        mockApiKeyManager,
        mockExpressServer,
        mockWebSocketManager
      );

      expect(controller.isRunning()).toBe(false);
    });
  });

  describe('start()', () => {
    beforeEach(() => {
      controller = new ExtensionServerController(
        mockContext,
        mockTerminalService,
        mockApiKeyManager,
        mockExpressServer,
        mockWebSocketManager
      );
    });

    it('should start express server and websocket manager', async () => {
      await controller.start();

      expect(mockExpressServer.start).toHaveBeenCalledTimes(1);
      expect(mockWebSocketManager.start).toHaveBeenCalledTimes(1);
      expect(controller.isRunning()).toBe(true);
    });

    it('should not start if already running', async () => {
      // Start once
      await controller.start();
      jest.clearAllMocks();

      // Try to start again
      await controller.start();

      expect(mockExpressServer.start).not.toHaveBeenCalled();
      expect(mockWebSocketManager.start).not.toHaveBeenCalled();
    });

    it('should handle express server start failure', async () => {
      const error = new Error('Express server failed to start');
      mockExpressServer.start.mockRejectedValue(error);

      await expect(controller.start()).rejects.toThrow('Express server failed to start');
      expect(controller.isRunning()).toBe(false);
    });

    it('should handle websocket manager start failure', async () => {
      const error = new Error('WebSocket manager failed to start');
      mockWebSocketManager.start.mockRejectedValue(error);

      await expect(controller.start()).rejects.toThrow('WebSocket manager failed to start');
      expect(controller.isRunning()).toBe(false);
    });

    it('should stop express server if websocket manager fails to start', async () => {
      const error = new Error('WebSocket manager failed to start');
      mockWebSocketManager.start.mockRejectedValue(error);

      try {
        await controller.start();
      } catch (e) {
        // Expected to fail
      }

      expect(mockExpressServer.stop).toHaveBeenCalledTimes(1);
    });
  });

  describe('stop()', () => {
    beforeEach(async () => {
      controller = new ExtensionServerController(
        mockContext,
        mockTerminalService,
        mockApiKeyManager,
        mockExpressServer,
        mockWebSocketManager
      );
      await controller.start();
      jest.clearAllMocks();
    });

    it('should stop express server and websocket manager', async () => {
      await controller.stop();

      expect(mockWebSocketManager.stop).toHaveBeenCalledTimes(1);
      expect(mockExpressServer.stop).toHaveBeenCalledTimes(1);
      expect(controller.isRunning()).toBe(false);
    });

    it('should not stop if already stopped', async () => {
      // Stop once
      await controller.stop();
      jest.clearAllMocks();

      // Try to stop again
      await controller.stop();

      expect(mockExpressServer.stop).not.toHaveBeenCalled();
      expect(mockWebSocketManager.stop).not.toHaveBeenCalled();
    });

    it('should handle websocket manager stop failure gracefully', async () => {
      const error = new Error('WebSocket manager failed to stop');
      mockWebSocketManager.stop.mockRejectedValue(error);

      await expect(controller.stop()).rejects.toThrow('WebSocket manager failed to stop');
      // Express server should still be stopped
      expect(mockExpressServer.stop).toHaveBeenCalledTimes(1);
    });

    it('should handle express server stop failure gracefully', async () => {
      const error = new Error('Express server failed to stop');
      mockExpressServer.stop.mockRejectedValue(error);

      await expect(controller.stop()).rejects.toThrow('Express server failed to stop');
      // WebSocket manager should still be stopped
      expect(mockWebSocketManager.stop).toHaveBeenCalledTimes(1);
    });
  });

  describe('getConnectionInfo()', () => {
    beforeEach(async () => {
      controller = new ExtensionServerController(
        mockContext,
        mockTerminalService,
        mockApiKeyManager,
        mockExpressServer,
        mockWebSocketManager
      );
    });

    it('should return connection information when server is running', async () => {
      await controller.start();
      
      const connectionInfo = await controller.getConnectionInfo();

      expect(connectionInfo).toEqual({
        host: expect.any(String),
        port: expect.any(Number),
        apiKey: 'mock-api-key',
        isRunning: true
      });
    });

    it('should return null when server is not running', async () => {
      const connectionInfo = await controller.getConnectionInfo();

      expect(connectionInfo).toBeNull();
    });
  });

  describe('restart()', () => {
    beforeEach(async () => {
      controller = new ExtensionServerController(
        mockContext,
        mockTerminalService,
        mockApiKeyManager,
        mockExpressServer,
        mockWebSocketManager
      );
      await controller.start();
      jest.clearAllMocks();
    });

    it('should stop and start the server', async () => {
      await controller.restart();

      expect(mockWebSocketManager.stop).toHaveBeenCalledTimes(1);
      expect(mockExpressServer.stop).toHaveBeenCalledTimes(1);
      expect(mockExpressServer.start).toHaveBeenCalledTimes(1);
      expect(mockWebSocketManager.start).toHaveBeenCalledTimes(1);
    });

    it('should handle restart when server is not running', async () => {
      await controller.stop();
      jest.clearAllMocks();

      await controller.restart();

      expect(mockExpressServer.start).toHaveBeenCalledTimes(1);
      expect(mockWebSocketManager.start).toHaveBeenCalledTimes(1);
    });
  });
});