# Deployment

Run SSHPortal in production behind TLS.

## Behind a reverse proxy

The container itself terminates plain HTTP. Put it behind nginx, Caddy, or
Traefik for TLS — and add `X-Forwarded-For` so per-IP rate limiting sees
the real client address.

### Caddy

```caddy
keys.example.com {
  reverse_proxy localhost:8080
}
```

Caddy sets `X-Forwarded-For` automatically.

### nginx

```nginx
server {
  listen 443 ssl http2;
  server_name keys.example.com;
  ssl_certificate     /etc/letsencrypt/live/keys.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/keys.example.com/privkey.pem;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

## systemd unit (containerless)

```ini
[Unit]
Description=SSHPortal
After=network-online.target

[Service]
Environment=KEYS_FILE=/etc/sshportal/keys.yaml
Environment=BASE_URL=https://keys.example.com
ExecStart=/usr/local/bin/sshportal
DynamicUser=yes
StateDirectory=sshportal
ProtectSystem=strict
NoNewPrivileges=yes
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Health checks

`GET /health` returns:

```json
{ "status": "ok", "keys_loaded": 5, "last_refresh": "2026-04-27T17:00:00Z" }
```

Use it as a liveness probe. The endpoint never blocks on remote fetches.
