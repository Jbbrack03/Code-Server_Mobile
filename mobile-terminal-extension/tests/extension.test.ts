import { activate } from '../src/extension';
import * as vscode from 'vscode';

// Mock the services
jest.mock('../src/services/terminal.service');
jest.mock('../src/services/api-key-manager');
jest.mock('../src/services/websocket-server');
jest.mock('../src/services/extension-server-controller');
jest.mock('../src/services/qr-webview');
jest.mock('../src/services/network-discovery');
jest.mock('../src/server/express-server');
jest.mock('../src/server/websocket-server-manager');
jest.mock('../src/services/qr-code-service');

describe('Extension', () => {
  describe('activate', () => {
    it('should activate without errors', async () => {
      // Arrange
      const mockContext = {
        subscriptions: [],
        globalState: {
          get: jest.fn(),
          update: jest.fn()
        },
        workspaceState: {
          get: jest.fn(),
          update: jest.fn()
        },
        secrets: {
          get: jest.fn(),
          store: jest.fn(),
          delete: jest.fn()
        }
      } as any as vscode.ExtensionContext;

      // Act
      const result = await activate(mockContext);

      // Assert
      expect(mockContext.subscriptions.length).toBeGreaterThan(0); // Should have subscriptions
    });

    it('should register mobileTerminal.start command', async () => {
      // Arrange
      const mockContext = {
        subscriptions: []
      } as any as vscode.ExtensionContext;

      // Act
      await activate(mockContext);

      // Assert
      expect(vscode.commands.registerCommand).toHaveBeenCalledWith(
        'mobileTerminal.start',
        expect.any(Function)
      );
    });

    it('should register mobileTerminal.stop command', async () => {
      // Arrange
      const mockContext = {
        subscriptions: []
      } as any as vscode.ExtensionContext;

      // Act
      await activate(mockContext);

      // Assert
      expect(vscode.commands.registerCommand).toHaveBeenCalledWith(
        'mobileTerminal.stop',
        expect.any(Function)
      );
    });

    it('should register mobileTerminal.showQR command', async () => {
      // Arrange
      const mockContext = {
        subscriptions: []
      } as any as vscode.ExtensionContext;

      // Act
      await activate(mockContext);

      // Assert
      expect(vscode.commands.registerCommand).toHaveBeenCalledWith(
        'mobileTerminal.showQR',
        expect.any(Function)
      );
    });

    it('should register mobileTerminal.rotateKey command', async () => {
      // Arrange
      const mockContext = {
        subscriptions: []
      } as any as vscode.ExtensionContext;

      // Act
      await activate(mockContext);

      // Assert
      expect(vscode.commands.registerCommand).toHaveBeenCalledWith(
        'mobileTerminal.rotateKey',
        expect.any(Function)
      );
    });

    it('should start server when start command is executed', async () => {
      // Arrange
      const mockContext = {
        subscriptions: [],
        globalState: {
          get: jest.fn(),
          update: jest.fn()
        },
        workspaceState: {
          get: jest.fn(),
          update: jest.fn()
        },
        secrets: {
          get: jest.fn(),
          store: jest.fn(),
          delete: jest.fn()
        }
      } as any as vscode.ExtensionContext;
      let startHandler: Function;
      
      // Mock ExtensionServerController to not be running
      const { ExtensionServerController } = require('../src/services/extension-server-controller');
      const mockServerController = {
        isRunning: jest.fn().mockReturnValue(false),
        start: jest.fn().mockResolvedValue(undefined),
        getServerUrl: jest.fn().mockReturnValue('http://localhost:8092')
      };
      ExtensionServerController.mockImplementation(() => mockServerController);
      
      // Capture the start command handler
      (vscode.commands.registerCommand as jest.Mock).mockImplementation((command, handler) => {
        if (command === 'mobileTerminal.start') {
          startHandler = handler;
        }
        return { dispose: jest.fn() };
      });

      // Act
      await activate(mockContext);
      
      // Execute the start command
      await startHandler!();

      // Assert
      expect(vscode.window.showInformationMessage).toHaveBeenCalledWith(
        expect.stringContaining('Mobile Terminal server started')
      );
    });

    it('should stop server when stop command is executed', async () => {
      // Arrange
      const mockContext = {
        subscriptions: [],
        globalState: {
          get: jest.fn(),
          update: jest.fn()
        },
        workspaceState: {
          get: jest.fn(),
          update: jest.fn()
        },
        secrets: {
          get: jest.fn(),
          store: jest.fn(),
          delete: jest.fn()
        }
      } as any as vscode.ExtensionContext;
      let stopHandler: Function;
      
      // Mock ExtensionServerController to be running
      const { ExtensionServerController } = require('../src/services/extension-server-controller');
      const mockServerController = {
        isRunning: jest.fn().mockReturnValue(true),
        stop: jest.fn().mockResolvedValue(undefined)
      };
      ExtensionServerController.mockImplementation(() => mockServerController);
      
      // Capture the stop command handler
      (vscode.commands.registerCommand as jest.Mock).mockImplementation((command, handler) => {
        if (command === 'mobileTerminal.stop') {
          stopHandler = handler;
        }
        return { dispose: jest.fn() };
      });

      // Act
      await activate(mockContext);
      
      // Execute the stop command
      await stopHandler!();

      // Assert
      expect(vscode.window.showInformationMessage).toHaveBeenCalledWith(
        expect.stringContaining('Mobile Terminal server stopped')
      );
    });

    it('should initialize TerminalService on activation', async () => {
      // Arrange
      const mockContext = {
        subscriptions: []
      } as any as vscode.ExtensionContext;
      
      const { TerminalService } = require('../src/services/terminal.service');
      
      // Act
      await activate(mockContext);
      
      // Assert
      expect(TerminalService).toHaveBeenCalledTimes(1);
    });

    it('should initialize ApiKeyManager on activation', async () => {
      // Arrange
      const mockContext = {
        subscriptions: [],
        secrets: {
          get: jest.fn(),
          store: jest.fn(),
          delete: jest.fn()
        }
      } as any as vscode.ExtensionContext;
      
      const { ApiKeyManager } = require('../src/services/api-key-manager');
      
      // Act
      await activate(mockContext);
      
      // Assert
      expect(ApiKeyManager).toHaveBeenCalledTimes(1);
      expect(ApiKeyManager).toHaveBeenCalledWith(mockContext);
    });
  });
});