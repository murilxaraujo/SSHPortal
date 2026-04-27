# Architecture

How the pieces fit together.

## Overview

```
┌──────────┐   GET /, /keys, /keys/:type, /health
│  Client  │ ─────────────────────────────────────┐
└──────────┘                                      ▼
                                       ┌──────────────────────┐
                                       │  RateLimitMiddleware │  60 req/min/IP
                                       └──────────┬───────────┘
                                                  ▼
                                 ┌──────────────────────────────┐
                                 │  Router (Hummingbird 2.x)    │
                                 └──┬────────────┬──────────────┘
                                    ▼            ▼
                           ┌──────────────┐  ┌────────────┐
                           │  WebRoutes   │  │ KeyRoutes  │
                           │  IndexView   │  │ plain text │
                           └──────┬───────┘  └─────┬──────┘
                                  └────────┬───────┘
                                           ▼
                                    ┌─────────────┐
                                    │  KeyStore   │  (actor)
                                    └──────┬──────┘
                                           ▲
                                           │ replaceAll(...)
                                ┌──────────┴────────────┐
                                │     RefreshService    │  every REFRESH_INTERVAL
                                └──────────┬────────────┘
                                           ▼
                                    ┌─────────────┐
                                    │  KeyLoader  │
                                    └──┬────────┬─┘
                                       ▼        ▼
                           ┌────────────┐  ┌───────────────────┐
                           │ keys.yaml  │  │ RemoteKeyFetcher  │
                           │  (manual)  │  │  github / gitlab  │
                           └────────────┘  └───────────────────┘
```

## Key responsibilities

- ``ServerBuilder`` — pure factory. Wires Router, middlewares, services.
- ``KeyStore`` — the only mutable state. Swift `actor` with one writer
  (``RefreshService``) and many readers (HTTP handlers).
- ``RefreshService`` — runs an initial load on startup, then re-fetches
  every `REFRESH_INTERVAL` seconds. Cancels cleanly on graceful shutdown
  via `withGracefulShutdownHandler`.
- ``KeyLoader`` — combines `KeysFile` (manual keys) with two
  ``KeyFetcher`` instances (GitHub, GitLab). Failure of any one source is
  logged and ignored; the others still load.
- ``RemoteKeyFetcher`` — small wrapper around AsyncHTTPClient hitting
  `https://github.com/{user}.keys` or `https://gitlab.com/{user}.keys`.
- ``SSHKey`` — value type with type-prefix detection and a
  base64-decoded SHA-256 fingerprint used for deduplication.

## Concurrency

- One `actor` (``KeyStore``) — no shared mutable state outside it.
- HTTP handlers are `Sendable` closures.
- The refresh loop and the HTTP server run as siblings under
  `ServiceGroup`, so SIGINT/SIGTERM cancels both atomically.

## Why these choices

- **Hummingbird 2.x** for HTTP — small surface area, `Sendable`-clean,
  Swift-native concurrency.
- **AsyncHTTPClient** — single shared `EventLoopGroup`, async/await API.
- **Yams** — battle-tested YAML parser.
- **swift-crypto** — `SHA256.hash(data:)` is one line, portable on macOS
  and Linux.
- **Apple `container` framework** — first-class macOS dev loop without a
  Docker daemon. The same Dockerfile works on Linux CI.
