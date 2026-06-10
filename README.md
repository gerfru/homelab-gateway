<div align="center">

# Homelab Gateway

**Your infrastructure. Your network. One `make up`.**

A self-hosted reverse proxy, DNS, Git hosting, and full observability stack for Tailscale homelabs —
CoreDNS, Caddy, Gitea, Grafana, Prometheus, Loki, Tempo, and Uptime Kuma in a single Docker Compose.

![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker&logoColor=white)
![Caddy](https://img.shields.io/badge/Caddy-Reverse%20Proxy-22B638?style=flat-square&logo=caddy&logoColor=white)
![Tailscale](https://img.shields.io/badge/Tailscale-WireGuard-4C8BF5?style=flat-square&logo=tailscale&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-F46800?style=flat-square&logo=grafana&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C?style=flat-square&logo=prometheus&logoColor=white)
![Self-hosted](https://img.shields.io/badge/Self--hosted-Privacy--first-10B981?style=flat-square)

[Quickstart](#quickstart) · [Architecture](#architecture) · [Commands](#commands) · [Security](#security)

</div>

---

> *Every self-hosted app needs DNS, HTTPS, logging, metrics, and uptime checks.*
> *That's five problems to solve before your first line of application code runs.*

**Homelab Gateway solves all five at once.**

One `make up`, and every `*.home.lab` subdomain routes through Caddy with auto-TLS,
centralized logs flow into Loki, Prometheus scrapes metrics, Tempo collects traces,
Uptime Kuma watches it all, and Gitea hosts your Git repos — accessible only from
your Tailscale network.

> **Tailscale-only by design.** Nothing binds to `0.0.0.0`. DNS resolves exclusively
> on your Tailscale IP, Caddy listens only on your Tailscale interface, and every
> connection is wrapped in a WireGuard tunnel.

---

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

---

## Prerequisites

| Requirement | Purpose | Install |
|-------------|---------|---------|
| Docker + Docker Compose v2 | Container runtime | [docs.docker.com](https://docs.docker.com/engine/install/) |
| Tailscale | WireGuard mesh VPN | [tailscale.com/download](https://tailscale.com/download) |
| `envsubst` | Template variable substitution | `apt install gettext-base` (Linux) / pre-installed (macOS) |
| `dig` | DNS resolution tests | `apt install dnsutils` (Linux) / pre-installed (macOS) |
| `jq` | JSON parsing in smoke tests | `apt install jq` (Linux) / `brew install jq` (macOS) |
| `coredns` | Local DNS server (macOS only) | `brew install coredns` (auto-installed by `make dns-up`) |

---

## Quickstart

### 1. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:
```bash
TAILSCALE_IP=100.x.x.x                        # tailscale ip -4
DOMAIN=home.lab
UPTIME_KUMA_USERNAME=admin
UPTIME_KUMA_PASSWORD=<strong-password>

# Recommended: basicauth for prometheus.home.lab and metrics.home.lab
# Generate hash: docker run --rm caddy:2-alpine caddy hash-password --plaintext 'yourpassword'
# IMPORTANT: Wrap hash in single quotes (bcrypt $ signs break Docker Compose interpolation)
CADDY_AUTH_USER=admin
CADDY_AUTH_PASS_HASH='$2a$14$...'
```

Create Docker Secrets:
```bash
mkdir -p secrets

# Grafana
echo -n "admin" > secrets/gf_admin_user
echo -n "<strong-password>" > secrets/gf_admin_password

# Gitea
echo -n "<db-password>" > secrets/gitea_db_password
echo -n "<admin-password>" > secrets/gitea_admin_password
```

### 2. Generate config + start

```bash
make generate
make up
```

### 3. Configure Tailscale Split DNS (once)

> **Note:** Split DNS configuration requires **admin access** to the Tailscale admin console.

1. Open https://login.tailscale.com/admin/dns
2. Under **Nameservers** -> "Add nameserver" -> "Custom"
3. Enter your Tailscale IP (e.g. `100.x.x.x`)
4. Check **"Restrict to search domain"**
5. Enter your domain: `home.lab`
6. Save

### 4. Verify

```bash
make test-dns
```

From any device on your Tailnet:
```bash
curl -k https://niles.home.lab
curl -k https://status.home.lab
```

> Full env var reference: **[.env.example](.env.example)**

---

## Architecture

```
homelab-gateway
├── CoreDNS ──────────── *.home.lab -> Tailscale IP (port 53)
├── Caddy ────────────── HTTPS reverse proxy (port 443)
│                         ├── niles.home.lab      -> niles_core:8000
│                         ├── garmin.home.lab     -> pulsebase-api:8000
│                         ├── vikunja.home.lab    -> vikunja:3456
│                         ├── whatsapp.home.lab   -> evolution_api:8080
│                         ├── gitea.home.lab      -> gitea:3000
│                         ├── status.home.lab     -> gateway-uptime:3001
│                         ├── logs.home.lab       -> gateway-grafana:3000
│                         ├── prometheus.home.lab -> prometheus:9090     (basicauth)
│                         └── metrics.home.lab    -> localhost:9180      (basicauth)
├── Gitea ────────────── Git hosting (PostgreSQL backend, push-mirror to GitHub)
├── PostgreSQL ───────── Gitea database (gitea-db)
├── Loki ─────────────── Log aggregation (port 3100, localhost only)
├── Promtail ─────────── Log collection via Docker labels
├── Grafana ──────────── Dashboards + Unified Alerting
├── Prometheus ───────── Time-series metrics (8 scrape targets, 30d retention)
├── Tempo ────────────── Distributed tracing (OTLP gRPC + HTTP)
├── node-exporter ────── System metrics (CPU, RAM, disk, network)
├── Uptime Kuma ──────── Service health monitoring (auto-provisioned)
├── Watchtower ───────── Container update monitoring (daily 4 AM, notify-only)
└── Docker Socket Proxy  Read-only Docker API for Promtail

Tools (on-demand via 'docker compose --profile tools'):
└── Renovate ─────────── Automated dependency updates for Gitea repos

External apps (connect via 'proxy' network):
├── Niles         (niles_core, evolution_api, vikunja)
└── PulseBase     (pulsebase-api, sync-service, ml-service, TimescaleDB)
```

### Platform notes

| | macOS | Linux |
|---|---|---|
| **CoreDNS** | Native via `brew install coredns` | Docker container (`network_mode: host`) |
| **Caddy** | Docker | Docker |
| **Why?** | Docker Desktop can't bind Tailscale's utun0 interface | Host networking works natively |

`make up` auto-detects the OS and handles this transparently.

### Networks

| Network | Purpose | Used by |
|---------|---------|---------|
| `proxy` | Reverse proxy access to app containers | Caddy, Gitea, Grafana, Uptime Kuma, app services |
| `monitoring` | Internal observability communication | Loki, Promtail, Prometheus, Grafana, Tempo, Uptime Kuma, Gitea, PostgreSQL, Renovate |

---

## What's inside

### DNS + Reverse Proxy

- **CoreDNS** wildcard DNS — `*.home.lab` resolves to your Tailscale IP, no per-service config
- **Caddy** HTTPS termination — internal TLS certificates, security headers on every response
- Add a new service: one Caddyfile block + `docker compose restart caddy` (DNS wildcard already covers it)

### Git Hosting

- **Gitea** lightweight Git server with PostgreSQL backend — self-hosted GitHub alternative
- **Renovate Bot** automated dependency updates — runs on-demand via `docker compose --profile tools run --rm renovate`
- **GitHub mirroring** — `scripts/gitea-mirror.sh` auto-configures Gitea push mirrors to GitHub for all repos (daily offsite backup)
- Volume separation: `gitea-data` (app), `gitea-repos` (source code), `gitea-db-data` (PostgreSQL)

### Observability

- **Grafana** dashboards with Loki, Prometheus, and Tempo pre-configured as datasources
- **Prometheus** scrapes 8 targets (node-exporter, Caddy, Loki, Grafana, Promtail, Tempo, Gitea, self) every 30s
- **Loki + Promtail** centralized logging — auto-discovers containers with `monitoring=true` label via Docker Socket Proxy
- **Tempo** distributed tracing — receives OTLP on gRPC (4317) and HTTP (4318), container-internal only. To send traces from your app, add it to the `monitoring` network and configure:

  ```yaml
  environment:
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://gateway-tempo:4317
  networks:
    - monitoring
  ```

- **PII redaction** — IP addresses and email addresses scrubbed before Loki ingestion

### Alerting + Monitoring

- **Grafana Unified Alerting** — 8 rules (HighCPU, HighMemory, DiskAlmostFull, TargetDown, HighErrorRate, AuthFailures, HighP95Latency, ContainerRestartLoop) with webhook notifications
- **Uptime Kuma** — auto-provisioned monitors from Caddyfile subdomains via `./scripts/setup-uptime-monitors.sh`
- **Watchtower** — daily container update checks at 4 AM (monitor-only, notifies but does not auto-apply)

---

## Adding a service

1. Ensure your app's `docker-compose.yml` joins the `proxy` network:
   ```yaml
   services:
     myapp:
       networks:
         - internal
         - proxy

   networks:
     internal:
       driver: bridge
     proxy:
       external: true
   ```

2. Add a vhost block to `Caddyfile.tmpl`:
   ```caddyfile
   myapp.${DOMAIN} {
       tls internal
       import security_headers
       import common_log
       reverse_proxy myapp-container:8000
   }
   ```

3. Regenerate and restart:
   ```bash
   make generate
   docker compose restart caddy
   ```

The DNS wildcard already resolves `myapp.home.lab` — no DNS changes needed.

---

## Commands

| Command | Description |
|---------|-------------|
| `make up` | Start gateway (CoreDNS + Caddy + monitoring, OS-aware) |
| `make down` | Stop all services |
| `make generate` | Generate DNS + Caddy config from templates |
| `make dry-run` | Preview what `make up` would do (no deployment) |
| `make test-dns` | Test DNS resolution |
| `make test` | Run offline generation tests |
| `make test-smoke` | Run stack smoke tests (requires running stack) |
| `make logs` | Live logs (all services) |
| `make logs-caddy` | Live Caddy logs |
| `make logs-dns` | Live CoreDNS logs |
| `make status` | Container + DNS status |
| `make dns-status` | Check if CoreDNS is running |
| `make check-env` | Verify no default passwords in .env |
| `make test-update-golden` | Regenerate golden test files |
| `make backup` | Backup all Docker volumes to `backups/` |
| `make restore BACKUP=<file>` | Restore Docker volumes from backup |
| `make clean` | Stop + remove volumes + generated files |
| `./scripts/setup-uptime-monitors.sh` | Provision Uptime Kuma monitors from Caddyfile.tmpl |
| `docker compose --profile tools run --rm renovate` | Run Renovate Bot (dependency updates for all Gitea repos) |
| `./scripts/gitea-mirror.sh` | Configure GitHub push mirrors for all Gitea repos |

---

## Security

- **Network isolation** — all traffic encrypted via Tailscale WireGuard tunnel; Caddy and CoreDNS bind exclusively to Tailscale IP
- **HTTPS everywhere** — internal TLS certificates, security headers on all responses (HSTS, CSP, X-Frame-Options)
- **Authentication** — Grafana login required, Gitea login required (registration disabled by default), Caddy basicauth on Prometheus/metrics subdomains, Loki tenant auth (`X-Scope-OrgID`)
- **Container hardening** — `no-new-privileges`, `cap_drop: ALL`, `read_only` where possible, all images pinned by SHA256 digest. Exception: PostgreSQL and Gitea require `no-new-privileges` disabled (su-exec/gosu needs setuid for user switching) — documented as accepted risk in docker-compose.yml
- **Least privilege** — Promtail uses read-only Docker Socket Proxy instead of direct socket mount; Loki only on `127.0.0.1:3100`
- **PII redaction** — IP addresses and email addresses scrubbed in log pipeline before Loki ingestion
- **CI pipeline** — YAML lint, ShellCheck, Docker Compose validate, Caddyfile validate, TruffleHog secret scan, Trivy container scan, Semgrep SAST, Checkov IaC scan (9 checks)

---

## Rollback

```bash
# Revert last change
git log --oneline -5
git revert <commit-hash>
make generate && make up

# Roll back a single service (change image tag/digest in docker-compose.yml)
docker compose up -d <service-name>

# Full stack reset
make down
git checkout <known-good-commit>
make generate && make up
```

---

## Upgrade

```bash
git pull
make generate
make up
```

Docker Compose recreates only containers whose images or config changed. For a safer upgrade:

```bash
make backup
git pull
make generate && make up
make test-dns && make test-smoke
```

---

## Stack

CoreDNS · Caddy · Gitea · PostgreSQL · Grafana · Prometheus · Loki · Promtail · Tempo ·
node-exporter · Uptime Kuma · Watchtower · Docker Socket Proxy (+Renovate on-demand)

Thirteen containers — one for DNS, one for HTTPS, two for Git hosting, nine for
observability and operations — behind a Tailscale WireGuard mesh.

---

<div align="center">
<sub>Built for people who run their own infrastructure.</sub>
</div>
