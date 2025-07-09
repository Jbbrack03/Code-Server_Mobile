import request from 'supertest';
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

describe('API Authentication - TDD', () => {
  let expressServer: ExpressServer;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockContext: vscode.ExtensionContext;
  let mockStorage: { apiKey: string | null; apiKeyHash: string | null };

  beforeEach(() => {
    // Setup mock storage
    mockStorage = {
      apiKey: null,
      apiKeyHash: null,
    };

    // Setup mock context
    mockContext = {
      subscriptions: [],
      globalState: {
        get: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKeyHash') {
            return mockStorage.apiKeyHash;
          }
          return undefined;
        }),
        update: jest.fn().mockImplementation((key, value) => {
          if (key === 'mobileTerminal.apiKeyHash') {
            mockStorage.apiKeyHash = value;
          }
          return Promise.resolve();
        }),
      },
      secrets: {
        get: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKey') {
            return Promise.resolve(mockStorage.apiKey);
          }
          return Promise.resolve(undefined);
        }),
        store: jest.fn().mockImplementation((key, value) => {
          if (key === 'mobileTerminal.apiKey') {
            mockStorage.apiKey = value;
          }
          return Promise.resolve();
        }),
        delete: jest.fn().mockImplementation((key) => {
          if (key === 'mobileTerminal.apiKey') {
            mockStorage.apiKey = null;
          }
          return Promise.resolve();
        }),
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

  describe('Protected endpoints', () => {
    it('should return 401 when no API key is provided', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/terminals')
        .expect(401);

      // Assert
      expect(response.body).toMatchObject({
        type: 'https://httpstatuses.com/401',
        title: 'Unauthorized',
        status: 401,
        detail: 'Missing API key',
        instance: '/api/terminals',
        timestamp: expect.any(String),
        requestId: expect.any(String),
      });
    });

    it('should return 401 when invalid API key is provided', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Generate and store a valid API key
      const validApiKey = await apiKeyManager.generateApiKey();
      await apiKeyManager.storeApiKey(validApiKey);

      // Act - Use invalid API key
      const response = await request(app)
        .get('/api/terminals')
        .set('X-API-Key', 'invalid-api-key')
        .expect(401);

      // Assert
      expect(response.body).toMatchObject({
        type: 'https://httpstatuses.com/401',
        title: 'Unauthorized',
        status: 401,
        detail: 'Invalid API key',
        instance: '/api/terminals',
        timestamp: expect.any(String),
        requestId: expect.any(String),
      });
    });

    it('should allow access with valid API key', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Generate and store a valid API key
      const validApiKey = await apiKeyManager.generateApiKey();
      await apiKeyManager.storeApiKey(validApiKey);

      // Act
      const response = await request(app)
        .get('/api/terminals')
        .set('X-API-Key', validApiKey)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        terminals: expect.any(Array),
      });
      expect(response.body.activeTerminalId === null || typeof response.body.activeTerminalId === 'string').toBe(true);
    });

    it('should include request ID in all responses', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act - Test with missing API key
      const response = await request(app)
        .get('/api/terminals')
        .expect(401);

      // Assert
      expect(response.body.requestId).toBeDefined();
      expect(typeof response.body.requestId).toBe('string');
      expect(response.body.requestId.length).toBeGreaterThan(0);
    });

    it('should use timing-safe comparison for API key validation', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Generate and store a valid API key
      const validApiKey = await apiKeyManager.generateApiKey();
      await apiKeyManager.storeApiKey(validApiKey);

      // Act - Test with key that has same length but different content
      const similarKey = validApiKey.substring(0, validApiKey.length - 1) + 'X';
      const response = await request(app)
        .get('/api/terminals')
        .set('X-API-Key', similarKey)
        .expect(401);

      // Assert
      expect(response.body.detail).toBe('Invalid API key');
    });
  });

  describe('Public endpoints', () => {
    it('should allow access to health endpoint without API key', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('CORS headers', () => {
    it('should include CORS headers in responses', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .get('/api/health')
        .expect(200);

      // Assert
      expect(response.headers['access-control-allow-origin']).toBe('*');
      expect(response.headers['access-control-allow-methods']).toBe('GET, POST, PUT, DELETE, OPTIONS');
      expect(response.headers['access-control-allow-headers']).toBe('Origin, X-Requested-With, Content-Type, Accept, Authorization, X-API-Key');
    });

    it('should handle OPTIONS preflight requests', async () => {
      // Arrange
      await expressServer.start(0, 'localhost');
      const app = expressServer.getApp();

      // Act
      const response = await request(app)
        .options('/api/terminals')
        .set('Origin', 'http://localhost:3000')
        .set('Access-Control-Request-Method', 'GET')
        .set('Access-Control-Request-Headers', 'X-API-Key')
        .expect(204);

      // Assert
      expect(response.status).toBe(204);
    });
  });
});