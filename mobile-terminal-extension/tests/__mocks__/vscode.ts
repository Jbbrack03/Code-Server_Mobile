export const window = {
  createTerminal: jest.fn(),
  onDidOpenTerminal: jest.fn(),
  onDidCloseTerminal: jest.fn(),
  onDidChangeActiveTerminal: jest.fn(),
  onDidWriteTerminalData: jest.fn(),
  terminals: [],
  activeTerminal: null,
  showInformationMessage: jest.fn(),
  showErrorMessage: jest.fn(),
  showWarningMessage: jest.fn(),
  createStatusBarItem: jest.fn(() => ({
    text: '',
    tooltip: '',
    command: undefined,
    show: jest.fn(),
    hide: jest.fn(),
    dispose: jest.fn()
  })),
  createWebviewPanel: jest.fn(() => WebviewPanel),
};

export const workspace = {
  getConfiguration: jest.fn(() => ({
    get: jest.fn(),
    update: jest.fn(),
    has: jest.fn(),
    inspect: jest.fn(),
  })),
  onDidChangeConfiguration: jest.fn(),
  workspaceFolders: [],
};

export const env = {
  clipboard: {
    writeText: jest.fn(),
    readText: jest.fn()
  }
};

export const commands = {
  registerCommand: jest.fn(),
  executeCommand: jest.fn(),
};

export const extensions = {
  getExtension: jest.fn(),
  all: [],
};

export const ExtensionContext = {
  subscriptions: [],
  workspaceState: {
    get: jest.fn(),
    update: jest.fn(),
  },
  globalState: {
    get: jest.fn(),
    update: jest.fn(),
  },
  extensionPath: '/mock/extension/path',
  storagePath: '/mock/storage/path',
  globalStoragePath: '/mock/global/storage/path',
  logPath: '/mock/log/path',
};

export const Terminal = {
  name: 'Mock Terminal',
  processId: 12345,
  creationOptions: {},
  exitStatus: undefined,
  state: {},
  sendText: jest.fn(),
  show: jest.fn(),
  hide: jest.fn(),
  dispose: jest.fn(),
};

export const TerminalOptions = {};

export const Disposable = {
  from: jest.fn(() => ({ dispose: jest.fn() })),
};

export const EventEmitter = jest.fn(() => ({
  event: jest.fn(),
  fire: jest.fn(),
  dispose: jest.fn(),
}));

export const Uri = {
  file: jest.fn((path: string) => ({ fsPath: path, path, scheme: 'file' })),
  parse: jest.fn((uri: string) => ({ fsPath: uri, path: uri, scheme: 'file' })),
};

export const ConfigurationTarget = {
  Global: 1,
  Workspace: 2,
  WorkspaceFolder: 3,
};

export const StatusBarAlignment = {
  Left: 1,
  Right: 2,
};

export const ProgressLocation = {
  Notification: 15,
  Window: 10,
  SourceControl: 1,
};

export const ViewColumn = {
  Active: -1,
  Beside: -2,
  One: 1,
  Two: 2,
  Three: 3,
};

export const WebviewPanel = {
  viewType: 'mock',
  title: 'Mock Panel',
  webview: {
    html: '',
    options: {},
    cspSource: 'mock',
    asWebviewUri: jest.fn(),
    postMessage: jest.fn(),
    onDidReceiveMessage: jest.fn(),
  },
  options: {},
  viewColumn: ViewColumn.One,
  active: true,
  visible: true,
  onDidDispose: jest.fn(),
  onDidChangeViewState: jest.fn(),
  reveal: jest.fn(),
  dispose: jest.fn(),
};

export interface TerminalDataWriteEvent {
  terminal: any;
  data: string;
}