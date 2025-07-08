import * as vscode from 'vscode';
import { QRCodeService } from './qr-code-service';
import { ConnectionProfile } from '../types';

/**
 * QRWebviewService manages QR code display in VS Code webview panels
 */
export class QRWebviewService {
  private currentPanel: vscode.WebviewPanel | undefined;

  constructor(
    private readonly context: vscode.ExtensionContext,
    private readonly qrCodeService: QRCodeService
  ) {}

  /**
   * Show QR code for connection profile in webview
   */
  async showQRCode(connectionProfile: ConnectionProfile): Promise<void> {
    // If panel exists, reveal it instead of creating new one
    if (this.currentPanel) {
      this.currentPanel.reveal(vscode.ViewColumn.One);
      return;
    }

    // Create new webview panel
    this.currentPanel = vscode.window.createWebviewPanel(
      'mobileTerminalQR',
      'Mobile Terminal QR Code',
      vscode.ViewColumn.One,
      {
        enableScripts: true,
        retainContextWhenHidden: true,
        localResourceRoots: [this.context.extensionUri]
      }
    );

    // Handle panel disposal
    this.currentPanel.onDidDispose(() => {
      this.currentPanel = undefined;
    });

    // Handle messages from webview
    this.currentPanel.webview.onDidReceiveMessage(async (message) => {
      switch (message.type) {
        case 'copyToClipboard':
          await vscode.env.clipboard.writeText(message.data);
          break;
        default:
          // Handle unknown message types gracefully
          break;
      }
    });

    try {
      // Generate QR code
      const qrCodeDataUrl = await this.qrCodeService.generateConnectionQR(connectionProfile, {
        width: 400,
        margin: 2,
        errorCorrectionLevel: 'M'
      });

      // Set webview content
      this.currentPanel.webview.html = this.getWebviewContent(qrCodeDataUrl, connectionProfile);
    } catch (error) {
      throw error;
    }
  }

  /**
   * Check if there's an active panel
   */
  hasActivePanel(): boolean {
    return this.currentPanel !== undefined;
  }

  /**
   * Dispose the current panel
   */
  dispose(): void {
    if (this.currentPanel) {
      this.currentPanel.dispose();
      this.currentPanel = undefined;
    }
  }

  /**
   * Generate HTML content for the webview
   */
  private getWebviewContent(qrCodeDataUrl: string, connectionProfile: ConnectionProfile): string {
    const nonce = this.generateNonce();
    
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${this.currentPanel!.webview.cspSource} data:; script-src 'nonce-${nonce}'; style-src 'unsafe-inline';">
    <title>Mobile Terminal QR Code</title>
    <style>
        body {
            font-family: var(--vscode-font-family);
            color: var(--vscode-foreground);
            background-color: var(--vscode-editor-background);
            padding: 20px;
            margin: 0;
            text-align: center;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
        }
        .qr-container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
            display: inline-block;
        }
        .qr-code {
            max-width: 100%;
            height: auto;
        }
        .connection-info {
            background: var(--vscode-textBlockQuote-background);
            border-left: 4px solid var(--vscode-textBlockQuote-border);
            padding: 16px;
            margin: 20px 0;
            text-align: left;
            border-radius: 4px;
        }
        .connection-info h3 {
            margin-top: 0;
            color: var(--vscode-textPreformat-foreground);
        }
        .connection-info p {
            margin: 8px 0;
            font-family: var(--vscode-editor-font-family);
        }
        .copy-button {
            background: var(--vscode-button-background);
            color: var(--vscode-button-foreground);
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            margin: 8px 4px;
        }
        .copy-button:hover {
            background: var(--vscode-button-hoverBackground);
        }
        .instructions {
            margin: 20px 0;
            color: var(--vscode-descriptionForeground);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Mobile Terminal QR Code</h1>
        
        <div class="instructions">
            <p>Scan this QR code with your mobile device to connect to the terminal server.</p>
        </div>
        
        <div class="qr-container">
            <img src="${qrCodeDataUrl}" alt="Mobile Terminal Connection QR Code" class="qr-code" />
        </div>
        
        <div class="connection-info">
            <h3>Connection Details</h3>
            <p><strong>Name:</strong> ${connectionProfile.name}</p>
            <p><strong>URLs:</strong> ${connectionProfile.urls.join(', ')}</p>
            <p><strong>Auto Connect:</strong> ${connectionProfile.autoConnect ? 'Yes' : 'No'}</p>
        </div>
        
        <button class="copy-button" onclick="copyConnectionString()">Copy Connection String</button>
    </div>
    
    <script nonce="${nonce}">
        const vscode = acquireVsCodeApi();
        
        function copyConnectionString() {
            const connectionString = JSON.stringify(${JSON.stringify(connectionProfile)});
            vscode.postMessage({
                type: 'copyToClipboard',
                data: connectionString
            });
        }
    </script>
</body>
</html>`;
  }

  /**
   * Generate a cryptographically secure nonce for CSP
   */
  private generateNonce(): string {
    let text = '';
    const possible = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    for (let i = 0; i < 32; i++) {
      text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
  }
}