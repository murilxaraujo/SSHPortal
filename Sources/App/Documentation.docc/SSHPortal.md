# ``App``

Self-hosted SSH public key distribution portal.

@Metadata {
    @DisplayName("SSHPortal")
}

## Overview

SSHPortal is a small Swift HTTP server that publishes your SSH public keys
behind a single URL. It renders a terminal-themed web UI for humans and
serves a plain-text endpoint for `curl >> ~/.ssh/authorized_keys`. It is
inspired by [SSH.id](https://sshid.io) but is fully self-hosted and
open-source.

The portal merges keys from three kinds of sources:

- A YAML config file (`keys.yaml`) you mount into the container.
- One or more GitHub usernames — `https://github.com/{user}.keys`.
- One or more GitLab usernames — `https://gitlab.com/{user}.keys`.

Duplicates across sources are removed by SHA-256 fingerprint, with manual
keys taking priority over GitHub, and GitHub over GitLab.

![SSHPortal terminal-themed web UI](screenshot)

## Topics

### Getting started

- <doc:GettingStarted>
- <doc:Configuration>

### Operations

- <doc:Deployment>
- <doc:Security>

### Design

- <doc:Architecture>
- ``Config``
- ``KeysFile``
- ``SSHKey``
- ``SSHKeyType``
- ``KeySource``

### Services

- ``KeyStore``
- ``KeyLoader``
- ``KeyFetcher``
- ``RemoteKeyFetcher``
- ``RefreshService``
- ``TokenBucketRateLimiter``
- ``RateLimitMiddleware``

### HTTP

- ``KeyRoutes``
- ``WebRoutes``
- ``ServerBuilder``
- ``HealthResponse``
