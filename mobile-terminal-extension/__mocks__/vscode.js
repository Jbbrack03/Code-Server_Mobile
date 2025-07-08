// Manual mock for vscode module

// Create mock functions that can be spied on
const showInformationMessage = jest.fn();
const showErrorMessage = jest.fn();
const showWarningMessage = jest.fn();
const createOutputChannel = jest.fn(() => ({
  appendLine: jest.fn(),
  append: jest.fn(),
  clear: jest.fn(),
  dispose: jest.fn(),
  hide: jest.fn(),
  show: jest.fn(),
  replace: jest.fn(),
  name: 'Mock Output Channel'
}));
const createWebviewPanel = jest.fn(() => ({
  webview: {
    html: '',
    options: {},
    onDidReceiveMessage: jest.fn(),
    postMessage: jest.fn(),
    asWebviewUri: jest.fn()
  },
  title: '',
  viewType: '',
  options: {},
  viewColumn: 1,
  active: true,
  visible: true,
  onDidChangeViewState: jest.fn(),
  onDidDispose: jest.fn(),
  reveal: jest.fn(),
  dispose: jest.fn()
}));
const registerCommand = jest.fn((command, callback) => ({
  dispose: jest.fn()
}));

const vscode = {
  Uri: {
    parse: jest.fn((str) => ({ toString: () => str })),
    file: jest.fn((path) => ({ fsPath: path, toString: () => path })),
  },
  
  ViewColumn: {
    One: 1,
    Two: 2,
    Three: 3,
  },
  
  ExtensionMode: {
    Production: 1,
    Development: 2,
    Test: 3,
  },
  
  window: {
    showInformationMessage,
    showErrorMessage,
    showWarningMessage,
    createOutputChannel,
    createWebviewPanel,
    onDidOpenTerminal: jest.fn((callback) => ({ dispose: jest.fn() })),
    onDidCloseTerminal: jest.fn((callback) => ({ dispose: jest.fn() })),
    onDidChangeActiveTerminal: jest.fn((callback) => ({ dispose: jest.fn() })),
    terminals: [],
  },
  
  workspace: {
    getConfiguration: jest.fn(() => ({
      get: jest.fn((key) => {
        const defaults = {
          'server.port': 8092,
          'server.host': '0.0.0.0',
          'auth.allowedIPs': [],
          'buffer.maxLines': 1000,
          'terminal.trackClaudeCode': true,
          'logging.level': 'info'
        };
        return defaults[key];
      })
    })),
  },
  
  commands: {
    registerCommand,
  },
};

module.exports = vscode;