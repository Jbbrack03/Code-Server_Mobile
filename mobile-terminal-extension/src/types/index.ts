export interface Terminal {
  id: string;
  name: string;
  pid: number;
  cwd: string;
  shellType: 'bash' | 'zsh' | 'fish' | 'pwsh' | 'cmd';
  isActive: boolean;
  isClaudeCode: boolean;
  createdAt: Date;
  lastActivity: Date;
  dimensions: {
    cols: number;
    rows: number;
  };
  status: 'active' | 'inactive' | 'crashed';
}

export interface ConnectionProfile {
  id: string;
  name: string;
  urls: string[];
  apiKey: string;
  autoConnect: boolean;
  networkSSIDs?: string[];
  tlsConfig?: {
    allowSelfSigned: boolean;
    pinnedCertificates: string[];
  };
  createdAt: Date;
  lastUsed: Date;
}

export interface CommandShortcut {
  id: string;
  label: string;
  command: string;
  position: number;
  icon?: string;
  color?: string;
  category: 'default' | 'git' | 'npm' | 'docker' | 'custom';
  usage: number;
  createdAt: Date;
}

export interface WebSocketMessage {
  id: string;
  type: MessageType;
  timestamp: number;
  payload: any;
}

export type MessageType = 
  | 'terminal.output'
  | 'terminal.input'
  | 'terminal.resize'
  | 'terminal.list'
  | 'terminal.select'
  | 'connection.ping'
  | 'connection.pong'
  | 'error'
  | 'auth.challenge'
  | 'auth.response';

export interface TerminalOutputMessage extends WebSocketMessage {
  type: 'terminal.output';
  payload: {
    terminalId: string;
    data: string;
    sequence: number;
  };
}

export interface TerminalInputMessage extends WebSocketMessage {
  type: 'terminal.input';
  payload: {
    terminalId: string;
    data: string;
  };
}

export interface ErrorMessage extends WebSocketMessage {
  type: 'error';
  payload: {
    code: string;
    message: string;
    details?: any;
  };
}

export enum ErrorCode {
  // Authentication
  AUTH_INVALID_KEY = 'AUTH_001',
  AUTH_EXPIRED_KEY = 'AUTH_002',
  AUTH_RATE_LIMITED = 'AUTH_003',
  
  // Terminal
  TERMINAL_NOT_FOUND = 'TERM_001',
  TERMINAL_CRASHED = 'TERM_002',
  TERMINAL_BUSY = 'TERM_003',
  
  // Network
  NETWORK_TIMEOUT = 'NET_001',
  NETWORK_DISCONNECTED = 'NET_002',
  NETWORK_UNREACHABLE = 'NET_003',
  
  // WebSocket
  WS_CONNECTION_FAILED = 'WS_001',
  WS_MESSAGE_INVALID = 'WS_002',
  WS_BUFFER_OVERFLOW = 'WS_003',
  
  // System
  INTERNAL_ERROR = 'SYS_001',
  RESOURCE_EXHAUSTED = 'SYS_002',
  SERVICE_UNAVAILABLE = 'SYS_003'
}

export interface ErrorResponse {
  type: string;
  title: string;
  status: number;
  detail: string;
  instance: string;
  timestamp: string;
  requestId: string;
}

export interface HealthResponse {
  status: 'healthy' | 'degraded' | 'unhealthy';
  version: string;
  uptime: number;
  terminals: number;
}

export interface TerminalListResponse {
  terminals: Terminal[];
  activeTerminalId: string | null;
}

export interface TerminalDetailsResponse {
  terminal: Terminal;
  buffer: string[];
}