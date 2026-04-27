# Getting Started

Run SSHPortal locally in under a minute.

## Overview

The fastest way to try SSHPortal is with the prebuilt container image and a
small `keys.yaml`.

## With Apple `container` (macOS)

```bash
container system start

cat > keys.yaml <<'YAML'
title: yourhandle
sources:
  github:
    - your-github-username
YAML

container run -d --name sshportal \
  -p 8080:8080 \
  -v "$PWD/keys.yaml:/config/keys.yaml:ro" \
  -e BASE_URL=http://localhost:8080 \
  ghcr.io/murilxaraujo/sshportal:latest
```

Open <http://localhost:8080>.

## With Docker

```bash
docker run -d --name sshportal \
  -p 8080:8080 \
  -v "$PWD/keys.yaml:/config/keys.yaml:ro" \
  -e BASE_URL=http://localhost:8080 \
  ghcr.io/murilxaraujo/sshportal:latest
```

## From source

```bash
git clone https://github.com/murilxaraujo/sshportal.git
cd sshportal
swift run App
```

By default it loads `/config/keys.yaml`. Point it elsewhere with
`KEYS_FILE`:

```bash
KEYS_FILE=config/keys.example.yaml swift run App
```

## Adding keys to a server

On any host you want to authorize:

```bash
curl -fs https://your-portal.example.com/keys >> ~/.ssh/authorized_keys
```

For idempotent appending (skip already-authorized keys), use
[`scripts/install.sh`](https://github.com/murilxaraujo/sshportal/blob/main/scripts/install.sh):

```bash
PORTAL=https://your-portal.example.com bash <(curl -fsSL https://your-portal.example.com/install.sh)
```
