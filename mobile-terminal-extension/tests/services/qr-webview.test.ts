import * as vscode from 'vscode';
import { QRWebviewService } from '../../src/services/qr-webview';
import { QRCodeService } from '../../src/services/qr-code-service';
import { ConnectionProfile } from '../../src/types';

// Mock dependencies
jest.mock('../../src/services/qr-code-service');

describe('QRWebviewService', () => {
  let service: QRWebviewService;
  let mockContext: vscode.ExtensionContext;
  let mockQRCodeService: jest.Mocked<QRCodeService>;
  let mockWebviewPanel: jest.Mocked<vscode.WebviewPanel>;

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

    // Mock QRCodeService
    mockQRCodeService = new (QRCodeService as jest.MockedClass<typeof QRCodeService>)() as jest.Mocked<QRCodeService>;
    mockQRCodeService.generateConnectionQR = jest.fn().mockResolvedValue('data:image/png;base64,mock-png-data');
    mockQRCodeService.generateConnectionQRSVG = jest.fn().mockResolvedValue('<svg>mock-svg-data</svg>');
    mockQRCodeService.generateConnectionQRUTF8 = jest.fn().mockResolvedValue('mock-utf8-data');

    // Mock WebviewPanel
    mockWebviewPanel = {
      webview: {
        html: '',
        options: {},
        cspSource: 'mock-csp',
        asWebviewUri: jest.fn().mockReturnValue({ toString: () => 'mock-uri' }),
        postMessage: jest.fn(),
        onDidReceiveMessage: jest.fn()
      },
      title: 'Mobile Terminal QR Code',
      viewType: 'mobileTerminalQR',
      options: {},
      viewColumn: 1,
      active: true,
      visible: true,
      onDidDispose: jest.fn(),
      onDidChangeViewState: jest.fn(),
      reveal: jest.fn(),
      dispose: jest.fn()
    } as any;

    // Mock vscode.window.createWebviewPanel
    (vscode.window.createWebviewPanel as jest.Mock) = jest.fn().mockReturnValue(mockWebviewPanel);

    service = new QRWebviewService(mockContext, mockQRCodeService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should create QR webview service with required dependencies', () => {
      expect(() => {
        new QRWebviewService(mockContext, mockQRCodeService);
      }).not.toThrow();
    });

    it('should initialize with no active panel', () => {
      expect(service.hasActivePanel()).toBe(false);
    });
  });

  describe('showQRCode()', () => {
    it('should create new webview panel when none exists', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      expect(vscode.window.createWebviewPanel).toHaveBeenCalledWith(
        'mobileTerminalQR',
        'Mobile Terminal QR Code',
        vscode.ViewColumn.One,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
          localResourceRoots: [expect.any(Object)]
        }
      );
      expect(service.hasActivePanel()).toBe(true);
    });

    it('should reveal existing panel when one exists', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      // Create first panel
      await service.showQRCode(connectionProfile);
      jest.clearAllMocks();

      // Try to create second panel
      await service.showQRCode(connectionProfile);

      expect(vscode.window.createWebviewPanel).not.toHaveBeenCalled();
      expect(mockWebviewPanel.reveal).toHaveBeenCalledWith(vscode.ViewColumn.One);
    });

    it('should generate QR code for connection profile', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      expect(mockQRCodeService.generateConnectionQR).toHaveBeenCalledWith(
        connectionProfile,
        expect.any(Object)
      );
    });

    it('should set webview HTML content', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      expect(mockWebviewPanel.webview.html).toContain('Mobile Terminal QR Code');
      expect(mockWebviewPanel.webview.html).toContain('mock-png-data');
    });

    it('should handle QR code generation failure', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const error = new Error('QR generation failed');
      mockQRCodeService.generateConnectionQR.mockRejectedValue(error);

      await expect(service.showQRCode(connectionProfile)).rejects.toThrow('QR generation failed');
    });
  });

  describe('dispose()', () => {
    it('should dispose active panel', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);
      service.dispose();

      expect(mockWebviewPanel.dispose).toHaveBeenCalledTimes(1);
      expect(service.hasActivePanel()).toBe(false);
    });

    it('should handle dispose when no panel exists', () => {
      expect(() => service.dispose()).not.toThrow();
    });
  });

  describe('panel disposal callback', () => {
    it('should clean up when panel is disposed externally', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      // Simulate external disposal
      const onDisposeCallback = (mockWebviewPanel.onDidDispose as jest.Mock).mock.calls[0][0];
      onDisposeCallback();

      expect(service.hasActivePanel()).toBe(false);
    });
  });

  describe('message handling', () => {
    it('should handle copy to clipboard message', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      const onMessageCallback = (mockWebviewPanel.webview.onDidReceiveMessage as jest.Mock).mock.calls[0][0];
      
      // Mock vscode.env.clipboard
      const mockClipboard = {
        writeText: jest.fn().mockResolvedValue(undefined)
      };
      
      // Ensure vscode.env exists
      if (!(vscode as any).env) {
        (vscode as any).env = {};
      }
      (vscode.env as any).clipboard = mockClipboard;

      await onMessageCallback({
        type: 'copyToClipboard',
        data: 'test-connection-string'
      });

      expect(mockClipboard.writeText).toHaveBeenCalledWith('test-connection-string');
    });

    it('should handle unknown message types gracefully', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-id',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092'],
        apiKey: 'test-api-key',
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await service.showQRCode(connectionProfile);

      const onMessageCallback = (mockWebviewPanel.webview.onDidReceiveMessage as jest.Mock).mock.calls[0][0];
      
      expect(() => onMessageCallback({
        type: 'unknownType',
        data: 'test-data'
      })).not.toThrow();
    });
  });
});