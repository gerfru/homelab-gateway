# Implementation Plan — homelab-gateway

Datum: 2026-06-09
Quellen: `review-app-report.md` (54 Findings) · `review-secure-report.md` (20 Findings) · `review-ux-report.md` (17 Findings)
Dedupliziert: **91 Roh-Findings → 67 unique Tasks** (24 Duplikate eliminiert)

---

## Uebersicht

| Wave | Thema | Tasks | Aufwand | Status | Ziel |
| :----: | ------- | :-----: | :-------: | :------: | ------ |
| 1 | CI Security Gates + Secrets | 7 | S-M | ✅ PR #51 | Supply-Chain blockiert, Credentials geschuetzt |
| 2 | Onboarding & Quick Wins | 8 | S | ✅ PR #51 | Erster `git clone` funktioniert reibungslos |
| 3 | Alerting & Observability | 8 | S-M | ✅ PR #53 | Funktionierende Alert-Pipeline, keine toten Regeln |
| 4 | Security Hardening | 10 | S-M | ✅ PR #54 | Container gehaertet, Injection gefixt, CSP differenziert |
| 5 | Tests & CI | 10 | S-M | ✅ PR #55 | Vollstaendige Test-Abdeckung, CI-Luecken geschlossen |
| 6 | Dokumentation & Operator Polish | 9 | S-M | ✅ PR #57 | README, Makefile-Feedback, Upgrade/Backup |
| 7 | Langfristig / Kommerziell | 15 | M-L | ✅ | Weiterverkauf-Readiness |

**Aufwand:** S = < 30 Min, M = 30-120 Min, L = > 2h

---

## Wave 1 — CI Security Gates + Secrets

**Ziel:** Keine verwundbaren Images mehr in Production. Credentials nicht ueber Docker API lesbar.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 1.1 | Trivy `--exit-code 1`, `--severity CRITICAL,HIGH`, `\|\| true` entfernen | App #1, S-02 | ci.yml:112 | S |
| 1.2 | Golden-Files erstellen: `make test-update-golden`, Ergebnis committen | App #2 | tests/golden/ | S |
| 1.3 | test-generate Job in CI-Pipeline hinzufuegen | App #3 | ci.yml | S |
| 1.4 | Secrets aus Docker Env-Vars → Docker Secrets / `__FILE`-Suffixe migrieren (Grafana, Caddy) | S-01, S-07 | docker-compose.yml, secrets/ | M |
| 1.5 | Watchtower auf `WATCHTOWER_MONITOR_ONLY=true` umstellen (oder entfernen) | S-03 | docker-compose.yml:396 | S |
| 1.6 | Branch Protection auf `main` verifizieren und aktivieren | App #6 | GitHub Settings | S |
| 1.7 | `.gitignore`: `secrets/` Verzeichnis aufnehmen | S-01 | .gitignore | S |

**Abhaengigkeiten:** 1.4 → 1.7 (secrets/ muss gitignored sein bevor Dateien erstellt werden)
**Validierung:** CI gruent, `docker inspect gateway-grafana` zeigt keine Klartext-Passwoerter, `make test` erfolgreich

---

## Wave 2 — Onboarding & Quick Wins

**Ziel:** `git clone` → `make help` → `make up` funktioniert ohne Stolpersteine.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 2.1 | `include .env` → `-include .env` (optional include) | App #18, U-03 | Makefile:3 | S |
| 2.2 | `make help` Target mit Auto-Discovery aus `##`-Kommentaren; `.DEFAULT_GOAL := help` | U-01 | Makefile | S |
| 2.3 | Alle Make-Targets mit `## Beschreibung` kommentieren | U-01 | Makefile | S |
| 2.4 | `make clean` mit Bestaetigungs-Prompt (`read -p`) | U-02 | Makefile:160 | S |
| 2.5 | `check-env` erweitern: .env-Existenz, Placeholder-IP, CADDY_AUTH-Warnung | App #8, S-08, U-08 | Makefile:31-35 | S |
| 2.6 | `.env.example`: CADDY_AUTH_USER/PASS_HASH auskommentiert → Pflichtfeld mit CHANGE_ME | U-04, S-08 | .env.example:22-23 | S |
| 2.7 | README: Prerequisites-Sektion (Docker, Tailscale, envsubst, dig, jq) | U-05 | README.md | S |
| 2.8 | macOS dns-up: sudo-Vorwarnung ("Port 53 requires sudo") | U-12 | Makefile:54 | S |

**Abhaengigkeiten:** 2.1 vor 2.2 (help braucht optionalen include)
**Validierung:** Frischer `git clone` → `make` zeigt Hilfe, `make up` mit unvollstaendiger .env gibt klare Fehler

---

## Wave 3 — Alerting & Observability

**Ziel:** Alerts erreichen den Operator. Keine toten Regeln, keine Duplikate.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 3.1 | Prometheus `alert-rules.yml` entfernen + `rule_files`-Block aus prometheus.yml entfernen (Grafana Unified Alerting ist Single Source of Truth) | App #4, #9 | prometheus.yml, alert-rules.yml, docker-compose.yml:318 | S |
| 3.2 | `monitoring=true` Labels auf Loki, Tempo, Watchtower setzen | App #10, S-09 | docker-compose.yml | S |
| 3.3 | Grafana: AuthFailures-Alert-Regel ergaenzen (Caddy 401/403 aus Loki) | S-05 | rules.yaml | S |
| 3.4 | HighErrorRate von absolut (>20) auf prozentual (>1% via Caddy-Metriken) umstellen | App #12 | rules.yaml:144 | S |
| 3.5 | Fehlende Alerts: p95-Latenz, Container-Restart-Loop | App #11 | rules.yaml | M |
| 3.6 | Promtail positions aus tmpfs → Named Volume oder Host-Mount | App #13 | promtail-config.yml:5, docker-compose.yml | S |
| 3.7 | `ALERTING_WEBHOOK_URL` in .env.example als Pflichtfeld markieren + check-env ergaenzen | App #4, S-10 | .env.example, Makefile | S |
| 3.8 | Webhook Contact Point: Fallback-Kontaktpunkt konfigurieren (oder zumindest dokumentieren) | App #49 | contactpoints.yaml | S |

**Abhaengigkeiten:** 3.1 vor 3.4 (erst Duplikate entfernen, dann Rules ueberarbeiten)
**Validierung:** `make test-smoke` gruent, Grafana Alerting zeigt alle Regeln als "OK", Webhook erreichbar

---

## Wave 4 — Security Hardening

**Ziel:** Container-Haertung konsistent, Injection gefixt, CSP differenziert.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 4.1 | SQL-Injection Fix: DOMAIN-Validierung + SQL-Escaping in setup-uptime-monitors.sh | App #16, S-04 | scripts/setup-uptime-monitors.sh:56 | S |
| 4.2 | CSP pro Subdomain differenzieren: restriktive CSP fuer niles/garmin/vikunja, laxe nur fuer Grafana/Uptime Kuma | App #7, S-06 | Caddyfile.tmpl:8-18 | M |
| 4.3 | socket-proxy: `cap_drop: [ALL]` hinzufuegen | App #26 | docker-compose.yml:120 | S |
| 4.4 | Grafana: `user: "472:472"` statt `"472:0"` | App #30, S-13 | docker-compose.yml:190 | S |
| 4.5 | Grafana: `read_only: true` + `tmpfs: [/tmp]` | App #24 | docker-compose.yml:186 | S |
| 4.6 | Uptime Kuma: `read_only: true` + tmpfs testen | App #25 | docker-compose.yml:349 | S |
| 4.7 | PII IP-Regex praezisieren (Oktett-Validierung) + IPv6-Regex ergaenzen | App #19, S-11 | promtail-config.yml:43 | S |
| 4.8 | Permissions-Policy erweitern: `payment=(), usb=(), bluetooth=()` | App #23 | Caddyfile.tmpl:13 | S |
| 4.9 | Watchtower: Docker-Socket-Zugriff als akzeptiertes Risiko kommentieren | App #5 | docker-compose.yml:401 | S |
| 4.10 | Uptime Kuma SETUID/SETGID + node-exporter pid:host als akzeptiert kommentieren | S-15, S-16 | docker-compose.yml:358, 237 | S |

**Abhaengigkeiten:** 4.4 erfordert Volume-Permission-Anpassung (`chown 472:472` auf grafana-data)
**Validierung:** `docker compose config --quiet` erfolgreich, `make test-smoke` gruent, ShellCheck/Semgrep clean

---

## Wave 5 — Tests & CI ✅ (PR #55)

**Ziel:** Test-Luecken geschlossen, CI deckt alle kritischen Pfade ab.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 5.1 | ShellCheck scandir: `scripts` → `.` (oder `scripts` + `tests` explizit) | App #17 | ci.yml:27 | S |
| 5.2 | test-dns.sh: Alle 8 Subdomains testen (+ whatsapp, prometheus, metrics) | App #39 | tests/test-dns.sh:27-32 | S |
| 5.3 | test-dns.sh: CoreDNS-Erreichbarkeits-Check als Prerequisite | U-11 | tests/test-dns.sh:1 | S |
| 5.4 | PII-Redaktions-Test: Testlog mit IP/E-Mail einspeisen, Redaktion in Loki verifizieren | App #41 | tests/ (neu) | M |
| 5.5 | Security-Header-Test: Assertions fuer HSTS, CSP, X-Frame-Options im Smoke-Test | App #42 | tests/test-smoke.sh | M |
| 5.6 | Checkov CKV2_GHA_1 Skip mit Inline-Kommentar begruenden | App #43 | ci.yml:139 | S |
| 5.7 | PR Template: "Breaking Changes"-Checkbox ergaenzen | App #44 | pull_request_template.md | S |
| 5.8 | GitHub-native Secret Scanning aktivieren (fuer Public Repo) | App #22 | GitHub Settings | S |
| 5.9 | Repo-Settings pruefen: Squash merge, Delete branch, Dependabot alerts | App #20 | GitHub Settings | S |
| 5.10 | Renovate Digest-Automerge: bewusste Abweichung dokumentieren oder Schedule hinzufuegen | App #21 | renovate.json | S |

**Validierung:** CI gruent mit allen neuen Jobs, `make test` + `make test-smoke` erfolgreich

---

## Wave 6 — Dokumentation & Operator Polish

**Ziel:** Klare Kommunikation, gutes Feedback, Upgrade- und Backup-Pfad.

| # | Task | Quelle | Datei | Aufwand |
|---|------|--------|-------|:-------:|
| 6.1 | `make up` Output: Service-URLs + "Verify/Status"-Hinweise nach Start | U-06 | Makefile:37-45 | S |
| 6.2 | `make generate`: "GENERATED FILE"-Header in generierten Dateien | U-07 | Makefile:12-27 | S |
| 6.3 | `make up`: Fehlerkontext bei Docker-Compose-Fehlern (Troubleshooting-Hinweise) | U-10 | Makefile:40 | S |
| 6.4 | README: Upgrade-Sektion (`git pull && make generate && make up`) | U-13 | README.md | S |
| 6.5 | `make backup` / `make restore` Targets fuer Volume-Sicherung | U-14 | Makefile | M |
| 6.6 | `make down`: Zusammenfassendes Feedback was gestoppt wurde | U-16 | Makefile:47-48 | S |
| 6.7 | UPTIME_KUMA_USERNAME/PASSWORD: Kommentar in .env.example praezisieren ("used by setup-uptime-monitors.sh, not by container") | U-18, App #36 | .env.example:13-14 | S |
| 6.8 | README Quickstart: Tailscale-Admin-Berechtigung erwaehnen | U-15 | README.md | S |
| 6.9 | README: "5 Alert Rules" → "5 Grafana Unified Alerting rules" praezisieren | App #37 | README.md:179 | S |

**Validierung:** `make help` zeigt alle Targets, `make backup` + `make restore` Round-Trip funktioniert

---

## Wave 7 ✅ — Langfristig / Kommerziell

**Ziel:** Weiterverkauf-Readiness, Konfigurierbarkeit, professioneller Betrieb.

| # | Task | Quelle | Datei | Aufwand | Status |
| --- | ------ | -------- | ------- | :-------: | :------: |
| 7.1 | `make dry-run` Target (Preview ohne Deployment) | U-09 | Makefile | S | ✅ |
| 7.2 | CHANGELOG via Release Please Workflow | U-17, App #46 | .github/workflows/ | M | ✅ |
| 7.3 | Caddyfile Backing-Service-URLs als Env-Vars (`NILES_UPSTREAM` etc.) | App #14 | Caddyfile.tmpl | M | ✅ |
| 7.4 | Healthchecks ergaenzen (Watchtower, Tempo); Loki/Promtail distroless dokumentiert | App #15, #27 | docker-compose.yml | M | ✅ |
| 7.5 | `stop_grace_period: 30s` fuer Prometheus, Loki, Grafana | App #28 | docker-compose.yml | S | ✅ |
| 7.6 | Retention als Env-Vars mit Defaults (Prometheus, Loki) | App #29 | docker-compose.yml | S | ✅ |
| 7.7 | Caddy Rate Limiting evaluieren | App #32 | — | M | Closed |
| 7.8 | OAuth2/OIDC evaluieren | App #31 | — | L | Closed |
| 7.9 | CD-Pipeline evaluieren | App #45 | — | L | Closed |
| 7.10 | mTLS intern evaluieren | S-12 | — | L | Closed |
| 7.11 | COMPOSE_PROJECT_NAME in .env.example | App #54 | .env.example | S | ✅ |
| 7.12 | HTTP-to-HTTPS Redirect (Port 80) | App #53 | docker-compose.yml, Caddyfile.tmpl | S | ✅ |
| 7.13 | Tempo: Tracing-Beispielkonfiguration dokumentieren | App #48 | README.md | M | ✅ |
| 7.14 | Prometheus Self-Monitoring (`job_name: prometheus`) | App #50 | prometheus.yml | S | ✅ |
| 7.15 | Kosmetik-Batch: docs/ entfernen, SENTRY_DSN entfernen, Test-DRY (lib.sh), Subdomain-Regex, Tempo OTLP Kommentar, CoreDNS Log Rotation, PID Kommentar | App #33-#51, S-14 | diverse | M | ✅ |

### Decision Records (7.7–7.10)

Alle vier Evaluierungs-Tasks wurden als **nicht noetig** fuer den aktuellen Betrieb bewertet:

| Task | Thema | Entscheidung |
| ------ | ------- | ------------- |
| 7.7 | Caddy Rate Limiting | Nicht noetig — Tailscale-only, kein oeffentlicher Traffic. Caddy-ratelimit Plugin bleibt Option fuer spaeter. |
| 7.8 | OAuth2/OIDC (Authelia) | Nicht noetig — Tailscale ACLs + Caddy basicauth reicht fuer Single-User-Homelab. |
| 7.9 | CD-Pipeline (SSH-Deploy/GitOps) | Nicht noetig — Single-Node-Setup, `git pull && make up` reicht. |
| 7.10 | mTLS intern | Nicht noetig — Single-Host, Docker-Netzwerk isoliert, kein Multi-Node-Betrieb geplant. |

Volume-Namenskonvention (#33) wurde bewusst uebersprungen: Volume-Rename erfordert Datenmigration aller bestehenden Installationen. Kosmetischer Nutzen rechtfertigt das Risiko nicht.

**Validierung:** `make test` (21/21), `docker compose config`, `shellcheck -x`, `make dry-run`

---

## Compliance-Abdeckung

| Regulation | Finding | Abgedeckt in Wave |
|------------|---------|:-----------------:|
| DSGVO Art. 32 (Technische Massnahmen) | C-01: PII-Redaktion unvollstaendig | Wave 3 (3.2) + Wave 4 (4.7) |
| DSGVO Art. 33 (Breach Notification) | C-04: Alerting nicht funktional | Wave 3 (3.1-3.8) |
| ISO 27001 A.8.15 (Logging) | C-02: Kein Security-Event-Logging | Wave 3 (3.3) |
| ISO 27001 A.8.29 (Security Testing) | C-03: Kein DAST, Trivy non-blocking | Wave 1 (1.1) + Wave 5 (5.4-5.5) |
| EU AI Act | Nicht anwendbar | — |

---

## Abhaengigkeits-Graph

```
Wave 1 (CI + Secrets)
  │
  ├──→ Wave 2 (Onboarding)     ← kann parallel zu Wave 1 starten
  │
  ├──→ Wave 3 (Alerting)       ← nach Wave 1 (Secrets muessen migriert sein)
  │         │
  │         └──→ Wave 4 (Hardening)  ← nach Wave 3 (PII-Regex haengt von Labels ab)
  │                   │
  │                   └──→ Wave 5 (Tests)  ← nach Wave 4 (Tests pruefen Security-Fixes)
  │
  └──→ Wave 6 (Doku)           ← nach Wave 2 (Makefile muss stabil sein)
              │
              └──→ Wave 7 (Kommerziell)  ← nach Wave 6
```

Empfehlung: **Wave 1 + Wave 2 parallel starten.** Wave 1 auf einem Feature-Branch, Wave 2 direkt auf main (risikoarme Quick-Wins).

---

## Statistik nach Quelle

| Quelle | Roh-Findings | Davon Unique | In Plan |
|--------|:------------:|:------------:|:-------:|
| review-app-report.md | 54 | 39 | 39 |
| review-secure-report.md | 20 | 14 | 14 |
| review-ux-report.md | 17 | 14 | 14 |
| **Gesamt** | **91** | **67** | **67** |

Duplikate (24): Trivy (App/Secure), CSP (App/Secure), check-env (App/Secure/UX), monitoring-Labels (App/Secure), IP-Regex (App/Secure), SQL-Injection (App/Secure), include .env (App/UX), Alert-Void (App/Secure), Grafana GID (App/Secure), CADDY_AUTH (Secure/UX), und weitere Ueberlappungen.

---

*Erstellt auf Basis der drei Review-Reports vom 2026-06-09.
Generiert mit AI-Unterstuetzung (Claude Code + dev-best-practices plugin).*
