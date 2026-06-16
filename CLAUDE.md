# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker Compose–based home media server stack running on a Synology NAS. All services are defined in a single `compose.yaml` and are exposed via Traefik reverse proxy with optional OAuth authentication.

Host-level NAS tooling that is **not** part of the compose stack (the relocated Node/Claude Code toolchain on `/volume1`, shared shell aliases, and the boot task that re-establishes them after DSM resets) lives in `host-setup/` — see `host-setup/README.md`.

## Common Commands

```bash
# Start all services
docker compose up -d

# Start a single service
docker compose up -d <service>

# Restart a service
docker compose restart <service>

# View logs for a service
docker compose logs -f <service>

# Pull latest images and recreate
docker compose pull && docker compose up -d

# Validate compose file syntax
docker compose config
```

## Architecture

### Networks
Two Docker bridge networks are used:
- **`mediaserver`** — all application containers communicate on this network
- **`socket-proxy`** — isolates Docker socket access; only Traefik, dockhand, and restart-qbittorrent connect here via `socket-proxy` container (port 2375), never directly to `/var/run/docker.sock`

### Reverse Proxy (Traefik v3)
- Listens on ports `89` (HTTP) and `449` (HTTPS), externally mapped
- Wildcard TLS cert obtained via Cloudflare DNS challenge (Let's Encrypt)
- Dynamic configuration loaded from `traefik/rules/*.yml` (watched for changes)
- Dashboard accessible at `traefik.$DOMAINNAME` (localhost:8080 for API)

### Authentication
- **`auth`** container: `traefik-forward-auth` (italypaleale fork v4) handles OAuth SSO; forwardAuth address `http://auth:4181/portals/main`
- Three middleware chains defined in `traefik/rules/middlewares-chains.yml`:
  - **`chain-auth@file`** — crowdsec@docker → basic-ratelimit → secure-headers → auth → compress (most services)
  - **`chain-noauth@file`** — crowdsec@docker → basic-ratelimit → secure-headers → compress (the auth container plus services with their own auth: plex, tautulli, seerr, qbittorrent)
  - **`chain-api@file`** — crowdsec@docker → api-ratelimit → compress (API bypass routes; no browser security headers)
- One header middleware set in `traefik/rules/middlewares.yml`: `secure-headers` (HSTS + `contentTypeNosniff` + `referrerPolicy` + `X-Robots-Tag`). No CSP is defined, and `frameDeny`/`X-Frame-Options` is deliberately omitted so Organizr's iframe tabs keep working.
- `auth`'s `authResponseHeaders` carries only identity headers the auth server returns (`X-Forwarded-User`, `X-Forwarded-Displayname`); **do not** add `X-Forwarded-For` here — forwardAuth strips any listed header the auth response omits, which would blank the real client IP seen by backends and CrowdSec.

### API Key Bypass Pattern
Several *arr services (Prowlarr, Sonarr, Radarr, SABnzbd, Tautulli) expose a second router (`<service>-bypass`) with higher priority (`100`) that matches API key headers (`X-Api-Key`) or query params (`apikey`), routing to `chain-api@file`. qBittorrent's bypass instead matches `PathPrefix(/api/v2)`. This allows external apps (e.g., NZB360) to authenticate via API key instead of OAuth.

### VPN (Gluetun)
- `gluetun` runs AirVPN via WireGuard
- `qbittorrent` uses `network_mode: "service:gluetun"` — all its traffic routes through the VPN tunnel
- qBittorrent's WebUI port (9997) is exposed via gluetun's network namespace; Traefik routes to the gluetun container
- `restart-qbittorrent` monitors gluetun health and restarts qBittorrent if the VPN drops

### Environment Variables
All services rely on variables set in an `.env` file (not in this repo). Key variables:
- `$APPDIR` — base path for per-app config volumes (e.g., `$APPDIR/radarr`)
- `$DATADIR` — shared media/download data path; mounted as `/data` in *arr apps and follows the [unified `/data` layout](https://trash-guides.info/hardlinks/)
- `$DOCKERDIR` — path for shared files like TLS certs
- `$DOMAINNAME` — base domain for all subdomains
- `$PUID` / `$PGID` — UID/GID for file permission consistency
- `$TZ` — timezone
- `$CF_EMAIL`, `$CF_API_KEY` — Cloudflare credentials for DNS challenge
- `$WIREGUARD_*` — WireGuard keys/addresses for AirVPN
- `$TRUSTED_IPS` — comma-separated IPs/CIDRs Traefik trusts for forwarded headers (e.g., Cloudflare ranges)
- `$DISCORD`, `$PULLIO` — webhook URLs for Pullio update notifications
- `$*_API_KEY` — per-service API keys used in bypass router rules

### Static Routing (traefik/rules/)
- `middlewares.yml` — defines individual middlewares (`basic-ratelimit`, `api-ratelimit`, `secure-headers`, `auth`, `compress`)
- `middlewares-chains.yml` — defines the three chain middlewares (`chain-auth`, `chain-noauth`, `chain-api`)
- `tls.yml` — TLS options (`minVersion: VersionTLS12`)
- `transports.yml` — serversTransport with `insecureSkipVerify` for self-signed upstreams
- `synology.yml` — proxies Synology DSM (HTTPS, self-signed cert bypass via `insecureTransport`)
- `asus.yml` — proxies Asus router admin UI (same pattern)

### Update Automation
All containers include `org.hotio.pullio.*` labels for automated image update checking and Discord/webhook notifications via [Pullio](https://hotio.dev/pullio/).

## Service Map

| Service | Purpose | Internal Port |
|---|---|---|
| traefik | Reverse proxy | 80/443 |
| socket-proxy | Docker socket proxy | 2375 |
| auth | OAuth forward auth | 4181 |
| gluetun | WireGuard VPN | 8000 (control) |
| organizr | Dashboard (root domain) | 80 |
| prowlarr | Indexer aggregator | 9696 |
| sabnzbd | Usenet downloader | 8080 |
| qbittorrent | Torrent client (via VPN) | 9997 |
| restart-qbittorrent | Watchdog: restarts qBittorrent on VPN drop | — |
| qbitmanage | qBittorrent management | 9996 |
| autobrr | Torrent RSS automation | 7474 |
| radarr | Movie management | 7878 |
| sonarr | TV management | 8989 |
| plex | Media player | 32400 |
| tdarr | Video transcoding | 8265 |
| tautulli | Plex monitoring | 8181 |
| seerr (overseerr) | Media request portal | 5055 |
| maintainerr | Stale media cleanup | 6246 |
| books (calibre-web) | Book library | 8083 |
| dockhand | Container management UI | 3000 |
| notifiarr | *arr profile notifications | 5454 |
| vaultwarden | Password manager | 80 |
