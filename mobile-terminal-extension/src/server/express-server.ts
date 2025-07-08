import express, { Express, Request, Response, NextFunction } from 'express';
import { Server } from 'http';
import { v4 as uuidv4 } from 'uuid';
import { TerminalService } from '../services/terminal.service';
import { ApiKeyManager } from '../services/api-key-manager';
import { 
  HealthResponse, 
  TerminalListResponse, 
  TerminalDetailsResponse, 
  ErrorResponse,
  ErrorCode
} from '../types';

interface AuthenticatedRequest extends Request {
  requestId?: string;
}

export class ExpressServer {
  private app: Express;
  private server: Server | null = null;
  private port: number = 0;
  private host: string = '0.0.0.0';
  private startTime: Date = new Date();

  constructor(
    private terminalService: TerminalService,
    private apiKeyManager: ApiKeyManager
  ) {
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  /**
   * Start the Express server
   */
  async start(port: number, host: string = '0.0.0.0'): Promise<void> {
    if (this.server) {
      throw new Error('Server is already running');
    }

    return new Promise((resolve, reject) => {
      this.server = this.app.listen(port, host, () => {
        this.port = port;
        this.host = host;
        this.startTime = new Date();
        resolve();
      });

      this.server.on('error', (error: any) => {
        if (error.code === 'EADDRINUSE') {
          reject(new Error(`Port ${port} is already in use`));
        } else {
          reject(error);
        }
      });
    });
  }

  /**
   * Stop the Express server
   */
  async stop(): Promise<void> {
    if (!this.server) {
      return;
    }

    return new Promise((resolve, reject) => {
      this.server!.close((error) => {
        if (error) {
          reject(error);
        } else {
          this.server = null;
          resolve();
        }
      });
    });
  }

  /**
   * Check if server is running
   */
  isRunning(): boolean {
    return this.server !== null && this.server.listening;
  }

  /**
   * Get server port
   */
  getPort(): number {
    return this.port;
  }

  /**
   * Get server host
   */
  getHost(): string {
    return this.host;
  }

  /**
   * Get Express app instance (for testing)
   */
  getApp(): Express {
    return this.app;
  }

  /**
   * Get HTTP server instance (for WebSocket integration)
   */
  getServer(): Server | null {
    return this.server;
  }

  /**
   * Setup middleware
   */
  private setupMiddleware(): void {
    // Request ID middleware
    this.app.use((req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      req.requestId = uuidv4();
      next();
    });

    // JSON parsing
    this.app.use(express.json({ limit: '10mb' }));

    // CORS middleware
    this.app.use((req: Request, res: Response, next: NextFunction) => {
      res.header('Access-Control-Allow-Origin', '*');
      res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization, X-API-Key');
      
      if (req.method === 'OPTIONS') {
        res.sendStatus(204);
        return;
      }
      
      next();
    });
  }

  /**
   * Setup API routes
   */
  private setupRoutes(): void {
    // Health endpoint (no auth required)
    this.app.get('/api/health', this.handleHealth.bind(this));

    // Authentication middleware for protected routes
    this.app.use('/api', this.authenticateRequest.bind(this));

    // Terminal routes
    this.app.get('/api/terminals', this.handleGetTerminals.bind(this));
    this.app.get('/api/terminals/:id', this.handleGetTerminal.bind(this));
    this.app.post('/api/terminals/:id/select', this.handleSelectTerminal.bind(this));
    this.app.post('/api/terminals/:id/input', this.handleTerminalInput.bind(this));
    this.app.post('/api/terminals/:id/resize', this.handleTerminalResize.bind(this));

    // 404 handler
    this.app.use('*', this.handle404.bind(this));
  }

  /**
   * Setup error handling
   */
  private setupErrorHandling(): void {
    this.app.use((error: Error, req: AuthenticatedRequest, res: Response, next: NextFunction) => {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/500',
        title: 'Internal Server Error',
        status: 500,
        detail: 'An unexpected error occurred',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };

      res.status(500).json(errorResponse);
    });
  }

  /**
   * Authentication middleware
   */
  private async authenticateRequest(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    const apiKey = req.headers['x-api-key'] as string;

    if (!apiKey) {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/401',
        title: 'Unauthorized',
        status: 401,
        detail: 'Missing API key',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };
      res.status(401).json(errorResponse);
      return;
    }

    try {
      const isValid = await this.apiKeyManager.validateApiKeyAsync(apiKey);
      if (!isValid) {
        const errorResponse: ErrorResponse = {
          type: 'https://httpstatuses.com/401',
          title: 'Unauthorized',
          status: 401,
          detail: 'Invalid API key',
          instance: req.originalUrl,
          timestamp: new Date().toISOString(),
          requestId: req.requestId || 'unknown'
        };
        res.status(401).json(errorResponse);
        return;
      }

      next();
    } catch (error) {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/500',
        title: 'Internal Server Error',
        status: 500,
        detail: 'Authentication error',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };
      res.status(500).json(errorResponse);
    }
  }

  /**
   * Health check endpoint
   */
  private handleHealth(req: AuthenticatedRequest, res: Response): void {
    try {
      const terminals = this.terminalService.getTerminals();
      const uptime = Date.now() - this.startTime.getTime();

      const health: HealthResponse = {
        status: 'healthy',
        version: '1.0.0',
        uptime: Math.floor(uptime / 1000),
        terminals: terminals.length
      };

      res.json(health);
    } catch (error) {
      const health: HealthResponse = {
        status: 'degraded',
        version: '1.0.0',
        uptime: Math.floor((Date.now() - this.startTime.getTime()) / 1000),
        terminals: 0
      };

      res.json(health);
    }
  }

  /**
   * Get all terminals
   */
  private handleGetTerminals(req: AuthenticatedRequest, res: Response): void {
    try {
      const terminals = this.terminalService.getTerminals();
      const activeTerminalId = this.terminalService.getActiveTerminalId();

      const response: TerminalListResponse = {
        terminals,
        activeTerminalId
      };

      res.json(response);
    } catch (error) {
      throw error; // Let error handler catch it
    }
  }

  /**
   * Get specific terminal
   */
  private handleGetTerminal(req: AuthenticatedRequest, res: Response): void {
    const terminalId = req.params.id;
    const terminal = this.terminalService.getTerminal(terminalId);

    if (!terminal) {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/404',
        title: 'Not Found',
        status: 404,
        detail: 'Terminal not found',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };
      res.status(404).json(errorResponse);
      return;
    }

    const buffer = this.terminalService.getTerminalBuffer(terminalId);
    const response: TerminalDetailsResponse = {
      terminal,
      buffer
    };

    res.json(response);
  }

  /**
   * Select terminal
   */
  private async handleSelectTerminal(req: AuthenticatedRequest, res: Response): Promise<void> {
    const terminalId = req.params.id;

    try {
      const success = await this.terminalService.selectTerminal(terminalId);
      
      if (!success) {
        const errorResponse: ErrorResponse = {
          type: 'https://httpstatuses.com/404',
          title: 'Not Found',
          status: 404,
          detail: 'Terminal not found or selection failed',
          instance: req.originalUrl,
          timestamp: new Date().toISOString(),
          requestId: req.requestId || 'unknown'
        };
        res.status(404).json(errorResponse);
        return;
      }

      const activeTerminalId = this.terminalService.getActiveTerminalId();
      res.json({
        success: true,
        activeTerminalId
      });
    } catch (error) {
      throw error; // Let error handler catch it
    }
  }

  /**
   * Send input to terminal
   */
  private async handleTerminalInput(req: AuthenticatedRequest, res: Response): Promise<void> {
    const terminalId = req.params.id;
    const { data } = req.body;

    if (!data || typeof data !== 'string') {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/400',
        title: 'Bad Request',
        status: 400,
        detail: 'Missing input data',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };
      res.status(400).json(errorResponse);
      return;
    }

    try {
      const success = await this.terminalService.sendInput(terminalId, data);
      
      if (!success) {
        const errorResponse: ErrorResponse = {
          type: 'https://httpstatuses.com/404',
          title: 'Not Found',
          status: 404,
          detail: 'Terminal not found or input failed',
          instance: req.originalUrl,
          timestamp: new Date().toISOString(),
          requestId: req.requestId || 'unknown'
        };
        res.status(404).json(errorResponse);
        return;
      }

      res.json({
        success: true,
        sequence: Date.now() // Simple sequence number
      });
    } catch (error) {
      throw error; // Let error handler catch it
    }
  }

  /**
   * Resize terminal
   */
  private async handleTerminalResize(req: AuthenticatedRequest, res: Response): Promise<void> {
    const terminalId = req.params.id;
    const { cols, rows } = req.body;

    if (!cols || !rows || cols <= 0 || rows <= 0 || !Number.isInteger(cols) || !Number.isInteger(rows)) {
      const errorResponse: ErrorResponse = {
        type: 'https://httpstatuses.com/400',
        title: 'Bad Request',
        status: 400,
        detail: 'Invalid dimensions',
        instance: req.originalUrl,
        timestamp: new Date().toISOString(),
        requestId: req.requestId || 'unknown'
      };
      res.status(400).json(errorResponse);
      return;
    }

    try {
      const success = await this.terminalService.resizeTerminal(terminalId, cols, rows);
      
      if (!success) {
        const errorResponse: ErrorResponse = {
          type: 'https://httpstatuses.com/404',
          title: 'Not Found',
          status: 404,
          detail: 'Terminal not found or resize failed',
          instance: req.originalUrl,
          timestamp: new Date().toISOString(),
          requestId: req.requestId || 'unknown'
        };
        res.status(404).json(errorResponse);
        return;
      }

      res.json({
        success: true
      });
    } catch (error) {
      throw error; // Let error handler catch it
    }
  }

  /**
   * Handle 404 errors
   */
  private handle404(req: AuthenticatedRequest, res: Response): void {
    const errorResponse: ErrorResponse = {
      type: 'https://httpstatuses.com/404',
      title: 'Not Found',
      status: 404,
      detail: 'Resource not found',
      instance: req.originalUrl,
      timestamp: new Date().toISOString(),
      requestId: req.requestId || 'unknown'
    };
    res.status(404).json(errorResponse);
  }
}