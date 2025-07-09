import request from 'supertest';
import { Express } from 'express';
import { ExpressServer } from '../../src/server/express-server';
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

describe('Server Health Endpoint - TDD', () => {
  let expressServer: ExpressServer;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockContext: vscode.ExtensionContext;

  beforeEach(() => {
    // Setup mock context
    mockContext = {
      subscriptions: [],
      globalState: {
        get: jest.fn(),
        update: jest.fn(),
      },
      secrets: {
        get: jest.fn(),
        store: jest.fn(),
        delete: jest.fn(),
      },
    } as any;

    // Initialize services
    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockContext);
    expressServer = new ExpressServer(terminalService, apiKeyManager);
  });

  afterEach(async () => {
    await expressServer.stop();
  });

  describe('GET /api/health', () => {
    it('should return 200 status when server is healthy', async () => {
      // Arrange
      await expressServer.start(0, 'localhost'); // Use port 0 for dynamic port
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.status).toBe(200);
    });

    it('should return health information in response body', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        status: 'healthy',
        version: expect.any(String),
        uptime: expect.any(Number),
        terminals: expect.any(Number),
      });
    });

    it('should return uptime in seconds', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Wait more than 1 second to ensure uptime > 0 seconds
      await new Promise(resolve => setTimeout(resolve, 1100));

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.body.uptime).toBeGreaterThan(0);
    });

    it('should return current terminal count', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.body.terminals).toBe(0); // No terminals initially
    });

    it('should not require authentication', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act - No authentication headers
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('healthy');
    });
  });
});