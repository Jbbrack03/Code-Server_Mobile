import { TerminalService } from '../../src/services/terminal.service';
import { Terminal } from '../../src/types';
import * as vscode from 'vscode';

describe('TerminalService', () => {
  let service: TerminalService;
  let mockTerminal: any;

  beforeEach(() => {
    service = new TerminalService();
    mockTerminal = {
      name: 'Test Terminal',
      processId: Promise.resolve(12345),
      creationOptions: {
        name: 'Test Terminal',
        cwd: '/home/user',
        shellPath: '/bin/bash'
      },
      exitStatus: undefined,
      state: {},
      sendText: jest.fn(),
      show: jest.fn(),
      hide: jest.fn(),
      dispose: jest.fn(),
    };
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('initialization', () => {
    it('should initialize with empty terminals list', () => {
      // Test that service starts with no terminals
      const terminals = service.getTerminals();
      expect(terminals).toEqual([]);
    });

    it('should have no active terminal initially', () => {
      // Test that no terminal is active initially
      const activeTerminal = service.getActiveTerminal();
      expect(activeTerminal).toBeNull();
    });
  });

  describe('terminal detection', () => {
    it('should detect Claude Code terminals by name pattern', () => {
      // Test Claude Code detection logic
      const claudeTerminal = {
        ...mockTerminal,
        name: 'Claude Code Session - main'
      };
      
      const isClaudeCode = service.detectClaudeCode(claudeTerminal);
      expect(isClaudeCode).toBe(true);
    });

    it('should not detect regular terminals as Claude Code', () => {
      // Test that regular terminals are not detected as Claude Code
      const regularTerminal = {
        ...mockTerminal,
        name: 'bash'
      };
      
      const isClaudeCode = service.detectClaudeCode(regularTerminal);
      expect(isClaudeCode).toBe(false);
    });
  });

  describe('terminal lifecycle', () => {
    it('should track terminal creation', async () => {
      // Test terminal creation tracking
      await service.onDidCreateTerminal(mockTerminal);
      
      const terminals = service.getTerminals();
      expect(terminals).toHaveLength(1);
      expect(terminals[0].name).toBe('Test Terminal');
      expect(terminals[0].id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[4][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
    });

    it('should set created terminal as active', async () => {
      // Test that newly created terminal becomes active
      await service.onDidCreateTerminal(mockTerminal);
      
      const activeTerminal = service.getActiveTerminal();
      expect(activeTerminal).not.toBeNull();
      expect(activeTerminal?.name).toBe('Test Terminal');
      expect(activeTerminal?.isActive).toBe(true);
    });

    it('should track terminal closure', async () => {
      // Test terminal closure tracking
      await service.onDidCreateTerminal(mockTerminal);
      expect(service.getTerminals()).toHaveLength(1);
      
      await service.onDidCloseTerminal(mockTerminal);
      
      const terminals = service.getTerminals();
      expect(terminals).toHaveLength(0);
    });

    it('should update active terminal when changed', async () => {
      // Test active terminal change handling
      const terminal1 = { ...mockTerminal, name: 'Terminal 1' };
      const terminal2 = { ...mockTerminal, name: 'Terminal 2' };
      
      await service.onDidCreateTerminal(terminal1);
      await service.onDidCreateTerminal(terminal2);
      
      await service.onDidChangeActiveTerminal(terminal1);
      
      const activeTerminal = service.getActiveTerminal();
      expect(activeTerminal?.name).toBe('Terminal 1');
      expect(activeTerminal?.isActive).toBe(true);
      
      // Check that other terminal is not active
      const terminals = service.getTerminals();
      const inactiveTerminal = terminals.find(t => t.name === 'Terminal 2');
      expect(inactiveTerminal?.isActive).toBe(false);
    });
  });

  describe('terminal selection', () => {
    it('should select terminal by ID', async () => {
      // Test terminal selection by ID
      await service.onDidCreateTerminal(mockTerminal);
      const terminals = service.getTerminals();
      const terminalId = terminals[0].id;
      
      const result = await service.selectTerminal(terminalId);
      
      expect(result).toBe(true);
      const activeTerminal = service.getActiveTerminal();
      expect(activeTerminal?.id).toBe(terminalId);
      expect(activeTerminal?.isActive).toBe(true);
    });

    it('should return false when selecting non-existent terminal', async () => {
      // Test selecting terminal that doesn't exist
      const result = await service.selectTerminal('non-existent-id');
      
      expect(result).toBe(false);
      expect(service.getActiveTerminal()).toBeNull();
    });
  });

  describe('terminal input', () => {
    it('should send input to active terminal', async () => {
      // Test sending input to active terminal
      await service.onDidCreateTerminal(mockTerminal);
      const terminals = service.getTerminals();
      const terminalId = terminals[0].id;
      
      const result = await service.sendInput(terminalId, 'ls -la\n');
      
      expect(result).toBe(true);
      expect(mockTerminal.sendText).toHaveBeenCalledWith('ls -la\n');
    });

    it('should return false when sending input to non-existent terminal', async () => {
      // Test sending input to non-existent terminal
      const result = await service.sendInput('non-existent-id', 'ls -la\n');
      
      expect(result).toBe(false);
    });
  });

  describe('buffer management', () => {
    it('should maintain terminal output buffer', async () => {
      // Test terminal output buffer management
      await service.onDidCreateTerminal(mockTerminal);
      const terminals = service.getTerminals();
      const terminalId = terminals[0].id;
      
      // Simulate terminal output
      service.onDidWriteTerminalData(mockTerminal, 'Hello World\n');
      service.onDidWriteTerminalData(mockTerminal, 'Second line\n');
      
      const buffer = service.getTerminalBuffer(terminalId);
      expect(buffer).toContain('Hello World\n');
      expect(buffer).toContain('Second line\n');
      expect(buffer).toHaveLength(2);
    });

    it('should limit buffer size to maxLines configuration', async () => {
      // Test buffer size limit
      await service.onDidCreateTerminal(mockTerminal);
      const terminals = service.getTerminals();
      const terminalId = terminals[0].id;
      
      // Add more lines than the buffer limit (assume 1000)
      for (let i = 0; i < 1100; i++) {
        service.onDidWriteTerminalData(mockTerminal, `Line ${i}\n`);
      }
      
      const buffer = service.getTerminalBuffer(terminalId);
      expect(buffer.length).toBeLessThanOrEqual(1000);
      // Should contain the most recent lines
      expect(buffer[buffer.length - 1]).toBe('Line 1099\n');
    });
  });

  describe('terminal resize', () => {
    it('should resize terminal dimensions', async () => {
      // Test terminal resize functionality
      await service.onDidCreateTerminal(mockTerminal);
      const terminals = service.getTerminals();
      const terminalId = terminals[0].id;
      
      const result = await service.resizeTerminal(terminalId, 80, 24);
      
      expect(result).toBe(true);
      const terminal = service.getTerminals().find(t => t.id === terminalId);
      expect(terminal?.dimensions.cols).toBe(80);
      expect(terminal?.dimensions.rows).toBe(24);
    });

    it('should return false when resizing non-existent terminal', async () => {
      // Test resizing non-existent terminal
      const result = await service.resizeTerminal('non-existent-id', 80, 24);
      
      expect(result).toBe(false);
    });
  });
});