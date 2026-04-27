# Security

What SSHPortal protects against — and what it does not.

## Threat model

SSHPortal serves **public** keys only. The keys themselves are not secret.
The risks worth designing against are:

- **Key substitution.** A network attacker who can rewrite traffic between
  the portal and a target server can swap your keys for their own, granting
  themselves access. **Always serve over HTTPS.**
- **Cross-site fetch.** A malicious page in your browser could try to fetch
  `/keys` and exfiltrate it; the keys are public so the impact is limited,
  but SSHPortal still emits no permissive CORS headers.
- **Abuse.** A flood of requests could exhaust resources. SSHPortal applies
  a per-IP token bucket (60 req/min) by default.

## What SSHPortal does

- Read-only HTTP — no POST/PUT/DELETE endpoints exist.
- Validates every key in `keys.yaml` and every fetched line; malformed
  entries are dropped with a warning.
- Runs as a non-root `sshportal` user inside the container.
- Mounts the config file read-only by convention.
- Pins all Swift dependencies via `Package.resolved`.
- Escapes user-controlled fields (`title`, comments) before HTML rendering.

## What you must do

- **Put it behind TLS.** Use nginx, Caddy, Traefik, or any reverse proxy
  that terminates HTTPS. The default `BASE_URL` is `http://...`; change it.
- **Verify the source.** Anyone running your portal trusts that the install
  command they paste is yours. Pin the URL in your team docs.
- **Audit your `manual:` entries.** A key in `keys.yaml` becomes a permitted
  login on every server that runs the install command — treat it like a
  privileged credential.

## What SSHPortal does NOT do

- No removal/rotation. Once `curl ... >> authorized_keys` runs, removing
  a key requires editing `authorized_keys` on the target server.
- No agent on remote hosts. There is nothing watching servers; the
  authorization happens once at install time.
- No authentication. Every endpoint is public.
