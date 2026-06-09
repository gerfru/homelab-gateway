# App Evaluation Report — homelab-gateway

**Datum:** 2026-06-09
**Stack:** Docker Compose (11 Services) | CoreDNS · Caddy · Grafana · Prometheus · Loki · Promtail · Tempo · node-exporter · Uptime Kuma · Watchtower · Docker Socket Proxy | Bash/Make | Tailscale VPN
**ASVS Level:** L1 (Solo-Entwickler, Homelab)
**Regelquelle:** dev-best-practices Plugin v2.0.0 (essential-rules.md, app-rules.md, github-rules.md, architecture-rules.md)
**Bewertungsperspektiven:** (1) Public GitHub Repo, (2) Self-hosted hinter VPN, (3) Kommerzieller Weiterverkauf

---

## Dashboard

| Achse | Ampel | #Critical | #High | #Medium | #Low | Wichtigste verletzte Regel |
|-------|:-----:|:---------:|:-----:|:-------:|:----:|---|
| Architecture & 12-Factor | :green_circle: GRUEN | 0 | 0 | 2 | 5 | architecture-rules -> Docker -> HEALTHCHECK (Wave 7) |
| Security (ASVS L1 + Top 10) | :green_circle: GRUEN | 0 | 0 | 0 | 3 | Alle Critical/High/Medium behoben |
| Code Quality | :green_circle: GRUEN | 0 | 0 | 0 | 5 | Golden-Files + Tests behoben |
| Tests & Reliability | :green_circle: GRUEN | 0 | 0 | 0 | 2 | Test-Abdeckung erweitert (Wave 5) |
| CI/CD & Delivery (DORA) | :green_circle: GRUEN | 0 | 0 | 0 | 3 | Trivy blocking, ShellCheck, Secret Scanning |
| Observability & Operations | :green_circle: GRUEN | 0 | 0 | 1 | 4 | Alerting funktional, PII-Redaktion vollstaendig |

---

## Fortschritt seit letztem Review (2026-06-08)

Seit dem letzten Review wurden 6 Implementierungs-Waves umgesetzt (52/67 Tasks abgeschlossen):

| Wave | PR | Wesentliche Fixes |
|:----:|:--:|-------------------|
| 1+2 | #51 | Trivy blocking (#1), Golden Files (#2), CI test-generate (#3), Docker Secrets (#S-01/S-07), Watchtower monitor-only (#5), Branch Protection (#6), `make help` (U-01), `-include .env` (#18), `check-env` erweitert (#8) |
| 3 | #53 | Prometheus alert-rules entfernt (#4/#9), monitoring-Labels (#10), AuthFailures-Alert (S-05), HighErrorRate prozentual (#12), p95/Restart-Alerts (#11), Promtail positions Volume (#13) |
| 4 | #54 | SQL-Injection Fix (#16), CSP per Subdomain (#7), socket-proxy cap_drop (#26), Grafana 472:472 (#30), read_only auf Grafana/Uptime Kuma (#24/#25), PII IPv4+IPv6 Regex (#19), Permissions-Policy (#23) |
| 5 | #55 | ShellCheck scandir (#17), test-dns alle Subdomains (#39), PII-Test (#41), Security-Header-Test (#42), Checkov-Kommentar (#43), PR Template (#44), Repo-Settings (#20/#22), Renovate-Doku (#21) |
| 6 | #57 | `make up` Service-URLs (U-06), GENERATED FILE Header (U-07), Error-Troubleshooting (U-10), Upgrade-Sektion (U-13), backup/restore (U-14), `make down` Feedback (U-16), UPTIME_KUMA Kommentar (#36), Alert-Rules-Zaehler (#37) |

### Resolution Summary

| Severity | Total | Resolved | Open | Resolved % |
|----------|:-----:|:--------:|:----:|:----------:|
| Critical | 2 | 2 | 0 | 100% |
| High | 4 | 4 | 0 | 100% |
| Medium | 16 | 13 | 3 | 81% |
| Low | 32 | 18 | 14 | 56% |
| **Gesamt** | **54** | **37** | **17** | **69%** |

**Verbleibende 17 Findings** → Wave 7 (Langfristig / Kommerziell): #14, #15, #27, #28, #29, #31, #32, #33, #34, #35, #38, #40, #45, #46, #47, #48, #50, #51, #53, #54

---

## Alle Findings (sortiert nach Severity, dedupliziert)

### CRITICAL

| # | Finding | Achse | Datei:Zeile | Konf. | Verletzte Regel | Fix | Aufwand |
|---|---------|-------|-------------|:-----:|-----------------|-----|:-------:|
| 1 | **Trivy exit-code 0 — Container-Scan blockiert Merge nicht** | CI/CD | ci.yml:112 | 10 | github-rules -> Security Scanning ("exit-code: 1") | `--exit-code 1`, `--severity CRITICAL,HIGH`, `\|\| true` entfernen | S |
| 2 | **Golden-Files-Verzeichnis fehlt — `make test` broken** | Code Quality / Tests | tests/golden/ (fehlt) | 10 | architecture-rules -> Testing Strategy | `make test-update-golden`, Golden-Files committen | S |

### HIGH

| # | Finding | Achse | Datei:Zeile | Konf. | Verletzte Regel | Fix | Aufwand |
|---|---------|-------|-------------|:-----:|-----------------|-----|:-------:|
| 3 | **test-generate nicht in CI-Pipeline** | CI/CD | ci.yml (fehlt) | 9 | github-rules -> CI Pipeline ("Every PR through pipeline") | Neuen Job `test-generate` hinzufuegen | S |
| 4 | **Prometheus Alert-Rules feuern ins Leere** — kein Alertmanager konfiguriert | Observability | prometheus.yml | 10 | app-rules -> Alert thresholds | alert-rules.yml entfernen (Grafana uebernimmt) oder Alertmanager konfigurieren | S |
| 5 | **Watchtower: Direkter Docker-Socket-Zugriff** | Security / Architecture | docker-compose.yml:402 | 8 | CIS Docker 5.31, Least Privilege | Dokumentieren als akzeptiertes Risiko (Watchtower braucht POST-Zugriff) | S |
| 6 | **Branch Protection auf main [to verify]** | CI/CD | GitHub Settings | N/A | github-rules -> Branch Protection | Via `gh api` pruefen und aktivieren | S |

### MEDIUM

| # | Finding | Achse | Datei:Zeile | Konf. | Verletzte Regel | Fix | Aufwand |
|---|---------|-------|-------------|:-----:|-----------------|-----|:-------:|
| 7 | CSP mit `'unsafe-inline'` und `'unsafe-eval'` in script-src | Security | Caddyfile.tmpl:15 | 8 | app-rules -> CSP (Nonce-based) | CSP pro Subdomain differenzieren; Grafana braucht unsafe-eval, andere nicht | M |
| 8 | `check-env` prueft keine Caddy-Auth-Variablen | Security | Makefile:32, .env.example:22 | 8 | app-rules -> Auth Failures | check-env um Pruefung auf CADDY_AUTH_USER/PASS_HASH erweitern | S |
| 9 | Duplizierte Alert-Rules: Prometheus + Grafana | Observability | alert-rules.yml + rules.yaml | 10 | DRY-Prinzip | alert-rules.yml entfernen — Prometheus hat keinen Alertmanager | S |
| 10 | Unvollstaendige `monitoring=true` Labels — 7 von 11 Services ohne Log-Sammlung | Observability | docker-compose.yml | 9 | app-rules -> Log Aggregation | Mindestens Loki, Tempo, Watchtower labeln | S |
| 11 | Fehlende Alerts: Latenz p95, Traffic-Anomalie, Container-Restart | Observability | rules.yaml | 8 | app-rules -> Alert thresholds (p95 > 2s) | p95-Latenz-Alert und Container-Restart-Alert ergaenzen | M |
| 12 | HighErrorRate basiert auf absoluter Zahl (>20) statt Prozentsatz (>1%) | Observability | rules.yaml:144-177 | 9 | app-rules -> Alert thresholds (error rate > 1%) | Prozentualen Error-Rate-Alert via Caddy-Metriken ergaenzen | S |
| 13 | Promtail positions in tmpfs — Log-Duplikate nach Restart | Architecture | promtail-config.yml:5 | 9 | 12-Factor (6) Stateless / Docker Architecture | Named Volume oder Host-Mount fuer positions.yaml | S |
| 14 | Caddyfile backing-service URLs hardcodiert | Architecture | Caddyfile.tmpl:33-96 | 9 | 12-Factor (4) Backing services as env vars | Upstream-URLs als Env-Vars (NILES_UPSTREAM etc.) | M |
| 15 | Fehlende Healthchecks: Loki, Promtail, Tempo, CoreDNS, Watchtower | Architecture | docker-compose.yml | 10 | architecture-rules -> Docker -> HEALTHCHECK | Healthchecks wo moeglich hinzufuegen (Loki/Promtail: distroless dokumentieren) | M |
| 16 | SQL-Injection-Risiko in setup-uptime-monitors.sh | Security / Code Quality | scripts/setup-uptime-monitors.sh:56-63 | 7 | OWASP A03 (Injection) | Input-Validierung oder Shell-seitiges Escaping | S |
| 17 | ShellCheck in CI scannt nur scripts/, nicht tests/ | Code Quality | ci.yml:27 | 10 | Code Quality -> CI Coverage | `scandir` auf `.` aendern oder tests/ ergaenzen | S |
| 18 | `include .env` statt `-include .env` in Makefile | Code Quality | Makefile:3 | 9 | Code Quality -> Makefile -> Error Handling | `-include .env` verwenden | S |
| 19 | IP-Regex in Promtail zu breit — matched Versionsnummern | Observability | promtail-config.yml:43-44 | 8 | PII-Redaktion -> Praezision | Praezisere IPv4-Regex mit Oktett-Validierung | S |
| 20 | Repo-Settings [to verify]: Squash merge, Delete branch, Dependabot alerts | CI/CD | GitHub Settings | N/A | github-rules -> Repository Settings | Via `gh api` pruefen und konfigurieren | S |
| 21 | Docker-Digest Automerge in Renovate vs. Regel (Regel sagt: kein Automerge) | CI/CD | renovate.json:22-26 | 7 | github-rules -> Dependency Management | Bewusste Abweichung dokumentieren oder Schedule hinzufuegen | S |
| 22 | GitHub-native Secret Scanning [to verify] | CI/CD | GitHub Settings | N/A | github-rules -> Secret Scanning (3 Layers) | Fuer Public Repo aktivieren | S |

### LOW

| # | Finding | Achse | Datei:Zeile | Konf. | Verletzte Regel | Fix | Aufwand |
|---|---------|-------|-------------|:-----:|-----------------|-----|:-------:|
| 23 | Permissions-Policy unvollstaendig (`payment=()` fehlt) | Security | Caddyfile.tmpl:13 | 7 | app-rules -> Security Headers | Erweitern um `payment=(), usb=(), bluetooth=()` | S |
| 24 | Grafana `read_only: true` fehlt | Security / Architecture | docker-compose.yml:186-229 | 8 | CIS Docker 5.12 | `read_only: true` + `tmpfs: [/tmp]` testen | S |
| 25 | Uptime Kuma `read_only: true` fehlt | Security / Architecture | docker-compose.yml:349-382 | 7 | CIS Docker 5.12 | `read_only: true` + tmpfs testen | S |
| 26 | socket-proxy `cap_drop: ALL` fehlt | Security / Code Quality | docker-compose.yml:116-148 | 10 | Container Hardening Konsistenz | `cap_drop: [ALL]` hinzufuegen | S |
| 27 | Watchtower Healthcheck fehlt | Architecture | docker-compose.yml:386-414 | 9 | architecture-rules -> HEALTHCHECK | HTTP-API aktivieren + Healthcheck setzen | S |
| 28 | Kein `stop_grace_period` fuer Prometheus/Loki/Grafana | Architecture | docker-compose.yml | 8 | 12-Factor (9) Disposability | `stop_grace_period: 30s` fuer datenbankaehnliche Services | S |
| 29 | Hardcodierte Retention (Prometheus 30d, Loki 336h) | Architecture | docker-compose.yml:322, loki-config.yml:30 | 8 | 12-Factor (3) Config in env | Retention als Env-Vars mit Defaults | S |
| 30 | Grafana GID 0 (root-Gruppe) | Security | docker-compose.yml:190 | 8 | Least Privilege | user: "472:472" mit Volume-Permission testen | S |
| 31 | Basicauth statt OAuth2/OIDC fuer kommerziellen Einsatz | Security | Caddyfile.tmpl:81-94 | 8 | ASVS V2 (fuer L2+) | Authelia/Caddy-Security evaluieren | L |
| 32 | Kein Rate Limiting in Caddy | Security | Caddyfile.tmpl | 7 | ASVS V13.2 | caddy-ratelimit Plugin evaluieren | M |
| 33 | Inkonsistente Volume-Namenskonvention (Unterstrich vs. Bindestrich) | Code Quality | docker-compose.yml:416-422 | 10 | Naming Conventions | Auf Bindestrich vereinheitlichen (Volume-Migration) | S |
| 34 | Leeres `docs/` Verzeichnis | Code Quality | docs/ | 10 | Dead Code | Entfernen oder mit Inhalt fuellen | S |
| 35 | `SENTRY_DSN` in .env.example unreferenziert | Code Quality | .env.example:27 | 9 | Dead Code | Entfernen oder Service konfigurieren | S |
| 36 | `UPTIME_KUMA_USERNAME/PASSWORD` nicht an Container uebergeben | Code Quality | .env.example:13-14 | 9 | Dead Code | Variablen nutzen oder dokumentieren | S |
| 37 | README: "5 Alert Rules" — Grafana-Kontext nicht klar | Code Quality | README.md:179 | 10 | Dokumentation -> Accuracy | "5 Grafana Unified Alerting rules" praezisieren | S |
| 38 | Wiederholtes Test-Scaffolding (PASS/FAIL-Zaehler) | Code Quality | tests/*.sh | 8 | DRY | Optional: tests/lib.sh extrahieren | S |
| 39 | test-dns.sh testet nur 5 von 8 Subdomains | Tests | tests/test-dns.sh:27-32 | 10 | Testing Strategy -> Completeness | whatsapp, prometheus, metrics ergaenzen | S |
| 40 | Hardcodierte Subdomains in test-dns.sh statt extrahiert | Tests | tests/test-dns.sh:27-32 | 8 | Testing Strategy -> DRY | Subdomain-Liste aus Caddyfile.tmpl extrahieren | S |
| 41 | Kein Test fuer PII-Redaktion | Tests | tests/ | 8 | Testing Strategy -> Critical Paths | PII-Redaktions-Test ergaenzen | M |
| 42 | Kein Test fuer Security-Headers | Tests | tests/ | 8 | Testing Strategy -> Critical Paths | Security-Header-Assertions im Smoke-Test | M |
| 43 | Checkov skip_check CKV2_GHA_1 undokumentiert | CI/CD | ci.yml:139 | 7 | Documentation | Inline-Kommentar mit Begruendung | S |
| 44 | PR Template: "Breaking Changes"-Checkbox fehlt | CI/CD | pull_request_template.md | 9 | github-rules -> PR Template | Checkbox ergaenzen | S |
| 45 | Kein CD-Pipeline (manuelles `make up`) | CI/CD | Makefile:37 | 9 | Release Management | Fuer Perspektive 3: Deployment-Automatisierung evaluieren | L |
| 46 | Kein Versions-Tagging-Workflow | CI/CD | .github/workflows/ | 8 | Release Management | Optional: Release Please evaluieren | M |
| 47 | Tempo OTLP auf 0.0.0.0 (innerhalb Container, nicht Host-exponiert) | Architecture | tempo-config.yml:11-13 | 8 | Network Segmentation | Kommentar in docker-compose.yml ergaenzen | S |
| 48 | Kein Service sendet Traces an Tempo | Observability | tempo-config.yml | 9 | Observability -> Tracing | Beispielkonfiguration fuer OTLP-Export dokumentieren | M |
| 49 | Webhook Contact Point ohne Fallback | Observability | contactpoints.yaml | 7 | Alerting -> Zuverlaessigkeit | Zweiten Contact Point konfigurieren | S |
| 50 | Prometheus Self-Monitoring fehlt | Observability | prometheus.yml | 7 | Metrics -> Vollstaendigkeit | `job_name: prometheus` Target hinzufuegen | S |
| 51 | CoreDNS macOS: Logs ohne Rotation/JSON-Format | Observability | Makefile:67 | 5 | Structured Logging | Logrotate oder CoreDNS JSON-Plugin | S |
| 52 | Watchtower ohne `monitoring=true` Label | Observability | docker-compose.yml:386-414 | 9 | Log Aggregation | Label hinzufuegen fuer Update-Log-Erfassung | S |
| 53 | Kein HTTP-to-HTTPS-Redirect (Port 80) | Architecture | docker-compose.yml:47-48 | 7 | Reverse Proxy Best Practice | Port 80 binden mit Redirect | S |
| 54 | Kein `COMPOSE_PROJECT_NAME` in .env.example | Architecture | .env.example | 7 | 12-Factor (1) Multi-Deploy | In .env.example hinzufuegen | S |

---

## DORA-Metriken (Schaetzungen)

| Metrik | Schaetzung | Messbar? | Kommentar |
|--------|-----------|:--------:|-----------|
| Deployment Frequency | Mehrmals pro Woche | Teilweise (git log) | Merge auf main + manuelles `make up` |
| Lead Time for Changes | Minuten bis Stunden | Nein | Solo-Projekt, kurze Zykluszeit |
| Change Failure Rate | Unbekannt | Nein | Kein Deployment-Tracking |
| Failed Deployment Recovery Time | ~5 Minuten (geschaetzt) | Nein | Rollback via `git revert` + `make up` dokumentiert |

---

## Bewertung nach Perspektive

### Perspektive 1: Public GitHub Repository

**Gesamtbewertung: SEHR GUT**

Alle Critical- und High-Findings behoben. CI-Pipeline mit 8 Jobs (lint, compose-validate, secret-scan, caddyfile-validate, trivy, semgrep, checkov, test-generate+PII), Trivy blockiert bei CRITICAL/HIGH (#1 ✅), Golden-Files vorhanden (#2 ✅), test-generate in CI (#3 ✅). Pre-commit-Hooks, SHA-gepinnte Images, Security-Hardening, Docker Secrets, PII-Redaktion mit IPv4+IPv6. Verbleibend: 17 Low-Priority-Findings (Wave 7).

### Perspektive 2: Self-hosted hinter Tailscale VPN

**Gesamtbewertung: EXZELLENT**

Alle sicherheits- und operativ relevanten Findings behoben: Docker Secrets statt Env-Vars, Watchtower monitor-only, funktionale Alerting-Pipeline mit 8 Grafana-Regeln, PII-Redaktion auf allen Containern, CSP per Subdomain, SQL-Injection gefixt, Security-Header-Tests. Backup/Restore und Upgrade-Pfad dokumentiert.

### Perspektive 3: Kommerzieller Weiterverkauf

**Gesamtbewertung: GUT mit Einschraenkungen**

Wesentliche Security- und Ops-Grundlagen stehen. Fuer kommerzielle Nutzung verbleibend:
- **Security:** Rate Limiting (#32), OAuth2 statt Basicauth (#31) — beide Wave 7
- **Delivery:** Kein CD-Pipeline (#45), kein CHANGELOG (#46) — Wave 7
- **Konfigurierbarkeit:** Backing-Service-URLs hardcodiert (#14), Retention hardcodiert (#29) — Wave 7
- **Observability:** Kein aktives Tracing (#48) — Wave 7

---

## Fix-Prioritaet

### Phase 1 — Sofort (Security + CI-Gates)

| # | Finding | Aufwand |
|---|---------|:-------:|
| 1 | Trivy `--exit-code 1` + `--severity CRITICAL,HIGH` | S |
| 2 | `make test-update-golden` + Golden-Files committen | S |
| 3 | test-generate Job in CI hinzufuegen | S |
| 5 | Watchtower Docker-Socket als akzeptiertes Risiko dokumentieren | S |
| 6 | Branch Protection auf main verifizieren/aktivieren | S |
| 26 | socket-proxy `cap_drop: ALL` hinzufuegen | S |

### Phase 2 — Alerting bereinigen

| # | Finding | Aufwand |
|---|---------|:-------:|
| 4 | alert-rules.yml entfernen oder Alertmanager konfigurieren | S |
| 9 | Duplizierte Alert-Rules bereinigen | S |
| 10 | `monitoring=true` Labels auf Loki, Tempo, Watchtower | S |
| 12 | HighErrorRate -> prozentuale Error-Rate ergaenzen | S |

### Phase 3 — Haertung

| # | Finding | Aufwand |
|---|---------|:-------:|
| 7 | CSP pro Subdomain differenzieren | M |
| 8 | check-env fuer Caddy-Auth-Variablen erweitern | S |
| 13 | Promtail positions aus tmpfs in Volume | S |
| 15 | Healthchecks wo moeglich ergaenzen | M |
| 16 | SQL-Injection in setup-uptime-monitors.sh fixen | S |
| 17 | ShellCheck scandir auf `.` erweitern | S |
| 18 | `include .env` -> `-include .env` | S |

### Phase 4 — Tests

| # | Finding | Aufwand |
|---|---------|:-------:|
| 39 | test-dns.sh: alle 8 Subdomains testen | S |
| 41 | PII-Redaktions-Test ergaenzen | M |
| 42 | Security-Header-Test ergaenzen | M |

### Phase 5 — Kosmetik und Langfristig

Verbleibende Low-Findings (#23-#54) nach Aufwand und Impact priorisieren.

---

## Positive Befunde (kein Finding)

| Bereich | Status | Details |
|---------|--------|---------|
| Secrets in Git | OK | `.env` in `.gitignore`, TruffleHog pre-commit + CI, PII-Check |
| Docker-Image-Pinning | OK | Alle 11 Images mit `@sha256:` Digest gepinnt |
| CI Actions-Pinning | OK | Alle GitHub Actions mit vollem Commit-SHA gepinnt |
| no-new-privileges | OK | Auf allen 11 Containern gesetzt |
| cap_drop: ALL | OK | 10/11 Container (socket-proxy fehlt -> #26) |
| Netzwerk-Segmentierung | OK | `proxy` + `monitoring` korrekt getrennt |
| Caddy auf Tailscale-IP | OK | `${TAILSCALE_IP}:443` — nicht `0.0.0.0` |
| Loki auf 127.0.0.1 | OK | Port `127.0.0.1:3100` |
| Default-Passwort-Schutz | OK | `CHANGE_ME_BEFORE_DEPLOY` + `make check-env` |
| Grafana Auth | OK | Anonymous=false, SignUp=false |
| CI Permissions | OK | `contents: read` (Least Privilege) |
| Resource Limits | OK | Memory + CPU auf allen 11 Services |
| Log Rotation | OK | json-file mit max-size/max-file auf allen Services |
| Renovate | OK | Pin Digests + Platform Automerge |
| SBOM | OK | syft CycloneDX auf Tag-Push |
| PR Template | OK | Test- und Security-Checkliste vorhanden |
| Template-System | OK | envsubst-Pipeline mit Golden-File-Tests (wenn Tests vorhanden) |
| make up Dependency Chain | OK | check-env -> generate -> dns-up -> docker compose up |

---

*Created with AI assistance (Claude Code + dev-best-practices plugin).
Findings are to be verified — not a substitute for manual penetration testing.*
