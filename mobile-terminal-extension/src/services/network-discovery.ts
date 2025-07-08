import * as os from 'os';
import { EventEmitter } from 'events';

export interface ServiceInfo {
  name: string;
  type: string;
  port: number;
  txt: Record<string, string>;
}

export interface DiscoveredService {
  name: string;
  addresses: string[];
  port: number;
  txt: Record<string, string>;
}

/**
 * NetworkDiscoveryService provides local network discovery and mDNS advertising
 * capabilities for the mobile terminal server.
 * 
 * This implementation uses a pure JavaScript approach to avoid native dependencies.
 */
export class NetworkDiscoveryService extends EventEmitter {
  private isAdvertising = false;
  private discoveredServers: DiscoveredService[] = [];
  private advertisementHandle: any = null;

  constructor() {
    super();
  }

  /**
   * Get URLs for all local network interfaces
   */
  getLocalNetworkUrls(port: number, protocol: string = 'http'): string[] {
    const interfaces = os.networkInterfaces();
    const urls: string[] = [];

    for (const [name, addresses] of Object.entries(interfaces)) {
      if (!addresses) continue;

      for (const addr of addresses) {
        // Skip internal/loopback interfaces
        if (addr.internal) continue;

        if (addr.family === 'IPv4') {
          urls.push(`${protocol}://${addr.address}:${port}`);
        } else if (addr.family === 'IPv6') {
          // IPv6 addresses need brackets in URLs
          urls.push(`${protocol}://[${addr.address}]:${port}`);
        }
      }
    }

    return urls;
  }

  /**
   * Get local hostnames that can be used for connection
   */
  getHostnames(): string[] {
    const hostnames: string[] = [];
    
    // Add localhost variants
    hostnames.push('localhost');
    
    // Add OS hostname if available
    try {
      const hostname = os.hostname();
      if (hostname && hostname !== 'localhost') {
        hostnames.push(hostname);
        // Also add .local variant for mDNS
        if (!hostname.endsWith('.local')) {
          hostnames.push(`${hostname}.local`);
        }
      }
    } catch (error) {
      // Ignore hostname errors
    }

    return hostnames;
  }

  /**
   * Generate complete list of service URLs (IPs + hostnames)
   */
  generateServiceUrls(port: number, protocol: string = 'http'): string[] {
    const urls: string[] = [];

    // Add IP-based URLs
    urls.push(...this.getLocalNetworkUrls(port, protocol));

    // Add hostname-based URLs
    const hostnames = this.getHostnames();
    for (const hostname of hostnames) {
      urls.push(`${protocol}://${hostname}:${port}`);
    }

    return urls;
  }

  /**
   * Advertise a service using mDNS (simulated for pure JS implementation)
   */
  async advertiseService(serviceInfo: ServiceInfo): Promise<void> {
    try {
      // In a real implementation, this would use an mDNS library like mdns-js
      // For now, we simulate the advertising
      this.isAdvertising = true;
      this.advertisementHandle = {
        service: serviceInfo,
        startTime: new Date()
      };

      // Simulate async operation
      await new Promise(resolve => setTimeout(resolve, 10));
    } catch (error) {
      // Handle errors gracefully - don't throw
      console.error('Failed to advertise service:', error);
    }
  }

  /**
   * Stop advertising the current service
   */
  async stopAdvertising(): Promise<void> {
    try {
      if (this.advertisementHandle) {
        this.advertisementHandle = null;
      }
      this.isAdvertising = false;

      // Simulate async operation
      await new Promise(resolve => setTimeout(resolve, 10));
    } catch (error) {
      // Handle errors gracefully
      console.error('Failed to stop advertising:', error);
    }
  }

  /**
   * Discover services of a specific type on the network
   */
  async discoverServices(serviceType: string, timeoutMs: number = 5000): Promise<DiscoveredService[]> {
    try {
      // In a real implementation, this would use an mDNS browser
      // For now, we simulate discovery with a timeout
      return new Promise((resolve) => {
        const timer = setTimeout(() => {
          // Return empty array if no services found within timeout
          resolve([]);
        }, timeoutMs);

        // In a real implementation, we would listen for mDNS responses
        // and resolve early if services are found
      });
    } catch (error) {
      console.error('Failed to discover services:', error);
      return [];
    }
  }

  /**
   * Check if the service is currently being advertised
   */
  isRunning(): boolean {
    return this.isAdvertising;
  }

  /**
   * Get list of discovered servers
   */
  getDiscoveredServers(): DiscoveredService[] {
    return [...this.discoveredServers];
  }

  /**
   * Add a discovered server (for testing/simulation)
   */
  addDiscoveredServer(service: DiscoveredService): void {
    this.discoveredServers.push(service);
    this.emit('serviceDiscovered', service);
  }

  /**
   * Remove a discovered server by name
   */
  removeDiscoveredServer(serviceName: string): void {
    const index = this.discoveredServers.findIndex(s => s.name === serviceName);
    if (index !== -1) {
      const removed = this.discoveredServers.splice(index, 1)[0];
      this.emit('serviceRemoved', removed);
    }
  }

  /**
   * Clean up resources
   */
  async dispose(): Promise<void> {
    await this.stopAdvertising();
    this.discoveredServers = [];
    this.removeAllListeners();
  }
}