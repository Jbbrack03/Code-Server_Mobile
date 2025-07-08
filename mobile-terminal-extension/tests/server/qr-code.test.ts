import { QRCodeService } from '../../src/services/qr-code-service';
import { ConnectionProfile } from '../../src/types';

// Mock the VS Code module
jest.mock('vscode', () => ({
  window: { terminals: [] },
  ExtensionContext: jest.fn(),
  Terminal: jest.fn(),
  Disposable: { from: jest.fn() }
}), { virtual: true });

describe('QRCodeService', () => {
  let qrCodeService: QRCodeService;

  beforeEach(() => {
    qrCodeService = new QRCodeService();
  });

  describe('Connection Information QR Code Generation', () => {
    it('should generate QR code from connection profile', async () => {
      const connectionProfile: ConnectionProfile = {
        id: 'test-profile-1',
        name: 'Test Connection',
        urls: ['http://192.168.1.100:8092', 'http://terminal.local:8092'],
        apiKey: 'test-api-key-12345',
        autoConnect: true,
        networkSSIDs: ['HomeWiFi', 'OfficeWiFi'],
        tlsConfig: {
          allowSelfSigned: false,
          pinnedCertificates: []
        },
        createdAt: new Date('2025-01-01T00:00:00Z'),
        lastUsed: new Date('2025-01-01T00:00:00Z')
      };

      const qrCode = await qrCodeService.generateConnectionQR(connectionProfile);
      
      expect(qrCode).toBeDefined();
      expect(typeof qrCode).toBe('string');
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
    });

    it('should generate QR code with minimal connection info', async () => {
      const minimalProfile: ConnectionProfile = {
        id: 'minimal-profile',
        name: 'Minimal Connection',
        urls: ['http://localhost:8092'],
        apiKey: 'simple-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrCode = await qrCodeService.generateConnectionQR(minimalProfile);
      
      expect(qrCode).toBeDefined();
      expect(typeof qrCode).toBe('string');
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
    });

    it('should include version information in QR code data', async () => {
      const profile: ConnectionProfile = {
        id: 'version-test',
        name: 'Version Test',
        urls: ['http://test.example.com:8092'],
        apiKey: 'version-test-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile);
      
      expect(qrData).toHaveProperty('version');
      expect(qrData.version).toBe('1.0.0');
    });

    it('should include all connection URLs in QR data', async () => {
      const profile: ConnectionProfile = {
        id: 'multi-url-test',
        name: 'Multi URL Test',
        urls: [
          'http://192.168.1.100:8092',
          'http://terminal.home.lan:8092',
          'https://terminal.mydomain.com:8092'
        ],
        apiKey: 'multi-url-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile);
      
      expect(qrData).toHaveProperty('urls');
      expect(qrData.urls).toEqual(profile.urls);
      expect(qrData.urls).toHaveLength(3);
    });

    it('should include API key in QR data', async () => {
      const profile: ConnectionProfile = {
        id: 'api-key-test',
        name: 'API Key Test',
        urls: ['http://test.local:8092'],
        apiKey: 'secure-api-key-123',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile);
      
      expect(qrData).toHaveProperty('apiKey');
      expect(qrData.apiKey).toBe('secure-api-key-123');
    });

    it('should include connection name in QR data', async () => {
      const profile: ConnectionProfile = {
        id: 'name-test',
        name: 'Development Server',
        urls: ['http://dev.local:8092'],
        apiKey: 'dev-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile);
      
      expect(qrData).toHaveProperty('name');
      expect(qrData.name).toBe('Development Server');
    });
  });

  describe('QR Code Format Validation', () => {
    it('should generate valid base64 data URL', async () => {
      const profile: ConnectionProfile = {
        id: 'format-test',
        name: 'Format Test',
        urls: ['http://format.test:8092'],
        apiKey: 'format-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrCode = await qrCodeService.generateConnectionQR(profile);
      
      // Check data URL format
      expect(qrCode).toMatch(/^data:image\/png;base64,[A-Za-z0-9+/]+=*$/);
      
      // Decode base64 and check if it's a valid PNG
      const base64Data = qrCode.replace('data:image/png;base64,', '');
      const buffer = Buffer.from(base64Data, 'base64');
      
      // PNG files start with specific magic bytes
      expect(buffer[0]).toBe(0x89);
      expect(buffer[1]).toBe(0x50);
      expect(buffer[2]).toBe(0x4E);
      expect(buffer[3]).toBe(0x47);
    });

    it('should handle special characters in connection data', async () => {
      const profile: ConnectionProfile = {
        id: 'special-chars-test',
        name: 'Connection with Special Characters: !@#$%^&*()',
        urls: ['http://special-chars.test:8092'],
        apiKey: 'key-with-special-chars_123!@#',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrCode = await qrCodeService.generateConnectionQR(profile);
      
      expect(qrCode).toBeDefined();
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
    });

    it('should handle Unicode characters in connection data', async () => {
      const profile: ConnectionProfile = {
        id: 'unicode-test',
        name: 'Connection 测试 🚀 émoji',
        urls: ['http://unicode.test:8092'],
        apiKey: 'unicode-key-测试',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrCode = await qrCodeService.generateConnectionQR(profile);
      
      expect(qrCode).toBeDefined();
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
    });
  });

  describe('QR Code Options and Customization', () => {
    it('should generate QR code with custom error correction level', async () => {
      const profile: ConnectionProfile = {
        id: 'error-correction-test',
        name: 'Error Correction Test',
        urls: ['http://error-correction.test:8092'],
        apiKey: 'error-correction-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const options = {
        errorCorrectionLevel: 'H' as const, // High error correction
        width: 256,
        margin: 2
      };

      const qrCode = await qrCodeService.generateConnectionQR(profile, options);
      
      expect(qrCode).toBeDefined();
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
    });

    it('should generate QR code with custom dimensions', async () => {
      const profile: ConnectionProfile = {
        id: 'dimensions-test',
        name: 'Dimensions Test',
        urls: ['http://dimensions.test:8092'],
        apiKey: 'dimensions-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const options = {
        width: 512,
        margin: 4
      };

      const qrCode = await qrCodeService.generateConnectionQR(profile, options);
      
      expect(qrCode).toBeDefined();
      expect(qrCode).toMatch(/^data:image\/png;base64,/);
      
      // Larger width should result in larger base64 string
      const defaultQrCode = await qrCodeService.generateConnectionQR(profile);
      expect(qrCode.length).toBeGreaterThan(defaultQrCode.length);
    });

    it('should support different output formats', async () => {
      const profile: ConnectionProfile = {
        id: 'format-test',
        name: 'Format Test',
        urls: ['http://format.test:8092'],
        apiKey: 'format-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      // Test SVG format
      const svgQrCode = await qrCodeService.generateConnectionQRSVG(profile);
      expect(svgQrCode).toBeDefined();
      expect(svgQrCode).toMatch(/^<svg/);
      expect(svgQrCode.trim()).toMatch(/<\/svg>$/);

      // Test UTF8 format (terminal output)
      const utfQrCode = await qrCodeService.generateConnectionQRUTF8(profile);
      expect(utfQrCode).toBeDefined();
      expect(typeof utfQrCode).toBe('string');
      expect(utfQrCode.length).toBeGreaterThan(0);
    });
  });

  describe('Error Handling', () => {
    it('should throw error for empty URLs array', async () => {
      const invalidProfile: ConnectionProfile = {
        id: 'invalid-test',
        name: 'Invalid Test',
        urls: [], // Empty URLs
        apiKey: 'test-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await expect(qrCodeService.generateConnectionQR(invalidProfile))
        .rejects.toThrow('Connection profile must have at least one URL');
    });

    it('should throw error for empty API key', async () => {
      const invalidProfile: ConnectionProfile = {
        id: 'invalid-key-test',
        name: 'Invalid Key Test',
        urls: ['http://test.local:8092'],
        apiKey: '', // Empty API key
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await expect(qrCodeService.generateConnectionQR(invalidProfile))
        .rejects.toThrow('Connection profile must have a valid API key');
    });

    it('should throw error for invalid URL format', async () => {
      const invalidProfile: ConnectionProfile = {
        id: 'invalid-url-test',
        name: 'Invalid URL Test',
        urls: ['not-a-valid-url'], // Invalid URL format
        apiKey: 'test-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      await expect(qrCodeService.generateConnectionQR(invalidProfile))
        .rejects.toThrow('Invalid URL format in connection profile');
    });

    it('should handle QR code generation errors gracefully', async () => {
      const profile: ConnectionProfile = {
        id: 'error-test',
        name: 'Error Test',
        urls: ['http://error.test:8092'],
        apiKey: 'error-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      // Mock qrcode library to throw error
      const qrCodeLib = require('qrcode');
      const originalToDataURL = qrCodeLib.toDataURL;
      qrCodeLib.toDataURL = jest.fn().mockRejectedValue(new Error('QR generation failed'));

      await expect(qrCodeService.generateConnectionQR(profile))
        .rejects.toThrow('Failed to generate QR code: QR generation failed');

      // Restore original method
      qrCodeLib.toDataURL = originalToDataURL;
    });
  });

  describe('Data Serialization', () => {
    it('should serialize connection data to valid JSON', async () => {
      const profile: ConnectionProfile = {
        id: 'json-test',
        name: 'JSON Test',
        urls: ['http://json.test:8092'],
        apiKey: 'json-key',
        autoConnect: true,
        networkSSIDs: ['TestWiFi'],
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile);
      const jsonString = JSON.stringify(qrData);
      
      expect(() => JSON.parse(jsonString)).not.toThrow();
      
      const parsedData = JSON.parse(jsonString);
      expect(parsedData.name).toBe('JSON Test');
      expect(parsedData.urls).toEqual(['http://json.test:8092']);
      expect(parsedData.apiKey).toBe('json-key');
    });

    it('should exclude sensitive data from QR code when specified', async () => {
      const profile: ConnectionProfile = {
        id: 'sensitive-test',
        name: 'Sensitive Test',
        urls: ['http://sensitive.test:8092'],
        apiKey: 'sensitive-key',
        autoConnect: false,
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const qrData = await qrCodeService.getConnectionData(profile, { excludeSensitive: true });
      
      expect(qrData).not.toHaveProperty('apiKey');
      expect(qrData).toHaveProperty('urls');
      expect(qrData).toHaveProperty('name');
    });

    it('should compress large connection data when specified', async () => {
      const largeProfile: ConnectionProfile = {
        id: 'large-profile-with-very-long-identifier',
        name: 'Large Profile with Many URLs and Long Names for Testing Compression',
        urls: [
          'http://very-long-url-name-for-testing-compression-1.example.com:8092',
          'http://very-long-url-name-for-testing-compression-2.example.com:8092',
          'http://very-long-url-name-for-testing-compression-3.example.com:8092',
          'http://very-long-url-name-for-testing-compression-4.example.com:8092'
        ],
        apiKey: 'very-long-api-key-for-testing-compression-purposes-12345',
        autoConnect: true,
        networkSSIDs: ['LongWiFiNetworkName1', 'LongWiFiNetworkName2'],
        createdAt: new Date(),
        lastUsed: new Date()
      };

      const normalQrCode = await qrCodeService.generateConnectionQR(largeProfile);
      const compressedQrCode = await qrCodeService.generateConnectionQR(largeProfile, { compress: true });
      
      expect(compressedQrCode).toBeDefined();
      expect(compressedQrCode.length).toBeLessThan(normalQrCode.length);
    });
  });
});