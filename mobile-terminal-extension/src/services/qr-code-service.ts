import * as QRCode from 'qrcode';
import { ConnectionProfile } from '../types';

export interface QRCodeOptions {
  errorCorrectionLevel?: 'L' | 'M' | 'Q' | 'H';
  width?: number;
  margin?: number;
  compress?: boolean;
  excludeSensitive?: boolean;
}

export interface ConnectionData {
  version: string;
  name: string;
  urls: string[];
  apiKey?: string;
  autoConnect?: boolean;
  networkSSIDs?: string[];
  tlsConfig?: {
    allowSelfSigned: boolean;
    pinnedCertificates: string[];
  };
}

export class QRCodeService {
  private readonly version = '1.0.0';

  /**
   * Generate a QR code as base64 data URL from connection profile
   */
  async generateConnectionQR(profile: ConnectionProfile, options?: QRCodeOptions): Promise<string> {
    try {
      // Validate profile
      this.validateConnectionProfile(profile);

      // Get connection data
      const connectionData = await this.getConnectionData(profile, options);

      // Serialize to JSON
      let jsonData = JSON.stringify(connectionData);

      // Apply compression if requested
      if (options?.compress) {
        jsonData = await this.compressData(jsonData);
      }

      // Generate QR code options
      const qrOptions = this.buildQROptions(options);

      // Generate QR code
      const qrCodeDataURL = await QRCode.toDataURL(jsonData, qrOptions);
      
      return qrCodeDataURL;
    } catch (error) {
      throw new Error(`Failed to generate QR code: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Generate a QR code as SVG string from connection profile
   */
  async generateConnectionQRSVG(profile: ConnectionProfile, options?: QRCodeOptions): Promise<string> {
    try {
      // Validate profile
      this.validateConnectionProfile(profile);

      // Get connection data
      const connectionData = await this.getConnectionData(profile, options);

      // Serialize to JSON
      let jsonData = JSON.stringify(connectionData);

      // Apply compression if requested
      if (options?.compress) {
        jsonData = await this.compressData(jsonData);
      }

      // Generate QR code options
      const qrOptions = this.buildQROptions(options);

      // Generate SVG QR code
      const svgString = await QRCode.toString(jsonData, { 
        ...qrOptions, 
        type: 'svg' as any 
      });
      
      return svgString;
    } catch (error) {
      throw new Error(`Failed to generate SVG QR code: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Generate a QR code as UTF8 string (terminal output) from connection profile
   */
  async generateConnectionQRUTF8(profile: ConnectionProfile, options?: QRCodeOptions): Promise<string> {
    try {
      // Validate profile
      this.validateConnectionProfile(profile);

      // Get connection data
      const connectionData = await this.getConnectionData(profile, options);

      // Serialize to JSON
      let jsonData = JSON.stringify(connectionData);

      // Apply compression if requested
      if (options?.compress) {
        jsonData = await this.compressData(jsonData);
      }

      // Generate QR code options
      const qrOptions = this.buildQROptions(options);

      // Generate UTF8 QR code
      const utfString = await QRCode.toString(jsonData, { 
        ...qrOptions, 
        type: 'utf8' as any 
      });
      
      return utfString;
    } catch (error) {
      throw new Error(`Failed to generate UTF8 QR code: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get connection data from profile
   */
  async getConnectionData(profile: ConnectionProfile, options?: QRCodeOptions): Promise<ConnectionData> {
    const connectionData: ConnectionData = {
      version: this.version,
      name: profile.name,
      urls: profile.urls
    };

    // Add API key unless excluded
    if (!options?.excludeSensitive) {
      connectionData.apiKey = profile.apiKey;
    }

    // Add optional fields if present
    if (profile.autoConnect !== undefined) {
      connectionData.autoConnect = profile.autoConnect;
    }

    if (profile.networkSSIDs && profile.networkSSIDs.length > 0) {
      connectionData.networkSSIDs = profile.networkSSIDs;
    }

    if (profile.tlsConfig) {
      connectionData.tlsConfig = profile.tlsConfig;
    }

    return connectionData;
  }

  /**
   * Validate connection profile
   */
  private validateConnectionProfile(profile: ConnectionProfile): void {
    // Check URLs
    if (!profile.urls || profile.urls.length === 0) {
      throw new Error('Connection profile must have at least one URL');
    }

    // Validate URL formats
    for (const url of profile.urls) {
      if (!this.isValidURL(url)) {
        throw new Error('Invalid URL format in connection profile');
      }
    }

    // Check API key
    if (!profile.apiKey || profile.apiKey.trim() === '') {
      throw new Error('Connection profile must have a valid API key');
    }
  }

  /**
   * Validate URL format
   */
  private isValidURL(urlString: string): boolean {
    try {
      const url = new URL(urlString);
      return url.protocol === 'http:' || url.protocol === 'https:';
    } catch {
      return false;
    }
  }

  /**
   * Build QR code options
   */
  private buildQROptions(options?: QRCodeOptions): QRCode.QRCodeToDataURLOptions {
    const defaultOptions: QRCode.QRCodeToDataURLOptions = {
      errorCorrectionLevel: 'M',
      width: 256,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    };

    if (!options) {
      return defaultOptions;
    }

    const qrOptions: QRCode.QRCodeToDataURLOptions = {
      ...defaultOptions
    };

    if (options.errorCorrectionLevel) {
      qrOptions.errorCorrectionLevel = options.errorCorrectionLevel;
    }

    if (options.width) {
      qrOptions.width = options.width;
    }

    if (options.margin !== undefined) {
      qrOptions.margin = options.margin;
    }

    return qrOptions;
  }

  /**
   * Compress data for smaller QR codes
   */
  private async compressData(data: string): Promise<string> {
    // Simple compression: remove whitespace and use shorter property names
    const parsed = JSON.parse(data);
    
    // Create compressed object with shorter keys
    const compressed: any = {
      v: parsed.version,
      n: parsed.name,
      u: parsed.urls
    };

    if (parsed.apiKey) {
      compressed.k = parsed.apiKey;
    }

    if (parsed.autoConnect !== undefined) {
      compressed.a = parsed.autoConnect;
    }

    if (parsed.networkSSIDs) {
      compressed.s = parsed.networkSSIDs;
    }

    if (parsed.tlsConfig) {
      compressed.t = parsed.tlsConfig;
    }

    return JSON.stringify(compressed);
  }
}