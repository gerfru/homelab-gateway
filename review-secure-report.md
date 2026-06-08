# Security Code Review Report — homelab-gateway

**Language:** Bash, YAML, JSON (Infrastructure-as-Code)
**Framework:** Docker Compose, Caddy, CoreDNS, Grafana Stack
**Date:** 2026-06-08
**Reviewer:** Claude Opus 4.6 (ISEC methodology)
**Scope:** Security · Code Quality · Compliance (GDPR, ISO 27001, EU AI Act)

---

## Overall Assessment

**🟡 YELLOW** — Strong security fundamentals (digest-pinned images, network segmentation, `no-new-privileges` on all containers, pre-commit secret scanning, proper `.env` handling) with significant gaps in container privilege isolation (Docker socket exposure, full host filesystem mount) and missing CI security gates (Trivy, Semgrep, GitHub-native secret scanning).

---

## Findings

### 🔴 Critical (2)

---

### [CRITICAL] C-01: Docker Socket Exposed to Promtail Container
**Category:** Security
**Location:** [docker-compose.yml:86](docker-compose.yml#L86)
**CWE:** CWE-250 (Execution with Unnecessary Privileges)

**What:** Promtail is granted access to `/var/run/docker.sock`, which provides full Docker API access and effectively root-equivalent control over the host despite the `:ro` flag.

**Why it matters:** The Docker socket is the Docker daemon's control plane. Any process with socket access can create privileged containers, mount the host filesystem, and achieve full host compromise. The `:ro` mount flag prevents writing to the socket *file inode* but does **not** prevent sending API requests (POST, DELETE) through the socket. An attacker who compromises Promtail (e.g., via a vulnerability in the log ingestion pipeline) gains full root-equivalent access to the host. This is a well-known container escape vector documented in the CIS Docker Benchmark (5.31).

**Fix:**
1. **Preferred:** Replace Docker socket access with file-based log scraping. The container log directory is already mounted at line 85 (`/var/lib/docker/containers`). Remove the socket mount and switch Promtail from `docker_sd_configs` to file-based `static_configs` targeting the container log paths.
2. **Alternative:** Use a Docker socket proxy ([Tecnativa/docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy)) that exposes only safe read-only endpoints (containers list, container inspect) and blocks dangerous operations (create, exec, volumes):

```yaml
docker-socket-proxy:
  image: tecnativa/docker-socket-proxy:latest
  environment:
    CONTAINERS: 1
    POST: 0
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks:
    - monitoring

promtail:
  # Remove: /var/run/docker.sock:/var/run/docker.sock:ro
  # Point docker_sd_configs host to docker-socket-proxy:2375
```

**Learn more:** CIS Docker Benchmark 5.31, OWASP Docker Security Cheat Sheet

---

### [CRITICAL] C-02: Node-Exporter Mounts Entire Host Filesystem
**Category:** Security
**Location:** [docker-compose.yml:151](docker-compose.yml#L151)
**CWE:** CWE-732 (Incorrect Permission Assignment for Critical Resource)

**What:** Node-exporter mounts the entire host root filesystem (`/:/host:ro`), exposing all host files (including `/etc/shadow`, SSH keys, and the `.env` file containing credentials) to the container.

**Why it matters:** While the mount is read-only and node-exporter normally only reads `/proc` and `/sys` metrics, any vulnerability in node-exporter (or a container escape) would allow reading all secrets on the host. Combined with `pid: host` (line 145), the container has full visibility into host processes and their environments, potentially leaking secrets passed as environment variables to other processes.

**Fix:** Mount only the specific paths node-exporter needs:
```yaml
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/host/rootfs:ro  # Only if filesystem metrics needed
command:
  - "--path.procfs=/host/proc"
  - "--path.sysfs=/host/sys"
  - "--path.rootfs=/host/rootfs"
  - "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+)($$|/)"
```

**Learn more:** CIS Docker Benchmark 5.5, MIT 6.566 — Container Security

---

### 🟠 High (4)

---

### [HIGH] H-01: CoreDNS Linux Template Missing bind Directive — Listens on All Interfaces
**Category:** Security
**Location:** [dns/Corefile.tmpl](dns/Corefile.tmpl), line 1
**CWE:** CWE-668 (Exposure of Resource to Wrong Sphere)

**What:** The Linux `Corefile.tmpl` does not include a `bind` directive. With `network_mode: host`, CoreDNS listens on all interfaces (0.0.0.0:53), not just the Tailscale IP. The macOS template correctly uses `bind ${TAILSCALE_IP}`.

**Why it matters:** This exposes the DNS service to all network interfaces on the host. An attacker on the local network or the internet (if the host has a public IP) could query the DNS server, enumerate internal service names (`niles.home.lab`, `garmin.home.lab`, etc.), and use DNS as a reconnaissance tool.

**Fix:** Add `bind` directive to `dns/Corefile.tmpl`:
```
${DOMAIN}:53 {
    bind ${TAILSCALE_IP}
    file /etc/coredns/home.lab.zone
    log
    errors
}
```

**Learn more:** Stanford CS355 — Network Security, CIS Benchmark

---

### [HIGH] H-02: Weak Default Credentials in .env.example
**Category:** Security
**Location:** [.env.example:9-14](.env.example#L9)
**CWE:** CWE-1393 (Use of Default Credentials)

**What:** The `.env.example` ships with `admin/changeme` as default credentials for both Grafana and Uptime Kuma. Operators may deploy without changing these values.

**Why it matters:** Default credentials are the most common initial access vector (OWASP A07:2021). Even in a Tailscale-protected network, if any device on the tailnet is compromised, these credentials provide immediate access to monitoring data.

**Fix:**
1. Change to clearly non-functional placeholders: `CHANGE_ME_BEFORE_DEPLOY`
2. Add startup validation in Makefile `up` target:
```makefile
up: generate dns-up
	@if [ "$(GF_ADMIN_PASSWORD)" = "changeme" ] || [ "$(GF_ADMIN_PASSWORD)" = "CHANGE_ME_BEFORE_DEPLOY" ]; then \
		echo "ERROR: Change GF_ADMIN_PASSWORD in .env before deploying"; exit 1; fi
```

**Learn more:** OWASP Top 10 A07:2021, Stanford CS255 — Authentication

---

### [HIGH] H-03: Makefile `include .env` + `export` Leaks Secrets to All Child Processes
**Category:** Security / Quality
**Location:** [Makefile:3-4](Makefile#L3)
**CWE:** CWE-526 (Exposure of Sensitive Information Through Environmental Variables)

**What:** The Makefile uses `include .env` and `export`, loading all `.env` variables into every Make recipe's shell environment, including all child processes.

**Why it matters:** Every `docker`, `dig`, `brew`, `envsubst`, and shell command invoked by Make inherits all secrets (GF_ADMIN_PASSWORD, UPTIME_KUMA_PASSWORD). If any process logs its environment, crashes and generates a core dump, or has a command injection vulnerability, the secrets are exposed.

**Fix:** Remove blanket `export` and pass variables explicitly:
```makefile
include .env
# Only export what docker-compose needs:
up: generate dns-up
	TAILSCALE_IP=$(TAILSCALE_IP) docker compose --env-file .env up -d
```

**Learn more:** OWASP Secrets Management Cheat Sheet, MIT 6.566

---

### [HIGH] H-04: Promtail Log Pipeline May Ingest and Store PII Without Scrubbing
**Category:** Compliance (GDPR)
**Location:** [monitoring/promtail-config.yml:31-41](monitoring/promtail-config.yml#L31)
**CWE:** CWE-532 (Insertion of Sensitive Information into Log File)

**What:** Promtail's pipeline stages extract JSON fields but do not filter or redact sensitive data. All log content from monitored containers flows to Loki without PII scrubbing.

**Why it matters:** Under GDPR Art. 25 (Data Protection by Design), personal data must be minimized. Application logs frequently contain IP addresses, user identifiers, email addresses, or request bodies with personal data. Without a redaction pipeline stage, PII is stored in Loki for 7 days.

**Fix:** Add pipeline stages for PII redaction:
```yaml
pipeline_stages:
  - json:
      expressions:
        level: level
        event: event
  - replace:
      expression: '(\d{1,3}\.){3}\d{1,3}'
      replace: '[IP_REDACTED]'
  - replace:
      expression: '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
      replace: '[EMAIL_REDACTED]'
```

**Learn more:** GDPR Art. 25 (Data Protection by Design), Art. 32 (Security of Processing)

---

### 🟡 Medium (7)

---

### [MEDIUM] M-01: Uptime Kuma Missing cap_drop and User Isolation
**Category:** Security
**Location:** [docker-compose.yml:199-226](docker-compose.yml#L199)
**CWE:** CWE-250 (Execution with Unnecessary Privileges)

**What:** Uptime Kuma has `no-new-privileges` but is missing `cap_drop: ALL` and runs as root.

**Why it matters:** Running as root increases the impact of container escape vulnerabilities. Without `cap_drop: ALL`, the container retains default Linux capabilities (CAP_NET_RAW, CAP_CHOWN, CAP_SETUID).

**Fix:**
```yaml
uptime-kuma:
  user: "1000:1000"
  cap_drop:
    - ALL
```

**Learn more:** CIS Docker Benchmark 5.2, 5.3

---

### [MEDIUM] M-02: Caddy Container Missing Resource Limits
**Category:** Security
**Location:** [docker-compose.yml:19-43](docker-compose.yml#L19)
**CWE:** CWE-770 (Allocation of Resources Without Limits)

**What:** Caddy has no `deploy.resources.limits` for memory or CPU, unlike all other services. As the internet-facing reverse proxy, it is the most likely DoS target.

**Fix:**
```yaml
caddy:
  deploy:
    resources:
      limits:
        memory: 256m
        cpus: '0.50'
```

**Learn more:** CIS Docker Benchmark 5.10, 5.11

---

### [MEDIUM] M-03: CoreDNS Missing cap_drop and Resource Limits
**Category:** Security
**Location:** [docker-compose.yml:5-17](docker-compose.yml#L5)
**CWE:** CWE-250, CWE-770

**What:** CoreDNS has `no-new-privileges` but missing `cap_drop: ALL`, `cap_add: NET_BIND_SERVICE`, user directive, and resource limits. Processes untrusted DNS queries from the network.

**Fix:**
```yaml
coredns:
  user: "1000:1000"
  cap_drop:
    - ALL
  cap_add:
    - NET_BIND_SERVICE
  deploy:
    resources:
      limits:
        memory: 64m
        cpus: '0.10'
```

**Learn more:** CIS Docker Benchmark 5.2, 5.3

---

### [MEDIUM] M-04: Missing Health Checks on 7 of 8 Services
**Category:** Security / Quality
**Location:** [docker-compose.yml](docker-compose.yml) (general)
**CWE:** CWE-693 (Protection Mechanism Failure)

**What:** Only Uptime Kuma has a `healthcheck`. All other services lack health checks, meaning Docker cannot detect when a service becomes unresponsive.

**Fix:** Add health checks to all critical services:
```yaml
caddy:
  healthcheck:
    test: ["CMD", "wget", "--spider", "-q", "https://localhost:443"]
    interval: 30s
    timeout: 5s
    retries: 3
loki:
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:3100/ready"]
    interval: 30s
    timeout: 5s
    retries: 3
grafana:
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"]
    interval: 30s
    timeout: 5s
    retries: 3
prometheus:
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://localhost:9090/-/healthy"]
    interval: 30s
    timeout: 5s
    retries: 3
```

**Learn more:** Docker Compose healthcheck best practices

---

### [MEDIUM] M-05: Missing Content-Security-Policy (CSP) Header
**Category:** Security
**Location:** [Caddyfile.tmpl:5-13](Caddyfile.tmpl#L5)
**CWE:** CWE-1021 (Improper Restriction of Rendered UI Layers)

**What:** The Caddy security headers snippet includes HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, and Permissions-Policy, but is missing Content-Security-Policy.

**Fix:** Add to `(security_headers)` snippet:
```
header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; frame-ancestors 'none'"
```
Note: Grafana may need a more permissive CSP — test per vhost.

**Learn more:** app-rules.md → CSP strategy, OWASP Top 10 A05

---

### [MEDIUM] M-06: Prometheus and Node-Exporter Accessible Without Authentication
**Category:** Security
**Location:** [monitoring/prometheus.yml](monitoring/prometheus.yml), [docker-compose.yml:168-196](docker-compose.yml#L168)
**CWE:** CWE-306 (Missing Authentication for Critical Function)

**What:** Prometheus and node-exporter expose metrics endpoints without authentication. Any container on the `monitoring` network can query them.

**Why it matters:** Prometheus metrics reveal service names, internal IPs, and resource usage patterns. Node-exporter with `pid: host` exposes detailed host process information.

**Fix:** Enable Prometheus basic auth via web config:
```yaml
# monitoring/web.yml
basic_auth_users:
  admin: $2y$12$... # bcrypt hash
```

**Learn more:** Prometheus Security Model documentation

---

### [MEDIUM] M-07: Grafana Runs as UID 472 with GID 0 (root group)
**Category:** Security
**Location:** [docker-compose.yml:107](docker-compose.yml#L107)
**CWE:** CWE-250

**What:** Grafana runs as `user: "472:0"` where GID 0 is the root group. This is the Grafana upstream default but grants group-level access to root-owned files inside the container.

**Fix:**
```yaml
grafana:
  user: "472:472"
```
Note: May need volume permission adjustment.

**Learn more:** Principle of Least Privilege

---

### 🔵 Low (6)

---

### [LOW] L-01: TruffleHog Pre-commit Scans Only HEAD Commit
**Category:** Security
**Location:** [.pre-commit-config.yaml:9](.pre-commit-config.yaml#L9)
**CWE:** CWE-312

**What:** The TruffleHog pre-commit hook uses `--since-commit HEAD`, scanning only the latest commit diff. The CI pipeline compensates with full-history scanning.

**Fix:** Consider adding gitleaks as a complementary pre-commit scanner that operates on staged content directly.

---

### [LOW] L-02: PII Check Script Does Not Detect Email Addresses
**Category:** Compliance (GDPR)
**Location:** [scripts/check-pii.sh:17-28](scripts/check-pii.sh#L17)
**CWE:** CWE-359

**What:** The script detects IP addresses and Tailscale hostnames but not email addresses (PII under GDPR).

**Fix:** Add email pattern to PATTERNS array:
```bash
'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|Email address'
```

**Learn more:** GDPR Art. 4(1) — Definition of Personal Data

---

### [LOW] L-03: CI Pipeline Does Not Run PII Check
**Category:** Compliance (GDPR)
**Location:** [.github/workflows/ci.yml](.github/workflows/ci.yml)
**CWE:** CWE-359

**What:** The PII check only runs as a pre-commit hook, which can be bypassed with `--no-verify`.

**Fix:** Add a CI job for PII scanning (requires adapting script for CI context — scanning diff against base branch).

**Learn more:** GDPR Art. 32 — Security of Processing

---

### [LOW] L-04: Promtail Image Version (3.0.0) Significantly Behind Loki (3.7.2)
**Category:** Security (Supply Chain)
**Location:** [docker-compose.yml:76](docker-compose.yml#L76)
**CWE:** CWE-1104

**What:** ~7 minor version gap. May contain known CVEs patched in newer releases.

**Fix:** Update to `grafana/promtail:3.7.2@sha256:<current-digest>`.

---

### [LOW] L-05: Renovate and Dependabot Both Configured
**Category:** Quality
**Location:** [renovate.json](renovate.json), [.github/dependabot.yml](.github/dependabot.yml)

**What:** Both tools are active, creating duplicate PRs for GitHub Actions updates.

**Fix:** Remove `dependabot.yml` — Renovate's `config:recommended` already covers GitHub Actions.

---

### [LOW] L-06: No `read_only: true` Set on Any Container
**Category:** Security
**Location:** [docker-compose.yml](docker-compose.yml) (general)
**CWE:** CWE-732

**What:** No containers use `read_only: true`, allowing writable root filesystems.

**Fix:** Add `read_only: true` with appropriate `tmpfs` mounts for `/tmp` on services that don't need writable root FS (caddy, coredns, node-exporter, prometheus, promtail).

---

### ⚪ Info (6)

---

### [INFO] I-01: All Images Properly Digest-Pinned
**Category:** Security (Supply Chain)
All 8 Docker images use `@sha256:` digest pinning. Excellent supply chain protection.

### [INFO] I-02: CI Actions Properly Commit-Pinned
**Category:** Security (Supply Chain)
All GitHub Actions use full commit SHA pinning with version comments.

### [INFO] I-03: Good Network Segmentation
**Category:** Security
`proxy` and `monitoring` networks are properly separated. Grafana correctly bridges both.

### [INFO] I-04: Loki Retention (7 days) Reasonable for GDPR
**Category:** Compliance (GDPR)
168h retention with compaction and deletion. Compliant with data minimization (Art. 5(1)(e)).

### [INFO] I-05: .env Never Committed to Git History
**Category:** Security
Properly gitignored since repo creation. Pre-commit hooks provide additional protection.

### [INFO] I-06: EU AI Act — Not Directly Applicable
**Category:** Compliance
The gateway proxies to `niles_core:8000` (AI service), but the Act obligations apply to the Niles project itself, not the reverse proxy infrastructure.

---

## Statistics

| Severity | Security | Quality | Compliance | Total |
|----------|:---:|:---:|:---:|:---:|
| 🔴 Critical | 2 | 0 | 0 | **2** |
| 🟠 High | 3 | 0 | 1 | **4** |
| 🟡 Medium | 6 | 1 | 0 | **7** |
| 🔵 Low | 2 | 1 | 2 | **5** (+1 supply chain) |
| ⚪ Info | 3 | 0 | 3 | **6** |
| **Total** | **16** | **2** | **6** | **24** |

---

## ISO 27001 Mapping

| Control | Status | Finding |
|---------|:---:|---|
| A.8.9 Configuration management | 🟡 | Caddyfile.tmpl not properly templated; hardcoded values |
| A.8.15 Logging | 🟡 | Good pipeline but PII scrubbing missing; alerting absent |
| A.8.24 Use of cryptography | 🟢 | TLS via Caddy, digest-pinned images, Tailscale WireGuard |
| A.8.25 Secure development lifecycle | 🟡 | Pre-commit + CI scanning present; missing Trivy, Semgrep, branch protection |
| A.8.28 Secure coding | 🟡 | Shell scripts adequate; Makefile secret leakage issue |

---

## Top 3 Immediate Actions

1. **Mitigate Docker socket exposure (C-01):** Replace Promtail's Docker socket mount with a socket proxy or switch to file-based log scraping. This is the single highest-risk finding — enables full host compromise from within a container.

2. **Add `bind ${TAILSCALE_IP}` to Linux CoreDNS template (H-01):** One-line fix in `dns/Corefile.tmpl` that prevents DNS from being exposed on all host interfaces.

3. **Harden remaining containers (M-01, M-02, M-03):** Add `cap_drop: ALL` + user isolation to CoreDNS and Uptime Kuma, add resource limits to Caddy — brings all services to the same hardening level already applied to Loki/Prometheus/Grafana.

---

*Generated with AI assistance (Claude Code + dev-best-practices plugin).
Findings should be verified — not a substitute for manual penetration testing.*
