# Mobile Terminal Network Configuration Guide

## Network Access Scenarios

### 1. Local Network Access (Default)
- **Use Case**: Home/office WiFi access
- **Requirements**: iOS device and VS Code on same network
- **URL Format**: `http://192.168.1.100:8092`
- **Security**: API key only (acceptable for trusted network)

### 2. Remote Access via Port Forwarding
- **Use Case**: Access from anywhere on internet
- **Requirements**: 
  - Public IP or Dynamic DNS
  - Router port forwarding configuration
  - Strong security measures

#### Router Configuration Steps
1. Forward external port (e.g., 18092) to internal 8092
2. Configure firewall rules
3. Note public IP or setup DDNS
4. **URL Format**: `http://your-public-ip:18092` or `http://yourdomain.ddns.net:18092`

### 3. Reverse Proxy Setup (Recommended for Production)
- **Use Case**: Professional setup with HTTPS
- **Benefits**: 
  - SSL/TLS encryption
  - No port numbers in URL
  - Better firewall compatibility
  - Multiple services on one domain

#### Nginx Configuration Example
```
server {
    server_name terminal.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8092;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Forward headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # SSL configuration
    listen 443 ssl;
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
}
```

#### Apache Configuration Example
```
<VirtualHost *:443>
    ServerName terminal.yourdomain.com
    
    # WebSocket proxy
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:8092/$1" [P,L]
    
    # HTTP proxy
    ProxyPass / http://localhost:8092/
    ProxyPassReverse / http://localhost:8092/
    
    # SSL configuration
    SSLEngine on
    SSLCertificateFile /path/to/cert.pem
    SSLCertificateKeyFile /path/to/key.pem
</VirtualHost>
```

### 4. Dynamic DNS Services
- **Use Case**: Home internet with changing IP
- **Popular Services**:
  - DuckDNS (free)
  - No-IP (free tier)
  - DynDNS
  - Cloudflare (with API)

#### Setup Process
1. Register with DDNS provider
2. Install update client on server
3. Configure router port forwarding
4. Use DDNS hostname in app

### 5. VPN Access
- **Use Case**: Secure corporate/home access
- **Benefits**: 
  - No port exposure
  - Full network access
  - Enterprise-grade security

#### Configuration
1. Connect iOS device to VPN
2. Use internal IP address
3. **URL Format**: `http://10.0.0.50:8092`

### 6. Cloudflare Tunnel (Zero Trust)
- **Use Case**: No port forwarding needed
- **Benefits**:
  - Automatic HTTPS
  - DDoS protection
  - No public IP needed
  - WebSocket support

#### Setup Steps
1. Install cloudflared on server
2. Create tunnel: `cloudflared tunnel create mobile-terminal`
3. Configure tunnel to point to localhost:8092
4. **URL Format**: `https://terminal.yourdomain.com`

## Implementation Requirements

### VS Code Extension Updates

#### Network Detection
- Detect available network interfaces
- Show local IP addresses
- Generate appropriate QR codes based on network
- Support multiple URL formats in QR code

#### Configuration Options
```
{
  "mobileTerminal.network.mode": "local|remote|proxy",
  "mobileTerminal.network.publicUrl": "https://terminal.example.com",
  "mobileTerminal.network.allowedOrigins": ["*"],
  "mobileTerminal.network.behindProxy": true,
  "mobileTerminal.network.trustedProxies": ["127.0.0.1"]
}
```

### iOS App Updates

#### Connection Types
1. **Local Network**
   - Direct IP:port connection
   - mDNS/Bonjour discovery (future)
   
2. **Remote HTTP**
   - Support for non-standard ports
   - Handle redirects
   
3. **Remote HTTPS**
   - Certificate validation
   - Self-signed cert support (with warning)
   - Certificate pinning (optional)

#### Connection Setup UI Changes
- Connection type selector (Local/Remote)
- Advanced settings section:
  - Custom port
  - HTTPS toggle
  - Ignore certificate errors (dev only)
  - Proxy settings
- Connection test with detailed diagnostics

#### URL Validation
- Support formats:
  - `192.168.1.100:8092`
  - `terminal.local:8092`
  - `home.mydomain.com:18092`
  - `https://terminal.company.com`
  - `terminal.company.com/mobile-terminal/`

### Security Considerations

#### HTTPS Requirements
- Strongly recommend HTTPS for remote access
- Show security warning for HTTP remote connections
- Implement certificate pinning for known servers

#### API Key Enhancements
- Longer keys for remote access (32+ characters)
- Key rotation reminders
- IP-based key restrictions (optional)
- Rate limiting per key

#### Additional Security Layers
1. **IP Allowlisting**: Configure allowed source IPs
2. **Fail2Ban Integration**: Block brute force attempts
3. **Two-Factor Auth**: Future enhancement
4. **Audit Logging**: Track all connections and commands

## Network Troubleshooting

### Common Issues

1. **"Connection Refused"**
   - Check if port is open: `nc -zv hostname port`
   - Verify firewall rules
   - Confirm service is running
   - Check bind address (0.0.0.0 vs 127.0.0.1)

2. **"Connection Timeout"**
   - Test port forwarding
   - Check ISP blocking
   - Verify DDNS update
   - Try different port

3. **"WebSocket Failed"**
   - Ensure proxy supports WebSocket
   - Check upgrade headers
   - Verify proxy configuration
   - Test with wscat tool

4. **"Certificate Error"**
   - Verify certificate validity
   - Check certificate hostname
   - Update iOS trusted certificates
   - Consider Let's Encrypt

### Diagnostic Tools

#### From iOS Device
- Network utility apps
- Web-based port checkers
- Ping/traceroute tools
- SSL certificate checkers

#### From Server
```bash
# Check listening ports
netstat -tlnp | grep 8092

# Test WebSocket
wscat -l 8092

# Monitor connections
tcpdump -i any port 8092

# Check firewall
iptables -L -n | grep 8092
```

## Setup Wizards

### Quick Setup Guides

1. **Home Network Setup**
   - Install extension
   - Open on local network
   - Scan QR code
   - Done!

2. **Remote Access Setup**
   - Choose method (port forward/proxy/tunnel)
   - Follow platform-specific guide
   - Configure security
   - Test from cellular network

3. **Enterprise Setup**
   - Work with IT for proxy/VPN
   - Configure allowed IPs
   - Set up monitoring
   - Document for users

## QR Code Enhancements

### Multi-URL QR Code Format
```json
{
  "version": "1.0",
  "connections": [
    {
      "name": "Local Network",
      "url": "http://192.168.1.100:8092",
      "type": "local"
    },
    {
      "name": "Remote Access",
      "url": "https://terminal.home.com",
      "type": "remote"
    }
  ],
  "apiKey": "your-secure-api-key",
  "generated": "2024-01-07T10:00:00Z"
}
```

This allows users to:
- See all available connection options
- Choose based on their network
- Fall back if primary fails
- Store multiple configurations