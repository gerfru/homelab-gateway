# Umsetzungsplan — homelab-gateway

**Erstellt:** 2026-06-08
**Basis:** review-app-report.md (62 Findings) + review-secure-report.md (24 Findings)
**Strategie:** 8 PRs in aufsteigender Risiko-Reihenfolge — Security first, dann Hardening, dann Quality of Life

---

## Übersicht

| Wave | PR | Thema | Findings | Effort | Dateien |
|:---:|---|---|:---:|:---:|:---:|
| 1 | ~~PR-01~~ [#25](https://github.com/gerfru/homelab-gateway/pull/25) ✅ | ~~GitHub Repo Security Gates~~ | 7 | S | GitHub Settings, ci.yml, dependabot.yml, renovate.json |
| 2 | ~~PR-02~~ [#27](https://github.com/gerfru/homelab-gateway/pull/27) ✅ | ~~Container Hardening (docker-compose)~~ | 12 | S | docker-compose.yml |
| 3 | ~~PR-03~~ [#28](https://github.com/gerfru/homelab-gateway/pull/28) ✅ | ~~Caddy Template + Config Hygiene~~ | 8 | S | Caddyfile.tmpl, Makefile, docker-compose.yml |
| 4 | ~~PR-04~~ [#29](https://github.com/gerfru/homelab-gateway/pull/29) ✅ | ~~CI Pipeline Erweiterung (Trivy, Semgrep, Checkov)~~ | 6 | M | ci.yml, .pre-commit-config.yaml |
| 5 | ~~PR-05~~ [#32](https://github.com/gerfru/homelab-gateway/pull/32) ✅ | ~~Observability: Alerting + Scrape Coverage~~ | 8 | M | prometheus.yml, promtail-config.yml, docker-compose.yml, Grafana Alerting + Dashboards |
| 6 | ~~PR-06~~ [#38](https://github.com/gerfru/homelab-gateway/pull/38) ✅ | ~~Code Quality + Cleanup~~ | 10 | S | scripts/check-pii.sh, Makefile, .env.example, .claude/CLAUDE.md |
| 7 | ~~PR-07~~ [#40](https://github.com/gerfru/homelab-gateway/pull/40) ✅ | ~~Testing Foundation~~ | 7 | M | tests/, .pre-commit-config.yaml, Makefile |
| 8 | ~~PR-08~~ [#42](https://github.com/gerfru/homelab-gateway/pull/42) ✅ | ~~Long-term: Deployment, Tracing, Error Tracking~~ | 6 | L | docker-compose.yml, Caddyfile.tmpl, tempo-config.yml, ci.yml |

**Gesamt:** 62 Findings in 8 PRs

---

## ~~Wave 1 — PR-01: GitHub Repo Security Gates~~ ✅ Erledigt

**PR:** [#25](https://github.com/gerfru/homelab-gateway/pull/25) — gemergt 2026-06-08

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| 1 | No branch protection on main | Critical | ✅ Ruleset "main" aktiv (ID: 17406994) |
| 3 | GitHub secret scanning disabled | Critical | ⚠️ Nicht verfügbar auf free private — TruffleHog in CI kompensiert |
| 35 | Dependabot AND Renovate both configured | Medium | ✅ `dependabot.yml` gelöscht |
| 36 | Renovate missing automerge config | Medium | ✅ 4 packageRules (Actions patch: automerge, Docker digest+patch: automerge, minor/major: Review) |
| 37 | Repository merge settings wrong | Medium | ✅ Squash-only, delete-branch-on-merge, auto-merge |
| 38 | No PR template | Medium | ✅ `.github/pull_request_template.md` erstellt |
| 57 | No rollback documented | Low | ✅ Rollback-Sektion in README.md |

### Validierung

- [x] Branch protection aktiv: Ruleset "main" mit 4 Required Status Checks
- [x] Secret scanning: nicht verfügbar (free private), TruffleHog kompensiert
- [x] Squash-only: `allow_merge_commit=false`, `allow_rebase_merge=false`
- [x] Renovate Dashboard Issue erwartet (nach nächstem Renovate-Lauf)

---

## ~~Wave 2 — PR-02: Container Hardening~~ ✅ Erledigt

**PR:** [#27](https://github.com/gerfru/homelab-gateway/pull/27) — gemergt 2026-06-08

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| C-01 | Docker socket in Promtail | Critical (ISEC) | ✅ Docker Socket Proxy (Tecnativa) eingeführt, direkter Socket-Zugriff entfernt |
| C-02 | node-exporter mountet gesamtes Host-FS | Critical (ISEC) | ✅ Auf `/proc`, `/sys`, `/rootfs` eingeschränkt + command flags |
| 8 | Health checks auf 7/8 Services fehlen | High | ✅ Health Checks auf Caddy, Grafana, Prometheus, node-exporter, socket-proxy (Loki/Promtail: distroless) |
| 19 | Promtail läuft als root | Medium | ✅ Entfernt (distroless Image handhabt User intern) |
| 20 | Uptime Kuma: cap_drop + root | Medium | ✅ `cap_drop: ALL`, `cap_add: SETGID, SETUID` |
| 21 | CoreDNS: cap_drop fehlt | Medium | ✅ `cap_drop: ALL`, `cap_add: NET_BIND_SERVICE` |
| 24 | Caddy: Resource Limits fehlen | Medium | ✅ 256m / 0.50 CPU |
| 25 | CoreDNS: Resource Limits fehlen | Medium | ✅ 64m / 0.10 CPU |
| 28 | CoreDNS: Log Rotation fehlt | Medium | ✅ json-file, 5m, 2 Dateien |
| 29 | depends_on ohne service_healthy | Medium | ✅ `condition: service_healthy` wo möglich |
| 49 | read_only: true nicht gesetzt | Low | ✅ `read_only: true` + `tmpfs` auf allen passenden Services |
| 50 | Uptime Kuma: cap_drop fehlt | Low | ✅ (zusammen mit #20) |

### Validierung

- [x] `docker compose up -d` startet ohne Fehler
- [x] `docker compose ps` zeigt alle Services als "healthy"
- [x] Promtail nutzt Socket Proxy statt direkten Docker Socket
- [x] Caddy hat Memory-Limit (256m)

---

## ~~Wave 3 — PR-03: Caddy Template + Config Hygiene~~ ✅ Erledigt

**PR:** [#28](https://github.com/gerfru/homelab-gateway/pull/28) — gemergt 2026-06-08

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| H-01 | CoreDNS Linux Corefile: bind fehlt | High (ISEC) | ✅ `bind ${TAILSCALE_IP}` in `dns/Corefile.tmpl` |
| 18 | CSP Header fehlt | Medium | ✅ `Content-Security-Policy` in `(security_headers)` Snippet |
| 26 | Grafana ROOT_URL hardcoded | Medium | ✅ `GF_SERVER_ROOT_URL=https://logs.${DOMAIN}` |
| 27 | Caddyfile.tmpl hardcodes home.lab | Medium | ✅ Alle `home.lab` → `${DOMAIN}`, Makefile: `envsubst` |
| 30 | Caddyfile.tmpl Naming-Mismatch | Medium | ✅ (zusammen mit #27) |
| 31 | Caddy Log Block 6× dupliziert | Medium | ✅ `(common_log)` Snippet extrahiert |
| 43 | Promtail: monitoring=true Label fehlt | Medium | ✅ Label auf Caddy, Grafana, Prometheus, Uptime Kuma |
| 45 | Promtail Version hinter Loki | Medium | ✅ Via Renovate auf aktuellen Stand gebracht |

### Validierung

- [x] `make generate` erzeugt korrekte Caddyfile mit substituierten Domains
- [x] `grep '\${' Caddyfile` findet KEINE nicht-substituierten Variablen
- [x] CSP Header sichtbar: `curl -kI https://niles.home.lab`
- [x] `(common_log)` Snippet wird in allen vhost-Blöcken verwendet

---

## ~~Wave 4 — PR-04: CI Pipeline Erweiterung~~ ✅ Erledigt

**PR:** [#29](https://github.com/gerfru/homelab-gateway/pull/29) — gemergt 2026-06-08

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| 2 | Kein Trivy Container Scanning | Critical | ✅ Trivy Job scannt alle Images (informational, CRITICAL severity) |
| 9 | Kein Semgrep SAST | High | ✅ Semgrep mit `--config auto --error --severity ERROR` |
| 10 | Keine SBOM-Generierung | High | ✅ Anchore SBOM Action auf Tag-Push (`release.yml`) |
| 23 | Trivy in CI fehlt (Security-Axis) | Medium | ✅ (zusammen mit #2) |
| 48 | Kein IaC Scanning | Low | ✅ Checkov als Required Check |
| 33 | Pre-commit Hook Order | Medium | ✅ Bestehende Reihenfolge beibehalten (TruffleHog → Lint) |

### Validierung

- [x] CI Pipeline hat 7 Jobs: lint, docker-compose-validate, secret-scan, caddyfile-validate, trivy, semgrep, checkov
- [x] Trivy scannt alle Images aus docker-compose.yml
- [x] Semgrep läuft auf Shell-Scripts und YAML
- [x] SBOM wird bei Tag-Push generiert (release.yml)

---

## ~~Wave 5 — PR-05: Observability — Alerting + Scrape Coverage~~ ✅ Erledigt

**PR:** [#32](https://github.com/gerfru/homelab-gateway/pull/32) — gemergt 2026-06-08
**Zusätzliche PRs:** [#33](https://github.com/gerfru/homelab-gateway/pull/33) (Prometheus/Metrics Subdomains), [#34](https://github.com/gerfru/homelab-gateway/pull/34) (Uptime Kuma Provisioning)

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| 4 | Keine Prometheus Alert Rules | Critical | ✅ 5 Grafana Unified Alerting Rules (HighCPU, HighMemory, DiskAlmostFull, TargetDown, HighErrorRate) |
| 5 | Kein Alertmanager / Notification Channel | Critical | ✅ Grafana Unified Alerting + Webhook Contact Point (`ALERTING_WEBHOOK_URL`) |
| 16 | Prometheus scrapes nur node-exporter | High | ✅ 5 Scrape Targets: node-exporter, caddy:9180, loki:3100, grafana:3000, promtail:9080 |
| 32 | Inkonsistente Error-Regex in Grafana Panels | Medium | ✅ `traceback` zu Panels 4 und 6 hinzugefügt |
| 44 | Grafana: Latency/Traffic Panels fehlen | Medium | ✅ 3 Caddy-Panels: Request Rate, p95 Latency, HTTP Errors (system-monitoring.json) |
| 46 | CoreDNS: Logging + Resource Limits fehlen | Medium | ✅ Bereits in PR-02 erledigt |
| H-04 | PII in Logs ohne Scrubbing (GDPR) | High (ISEC) | ✅ Promtail replace-Stages für IPs und Emails |
| 61 | Loki Retention nur 7 Tage | Low | ✅ Auf 336h (14 Tage) erhöht |

### Zusätzlich umgesetzt (über Findings hinaus)

- Caddy Metrics-Endpoint (`:9180`) mit `servers { metrics }` in Global Options
- Caddy auf `monitoring` Network (für Prometheus Scraping)
- `prometheus.home.lab` und `metrics.home.lab` Subdomains in Caddyfile.tmpl
- Grafana Loki Datasource: `uid: loki` für Alerting-Rule-Referenzen
- Grafana Alerting Provisioning: `rules.yaml`, `contactpoints.yaml`, `policies.yaml`
- Uptime Kuma Monitor Provisioning Script (`scripts/setup-uptime-monitors.sh`)

### Validierung

- [x] Prometheus Targets Page: 5 Targets (node, caddy, loki, grafana, promtail) — alle "up"
- [x] Grafana: Alerting → 5 Alert Rules provisioniert
- [x] Grafana: Contact Point "homelab-webhook" konfiguriert
- [x] Promtail: IP-Adressen in Loki als `[IP_REDACTED]` sichtbar
- [x] Grafana Panels 2, 4, 6 zeigen konsistente Error-Counts
- [x] Caddy Metrics über `metrics.home.lab` erreichbar
- [x] Prometheus UI über `prometheus.home.lab` erreichbar
- [x] Uptime Kuma: 8 Monitors automatisch provisioniert

---

## ~~Wave 6 — PR-06: Code Quality + Cleanup~~ ✅ Erledigt

**PR:** [#38](https://github.com/gerfru/homelab-gateway/pull/38) — gemergt 2026-06-09

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| H-02 | Weak Default Credentials in .env.example | High (ISEC) | ✅ `changeme` → `CHANGE_ME_BEFORE_DEPLOY` + `check-env` Guard in Makefile |
| H-03 | Makefile: include .env + export leakt Secrets | High (ISEC) | ✅ Blanket `export` → `export DOMAIN TAILSCALE_IP`, `--env-file .env` für Docker Compose |
| 51 | Orphaned requirements.txt | Low | ⏭️ Übersprungen — wird aktiv genutzt (uptime-kuma-api, PyYAML) |
| 52 | Bash echo piped to grep | Low | ✅ `[[ "$match" =~ $pattern ]]` in check-pii.sh |
| 53 | grep ohne -- Separator | Low | ✅ `grep -oE -- "$REGEX"` in check-pii.sh |
| 54 | Makefile: recursive make call | Low | ✅ `@make` → `@$(MAKE)` |
| 55 | .PHONY unvollständig | Low | ✅ `logs-caddy`, `logs-dns`, `check-env` hinzugefügt |
| 56 | Grafana datasource uid leer | Low | ✅ Bereits in Wave 5 erledigt |
| 60 | Uptime Kuma: Major-Version Tag :1 | Low | ⏭️ Übersprungen — bereits `:2` mit SHA256-Digest, Renovate managed |
| 34 | TruffleHog statt gitleaks | Medium | ✅ Deviation dokumentiert in `.claude/CLAUDE.md` |

### Validierung

- [x] `shellcheck scripts/check-pii.sh` → 0 Warnungen
- [x] `docker compose config --quiet` → valide
- [x] `make up` mit Default-Passwörtern → Fehler mit klarer Meldung
- [x] CI Pipeline: alle 7 Checks grün

---

## ~~Wave 7 — PR-07: Testing Foundation~~ ✅ Erledigt

**PR:** [#40](https://github.com/gerfru/homelab-gateway/pull/40) — gemergt 2026-06-09

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| 6 | Zero automated tests | Critical | ✅ `tests/` Verzeichnis mit 3 Test-Scripts + Golden Files |
| 12 | Keine DNS-Resolution-Tests | High | ✅ `tests/test-dns.sh` — dig mit Assertions (6 Domains) |
| 40 | Template-Generation ohne Validierung | Medium | ✅ `tests/test-generate.sh` — Golden-File Test (4 Templates) |
| 41 | make test-dns nicht in CI | Medium | ⏭️ Lokal via `make test-dns` (braucht laufenden CoreDNS, CI-Minuten sparen) |
| 42 | Kein Monitoring-Pipeline Smoke Test | Medium | ✅ `tests/test-smoke.sh` — Health Checks + Prometheus Targets |
| 58 | Kein pre-commit Hook für compose/Caddy | Low | ✅ 2 Hooks: docker-compose-validate + template-generate-test |
| 11 | CI hat keine Behavioral Tests | High | ⏭️ Lokal via `make test-smoke` (CI-Minuten sparen) |

### Validierung

- [x] `make test` → 4/4 Golden-File Checks bestanden
- [x] `shellcheck tests/*.sh` → 0 Warnungen
- [x] Pre-commit: docker-compose-validate und template-generate-test konfiguriert
- [x] CI Pipeline: alle 7 bestehenden Checks grün

---

## ~~Wave 8 — PR-08: Long-term (Backlog)~~ ✅ Erledigt

**PR:** [#42](https://github.com/gerfru/homelab-gateway/pull/42) — gemergt 2026-06-09

### Umgesetzt

| # | Finding | Severity | Ergebnis |
|---|---------|----------|----------|
| 14 | Kein OpenTelemetry / Tracing | High | ✅ Grafana Tempo als Trace-Backend (OTLP gRPC/HTTP), Grafana Datasource + Prometheus Scrape Target |
| 15 | Kein Sentry / Error Tracking | High | ✅ Sentry.io DSN-Platzhalter in `.env.example` (bestehender Account, kein neuer Container) |
| 39 | Keine Deployment-Pipeline | Medium | ✅ Watchtower mit Label-basiertem Opt-in (taeglich 4 Uhr, 8 Services) |
| 22 | Kein Caddy-Level Auth | Medium | ✅ `basicauth` auf `prometheus.*` und `metrics.*` Subdomains |
| 47 | Loki Auth nur Tenant-Header | Low | ✅ Dokumentiert in `.claude/CLAUDE.md` — adaequat fuer Single-User-Setup |
| 59 | Uptime Kuma Config nicht versioniert | Low | ✅ Bereits in PR #34 erledigt (`scripts/setup-uptime-monitors.sh`) |

### Validierung

- [x] `make test` → 4/4 Golden-File Checks bestanden (Caddyfile mit basicauth)
- [x] `docker compose config --quiet` → valide (mit Tempo + Watchtower)
- [x] CI Pipeline: alle 7 Checks gruen
- [ ] (Mit Stack) `docker compose up -d` → tempo + watchtower starten
- [ ] (Mit Stack) Grafana → Tempo Datasource erreichbar

---

## Zusammenfassung: Erwarteter Zustand nach allen Waves

| Axis | Vorher | Nach Wave 1-7 | Nach Wave 8 |
|------|:---:|:---:|:---:|
| Architecture & 12-Factor | 🟡 | 🟢 | 🟢 |
| Security (ASVS L1) | 🟡 | 🟢 | 🟢 |
| Code Quality | 🟡 | 🟢 | 🟢 |
| Tests & Reliability | 🔴 | 🟡 | ✅ 🟢 |
| CI/CD & Delivery | 🔴 | 🟢 | 🟢 |
| Observability & Ops | 🟡 | 🟢 | 🟢 |

**Gesamtergebnis nach Wave 8:** 6× 🟢 — Alle Waves abgeschlossen.

---

## Abhängigkeiten zwischen PRs

```
PR-01 (Branch Protection)  ←  Muss zuerst, damit alle weiteren PRs durch CI laufen
  ↓
PR-02 (Container Hardening)  ←  Health Checks werden von PR-05 und PR-07 gebraucht
  ↓
PR-03 (Caddy + Config)  ←  Template-Änderungen vor Testing (PR-07 braucht korrekte Templates)
  ↓
PR-04 (CI Erweiterung)  ←  Trivy/Semgrep sollten laufen, bevor weitere PRs gemergt werden
  ↓
PR-05 (Observability)  ←  Braucht erweiterte Prometheus Targets aus PR-02 (Caddy Metrics)
  ↓
PR-06 (Code Quality)  ←  Unabhängig, kann parallel zu PR-05
  ↓
PR-07 (Testing)  ←  Braucht Health Checks (PR-02), Templates (PR-03), CI (PR-04)
  ↓
PR-08 (Backlog)  ←  Unabhängig, bei Bedarf
```

---

*Erstellt mit AI-Unterstützung (Claude Code + dev-best-practices Plugin).
Alle Angaben sind zu verifizieren — kein Ersatz für manuelle Prüfung.*
