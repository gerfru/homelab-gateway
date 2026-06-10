# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| latest `main` | Yes |

This project follows a rolling-release model. Only the latest commit on `main` is supported.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Report vulnerabilities privately via [GitHub's private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) (Security tab → Report a vulnerability).

**Include:**
- Description and potential impact
- Steps to reproduce
- Affected component(s) (Caddy, CoreDNS, Gitea, monitoring, etc.)

**Response time:** I aim to acknowledge reports within 7 days and publish a fix within 30 days for confirmed vulnerabilities.

## Security Design

Homelab Gateway is designed as a Tailscale-only infrastructure stack. Nothing is exposed to the public internet.

### Network Isolation

- All services bind exclusively to the Tailscale IP — nothing on `0.0.0.0`
- DNS (CoreDNS) resolves only on the Tailscale interface
- Every connection is wrapped in a WireGuard tunnel via Tailscale
- Loki API bound to `127.0.0.1:3100` only

### HTTPS & Headers

- Caddy terminates TLS with internal certificates on all subdomains
- Security headers on every response: HSTS, CSP, X-Frame-Options, X-Content-Type-Options

### Authentication

- Grafana: login required, default admin credentials via Docker Secrets
- Gitea: login required, registration disabled by default
- Prometheus & metrics endpoints: Caddy basicauth (bcrypt)
- Loki: tenant authentication via `X-Scope-OrgID`

### Container Hardening

- `security_opt: no-new-privileges` on all containers (except PostgreSQL and Gitea — accepted risk for su-exec/gosu user switching, documented in docker-compose.yml)
- `cap_drop: ALL` with minimal `cap_add` where required
- `read_only: true` where possible
- All images pinned by SHA256 digest
- Promtail uses read-only Docker Socket Proxy instead of direct socket mount

### Secrets Management

- Sensitive credentials stored as Docker Secrets (file-based, not in environment variables)
- Secret files gitignored, never committed
- `.env` contains only non-sensitive configuration and bcrypt hashes

### CI Pipeline

- YAML lint, ShellCheck, Hadolint
- Docker Compose validation
- TruffleHog secret scanning (pre-commit hook + CI)
- Trivy container vulnerability scanning
- Semgrep SAST
- Checkov IaC scanning
- Caddyfile syntax validation

### PII Redaction

- IP addresses and email addresses scrubbed in the Promtail pipeline before Loki ingestion

## Scope

**In scope:** authentication bypass, secret exposure, container escapes, network binding issues, configuration vulnerabilities.

**Out of scope:** denial-of-service on self-hosted instances, issues requiring Tailscale network access (by design all users on the tailnet are trusted), issues requiring physical access to the server.
