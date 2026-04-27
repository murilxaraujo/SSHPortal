# Configuration

Configure SSHPortal entirely through environment variables and a single
YAML file.

## keys.yaml

The keys file lists every source the portal pulls keys from.

```yaml
title: yourhandle
sources:
  github:
    - your-github-username
  gitlab:
    - your-gitlab-username
  manual:
    - comment: "Yubikey (laptop)"
      key: "sk-ecdsa-sha2-nistp256@openssh.com AAAA... user@yk"
    - comment: "Recovery key"
      key: "ssh-ed25519 AAAA... me@air"
```

The file is re-read on every refresh tick, so edits propagate without a
restart.

### Field reference

| Field | Type | Description |
|---|---|---|
| `title` | string | Display name shown in the UI heading. |
| `sources.github` | string[] | GitHub usernames; their `.keys` URL is fetched. |
| `sources.gitlab` | string[] | GitLab usernames; their `.keys` URL is fetched. |
| `sources.manual` | object[] | Inline keys, each with `key` and optional `comment`. |

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `8080` | HTTP listen port. |
| `HOST` | `0.0.0.0` | Bind address. |
| `BASE_URL` | `http://localhost:8080` | Public URL embedded in the install command shown in the UI. |
| `TITLE` | _(yaml `title:`)_ | UI heading; overrides yaml when set. |
| `KEYS_FILE` | `/config/keys.yaml` | Path to the YAML config inside the container. |
| `REFRESH_INTERVAL` | `3600` | Seconds between remote refreshes. `0` disables periodic refresh. |
| `THEME_COLOR` | `#00FF41` | Accent color (any CSS color value works). |
| `LOG_LEVEL` | `info` | `debug` / `info` / `warning` / `error`. |

## Precedence

Title resolution order:
1. `TITLE` environment variable
2. `title:` field in `keys.yaml`
3. Default literal `sshportal`
