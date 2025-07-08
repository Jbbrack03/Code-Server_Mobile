import * as vscode from 'vscode';
import { activate } from '../src/extension';
import { ExtensionServerController } from '../src/services/extension-server-controller';
import { QRWebviewService } from '../src/services/qr-webview';
import { ApiKeyManager } from '../src/services/api-key-manager';
import { NetworkDiscoveryService } from '../src/services/network-discovery';

// Mock the services
jest.mock('../src/services/extension-server-controller');
jest.mock('../src/services/qr-webview');
jest.mock('../src/services/api-key-manager');
jest.mock('../src/services/network-discovery');

describe('Extension Commands', () => {
  let context: vscode.ExtensionContext;
  let mockServerController: any;
  let mockQRWebview: any;
  let mockApiKeyManager: any;
  let mockNetworkDiscovery: any;
  let statusBarItem: vscode.StatusBarItem;

  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();

    // Create mock context
    context = {
      subscriptions: [],
      extensionUri: vscode.Uri.parse('file:///test'),
      extensionPath: '/test',
      globalState: {
        get: jest.fn(),
        update: jest.fn(),
        setKeysForSync: jest.fn()
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
    } as any;

    // Create mock status bar item
    statusBarItem = {
      text: '',
      tooltip: '',
      command: undefined,
      show: jest.fn(),
      hide: jest.fn(),
      dispose: jest.fn()
    } as any;

    (vscode.window.createStatusBarItem as jest.Mock).mockReturnValue(statusBarItem);

    // Setup service mocks
    mockServerController = {
      start: jest.fn().mockResolvedValue(undefined),
      stop: jest.fn().mockResolvedValue(undefined),
      isRunning: jest.fn().mockReturnValue(false),
      getServerUrl: jest.fn().mockReturnValue('http://localhost:8092')
    } as any;

    mockQRWebview = {
      showQRCode: jest.fn().mockResolvedValue(undefined),
      dispose: jest.fn()
    } as any;

    mockApiKeyManager = {
      generateApiKey: jest.fn().mockResolvedValue('test-api-key'),
      rotateApiKey: jest.fn().mockResolvedValue('new-api-key'),
      retrieveApiKey: jest.fn().mockResolvedValue('stored-api-key'),
      storeApiKey: jest.fn().mockResolvedValue(undefined),
      hashApiKey: jest.fn().mockReturnValue('hashed-key'),
      validateApiKey: jest.fn().mockReturnValue(true)
    } as any;

    mockNetworkDiscovery = {
      getLocalNetworkUrls: jest.fn().mockReturnValue(['http://localhost:8092', 'http://192.168.1.100:8092'])
    } as any;

    // Mock service constructors
    (ExtensionServerController as jest.Mock).mockImplementation(() => mockServerController);
    (QRWebviewService as jest.Mock).mockImplementation(() => mockQRWebview);
    (ApiKeyManager as jest.Mock).mockImplementation(() => mockApiKeyManager);
    (NetworkDiscoveryService as any).mockImplementation(() => mockNetworkDiscovery);
  });

  describe('activation', () => {
    it('should register all required commands', async () => {
      await activate(context);

      // Check that all commands are registered
      const registeredCommands = (vscode.commands.registerCommand as jest.Mock).mock.calls.map(call => call[0]);
      expect(registeredCommands).toContain('mobileTerminal.start');
      expect(registeredCommands).toContain('mobileTerminal.stop');
      expect(registeredCommands).toContain('mobileTerminal.showQR');
      expect(registeredCommands).toContain('mobileTerminal.rotateKey');
    });

    it('should create and show status bar item', async () => {
      await activate(context);

      expect(vscode.window.createStatusBarItem).toHaveBeenCalledWith(
        vscode.StatusBarAlignment.Right,
        100
      );
      expect(statusBarItem.show).toHaveBeenCalled();
    });

    it('should initialize status bar with correct text and tooltip', async () => {
      await activate(context);

      expect(statusBarItem.text).toBe('$(terminal) Mobile Terminal: Stopped');
      expect(statusBarItem.tooltip).toBe('Click to start Mobile Terminal server');
      expect(statusBarItem.command).toBe('mobileTerminal.start');
    });

    it('should add resources to subscriptions for cleanup', async () => {
      await activate(context);

      // Verify resources are added to subscriptions
      expect(context.subscriptions.length).toBeGreaterThan(0);
    });
  });

  describe('mobileTerminal.start command', () => {
    beforeEach(async () => {
      await activate(context);
    });

    it('should start the server when not running', async () => {
      const startCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.start')[1];

      await startCommand();

      expect(mockServerController.start).toHaveBeenCalled();
      expect(vscode.window.showInformationMessage).toHaveBeenCalledWith('Mobile Terminal server started on http://localhost:8092');
    });

    it('should update status bar when server starts', async () => {
      const startCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.start')[1];

      // Start returns false before starting, true after
      mockServerController.isRunning.mockReturnValueOnce(false).mockReturnValue(true);
      
      await startCommand();

      expect(statusBarItem.text).toBe('$(terminal) Mobile Terminal: Running');
      expect(statusBarItem.tooltip).toBe('Mobile Terminal server is running on http://localhost:8092\nClick to stop');
      expect(statusBarItem.command).toBe('mobileTerminal.stop');
    });

    it('should show error message if start fails', async () => {
      const error = new Error('Failed to start server');
      mockServerController.start.mockRejectedValue(error);

      const startCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.start')[1];

      await startCommand();

      expect(vscode.window.showErrorMessage).toHaveBeenCalledWith('Failed to start Mobile Terminal server: Failed to start server');
    });

    it('should show warning if server is already running', async () => {
      mockServerController.isRunning.mockReturnValue(true);

      const startCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.start')[1];

      await startCommand();

      expect(mockServerController.start).not.toHaveBeenCalled();
      expect(vscode.window.showWarningMessage).toHaveBeenCalledWith('Mobile Terminal server is already running');
    });
  });

  describe('mobileTerminal.stop command', () => {
    beforeEach(async () => {
      await activate(context);
    });

    it('should stop the server when running', async () => {
      mockServerController.isRunning.mockReturnValue(true);

      const stopCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.stop')[1];

      await stopCommand();

      expect(mockServerController.stop).toHaveBeenCalled();
      expect(vscode.window.showInformationMessage).toHaveBeenCalledWith('Mobile Terminal server stopped');
    });

    it('should update status bar when server stops', async () => {
      mockServerController.isRunning.mockReturnValue(false);

      const stopCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.stop')[1];

      await stopCommand();

      expect(statusBarItem.text).toBe('$(terminal) Mobile Terminal: Stopped');
      expect(statusBarItem.tooltip).toBe('Click to start Mobile Terminal server');
      expect(statusBarItem.command).toBe('mobileTerminal.start');
    });

    it('should show error message if stop fails', async () => {
      mockServerController.isRunning.mockReturnValue(true);
      const error = new Error('Failed to stop server');
      mockServerController.stop.mockRejectedValue(error);

      const stopCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.stop')[1];

      await stopCommand();

      expect(vscode.window.showErrorMessage).toHaveBeenCalledWith('Failed to stop Mobile Terminal server: Failed to stop server');
    });

    it('should show warning if server is not running', async () => {
      mockServerController.isRunning.mockReturnValue(false);

      const stopCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.stop')[1];

      await stopCommand();

      expect(mockServerController.stop).not.toHaveBeenCalled();
      expect(vscode.window.showWarningMessage).toHaveBeenCalledWith('Mobile Terminal server is not running');
    });
  });

  describe('mobileTerminal.showQR command', () => {
    beforeEach(async () => {
      await activate(context);
    });

    it('should show QR code when server is running', async () => {
      mockServerController.isRunning.mockReturnValue(true);
      mockApiKeyManager.retrieveApiKey.mockResolvedValue('test-api-key');
      mockNetworkDiscovery.getLocalNetworkUrls.mockReturnValue(['http://localhost:8092', 'http://192.168.1.100:8092']);

      const showQRCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.showQR')[1];

      await showQRCommand();

      expect(mockQRWebview.showQRCode).toHaveBeenCalledWith(
        expect.objectContaining({
          urls: ['http://localhost:8092', 'http://192.168.1.100:8092'],
          apiKey: 'test-api-key'
        })
      );
    });

    it('should start server first if not running', async () => {
      mockServerController.isRunning.mockReturnValueOnce(false).mockReturnValueOnce(true);

      const showQRCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.showQR')[1];

      await showQRCommand();

      expect(mockServerController.start).toHaveBeenCalled();
      expect(mockQRWebview.showQRCode).toHaveBeenCalled();
    });

    it('should generate API key if none exists', async () => {
      mockServerController.isRunning.mockReturnValue(true);
      mockApiKeyManager.retrieveApiKey.mockResolvedValue(null);
      mockApiKeyManager.generateApiKey.mockResolvedValue('new-api-key');

      const showQRCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.showQR')[1];

      await showQRCommand();

      expect(mockApiKeyManager.generateApiKey).toHaveBeenCalled();
      expect(mockApiKeyManager.storeApiKey).toHaveBeenCalledWith('new-api-key');
      expect(mockQRWebview.showQRCode).toHaveBeenCalledWith(
        expect.objectContaining({
          urls: expect.any(Array),
          apiKey: 'new-api-key'
        })
      );
    });

    it('should show error if failed to get connection URLs', async () => {
      mockServerController.isRunning.mockReturnValue(true);
      mockNetworkDiscovery.getLocalNetworkUrls.mockImplementation(() => {
        throw new Error('Network error');
      });

      const showQRCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.showQR')[1];

      await showQRCommand();

      expect(vscode.window.showErrorMessage).toHaveBeenCalledWith('Failed to show QR code: Network error');
    });
  });

  describe('mobileTerminal.rotateKey command', () => {
    beforeEach(async () => {
      await activate(context);
    });

    it('should rotate API key with confirmation', async () => {
      mockApiKeyManager.rotateApiKey.mockResolvedValue('rotated-api-key');
      (vscode.window.showWarningMessage as jest.Mock).mockResolvedValue('Yes');

      const rotateKeyCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.rotateKey')[1];

      await rotateKeyCommand();

      expect(vscode.window.showWarningMessage).toHaveBeenCalledWith(
        'Are you sure you want to rotate the API key? This will disconnect all existing clients.',
        'Yes',
        'No'
      );
      expect(mockApiKeyManager.rotateApiKey).toHaveBeenCalled();
      expect(vscode.window.showInformationMessage).toHaveBeenCalledWith(
        'API key rotated successfully. Please update your mobile app connection.',
        'Show QR Code'
      );
    });

    it('should not rotate key if user cancels', async () => {
      (vscode.window.showWarningMessage as jest.Mock).mockResolvedValue('No');

      const rotateKeyCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.rotateKey')[1];

      await rotateKeyCommand();

      expect(mockApiKeyManager.rotateApiKey).not.toHaveBeenCalled();
    });

    it('should show QR code after successful rotation if requested', async () => {
      mockApiKeyManager.rotateApiKey.mockResolvedValue('rotated-api-key');
      mockServerController.isRunning.mockReturnValue(true);
      (vscode.window.showWarningMessage as jest.Mock).mockResolvedValue('Yes');
      (vscode.window.showInformationMessage as jest.Mock).mockResolvedValue('Show QR Code');

      const rotateKeyCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.rotateKey')[1];

      await rotateKeyCommand();

      expect(mockQRWebview.showQRCode).toHaveBeenCalled();
    });

    it('should show error if rotation fails', async () => {
      const error = new Error('Rotation failed');
      mockApiKeyManager.rotateApiKey.mockRejectedValue(error);
      (vscode.window.showWarningMessage as jest.Mock).mockResolvedValue('Yes');

      const rotateKeyCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.rotateKey')[1];

      await rotateKeyCommand();

      expect(vscode.window.showErrorMessage).toHaveBeenCalledWith('Failed to rotate API key: Rotation failed');
    });
  });

  describe('status bar updates', () => {
    it('should update status bar periodically when server is running', async () => {
      jest.useFakeTimers();
      
      await activate(context);
      
      // Start the server
      const startCommand = (vscode.commands.registerCommand as jest.Mock).mock.calls
        .find(call => call[0] === 'mobileTerminal.start')[1];
      
      // Mock isRunning to return false initially, then true after start
      mockServerController.isRunning.mockReturnValueOnce(false).mockReturnValue(true);
      
      await startCommand();

      // Advance timer to trigger status update
      jest.advanceTimersByTime(5000);

      // Verify status bar is still showing running state
      expect(statusBarItem.text).toBe('$(terminal) Mobile Terminal: Running');
      
      jest.useRealTimers();
    });
  });
});