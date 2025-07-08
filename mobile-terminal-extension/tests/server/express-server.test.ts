import request from 'supertest';
import { ExpressServer } from '../../src/server/express-server';
import { TerminalService } from '../../src/services/terminal.service';
import { ApiKeyManager } from '../../src/services/api-key-manager';
import { HealthResponse, TerminalListResponse, ErrorResponse } from '../../src/types';

// Mock the VS Code module
jest.mock('vscode', () => ({
  window: { terminals: [] },
  ExtensionContext: jest.fn(),
  Terminal: jest.fn(),
  Disposable: { from: jest.fn() }
}), { virtual: true });

describe('ExpressServer', () => {
  let expressServer: ExpressServer;
  let terminalService: TerminalService;
  let apiKeyManager: ApiKeyManager;
  let mockExtensionContext: any;

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

    terminalService = new TerminalService();
    apiKeyManager = new ApiKeyManager(mockExtensionContext);
    expressServer = new ExpressServer(terminalService, apiKeyManager);
  });

  afterEach(async () => {
    if (expressServer) {
      await expressServer.stop();
    }
  });

  describe('Server Lifecycle', () => {
    it('should start server on specified port', async () => {
      const port = 8092;
      const host = '0.0.0.0';
      
      await expressServer.start(port, host);
      
      expect(expressServer.isRunning()).toBe(true);
      expect(expressServer.getPort()).toBe(port);
      expect(expressServer.getHost()).toBe(host);
    });

    it('should stop server gracefully', async () => {
      await expressServer.start(8093, '0.0.0.0');
      expect(expressServer.isRunning()).toBe(true);
      
      await expressServer.stop();
      
      expect(expressServer.isRunning()).toBe(false);
    });

    it('should throw error when starting on occupied port', async () => {
      await expressServer.start(8094, '0.0.0.0');
      const secondServer = new ExpressServer(terminalService, apiKeyManager);
      
      await expect(secondServer.start(8094, '0.0.0.0')).rejects.toThrow();
    });
  });

  describe('Health Endpoint', () => {
    beforeEach(async () => {
      await expressServer.start(8095, '0.0.0.0');
    });

    it('should return health status', async () => {
      const response = await request(expressServer.getApp())
        .get('/api/health')
        .expect('Content-Type', /json/)
        .expect(200);

      const health: HealthResponse = response.body;
      expect(health.status).toBe('healthy');
      expect(health.version).toBe('1.0.0');
      expect(typeof health.uptime).toBe('number');
      expect(typeof health.terminals).toBe('number');
    });

    it('should return degraded status when terminal service has issues', async () => {
      // Mock terminal service to throw error
      jest.spyOn(terminalService, 'getTerminals').mockImplementation(() => {
        throw new Error('Terminal service error');
      });

      const response = await request(expressServer.getApp())
        .get('/api/health')
        .expect('Content-Type', /json/)
        .expect(200);

      const health: HealthResponse = response.body;
      expect(health.status).toBe('degraded');
    });
  });

  describe('Authentication Middleware', () => {
    beforeEach(async () => {
      await expressServer.start(8096, '0.0.0.0');
      // Set up a valid API key
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
    });

    it('should reject requests without API key', async () => {
      const response = await request(expressServer.getApp())
        .get('/api/terminals')
        .expect('Content-Type', /json/)
        .expect(401);

      const error: ErrorResponse = response.body;
      expect(error.type).toBe('https://httpstatuses.com/401');
      expect(error.title).toBe('Unauthorized');
      expect(error.detail).toBe('Missing API key');
    });

    it('should reject requests with invalid API key', async () => {
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(false);

      const response = await request(expressServer.getApp())
        .get('/api/terminals')
        .set('X-API-Key', 'invalid-key')
        .expect('Content-Type', /json/)
        .expect(401);

      const error: ErrorResponse = response.body;
      expect(error.detail).toBe('Invalid API key');
    });

    it('should accept requests with valid API key', async () => {
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);

      await request(expressServer.getApp())
        .get('/api/terminals')
        .set('X-API-Key', 'valid-key')
        .expect(200);
    });
  });

  describe('Terminal Endpoints', () => {
    beforeEach(async () => {
      await expressServer.start(8097, '0.0.0.0');
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
    });

    describe('GET /api/terminals', () => {
      it('should return list of terminals', async () => {
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

        const response = await request(expressServer.getApp())
          .get('/api/terminals')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(200);

        const terminalList: TerminalListResponse = response.body;
        expect(terminalList.terminals).toHaveLength(1);
        expect(terminalList.terminals[0].id).toBe('terminal-1');
        expect(terminalList.activeTerminalId).toBe('terminal-1');
      });

      it('should return empty list when no terminals exist', async () => {
        jest.spyOn(terminalService, 'getTerminals').mockReturnValue([]);
        jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue(null);

        const response = await request(expressServer.getApp())
          .get('/api/terminals')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(200);

        const terminalList: TerminalListResponse = response.body;
        expect(terminalList.terminals).toHaveLength(0);
        expect(terminalList.activeTerminalId).toBeNull();
      });
    });

    describe('GET /api/terminals/:id', () => {
      it('should return terminal details and buffer', async () => {
        const mockTerminal = {
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
        };

        const mockBuffer = ['line 1', 'line 2', 'line 3'];

        jest.spyOn(terminalService, 'getTerminal').mockReturnValue(mockTerminal);
        jest.spyOn(terminalService, 'getTerminalBuffer').mockReturnValue(mockBuffer);

        const response = await request(expressServer.getApp())
          .get('/api/terminals/terminal-1')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(200);

        expect(response.body.terminal.id).toBe('terminal-1');
        expect(response.body.buffer).toEqual(mockBuffer);
      });

      it('should return 404 for non-existent terminal', async () => {
        jest.spyOn(terminalService, 'getTerminal').mockReturnValue(null);

        const response = await request(expressServer.getApp())
          .get('/api/terminals/non-existent')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(404);

        const error: ErrorResponse = response.body;
        expect(error.type).toBe('https://httpstatuses.com/404');
        expect(error.title).toBe('Not Found');
        expect(error.detail).toBe('Terminal not found');
      });
    });

    describe('POST /api/terminals/:id/select', () => {
      it('should select terminal and return success', async () => {
        jest.spyOn(terminalService, 'selectTerminal').mockResolvedValue(true);
        jest.spyOn(terminalService, 'getActiveTerminalId').mockReturnValue('terminal-1');

        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/select')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(200);

        expect(response.body.success).toBe(true);
        expect(response.body.activeTerminalId).toBe('terminal-1');
      });

      it('should return 404 when terminal selection fails', async () => {
        jest.spyOn(terminalService, 'selectTerminal').mockResolvedValue(false);

        const response = await request(expressServer.getApp())
          .post('/api/terminals/non-existent/select')
          .set('X-API-Key', 'valid-key')
          .expect('Content-Type', /json/)
          .expect(404);

        const error: ErrorResponse = response.body;
        expect(error.detail).toBe('Terminal not found or selection failed');
      });
    });

    describe('POST /api/terminals/:id/input', () => {
      it('should send input to terminal', async () => {
        jest.spyOn(terminalService, 'sendInput').mockResolvedValue(true);

        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/input')
          .set('X-API-Key', 'valid-key')
          .set('Content-Type', 'application/json')
          .send({ data: 'ls -la\n' })
          .expect('Content-Type', /json/)
          .expect(200);

        expect(response.body.success).toBe(true);
        expect(typeof response.body.sequence).toBe('number');
      });

      it('should return 400 for missing input data', async () => {
        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/input')
          .set('X-API-Key', 'valid-key')
          .set('Content-Type', 'application/json')
          .send({})
          .expect('Content-Type', /json/)
          .expect(400);

        const error: ErrorResponse = response.body;
        expect(error.detail).toBe('Missing input data');
      });

      it('should return 404 when input fails', async () => {
        jest.spyOn(terminalService, 'sendInput').mockResolvedValue(false);

        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/input')
          .set('X-API-Key', 'valid-key')
          .set('Content-Type', 'application/json')
          .send({ data: 'test command' })
          .expect('Content-Type', /json/)
          .expect(404);

        const error: ErrorResponse = response.body;
        expect(error.detail).toBe('Terminal not found or input failed');
      });
    });

    describe('POST /api/terminals/:id/resize', () => {
      it('should resize terminal', async () => {
        jest.spyOn(terminalService, 'resizeTerminal').mockResolvedValue(true);

        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/resize')
          .set('X-API-Key', 'valid-key')
          .set('Content-Type', 'application/json')
          .send({ cols: 120, rows: 30 })
          .expect('Content-Type', /json/)
          .expect(200);

        expect(response.body.success).toBe(true);
      });

      it('should return 400 for invalid dimensions', async () => {
        const response = await request(expressServer.getApp())
          .post('/api/terminals/terminal-1/resize')
          .set('X-API-Key', 'valid-key')
          .set('Content-Type', 'application/json')
          .send({ cols: -1, rows: 30 })
          .expect('Content-Type', /json/)
          .expect(400);

        const error: ErrorResponse = response.body;
        expect(error.detail).toBe('Invalid dimensions');
      });
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      await expressServer.start(8098, '0.0.0.0');
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);
    });

    it('should handle 404 for unknown routes', async () => {
      const response = await request(expressServer.getApp())
        .get('/api/unknown')
        .set('X-API-Key', 'valid-key')
        .expect('Content-Type', /json/)
        .expect(404);

      const error: ErrorResponse = response.body;
      expect(error.type).toBe('https://httpstatuses.com/404');
      expect(error.title).toBe('Not Found');
    });

    it('should handle internal server errors', async () => {
      jest.spyOn(terminalService, 'getTerminals').mockImplementation(() => {
        throw new Error('Unexpected error');
      });

      const response = await request(expressServer.getApp())
        .get('/api/terminals')
        .set('X-API-Key', 'valid-key')
        .expect('Content-Type', /json/)
        .expect(500);

      const error: ErrorResponse = response.body;
      expect(error.type).toBe('https://httpstatuses.com/500');
      expect(error.title).toBe('Internal Server Error');
    });

    it('should include request ID in error responses', async () => {
      const response = await request(expressServer.getApp())
        .get('/api/unknown')
        .set('X-API-Key', 'valid-key')
        .expect(404);

      const error: ErrorResponse = response.body;
      expect(error.requestId).toBeDefined();
      expect(typeof error.requestId).toBe('string');
    });
  });

  describe('CORS Configuration', () => {
    beforeEach(async () => {
      await expressServer.start(8099, '0.0.0.0');
    });

    it('should handle CORS preflight requests', async () => {
      await request(expressServer.getApp())
        .options('/api/terminals')
        .set('Origin', 'http://localhost:3000')
        .set('Access-Control-Request-Method', 'GET')
        .set('Access-Control-Request-Headers', 'X-API-Key')
        .expect(204);
    });

    it('should include CORS headers in responses', async () => {
      jest.spyOn(apiKeyManager, 'validateApiKeyAsync').mockResolvedValue(true);

      const response = await request(expressServer.getApp())
        .get('/api/terminals')
        .set('X-API-Key', 'valid-key')
        .set('Origin', 'http://localhost:3000')
        .expect(200);

      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });
  });
});