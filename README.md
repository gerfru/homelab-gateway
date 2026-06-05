# Homelab Gateway

**Centralized infrastructure for self-hosted apps over Tailscale — DNS, reverse proxy, monitoring, logging.**

CoreDNS provides wildcard DNS (`*.home.lab` -> your Tailscale IP), Caddy handles HTTPS termination and reverse proxying. Loki + Promtail collect logs from all projects, Uptime Kuma monitors service health. All services reachable on port 443 via subdomain.

## How it works

```
Browser: https://niles.home.lab
         |
         | 1. DNS query: niles.home.lab?
         |    -> Tailscale Split DNS forwards to CoreDNS
         |    -> CoreDNS: *.home.lab = 100.x.x.x (your Tailscale IP)
         |
         | 2. HTTPS connection to 100.x.x.x:443
         |    -> Caddy matches Host header
         |    -> reverse_proxy niles_core:8000
         |
         v
      Your app
```

## Requirements

- Docker + Docker Compose
- Tailscale installed on the server
- `envsubst` (part of `gettext` — pre-installed on macOS)
- `dig` for DNS testing (optional)

### Platform notes

| | macOS | Linux |
|---|---|---|
| **CoreDNS** | Native via `brew install coredns` | Docker container (`network_mode: host`) |
| **Caddy** | Docker | Docker |
| **Why?** | Docker Desktop can't bind Tailscale's utun0 interface | Host networking works natively |

`make up` auto-detects the OS and handles this transparently.

## Setup

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:
```bash
TAILSCALE_IP=100.85.159.70   # tailscale ip -4
DOMAIN=home.lab
```

### 2. Generate DNS config

```bash
make generate
```

### 3. Start the gateway

```bash
make up
```

### 4. Configure Tailscale Split DNS (once)

1. Open https://login.tailscale.com/admin/dns
2. Under **Nameservers** -> "Add nameserver" -> "Custom"
3. Enter your Tailscale IP (e.g. `100.85.159.70`)
4. Check **"Restrict to search domain"**
5. Enter your domain: `home.lab`
6. Save

### 5. Verify

```bash
make test-dns
```

From any device on your Tailnet:
```bash
curl -k https://niles.home.lab
curl -k https://garmin.home.lab/health
```

## Adding a service

1. Ensure your app's `docker-compose.yml` joins the `proxy` network:
   ```yaml
   services:
     myapp:
       # ...
       networks:
         - internal
         - proxy

   networks:
     internal:
       driver: bridge
     proxy:
       external: true
   ```

2. Add a vhost block to `Caddyfile`:
   ```caddyfile
   myapp.home.lab {
       tls internal
       import security_headers
       log {
           output stdout
           format json
           level INFO
       }
       reverse_proxy myapp-container:8000
   }
   ```

3. Restart Caddy:
   ```bash
   docker compose restart caddy
   ```

The DNS wildcard already resolves `myapp.home.lab` to your server — no DNS changes needed.

## Commands

| Command | Description |
|---------|-------------|
| `make up` | Start gateway (CoreDNS + Caddy, OS-aware) |
| `make down` | Stop gateway |
| `make generate` | Generate DNS config from templates |
| `make test-dns` | Test DNS resolution |
| `make logs` | Live logs (all services) |
| `make logs-caddy` | Live Caddy logs |
| `make logs-dns` | Live CoreDNS logs |
| `make dns-status` | Check if CoreDNS is running |
| `make status` | Container + DNS status |
| `make clean` | Stop + remove volumes + generated files |

## Architecture

```
homelab-gateway (this repo)
├── CoreDNS ──── *.home.lab -> Tailscale IP (port 53)
├── Caddy ────── SNI routing on port 443
│                 ├── niles.home.lab    -> niles_core:8000
│                 ├── garmin.home.lab   -> pulsebase-api:8000
│                 ├── vikunja.home.lab  -> vikunja:3456
│                 ├── whatsapp.home.lab -> evolution_api:8080
│                 ├── status.home.lab   -> gateway-uptime:3001
│                 └── logs.home.lab     -> gateway-grafana:3000
├── Loki ─────── Centralized log aggregation (port 3100, localhost only)
├── Grafana ──── Dashboards for logs and system metrics (via Caddy)
├── Promtail ─── Log collection via Docker labels (monitoring=true)
├── Prometheus ─ Time-series metrics storage (30d retention, 500MB cap)
├── node_exporter System metrics collector (CPU, RAM, disk, network)
└── Uptime Kuma  Service health monitoring

Other repos (connect via external 'proxy' network):
├── Niles         (niles_core, evolution_api, vikunja)
└── PulseBase     (pulsebase-api, sync-service, ml-service, TimescaleDB)
```

### Networks

| Network      | Purpose                                | Used by                                              |
|--------------|----------------------------------------|------------------------------------------------------|
| `proxy`      | Reverse proxy access to app containers | Caddy, Grafana, Uptime Kuma, app services            |
| `monitoring` | Internal monitoring communication      | Loki, Promtail, Prometheus, Grafana, Uptime Kuma     |

### Monitoring

Promtail auto-discovers containers with the `monitoring=true` Docker label. To include a container in centralized logging, add:

```yaml
labels:
  - "monitoring=true"
```

Logs are tagged with a `project` label (from `com.docker.compose.project`) so you can filter by project in Loki queries. Browse logs at `https://logs.home.lab` (Grafana with Loki pre-configured as datasource).

## Security

- All traffic encrypted via Tailscale WireGuard tunnel
- HTTPS with self-signed certificates (accept browser warning once per subdomain)
- Security headers on all responses (HSTS, CSP, X-Frame-Options, etc.)
- DNS only accessible from within Tailnet (CoreDNS binds to Tailscale IP on macOS, host network on Linux)
- Caddy binds exclusively to Tailscale IP (not `0.0.0.0`)
- Loki only accessible from localhost (`127.0.0.1:3100`)
- Promtail mounts Docker socket read-only for container log discovery

## Upgrading to real TLS certificates

Replace `tls internal` with the [caddy-tailscale plugin](https://github.com/tailscale/caddy-tailscale) for automatic Let's Encrypt certificates via Tailscale. Requires a custom Caddy build with the plugin and a Tailscale auth key.
