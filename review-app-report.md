# App Evaluation Report — homelab-gateway

**Date:** 2026-06-08
**Stack:** Docker Compose (8 services) | CoreDNS | Caddy | Loki + Promtail + Prometheus + Grafana | Uptime Kuma | Bash/Make | Tailscale VPN
**ASVS Level:** L1 (solo developer, homelab)
**Rule Source:** dev-best-practices plugin (essential-rules.md, app-rules.md, github-rules.md, architecture-rules.md)

---

## Dashboard

| Axis | Traffic Light | #Critical | #High | #Medium | #Low | Most Important Violated Rule |
|------|:---:|:---:|:---:|:---:|:---:|---|
| Architecture & 12-Factor | 🟡 YELLOW | 0 | 1 | 5 | 3 | architecture-rules → Docker → HEALTHCHECK |
| Security (ASVS L1 + Top 10) | 🟡 YELLOW | 0 | 1 | 5 | 3 | app-rules → Container hardening (Docker socket) |
| Code Quality | 🟡 YELLOW | 0 | 1 | 3 | 6 | DRY: Caddyfile.tmpl not a real template |
| Tests & Reliability | 🔴 RED | 1 | 3 | 3 | 1 | architecture-rules → Testing Strategy (zero tests) |
| CI/CD & Delivery (DORA) | 🔴 RED | 3 | 2 | 5 | 1 | github-rules → Branch protection on main |
| Observability & Operations | 🟡 YELLOW | 2 | 3 | 4 | 4 | app-rules → Alert thresholds (no alerting) |

---

## All Findings (sorted by severity)

### 🔴 Critical

| # | Finding | Axis | File:Line | Confidence | Violated Rule | Fix | Effort |
|---|---------|------|-----------|:---:|---|---|:---:|
| 1 | No branch protection on main | CI/CD | GitHub API | 10 | github-rules → Branch protection | Enable branch protection / rulesets: require PRs, status checks, no force push | S |
| 2 | No container scanning (Trivy) in CI | CI/CD | ci.yml (absent) | 10 | github-rules → Trivy (CRITICAL, HIGH, exit-code 1) | Add Trivy CI job scanning all referenced images | M |
| 3 | GitHub secret scanning + push protection disabled | CI/CD | GitHub API | 10 | github-rules → Secret scanning: 3 layers | Enable in Settings → Code security and analysis | S |
| 4 | No Prometheus alerting rules defined | Observability | prometheus.yml | 10 | app-rules → Alert thresholds | Create alert-rules.yml (CPU>80%, mem>80%, disk>85%) | M |
| 5 | No Alertmanager or alert notification channel | Observability | prometheus.yml | 10 | app-rules → Alert thresholds | Deploy Alertmanager or configure Grafana unified alerting | M |
| 6 | Zero automated tests in entire project | Tests | Project root | 10 | architecture-rules → Testing Strategy (70-80% coverage) | Create tests/ directory with config validation suite | M |

### 🟠 High

| # | Finding | Axis | File:Line | Confidence | Violated Rule | Fix | Effort |
|---|---------|------|-----------|:---:|---|---|:---:|
| 7 | Docker socket mount in Promtail | Security | docker-compose.yml:86 | 8 | OWASP A01 / CWE-269 | Use docker-socket-proxy or file-based log collection | M |
| 8 | Missing health checks on 7 of 8 services | Architecture | docker-compose.yml | 10 | architecture-rules → Docker → HEALTHCHECK | Add healthcheck blocks to all services | S |
| 9 | No SAST (Semgrep) in CI | CI/CD | ci.yml (absent) | 10 | github-rules → Security scanning: Semgrep | Add semgrep/semgrep-action to CI | S |
| 10 | No SBOM generation (syft) | CI/CD | (absent) | 10 | github-rules → SBOM on release | Add syft CycloneDX generation on tag push | M |
| 11 | CI has zero behavioral tests | Tests | ci.yml | 10 | architecture-rules → Tests test behavior | Add integration test job (spin up stack, run assertions) | L |
| 12 | No automated DNS resolution tests | Tests | Makefile:128 | 10 | architecture-rules → Testing Strategy | Convert make test-dns to script with assertions + exit codes | M |
| 13 | No service health check tests | Tests | docker-compose.yml | 10 | architecture-rules → Docker → HEALTHCHECK | Add healthchecks, then integration test for readiness | S |
| 14 | No OpenTelemetry / tracing infrastructure | Observability | Project-wide | 10 | app-rules → OpenTelemetry as standard | Add OTEL Collector container | L |
| 15 | No Sentry or equivalent error tracking | Observability | Project-wide | 10 | app-rules → Error tracking: Sentry | Deploy GlitchTip or add Sentry DSN to app services | L |
| 16 | Prometheus scrapes only node-exporter | Observability | prometheus.yml:5-8 | 10 | app-rules → Four golden signals | Add scrape targets: caddy:2019, loki:3100, grafana:3000 | S |
| 17 | PII check detects real credentials path (.env → generated files) | Code Quality | .env:3 | 10 | app-rules → Never commit .env | Verify .env is gitignored (confirmed); ensure make generate does not leak credentials into committed files | M |

### 🟡 Medium

| # | Finding | Axis | File:Line | Confidence | Violated Rule | Fix | Effort |
|---|---------|------|-----------|:---:|---|---|:---:|
| 18 | Missing CSP header in Caddyfile | Security | Caddyfile.tmpl:5-13 | 9 | app-rules → CSP (default-src 'self') | Add Content-Security-Policy to security_headers snippet | S |
| 19 | Promtail runs as root (no user: directive) | Security | docker-compose.yml:75-101 | 8 | app-rules → Container hardening | Add `user: "10001:10001"` | S |
| 20 | Uptime Kuma missing cap_drop + runs as root | Security | docker-compose.yml:199-226 | 8 | app-rules → Container hardening | Add `cap_drop: ALL` and `user: "1000:1000"` | S |
| 21 | CoreDNS missing cap_drop (host network) | Security | docker-compose.yml:5-17 | 7 | app-rules → Container hardening | Add `cap_drop: ALL`, `cap_add: NET_BIND_SERVICE` | S |
| 22 | No Caddy-level auth on reverse-proxied services | Security | Caddyfile.tmpl:17-86 | 7 | app-rules → Auth at 3 layers | Add basicauth or forward_auth to Caddy vhosts | M |
| 23 | No Trivy container image scanning in CI | Security | ci.yml (absent) | 9 | app-rules → Trivy (CRITICAL, HIGH, exit-code 1) | Add Trivy scanning job | S |
| 24 | Caddy missing resource limits | Architecture | docker-compose.yml:19-43 | 10 | architecture-rules → Docker → Resource limits | Add deploy.resources.limits (256m, 0.50 CPU) | S |
| 25 | CoreDNS missing resource limits | Architecture | docker-compose.yml:5-17 | 10 | architecture-rules → Docker → Resource limits | Add deploy.resources.limits (64m, 0.10 CPU) | S |
| 26 | Grafana ROOT_URL hardcoded | Architecture | docker-compose.yml:117 | 10 | 12-Factor → Config in environment | Change to `https://logs.${DOMAIN}` | S |
| 27 | Caddyfile.tmpl hardcodes `home.lab` — not a real template | Architecture | Caddyfile.tmpl | 10 | 12-Factor → Config in environment | Replace `home.lab` with `${DOMAIN}`, use envsubst | S |
| 28 | CoreDNS missing log rotation config | Architecture | docker-compose.yml:5-17 | 10 | architecture-rules → Docker → Log rotation | Add logging driver config (json-file, 5m, 2 files) | S |
| 29 | No `depends_on: condition: service_healthy` | Architecture | docker-compose.yml | 9 | 12-Factor → Disposability | Upgrade depends_on after adding health checks | S |
| 30 | Caddyfile.tmpl not a real template (naming mismatch) | Code Quality | Caddyfile.tmpl | 10 | DRY / naming conventions | Rename or convert to actual template with envsubst | S |
| 31 | Duplicated Caddy log block (6×) | Code Quality | Caddyfile.tmpl:20-84 | 10 | DRY principle | Extract into `(common_log)` snippet | S |
| 32 | Inconsistent error regex across Grafana panels | Code Quality | homelab-overview.json:73 vs 128,186 | 10 | Consistency | Add `traceback` to panels 4 and 6 regex | S |
| 33 | Pre-commit hook order deviates from standard | CI/CD | .pre-commit-config.yaml | 9 | github-rules → Pre-commit hooks: gitleaks → lint → format → type check | Document deviation or add format step | S |
| 34 | gitleaks not used (TruffleHog instead) | CI/CD | .pre-commit-config.yaml + ci.yml | 10 | github-rules → gitleaks in pipeline | Add gitleaks or amend standard to accept TruffleHog | S |
| 35 | Dependabot AND Renovate both configured | CI/CD | dependabot.yml + renovate.json | 10 | github-rules → Renovate (not Dependabot) | Remove dependabot.yml; Renovate covers GitHub Actions | S |
| 36 | Renovate missing automerge config for patches | CI/CD | renovate.json | 10 | github-rules → devDeps patch automerge | Add packageRules with automerge for minor/patch | S |
| 37 | Repository merge settings not configured per standard | CI/CD | GitHub API | 10 | github-rules → Squash merge only | Disable merge commit + rebase; enable squash + auto-delete | S |
| 38 | No PR template | CI/CD | .github/ (absent) | 10 | github-rules → PR template | Create .github/pull_request_template.md | S |
| 39 | No automated deployment pipeline | CI/CD | (absent) | 10 | General CI/CD best practice | Consider SSH-based deploy or Watchtower | L |
| 40 | Template generation has no validation test | Tests | Makefile:12-27 | 9 | architecture-rules → Testing Strategy | Write golden-file test for envsubst output | S |
| 41 | make test-dns not wired into CI | Tests | Makefile:128 + ci.yml | 10 | github-rules → CI pipeline test coverage | Add DNS test job to CI | S |
| 42 | No monitoring pipeline smoke test | Tests | docker-compose.yml | 8 | architecture-rules → Testing Strategy (critical paths) | Add Promtail→Loki→Grafana smoke test | M |
| 43 | Promtail only collects from `monitoring=true` containers | Observability | promtail-config.yml:17-20 | 10 | app-rules → Comprehensive log aggregation | Add label to all services or remove filter | S |
| 44 | Grafana dashboards lack latency/traffic panels | Observability | homelab-overview.json | 9 | app-rules → Four golden signals | Add panels for request latency, rate, errors | M |
| 45 | Promtail version (3.0.0) behind Loki (3.7.2) | Observability | docker-compose.yml:76 | 9 | Container hygiene → dependency alignment | Update Promtail to 3.7.2 with digest pin | S |
| 46 | CoreDNS missing logging limits and resource constraints | Observability | docker-compose.yml:5-17 | 10 | app-rules → Log rotation | Add logging driver + deploy.resources.limits | S |

### 🔵 Low

| # | Finding | Axis | File:Line | Confidence | Violated Rule | Fix | Effort |
|---|---------|------|-----------|:---:|---|---|:---:|
| 47 | Loki auth is tenant-header only, not real auth | Security | loki-config.yml:1 | 7 | app-rules → Auth at 3 layers | Accept as risk for solo homelab | L |
| 48 | No SAST/SCA (IaC scanning) in CI | Security | ci.yml (absent) | 8 | app-rules → Security assessment | Add checkov/kics for IaC scanning | S |
| 49 | `read_only: true` not set on any container | Security | docker-compose.yml | 7 | Container hardening | Add read_only: true + tmpfs where needed | M |
| 50 | Uptime Kuma missing cap_drop: ALL | Architecture | docker-compose.yml:199-226 | 10 | Security hardening consistency | Add `cap_drop: [ALL]` | S |
| 51 | Orphaned requirements.txt (no Python code) | Code Quality | requirements.txt | 9 | Dead code | Remove if provisioning code dropped | S |
| 52 | Bash echo piped to grep in check-pii.sh | Code Quality | scripts/check-pii.sh:43 | 8 | Shell best practices | Use `[[ "$match" =~ $pattern ]]` | S |
| 53 | Missing `--` separator in grep inside loop | Code Quality | scripts/check-pii.sh:75 | 7 | Shell robustness | Change to `grep -oE -- "$REGEX"` | S |
| 54 | Makefile recursive `make` call | Code Quality | Makefile:116 | 8 | Makefile best practice | Use `$(MAKE)` instead | S |
| 55 | Makefile .PHONY list incomplete | Code Quality | Makefile:1 | 10 | Makefile completeness | Add `logs-caddy logs-dns` | S |
| 56 | Grafana dashboard datasource uid empty string | Code Quality | homelab-overview.json:16 | 7 | Maintainability | Set explicit uid in datasource provisioning | S |
| 57 | No rollback capability documented | CI/CD | (absent) | 8 | General CI/CD best practice | Document rollback procedure; add make rollback | S |
| 58 | No pre-commit hook for docker-compose/Caddy validation | Tests | .pre-commit-config.yaml | 9 | architecture-rules → Config validation | Add local hooks for compose config + caddy validate | S |
| 59 | Uptime Kuma config not version-controlled | Observability | docker-compose.yml:206 | 8 | Reproducibility | Export monitors as JSON or use API provisioning | M |
| 60 | Uptime Kuma image uses major-version tag :1 | Observability | docker-compose.yml:200 | 8 | Container hygiene → version specificity | Use specific semver tag alongside digest | S |
| 61 | Loki retention only 7 days | Observability | loki-config.yml:30 | 7 | Informational | Consider 14-30 days if disk allows | S |
| 62 | Docker socket in Promtail (defense-in-depth) | Observability | docker-compose.yml:86 | 7 | Container hygiene | Consider docker-socket-proxy | M |

---

## DORA Metrics (Estimates)

| Metric | Estimate | Measurable? |
|--------|----------|:-----------:|
| Deployment Frequency | ~1-3×/month | Partial (git log only) |
| Lead Time for Changes | Minutes to hours | No |
| Change Failure Rate | Unknown | No |
| MTTR | Unknown | No |

---

## Fix Priority Order

1. **Security gates first:** Enable branch protection on main, enable GitHub secret scanning, add Trivy + Semgrep to CI
2. **Container hardening:** Add health checks to all services, add cap_drop/user to CoreDNS + Uptime Kuma, add resource limits to Caddy + CoreDNS
3. **Observability gaps:** Add Prometheus alerting rules + notification channel, expand scrape targets, align Promtail version
4. **Configuration hygiene:** Convert Caddyfile.tmpl to real template, extract duplicated Caddy log snippet, fix Grafana error regex
5. **Testing foundation:** Create config validation tests, wire test-dns into CI, add integration smoke tests
6. **CI/CD polish:** Remove Dependabot (keep Renovate), configure automerge, add PR template, configure squash merge
7. **Long-term:** OpenTelemetry, Sentry, deployment automation

---

*Created with AI assistance (Claude Code + dev-best-practices plugin).
Findings are to be verified — not a substitute for manual penetration testing.*
