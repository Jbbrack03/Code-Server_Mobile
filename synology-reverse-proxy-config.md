# Synology Reverse Proxy Configuration for Code-Server

## WebSocket Support Requirements

Code-Server requires WebSocket connections for terminal, file watching, and live features. Your Synology reverse proxy needs specific headers.

## Configuration Steps in Synology DSM:

1. **Control Panel > Application Portal > Reverse Proxy**
2. **Edit your code.brackinhouse.familyds.net rule**
3. **Custom Header tab - Add these headers:**

```
Upgrade: $http_upgrade
Connection: upgrade
```

## Alternative: Advanced Settings

If the above doesn't work, try these additional headers in Custom Header:

```
Host: $host
X-Real-IP: $remote_addr
X-Forwarded-For: $proxy_add_x_forwarded_for
X-Forwarded-Proto: $scheme
```

## Complete nginx-style configuration (if editing manually):

```nginx
location / {
    proxy_pass http://YOUR_MAC_IP:8091;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Accept-Encoding gzip;
}
```

## Troubleshooting:

1. Ensure WebSocket is enabled in Synology reverse proxy
2. Check that port 8091 is forwarded in your router to your Mac's local IP
3. Verify your Mac's firewall allows incoming connections on port 8091
4. The existing session on your Mac won't interfere - Code-Server supports multiple connections

## Test WebSocket Connection:

After updating Synology settings, test from your iPhone:
1. Open https://code.brackinhouse.familyds.net
2. Login with password: a1544904J$
3. Open terminal - if it works, WebSocket is connected