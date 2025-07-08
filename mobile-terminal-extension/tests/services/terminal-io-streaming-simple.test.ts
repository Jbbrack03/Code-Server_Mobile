import * as vscode from 'vscode';
import { TerminalService } from '../../src/services/terminal.service';
import { WebSocketServerManager } from '../../src/server/websocket-server-manager';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import { TerminalIOStreamingService } from '../../src/services/terminal-io-streaming.service';

// Mock vscode module
jest.mock('vscode');

// Define the event interface locally for testing
interface TerminalDataWriteEvent {
  terminal: any;
  data: string;
}

describe('TerminalIOStreamingService - Simple Tests', () => {
  let terminalService: TerminalService;
  let webSocketServerManager: WebSocketServerManager;
  let apiKeyManager: ApiKeyManager;
  let terminalIOStreaming: TerminalIOStreamingService;
  let mockContext: vscode.ExtensionContext;
  let mockTerminal: vscode.Terminal;
  let mockWorkspaceState: vscode.Memento;

  beforeEach(async () => {
    // Reset all mocks
    jest.clearAllMocks();

    // Mock workspace state
    mockWorkspaceState = {
      get: jest.fn().mockReturnValue(null),
      update: jest.fn().mockResolvedValue(undefined),
      keys: jest.fn().mockReturnValue([])
    };

    // Mock extension context
    mockContext = {
      subscriptions: [],
      workspaceState: mockWorkspaceState,
      extensionUri: { fsPath: '/test/extension' } as vscode.Uri,
      extensionPath: '/test/extension',
      globalState: mockWorkspaceState,
      secrets: {
        get: jest.fn().mockResolvedValue('test-api-key'),
        store: jest.fn().mockResolvedValue(undefined),
        delete: jest.fn().mockResolvedValue(undefined),
        onDidChange: jest.fn()
      }
    } as any;

    // Mock terminal
    mockTerminal = {
      processId: Promise.resolve(1234),
      name: 'Test Terminal',
      exitStatus: undefined,
      state: { isInteractedWith: true },
      creationOptions: {},
      show: jest.fn(),
      hide: jest.fn(),
      dispose: jest.fn(),
      sendText: jest.fn()
    } as any;

    // Mock vscode.window
    (vscode.window as any) = {
      activeTerminal: mockTerminal,
      terminals: [mockTerminal],
      onDidOpenTerminal: jest.fn(),
      onDidCloseTerminal: jest.fn(),
      onDidChangeActiveTerminal: jest.fn(),
      onDidWriteTerminalData: jest.fn().mockReturnValue({ dispose: jest.fn() })
    };

    // Create services
    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockContext);
    webSocketServerManager = new WebSocketServerManager(terminalService, apiKeyManager, 3);
    terminalIOStreaming = new TerminalIOStreamingService(terminalService, webSocketServerManager);
  });

  describe('initialization', () => {
    it('should subscribe to terminal data events on initialization', async () => {
      await terminalIOStreaming.initialize(mockContext);

      expect((vscode.window as any).onDidWriteTerminalData).toHaveBeenCalledWith(
        expect.any(Function)
      );
      expect(mockContext.subscriptions).toHaveLength(1);
    });

    it('should handle multiple initializations gracefully', async () => {
      await terminalIOStreaming.initialize(mockContext);
      await terminalIOStreaming.initialize(mockContext);

      // Should still only have one subscription
      expect(mockContext.subscriptions).toHaveLength(1);
    });
  });

  describe('terminal data handling', () => {
    it('should handle terminal data events without crashing', async () => {
      await terminalIOStreaming.initialize(mockContext);

      // Get the terminal data handler
      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      // Add a terminal to the service
      await terminalService.onDidCreateTerminal(mockTerminal);

      // Should not throw when handling terminal data
      expect(() => {
        terminalDataHandler({
          terminal: mockTerminal,
          data: 'Hello from terminal!'
        } as TerminalDataWriteEvent);
      }).not.toThrow();
    });

    it('should handle terminal not in service gracefully', async () => {
      await terminalIOStreaming.initialize(mockContext);

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      const unknownTerminal = {
        ...mockTerminal,
        name: 'Unknown Terminal'
      };

      // Should not throw when handling data from unknown terminal
      expect(() => {
        terminalDataHandler({
          terminal: unknownTerminal,
          data: 'Data from unknown terminal'
        } as TerminalDataWriteEvent);
      }).not.toThrow();
    });

    it('should handle empty data gracefully', async () => {
      await terminalIOStreaming.initialize(mockContext);

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      await terminalService.onDidCreateTerminal(mockTerminal);

      expect(() => {
        terminalDataHandler({
          terminal: mockTerminal,
          data: ''
        } as TerminalDataWriteEvent);
      }).not.toThrow();
    });
  });

  describe('sequence number management', () => {
    it('should track sequence numbers per terminal', async () => {
      await terminalIOStreaming.initialize(mockContext);

      // Create a spy to track broadcastTerminalOutput calls
      const broadcastSpy = jest.spyOn(webSocketServerManager, 'broadcastTerminalOutput');

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      // Add a terminal to the service
      await terminalService.onDidCreateTerminal(mockTerminal);

      // Send multiple data events
      terminalDataHandler({
        terminal: mockTerminal,
        data: 'First message'
      } as TerminalDataWriteEvent);

      terminalDataHandler({
        terminal: mockTerminal,
        data: 'Second message'
      } as TerminalDataWriteEvent);

      terminalDataHandler({
        terminal: mockTerminal,
        data: 'Third message'
      } as TerminalDataWriteEvent);

      // Verify that broadcastTerminalOutput was called with incrementing sequence numbers
      expect(broadcastSpy).toHaveBeenCalledTimes(3);
      expect(broadcastSpy).toHaveBeenNthCalledWith(1, expect.any(String), 'First message', 1);
      expect(broadcastSpy).toHaveBeenNthCalledWith(2, expect.any(String), 'Second message', 2);
      expect(broadcastSpy).toHaveBeenNthCalledWith(3, expect.any(String), 'Third message', 3);
    });

    it('should maintain separate sequence numbers for different terminals', async () => {
      await terminalIOStreaming.initialize(mockContext);

      const broadcastSpy = jest.spyOn(webSocketServerManager, 'broadcastTerminalOutput');

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      // Create two terminals
      const terminal1 = { ...mockTerminal, name: 'Terminal 1' };
      const terminal2 = { ...mockTerminal, name: 'Terminal 2', processId: Promise.resolve(5678) };

      await terminalService.onDidCreateTerminal(terminal1);
      await terminalService.onDidCreateTerminal(terminal2);

      // Send data from both terminals
      terminalDataHandler({ terminal: terminal1, data: 'T1-1' } as TerminalDataWriteEvent);
      terminalDataHandler({ terminal: terminal2, data: 'T2-1' } as TerminalDataWriteEvent);
      terminalDataHandler({ terminal: terminal1, data: 'T1-2' } as TerminalDataWriteEvent);
      terminalDataHandler({ terminal: terminal2, data: 'T2-2' } as TerminalDataWriteEvent);

      // Verify each terminal maintains its own sequence
      expect(broadcastSpy).toHaveBeenCalledTimes(4);
      
      // Get the terminal IDs from the calls
      const calls = broadcastSpy.mock.calls;
      const t1Id = calls[0][0];
      const t2Id = calls[1][0];
      
      // Verify sequences for each terminal
      expect(calls[0]).toEqual([t1Id, 'T1-1', 1]);
      expect(calls[1]).toEqual([t2Id, 'T2-1', 1]);
      expect(calls[2]).toEqual([t1Id, 'T1-2', 2]);
      expect(calls[3]).toEqual([t2Id, 'T2-2', 2]);
    });
  });

  describe('error handling', () => {
    it('should handle terminal service errors gracefully', async () => {
      await terminalIOStreaming.initialize(mockContext);

      // Mock terminal service to throw
      jest.spyOn(terminalService, 'getTerminals').mockImplementation(() => {
        throw new Error('Terminal service error');
      });

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      // Should not throw
      expect(() => {
        terminalDataHandler({
          terminal: mockTerminal,
          data: 'Test data'
        } as TerminalDataWriteEvent);
      }).not.toThrow();
    });

    it('should handle WebSocket server errors gracefully', async () => {
      await terminalIOStreaming.initialize(mockContext);

      // Mock WebSocket server to throw
      jest.spyOn(webSocketServerManager, 'broadcastTerminalOutput').mockImplementation(() => {
        throw new Error('WebSocket server error');
      });

      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      await terminalService.onDidCreateTerminal(mockTerminal);

      // Should not throw
      expect(() => {
        terminalDataHandler({
          terminal: mockTerminal,
          data: 'Test data'
        } as TerminalDataWriteEvent);
      }).not.toThrow();
    });
  });

  describe('cleanup', () => {
    it('should dispose of subscriptions on cleanup', async () => {
      await terminalIOStreaming.initialize(mockContext);

      const disposable = mockContext.subscriptions[0] as vscode.Disposable;
      const disposeSpy = jest.spyOn(disposable, 'dispose');

      terminalIOStreaming.dispose();

      expect(disposeSpy).toHaveBeenCalled();
    });

    it('should clear sequence numbers on cleanup', async () => {
      await terminalIOStreaming.initialize(mockContext);

      const broadcastSpy = jest.spyOn(webSocketServerManager, 'broadcastTerminalOutput');
      const terminalDataHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[0][0];

      // Add terminal and send data
      await terminalService.onDidCreateTerminal(mockTerminal);
      terminalDataHandler({
        terminal: mockTerminal,
        data: 'Test data'
      } as TerminalDataWriteEvent);

      // Verify sequence started at 1
      expect(broadcastSpy).toHaveBeenCalledWith(expect.any(String), 'Test data', 1);

      // Dispose and reinitialize
      terminalIOStreaming.dispose();
      await terminalIOStreaming.initialize(mockContext);

      // Get new handler and send data
      const newHandler = ((vscode.window as any).onDidWriteTerminalData as jest.Mock).mock.calls[1][0];
      newHandler({
        terminal: mockTerminal,
        data: 'New data'
      } as TerminalDataWriteEvent);

      // Sequence should start from 1 again
      expect(broadcastSpy).toHaveBeenCalledWith(expect.any(String), 'New data', 1);
    });
  });
});