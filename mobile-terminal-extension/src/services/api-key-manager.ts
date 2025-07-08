import * as vscode from 'vscode';
import * as crypto from 'crypto';

export class ApiKeyManager {
  private readonly keyLength = 32;
  private readonly hashAlgorithm = 'sha256';
  private readonly secretsKey = 'mobileTerminal.apiKey';
  private readonly stateKey = 'mobileTerminal.apiKeyHash';

  constructor(private context: vscode.ExtensionContext) {}

  /**
   * Get the key length constant
   */
  getKeyLength(): number {
    return this.keyLength;
  }

  /**
   * Get the hash algorithm constant
   */
  getHashAlgorithm(): string {
    return this.hashAlgorithm;
  }

  /**
   * Generate a cryptographically secure API key
   */
  async generateApiKey(): Promise<string> {
    const bytes = crypto.randomBytes(this.keyLength);
    return this.encodeBase64URL(bytes);
  }

  /**
   * Hash an API key using SHA-256
   */
  hashApiKey(key: string): string {
    return crypto
      .createHash(this.hashAlgorithm)
      .update(key)
      .digest('hex');
  }

  /**
   * Validate an API key against its hash using timing-safe comparison
   */
  validateApiKey(key: string, hash: string): boolean {
    const computedHash = this.hashApiKey(key);
    return crypto.timingSafeEqual(
      Buffer.from(computedHash),
      Buffer.from(hash)
    );
  }

  /**
   * Validate an API key against stored hash (async version for middleware)
   */
  async validateApiKeyAsync(key: string): Promise<boolean> {
    try {
      const storedHash = await this.retrieveApiKeyHash();
      if (!storedHash) {
        return false;
      }
      return this.validateApiKey(key, storedHash);
    } catch (error) {
      return false;
    }
  }

  /**
   * Store API key securely
   */
  async storeApiKey(key: string): Promise<void> {
    // Store raw key in secure storage
    await this.context.secrets.store(this.secretsKey, key);
    
    // Store hash in global state for validation
    const hash = this.hashApiKey(key);
    await this.context.globalState.update(this.stateKey, hash);
  }

  /**
   * Retrieve API key from secure storage
   */
  async retrieveApiKey(): Promise<string | null> {
    const key = await this.context.secrets.get(this.secretsKey);
    return key || null;
  }

  /**
   * Retrieve API key hash from global state
   */
  async retrieveApiKeyHash(): Promise<string | null> {
    const hash = this.context.globalState.get<string>(this.stateKey);
    return hash || null;
  }

  /**
   * Rotate the API key (generate new one and replace old)
   */
  async rotateApiKey(): Promise<string> {
    const newKey = await this.generateApiKey();
    await this.storeApiKey(newKey);
    return newKey;
  }

  /**
   * Delete API key from storage
   */
  async deleteApiKey(): Promise<void> {
    await this.context.secrets.delete(this.secretsKey);
    await this.context.globalState.update(this.stateKey, undefined);
  }

  /**
   * Check if an API key exists
   */
  async hasApiKey(): Promise<boolean> {
    const key = await this.context.secrets.get(this.secretsKey);
    return !!key;
  }

  /**
   * Encode bytes as Base64URL (URL-safe base64 without padding)
   */
  private encodeBase64URL(bytes: Buffer): string {
    return bytes
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }
}