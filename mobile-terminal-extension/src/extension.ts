import * as vscode from 'vscode';
import * as crypto from 'crypto';
import { TerminalService } from './services/terminal.service';
import { ApiKeyManager } from './services/api-key-manager';
import { ExtensionServerController } from './services/extension-server-controller';
import { QRWebviewService } from './services/qr-webview';
import { NetworkDiscoveryService } from './services/network-discovery';
import { ExpressServer } from './server/express-server';
import { WebSocketServerManager } from './server/websocket-server-manager';
import { QRCodeService } from './services/qr-code-service';

let statusBarItem: vscode.StatusBarItem;
let serverController: ExtensionServerController;
let apiKeyManager: ApiKeyManager;
let qrWebviewService: QRWebviewService;
let networkDiscoveryService: NetworkDiscoveryService;
let statusUpdateInterval: NodeJS.Timeout | undefined;

export async function activate(context: vscode.ExtensionContext) {
  // Initialize services
  const terminalService = new TerminalService();
  apiKeyManager = new ApiKeyManager(context);
  const expressServer = new ExpressServer(terminalService, apiKeyManager);
  const webSocketManager = new WebSocketServerManager(terminalService, apiKeyManager);
  networkDiscoveryService = new NetworkDiscoveryService();
  
  serverController = new ExtensionServerController(
    context,
    terminalService,
    apiKeyManager,
    expressServer,
    webSocketManager
  );
  
  const qrCodeService = new QRCodeService();
  qrWebviewService = new QRWebviewService(context, qrCodeService);

  // Create status bar item
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  updateStatusBar();
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  // Register the start command
  const startCommand = vscode.commands.registerCommand('mobileTerminal.start', async () => {
    if (serverController.isRunning()) {
      await vscode.window.showWarningMessage('Mobile Terminal server is already running');
      return;
    }

    try {
      await serverController.start();
      updateStatusBar();
      await vscode.window.showInformationMessage(`Mobile Terminal server started on ${serverController.getServerUrl()}`);
      
      // Start periodic status updates
      if (!statusUpdateInterval) {
        statusUpdateInterval = setInterval(updateStatusBar, 5000);
      }
    } catch (error: any) {
      await vscode.window.showErrorMessage(`Failed to start Mobile Terminal server: ${error.message}`);
    }
  });
  
  // Register the stop command
  const stopCommand = vscode.commands.registerCommand('mobileTerminal.stop', async () => {
    if (!serverController.isRunning()) {
      await vscode.window.showWarningMessage('Mobile Terminal server is not running');
      return;
    }

    try {
      await serverController.stop();
      updateStatusBar();
      await vscode.window.showInformationMessage('Mobile Terminal server stopped');
      
      // Stop periodic status updates
      if (statusUpdateInterval) {
        clearInterval(statusUpdateInterval);
        statusUpdateInterval = undefined;
      }
    } catch (error: any) {
      await vscode.window.showErrorMessage(`Failed to stop Mobile Terminal server: ${error.message}`);
    }
  });
  
  // Register the showQR command
  const showQRCommand = vscode.commands.registerCommand('mobileTerminal.showQR', async () => {
    try {
      // Start server if not running
      if (!serverController.isRunning()) {
        await serverController.start();
        updateStatusBar();
      }

      // Get or generate API key
      let apiKey = await apiKeyManager.retrieveApiKey();
      if (!apiKey) {
        apiKey = await apiKeyManager.generateApiKey();
        await apiKeyManager.storeApiKey(apiKey);
      }

      // Get connection URLs
      const urls = networkDiscoveryService.getLocalNetworkUrls(8092);

      // Show QR code
      await qrWebviewService.showQRCode({
        id: crypto.randomUUID(),
        name: 'Mobile Terminal Connection',
        urls,
        apiKey,
        autoConnect: true,
        createdAt: new Date(),
        lastUsed: new Date()
      });
    } catch (error: any) {
      await vscode.window.showErrorMessage(`Failed to show QR code: ${error.message}`);
    }
  });
  
  // Register the rotateKey command
  const rotateKeyCommand = vscode.commands.registerCommand('mobileTerminal.rotateKey', async () => {
    const choice = await vscode.window.showWarningMessage(
      'Are you sure you want to rotate the API key? This will disconnect all existing clients.',
      'Yes',
      'No'
    );

    if (choice !== 'Yes') {
      return;
    }

    try {
      const newKey = await apiKeyManager.rotateApiKey();
      const showQR = await vscode.window.showInformationMessage(
        'API key rotated successfully. Please update your mobile app connection.',
        'Show QR Code'
      );

      if (showQR === 'Show QR Code' && serverController.isRunning()) {
        const urls = networkDiscoveryService.getLocalNetworkUrls(8092);
        await qrWebviewService.showQRCode({
          id: crypto.randomUUID(),
          name: 'Mobile Terminal Connection',
          urls,
          apiKey: newKey,
          autoConnect: true,
          createdAt: new Date(),
          lastUsed: new Date()
        });
      }
    } catch (error: any) {
      await vscode.window.showErrorMessage(`Failed to rotate API key: ${error.message}`);
    }
  });
  
  context.subscriptions.push(startCommand);
  context.subscriptions.push(stopCommand);
  context.subscriptions.push(showQRCommand);
  context.subscriptions.push(rotateKeyCommand);

  // Clean up on deactivation
  context.subscriptions.push({
    dispose: async () => {
      if (statusUpdateInterval) {
        clearInterval(statusUpdateInterval);
      }
      if (serverController.isRunning()) {
        await serverController.stop();
      }
    }
  });
}

function updateStatusBar() {
  if (!statusBarItem) return;
  
  if (serverController && serverController.isRunning && serverController.isRunning()) {
    statusBarItem.text = '$(terminal) Mobile Terminal: Running';
    const serverUrl = serverController.getServerUrl ? serverController.getServerUrl() : 'http://localhost:8092';
    statusBarItem.tooltip = `Mobile Terminal server is running on ${serverUrl}\nClick to stop`;
    statusBarItem.command = 'mobileTerminal.stop';
  } else {
    statusBarItem.text = '$(terminal) Mobile Terminal: Stopped';
    statusBarItem.tooltip = 'Click to start Mobile Terminal server';
    statusBarItem.command = 'mobileTerminal.start';
  }
}

export function deactivate() {
  if (statusUpdateInterval) {
    clearInterval(statusUpdateInterval);
  }
  if (statusBarItem) {
    statusBarItem.dispose();
  }
  if (serverController && serverController.isRunning()) {
    return serverController.stop();
  }
}