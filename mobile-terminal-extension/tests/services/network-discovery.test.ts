import { NetworkDiscoveryService } from '../../src/services/network-discovery';

// Mock os module
jest.mock('os', () => ({
  networkInterfaces: jest.fn()
}));

describe('NetworkDiscoveryService', () => {
  let service: NetworkDiscoveryService;

  beforeEach(() => {
    service = new NetworkDiscoveryService();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should create network discovery service', () => {
      expect(() => new NetworkDiscoveryService()).not.toThrow();
    });

    it('should initialize with empty discovered servers list', () => {
      expect(service.getDiscoveredServers()).toEqual([]);
    });
  });

  describe('getLocalNetworkUrls()', () => {
    it('should return local network URLs for given port', () => {
      // Mock os.networkInterfaces
      const mockNetworkInterfaces = {
        'Wi-Fi': [
          {
            address: '192.168.1.100',
            netmask: '255.255.255.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: false,
            cidr: '192.168.1.100/24'
          }
        ],
        'Ethernet': [
          {
            address: '10.0.0.50',
            netmask: '255.255.255.0',
            family: 'IPv4',
            mac: '11:11:11:11:11:11',
            internal: false,
            cidr: '10.0.0.50/24'
          }
        ],
        'Loopback': [
          {
            address: '127.0.0.1',
            netmask: '255.0.0.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: true,
            cidr: '127.0.0.1/8'
          }
        ]
      };

      const os = require('os');
      os.networkInterfaces.mockReturnValue(mockNetworkInterfaces);

      const urls = service.getLocalNetworkUrls(8092);

      expect(urls).toEqual([
        'http://192.168.1.100:8092',
        'http://10.0.0.50:8092'
      ]);
    });

    it('should exclude internal/loopback interfaces', () => {
      const mockNetworkInterfaces = {
        'Loopback': [
          {
            address: '127.0.0.1',
            netmask: '255.0.0.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: true,
            cidr: '127.0.0.1/8'
          }
        ]
      };

      const os = require('os');
      os.networkInterfaces.mockReturnValue(mockNetworkInterfaces);

      const urls = service.getLocalNetworkUrls(8092);

      expect(urls).toEqual([]);
    });

    it('should handle IPv6 addresses', () => {
      const mockNetworkInterfaces = {
        'Wi-Fi': [
          {
            address: '192.168.1.100',
            netmask: '255.255.255.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: false,
            cidr: '192.168.1.100/24'
          },
          {
            address: 'fe80::1234:5678:9abc:def0',
            netmask: 'ffff:ffff:ffff:ffff::',
            family: 'IPv6',
            mac: '00:00:00:00:00:00',
            internal: false,
            cidr: 'fe80::1234:5678:9abc:def0/64'
          }
        ]
      };

      const os = require('os');
      os.networkInterfaces.mockReturnValue(mockNetworkInterfaces);

      const urls = service.getLocalNetworkUrls(8092);

      expect(urls).toEqual([
        'http://192.168.1.100:8092',
        'http://[fe80::1234:5678:9abc:def0]:8092'
      ]);
    });

    it('should handle missing network interfaces', () => {
      const os = require('os');
      os.networkInterfaces.mockReturnValue({});

      const urls = service.getLocalNetworkUrls(8092);

      expect(urls).toEqual([]);
    });
  });

  describe('getHostnames()', () => {
    it('should return local hostnames', () => {
      const hostnames = service.getHostnames();

      expect(Array.isArray(hostnames)).toBe(true);
      expect(hostnames.length).toBeGreaterThan(0);
    });

    it('should include localhost variants', () => {
      const hostnames = service.getHostnames();

      expect(hostnames).toContain('localhost');
    });
  });

  describe('advertiseService()', () => {
    it('should start mDNS service advertisement', async () => {
      const serviceInfo = {
        name: 'Mobile Terminal',
        type: '_mobile-terminal._tcp',
        port: 8092,
        txt: {
          version: '1.0.0',
          path: '/api'
        }
      };

      await expect(service.advertiseService(serviceInfo)).resolves.not.toThrow();
    });

    it('should handle advertisement errors gracefully', async () => {
      const serviceInfo = {
        name: 'Invalid Service',
        type: 'invalid-type',
        port: -1,
        txt: {}
      };

      // Should not throw, but should handle errors internally
      await expect(service.advertiseService(serviceInfo)).resolves.not.toThrow();
    });
  });

  describe('stopAdvertising()', () => {
    it('should stop mDNS service advertisement', async () => {
      const serviceInfo = {
        name: 'Mobile Terminal',
        type: '_mobile-terminal._tcp',
        port: 8092,
        txt: {
          version: '1.0.0'
        }
      };

      await service.advertiseService(serviceInfo);
      await expect(service.stopAdvertising()).resolves.not.toThrow();
    });

    it('should handle stop when not advertising', async () => {
      await expect(service.stopAdvertising()).resolves.not.toThrow();
    });
  });

  describe('discoverServices()', () => {
    it('should discover mobile terminal services on network', async () => {
      const serviceType = '_mobile-terminal._tcp.local';
      
      const discovered = await service.discoverServices(serviceType, 5000);
      
      expect(Array.isArray(discovered)).toBe(true);
    });

    it('should handle discovery timeout', async () => {
      const serviceType = '_nonexistent._tcp.local';
      
      const discovered = await service.discoverServices(serviceType, 100);
      
      expect(discovered).toEqual([]);
    });

    it('should return discovered server information', async () => {
      // Mock a discovered service
      const mockService = {
        name: 'Test Mobile Terminal',
        addresses: ['192.168.1.100'],
        port: 8092,
        txt: {
          version: '1.0.0',
          path: '/api'
        }
      };

      // Since we can't easily mock the discovery process in tests,
      // we'll test the data structure instead
      service.addDiscoveredServer(mockService);
      
      const servers = service.getDiscoveredServers();
      expect(servers).toHaveLength(1);
      expect(servers[0]).toEqual(mockService);
    });
  });

  describe('isRunning()', () => {
    it('should return false when not advertising', () => {
      expect(service.isRunning()).toBe(false);
    });

    it('should return true when advertising', async () => {
      const serviceInfo = {
        name: 'Mobile Terminal',
        type: '_mobile-terminal._tcp',
        port: 8092,
        txt: {}
      };

      await service.advertiseService(serviceInfo);
      expect(service.isRunning()).toBe(true);

      await service.stopAdvertising();
      expect(service.isRunning()).toBe(false);
    });
  });

  describe('generateServiceUrls()', () => {
    it('should generate URLs for multiple addresses and hostnames', () => {
      const port = 8092;
      const mockNetworkInterfaces = {
        'Wi-Fi': [
          {
            address: '192.168.1.100',
            netmask: '255.255.255.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: false,
            cidr: '192.168.1.100/24'
          }
        ]
      };

      const os = require('os');
      os.networkInterfaces.mockReturnValue(mockNetworkInterfaces);

      const urls = service.generateServiceUrls(port);

      expect(Array.isArray(urls)).toBe(true);
      expect(urls.length).toBeGreaterThan(0);
      
      // Should include IP addresses
      expect(urls.some((url: string) => url.includes('192.168.1.100'))).toBe(true);
      
      // Should include hostnames
      expect(urls.some((url: string) => url.includes('localhost'))).toBe(true);
    });

    it('should handle HTTPS protocol option', () => {
      const port = 8092;
      const protocol = 'https';
      
      const mockNetworkInterfaces = {
        'Wi-Fi': [
          {
            address: '192.168.1.100',
            netmask: '255.255.255.0',
            family: 'IPv4',
            mac: '00:00:00:00:00:00',
            internal: false,
            cidr: '192.168.1.100/24'
          }
        ]
      };

      const os = require('os');
      os.networkInterfaces.mockReturnValue(mockNetworkInterfaces);

      const urls = service.generateServiceUrls(port, protocol);

      expect(urls.every((url: string) => url.startsWith('https://'))).toBe(true);
    });
  });

  describe('event handling', () => {
    it('should emit serviceDiscovered event when service is found', (done) => {
      const mockService = {
        name: 'Test Service',
        addresses: ['192.168.1.100'],
        port: 8092,
        txt: {}
      };

      service.on('serviceDiscovered', (discoveredService: any) => {
        expect(discoveredService).toEqual(mockService);
        done();
      });

      // Simulate service discovery
      service.addDiscoveredServer(mockService);
    });

    it('should emit serviceRemoved event when service disappears', (done) => {
      const mockService = {
        name: 'Test Service',
        addresses: ['192.168.1.100'],
        port: 8092,
        txt: {}
      };

      service.addDiscoveredServer(mockService);

      service.on('serviceRemoved', (removedService: any) => {
        expect(removedService).toEqual(mockService);
        done();
      });

      // Simulate service removal
      service.removeDiscoveredServer(mockService.name);
    });
  });
});