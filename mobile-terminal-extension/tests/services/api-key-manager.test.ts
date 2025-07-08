import { ApiKeyManager } from '../../src/services/api-key-manager';
import * as vscode from 'vscode';

describe('ApiKeyManager - Simple Tests', () => {
  let manager: ApiKeyManager;
  let mockContext: vscode.ExtensionContext;

  beforeEach(() => {
    // Create mock extension context
    mockContext = {
      globalState: {
        get: jest.fn(),
        update: jest.fn(),
      },
      workspaceState: {
        get: jest.fn(),
        update: jest.fn(),
      },
      secrets: {
        get: jest.fn(),
        store: jest.fn(),
        delete: jest.fn(),
      },
    } as any;

    manager = new ApiKeyManager(mockContext);

    // Reset all mocks
    jest.clearAllMocks();
  });

  describe('initialization', () => {
    it('should initialize with extension context', () => {
      expect(manager).toBeInstanceOf(ApiKeyManager);
    });

    it('should have correct key length constant', () => {
      expect(manager.getKeyLength()).toBe(32);
    });

    it('should use SHA-256 as hash algorithm', () => {
      expect(manager.getHashAlgorithm()).toBe('sha256');
    });
  });

  describe('API key generation', () => {
    it('should generate a string API key', async () => {
      const apiKey = await manager.generateApiKey();

      expect(typeof apiKey).toBe('string');
      expect(apiKey.length).toBeGreaterThan(0);
    });

    it('should generate different keys on multiple calls', async () => {
      const key1 = await manager.generateApiKey();
      const key2 = await manager.generateApiKey();

      expect(key1).not.toBe(key2);
    });

    it('should generate keys without unsafe URL characters', async () => {
      const apiKey = await manager.generateApiKey();

      // Base64URL encoding should not contain + / = characters
      expect(apiKey).not.toMatch(/[+/=]/);
      expect(typeof apiKey).toBe('string');
    });
  });

  describe('API key hashing', () => {
    it('should hash API key consistently', () => {
      const testKey = 'test-api-key-123';

      const hash1 = manager.hashApiKey(testKey);
      const hash2 = manager.hashApiKey(testKey);

      expect(hash1).toBe(hash2);
      expect(typeof hash1).toBe('string');
      expect(hash1.length).toBe(64); // SHA-256 hex output is 64 characters
    });

    it('should produce different hashes for different inputs', () => {
      const hash1 = manager.hashApiKey('key1');
      const hash2 = manager.hashApiKey('key2');

      expect(hash1).not.toBe(hash2);
    });
  });

  describe('API key validation', () => {
    it('should validate correct API key against its hash', () => {
      const testKey = 'test-api-key-123';
      const hash = manager.hashApiKey(testKey);

      const isValid = manager.validateApiKey(testKey, hash);

      expect(isValid).toBe(true);
    });

    it('should reject incorrect API key against hash', () => {
      const testKey = 'test-api-key-123';
      const wrongKey = 'wrong-api-key-456';
      const hash = manager.hashApiKey(testKey);

      const isValid = manager.validateApiKey(wrongKey, hash);

      expect(isValid).toBe(false);
    });
  });

  describe('API key storage', () => {
    it('should store API key hash in global state', async () => {
      const testKey = 'test-api-key-123';

      await manager.storeApiKey(testKey);

      expect(mockContext.secrets.store).toHaveBeenCalledWith(
        'mobileTerminal.apiKey',
        testKey
      );
      expect(mockContext.globalState.update).toHaveBeenCalledWith(
        'mobileTerminal.apiKeyHash',
        expect.any(String)
      );
    });
  });

  describe('API key retrieval', () => {
    it('should retrieve API key from secure storage', async () => {
      const testKey = 'stored-api-key-123';
      (mockContext.secrets.get as jest.Mock).mockResolvedValue(testKey);

      const retrievedKey = await manager.retrieveApiKey();

      expect(mockContext.secrets.get).toHaveBeenCalledWith('mobileTerminal.apiKey');
      expect(retrievedKey).toBe(testKey);
    });

    it('should return null if no API key is stored', async () => {
      (mockContext.secrets.get as jest.Mock).mockResolvedValue(undefined);

      const retrievedKey = await manager.retrieveApiKey();

      expect(retrievedKey).toBeNull();
    });

    it('should retrieve API key hash from global state', async () => {
      const testHash = 'stored-hash-value';
      (mockContext.globalState.get as jest.Mock).mockReturnValue(testHash);

      const retrievedHash = await manager.retrieveApiKeyHash();

      expect(mockContext.globalState.get).toHaveBeenCalledWith('mobileTerminal.apiKeyHash');
      expect(retrievedHash).toBe(testHash);
    });
  });

  describe('API key rotation', () => {
    it('should generate new API key and store it', async () => {
      const rotatedKey = await manager.rotateApiKey();

      expect(typeof rotatedKey).toBe('string');
      expect(rotatedKey.length).toBeGreaterThan(0);
      expect(mockContext.secrets.store).toHaveBeenCalledWith(
        'mobileTerminal.apiKey',
        rotatedKey
      );
      expect(mockContext.globalState.update).toHaveBeenCalledWith(
        'mobileTerminal.apiKeyHash',
        expect.any(String)
      );
    });
  });

  describe('API key deletion', () => {
    it('should delete API key from storage', async () => {
      await manager.deleteApiKey();

      expect(mockContext.secrets.delete).toHaveBeenCalledWith('mobileTerminal.apiKey');
      expect(mockContext.globalState.update).toHaveBeenCalledWith(
        'mobileTerminal.apiKeyHash',
        undefined
      );
    });
  });

  describe('API key existence check', () => {
    it('should return true if API key exists', async () => {
      (mockContext.secrets.get as jest.Mock).mockResolvedValue('existing-key');

      const exists = await manager.hasApiKey();

      expect(exists).toBe(true);
    });

    it('should return false if no API key exists', async () => {
      (mockContext.secrets.get as jest.Mock).mockResolvedValue(undefined);

      const exists = await manager.hasApiKey();

      expect(exists).toBe(false);
    });
  });
});