# SSHPortal

Self-hosted SSH public key distribution portal. Visit a single URL, copy a one-liner, paste it on any server you control to authorize your keys.

## Quickstart

```bash
docker run -d --name sshportal \
  -p 8080:8080 \
  -v "$PWD/keys.yaml:/config/keys.yaml:ro" \
  -e BASE_URL=https://keys.example.com \
  -e TITLE=yourhandle \
  ghcr.io/murilxaraujo/sshportal:latest
```

Open `http://localhost:8080`. On a server, run:

```bash
curl -fs https://keys.example.com/keys >> ~/.ssh/authorized_keys
```

## Configuration

### `keys.yaml`

```yaml
title: yourhandle
sources:
  github:
    - your-github-username
  gitlab:
    - your-gitlab-username
  manual:
    - comment: Yubikey
      key: "sk-ecdsa-sha2-nistp256@openssh.com AAAA... user@yubikey"
```

The file is re-read on every refresh, so edits take effect within `REFRESH_INTERVAL` seconds without a restart.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `HOST` | `0.0.0.0` | bind address |
| `BASE_URL` | `http://localhost:8080` | public URL shown in install command |
| `TITLE` | `sshportal` | UI heading |
| `KEYS_FILE` | `/config/keys.yaml` | YAML config path |
| `REFRESH_INTERVAL` | `3600` | seconds between remote refresh (0 = startup only) |
| `THEME_COLOR` | `#00FF41` | accent color (hex) |
| `LOG_LEVEL` | `info` | debug/info/warning/error |

## Endpoints

- `GET /` — HTML UI
- `GET /keys` — all keys, `text/plain`
- `GET /keys/:type` — filtered (`ed25519`, `rsa`, `ecdsa`, `ecdsa-sk`, `ed25519-sk`)
- `GET /health` — JSON health probe

All endpoints are public, read-only, and rate-limited to 60 requests per minute per IP.

## Security

Always serve over HTTPS in production. Without TLS, a MITM attacker can substitute keys in transit. Put SSHPortal behind nginx, Caddy, or Traefik for TLS termination.

The container runs as a non-root `sshportal` user. The keys file should be mounted read-only.

## install.sh helper

`scripts/install.sh` is a smarter install command that dedupes against existing entries in `~/.ssh/authorized_keys`. Use it instead of plain `>>` if you may have run a previous install:

```bash
PORTAL=https://keys.example.com bash <(curl -fsSL https://keys.example.com/install.sh)
```

(You'll need to host the script alongside the portal, or vendor it into your dotfiles.)

## Development

```bash
swift build
swift test
KEYS_FILE=config/keys.example.yaml swift run App
```

Local container build (macOS, no Docker daemon needed):

```bash
swift package --allow-network-connections all build-container-image \
  --repository ghcr.io/murilxaraujo/sshportal --tag dev
```

Or via Docker on Linux:

```bash
docker build -t sshportal:dev .
```

## License

MIT — see `LICENSE`.
