# Umsetzungsplan — homelab-gateway

**Erstellt:** 2026-06-08
**Basis:** review-app-report.md (62 Findings) + review-secure-report.md (24 Findings)
**Strategie:** 8 PRs in aufsteigender Risiko-Reihenfolge — Security first, dann Hardening, dann Quality of Life

---

## Übersicht

| Wave | PR | Thema | Findings | Effort | Dateien |
|:---:|---|---|:---:|:---:|:---:|
| 1 | ~~PR-01~~ [#25](https://github.com/gerfru/homelab-gateway/pull/25) ✅ | ~~GitHub Repo Security Gates~~ | 7 | S | GitHub Settings, ci.yml, dependabot.yml, renovate.json |
| 2 | PR-02 | Container Hardening (docker-compose) | 12 | S | docker-compose.yml |
| 3 | PR-03 | Caddy Template + Config Hygiene | 8 | S | Caddyfile.tmpl, Makefile, docker-compose.yml |
| 4 | PR-04 | CI Pipeline Erweiterung (Trivy, Semgrep, PII) | 6 | M | ci.yml, .pre-commit-config.yaml |
| 5 | PR-05 | Observability: Alerting + Scrape Coverage | 8 | M | prometheus.yml, alert-rules.yml, promtail-config.yml, docker-compose.yml, Grafana Dashboards |
| 6 | PR-06 | Code Quality + Cleanup | 10 | S | scripts/check-pii.sh, Makefile, homelab-overview.json, requirements.txt, loki.yml |
| 7 | PR-07 | Testing Foundation | 7 | M | tests/, ci.yml, .pre-commit-config.yaml, Makefile |
| 8 | PR-08 | Long-term: Deployment, Tracing, Error Tracking | 4 | L | docker-compose.yml, ci.yml, Makefile |

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

## Wave 2 — PR-02: Container Hardening

**Priorität:** 🔴 CRITICAL + 🟠 HIGH — Sicherheitslücken schließen
**Begründung:** Docker Socket, fehlende Health Checks und ungehärtete Container sind die größten Angriffsflächen.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| C-01 | Docker socket in Promtail | Critical (ISEC) | Docker-Socket-Proxy (Tecnativa) einführen ODER auf file-based Scraping umstellen |
| C-02 | node-exporter mountet gesamtes Host-FS | Critical (ISEC) | `/` durch `/proc`, `/sys`, `/rootfs` ersetzen + command flags |
| 8 | Health checks auf 7/8 Services fehlen | High | healthcheck-Blöcke für alle Services |
| 19 | Promtail läuft als root | Medium | `user: "10001:10001"` |
| 20 | Uptime Kuma: cap_drop + root | Medium | `cap_drop: ALL`, `user: "1000:1000"` |
| 21 | CoreDNS: cap_drop fehlt | Medium | `cap_drop: ALL`, `cap_add: NET_BIND_SERVICE` |
| 24 | Caddy: Resource Limits fehlen | Medium | `deploy.resources.limits: 256m / 0.50` |
| 25 | CoreDNS: Resource Limits fehlen | Medium | `deploy.resources.limits: 64m / 0.10` |
| 28 | CoreDNS: Log Rotation fehlt | Medium | `logging: json-file, 5m, 2 files` |
| 29 | depends_on ohne service_healthy | Medium | `condition: service_healthy` (nach Health Checks) |
| 49 | read_only: true nicht gesetzt | Low | `read_only: true` + `tmpfs` für `/tmp` wo möglich |
| 50 | Uptime Kuma: cap_drop fehlt | Low | (zusammen mit #20) |

### Betroffene Dateien
```
docker-compose.yml               → Hauptarbeit (alle Services)
monitoring/promtail-config.yml    → falls Umstellung auf file-based Scraping
```

### Reihenfolge innerhalb des PRs
1. Docker-Socket-Proxy oder file-based Scraping für Promtail
2. node-exporter Volume-Mounts einschränken
3. Health Checks für alle Services hinzufügen
4. cap_drop + user für CoreDNS, Uptime Kuma, Promtail
5. Resource Limits für Caddy + CoreDNS
6. Log Rotation für CoreDNS
7. depends_on mit condition: service_healthy
8. read_only: true wo möglich

### Validierung
- [ ] `docker compose up -d` startet ohne Fehler
- [ ] `docker compose ps` zeigt alle Services als "healthy"
- [ ] `docker exec gateway-promtail cat /var/run/docker.sock` schlägt fehl (kein direkter Socket-Zugriff)
- [ ] `docker inspect gateway-caddy | jq '.[0].HostConfig.Memory'` zeigt Limit

---

## Wave 3 — PR-03: Caddy Template + Config Hygiene

**Priorität:** 🟡 MEDIUM — 12-Factor Compliance + DRY
**Begründung:** Hardcoded Domain verhindert Portabilität und widerspricht 12-Factor.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| H-01 | CoreDNS Linux Corefile: bind fehlt | High (ISEC) | `bind ${TAILSCALE_IP}` in `dns/Corefile.tmpl` |
| 18 | CSP Header fehlt | Medium | `Content-Security-Policy` in `(security_headers)` Snippet |
| 26 | Grafana ROOT_URL hardcoded | Medium | `GF_SERVER_ROOT_URL=https://logs.${DOMAIN}` |
| 27 | Caddyfile.tmpl hardcodes home.lab | Medium | Alle `home.lab` → `${DOMAIN}`, Makefile: `envsubst` statt `cp` |
| 30 | Caddyfile.tmpl Naming-Mismatch | Medium | (zusammen mit #27) |
| 31 | Caddy Log Block 6× dupliziert | Medium | `(common_log)` Snippet extrahieren |
| 43 | Promtail: monitoring=true Label fehlt auf Services | Medium | Label auf alle Services in docker-compose.yml |
| 45 | Promtail Version 3.0.0 hinter Loki 3.7.2 | Medium | Update auf `grafana/promtail:3.7.2@sha256:...` |

### Betroffene Dateien
```
dns/Corefile.tmpl                → bind-Direktive hinzufügen
Caddyfile.tmpl                   → ${DOMAIN}, CSP, (common_log) Snippet
Makefile                         → envsubst statt cp für Caddyfile
docker-compose.yml               → GF_SERVER_ROOT_URL, monitoring Labels, Promtail Image
.env.example                     → ggf. GF_ROOT_URL dokumentieren
```

### Validierung
- [ ] `make generate` erzeugt korrekte Caddyfile mit substituierten Domains
- [ ] `grep 'home\.lab' Caddyfile` findet Einträge (aus ${DOMAIN}=home.lab)
- [ ] `grep '\${' Caddyfile` findet KEINE nicht-substituierten Variablen
- [ ] `dig @${TAILSCALE_IP} niles.home.lab` funktioniert
- [ ] CSP Header sichtbar: `curl -kI https://niles.home.lab`

---

## Wave 4 — PR-04: CI Pipeline Erweiterung

**Priorität:** 🟡 MEDIUM — Security Scanning Gates
**Begründung:** Trivy, Semgrep und PII-Check schließen die verbleibenden CI-Lücken.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| 2 | Kein Trivy Container Scanning | Critical | Trivy Job: alle Images aus docker-compose.yml scannen |
| 9 | Kein Semgrep SAST | High | `semgrep/semgrep-action` hinzufügen |
| 10 | Keine SBOM-Generierung | High | `syft` Job auf Tag-Push |
| 23 | Trivy in CI fehlt (Security-Axis) | Medium | (zusammen mit #2) |
| 48 | Kein IaC Scanning | Low | `checkov` oder `kics` als optionaler Job |
| 33 | Pre-commit Hook Order | Medium | Dokumentieren oder anpassen |

### Betroffene Dateien
```
.github/workflows/ci.yml         → Trivy, Semgrep, PII-Check Jobs
.github/workflows/release.yml    → neu (SBOM auf Tag-Push)
.pre-commit-config.yaml          → Reihenfolge dokumentieren
```

### CI Job Skizze: Trivy
```yaml
trivy:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@...
    - name: Extract images from docker-compose
      run: grep 'image:' docker-compose.yml | awk '{print $2}' > images.txt
    - name: Scan images
      run: |
        while read img; do
          trivy image --severity CRITICAL,HIGH --exit-code 1 "$img"
        done < images.txt
```

### Validierung
- [ ] CI Pipeline hat Jobs: trivy, semgrep, pii-check
- [ ] Trivy scannt alle 8 Images
- [ ] Semgrep läuft auf Shell-Scripts und YAML
- [ ] SBOM wird bei Tag-Push generiert

---

## Wave 5 — PR-05: Observability — Alerting + Scrape Coverage

**Priorität:** 🟡 MEDIUM — Monitoring operationalisieren
**Begründung:** Monitoring ohne Alerting ist nur Logging mit UI.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| 4 | Keine Prometheus Alert Rules | Critical | `monitoring/alert-rules.yml` erstellen |
| 5 | Kein Alertmanager / Notification Channel | Critical | Grafana Unified Alerting mit Contact Point (Telegram/Email) |
| 16 | Prometheus scrapes nur node-exporter | High | Scrape Targets: caddy:2019, loki:3100, grafana:3000, promtail:9080 |
| 32 | Inkonsistente Error-Regex in Grafana Panels | Medium | `traceback` zu Panels 4 und 6 hinzufügen |
| 44 | Grafana: Latency/Traffic Panels fehlen | Medium | Panels für Request-Rate, p95 Latenz, Error Rate (basierend auf Caddy Metrics) |
| 46 | CoreDNS: Logging + Resource Limits fehlen | Medium | (bereits in PR-02 abgedeckt — hier nur Cross-Reference) |
| H-04 | PII in Logs ohne Scrubbing (GDPR) | High (ISEC) | Promtail Pipeline: replace-Stages für IPs und Emails |
| 61 | Loki Retention nur 7 Tage | Low | Auf 14 Tage erhöhen (wenn Disk es erlaubt) |

### Betroffene Dateien
```
monitoring/prometheus.yml                                → rule_files + alerting section
monitoring/alert-rules.yml                               → neu
monitoring/promtail-config.yml                           → PII-Redaction Pipeline Stages
monitoring/grafana/provisioning/dashboards/json/
  homelab-overview.json                                  → Error Regex fix + neue Panels
  system-monitoring.json                                 → ggf. Alert-Annotations
monitoring/loki-config.yml                               → Retention 14d (optional)
```

### Alert Rules Skizze
```yaml
groups:
  - name: homelab
    rules:
      - alert: HighCPU
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels: { severity: warning }
        annotations: { summary: "CPU > 80% für 5 Minuten" }
      - alert: HighMemory
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 80
        for: 5m
        labels: { severity: warning }
      - alert: DiskAlmostFull
        expr: (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 > 85
        for: 10m
        labels: { severity: critical }
```

### Validierung
- [ ] `curl http://localhost:9090/api/v1/rules` zeigt Alert Rules
- [ ] Prometheus Targets Page: 5+ Targets (node, caddy, loki, grafana, promtail)
- [ ] Grafana: Alerting → Contact Points konfiguriert
- [ ] Promtail: IP-Adressen in Loki als `[IP_REDACTED]` sichtbar
- [ ] Grafana Panels 2, 4, 6 zeigen konsistente Error-Counts

---

## Wave 6 — PR-06: Code Quality + Cleanup

**Priorität:** 🔵 LOW — Hygiene
**Begründung:** Technische Schulden abbauen, bevor Testing aufgebaut wird.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| H-02 | Weak Default Credentials in .env.example | High (ISEC) | `changeme` → `CHANGE_ME_BEFORE_DEPLOY` + Makefile-Validierung |
| H-03 | Makefile: include .env + export leakt Secrets | High (ISEC) | Blanket `export` entfernen, `--env-file` für Docker Compose |
| 51 | Orphaned requirements.txt | Low | Löschen (kein Python-Code im Repo) |
| 52 | Bash echo piped to grep | Low | `[[ "$match" =~ $pattern ]]` |
| 53 | grep ohne -- Separator | Low | `grep -oE -- "$REGEX"` |
| 54 | Makefile: recursive make call | Low | `$(MAKE)` statt `make` |
| 55 | .PHONY unvollständig | Low | `logs-caddy logs-dns` hinzufügen |
| 56 | Grafana datasource uid leer | Low | `uid: loki` in loki.yml + Dashboard-Referenzen |
| 60 | Uptime Kuma: Major-Version Tag :1 | Low | Spezifisches Semver-Tag neben Digest |
| 34 | TruffleHog statt gitleaks | Medium | Deviation dokumentieren in CLAUDE.md |

### Betroffene Dateien
```
.env.example                                     → Placeholder-Credentials
Makefile                                          → export entfernen, $(MAKE), .PHONY
scripts/check-pii.sh                              → Bash-Verbesserungen
requirements.txt                                  → löschen
monitoring/grafana/provisioning/datasources/loki.yml → uid: loki
monitoring/grafana/provisioning/dashboards/json/
  homelab-overview.json                           → uid-Referenzen
docker-compose.yml                                → Uptime Kuma Image-Tag
CLAUDE.md                                         → Deviation: TruffleHog statt gitleaks
```

### Validierung
- [ ] `make up` mit `GF_ADMIN_PASSWORD=changeme` → Fehler
- [ ] `make up` mit korrektem Passwort → Erfolg
- [ ] `shellcheck scripts/check-pii.sh` → 0 Warnungen
- [ ] `requirements.txt` existiert nicht mehr
- [ ] Grafana Datasource "Loki" hat uid `loki`

---

## Wave 7 — PR-07: Testing Foundation

**Priorität:** 🔵 LOW-MEDIUM — Rotes Licht auf Grün bringen
**Begründung:** Tests-Achse ist ROT. Mindestens Config-Validierung und Smoke Tests sollten existieren.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| 6 | Zero automated tests | Critical | `tests/` Verzeichnis + Test-Framework |
| 12 | Keine DNS-Resolution-Tests | High | `tests/test-dns.sh` mit Assertions |
| 40 | Template-Generation ohne Validierung | Medium | `tests/test-generate.sh` — Golden-File Test |
| 41 | make test-dns nicht in CI | Medium | CI Job für DNS-Tests (nach Stack-Start) |
| 42 | Kein Monitoring-Pipeline Smoke Test | Medium | `tests/test-monitoring.sh` — Log → Loki → Query |
| 58 | Kein pre-commit Hook für compose/Caddy | Low | Lokale Hooks: `docker compose config`, `caddy validate` |
| 11 | CI hat keine Behavioral Tests | High | Integration-Test Job (Stack starten, Assertions) |

### Betroffene Dateien
```
tests/                            → neu
  test-generate.sh                → Golden-File Test für envsubst
  test-dns.sh                     → DNS Resolution Assertions
  test-monitoring.sh              → Promtail→Loki Smoke Test
  test-stack.sh                   → Integration: Stack starten, Health Checks, Routing
.github/workflows/ci.yml          → Integration-Test Job
.pre-commit-config.yaml           → compose config + caddy validate Hooks
Makefile                           → test Target(s) hinzufügen
```

### Test-Strategie
```
tests/
├── test-generate.sh        # Unit: Template → Output korrekt?
├── test-dns.sh             # Unit: dig-Assertions (braucht laufenden CoreDNS)
├── test-monitoring.sh      # Integration: Log schreiben → Loki abfragen
└── test-stack.sh           # E2E: docker compose up → health checks → curl routing
```

### Validierung
- [ ] `make test` läuft lokal durch
- [ ] CI Integration-Test Job grün
- [ ] Pre-commit: `docker compose config` fängt Syntaxfehler ab
- [ ] tests/ Verzeichnis hat mindestens 3 Test-Skripte

---

## Wave 8 — PR-08: Long-term (Optional / Backlog)

**Priorität:** ⚪ BACKLOG — Kein sofortiger Handlungsbedarf
**Begründung:** Diese Items sind „nice to have" für ein Solo-Homelab. Umsetzung wenn Zeit und Bedarf.

### Findings

| # | Finding | Severity | Aktion |
|---|---------|----------|--------|
| 14 | Kein OpenTelemetry / Tracing | High | OTEL Collector Container, Caddy Tracing Plugin |
| 15 | Kein Sentry / Error Tracking | High | GlitchTip self-hosted oder Sentry Cloud Free Tier |
| 39 | Keine Deployment-Pipeline | Medium | Watchtower oder SSH-Deploy on merge-to-main |
| 22 | Kein Caddy-Level Auth | Medium | forward_auth mit Tailscale Header oder basicauth |
| 47 | Loki Auth nur Tenant-Header | Low | Auth-Proxy vor Loki (wenn Multi-User) |
| 59 | Uptime Kuma Config nicht versioniert | Low | API-Export als JSON + git-tracked |

### Betroffene Dateien
```
docker-compose.yml               → OTEL Collector, GlitchTip, Watchtower
Caddyfile.tmpl                   → forward_auth / basicauth
.github/workflows/deploy.yml     → neu (SSH-Deploy)
Makefile                          → make deploy Target
```

---

## Zusammenfassung: Erwarteter Zustand nach allen Waves

| Axis | Vorher | Nach Wave 1-7 | Nach Wave 8 |
|------|:---:|:---:|:---:|
| Architecture & 12-Factor | 🟡 | 🟢 | 🟢 |
| Security (ASVS L1) | 🟡 | 🟢 | 🟢 |
| Code Quality | 🟡 | 🟢 | 🟢 |
| Tests & Reliability | 🔴 | 🟡 | 🟢 |
| CI/CD & Delivery | 🔴 | 🟢 | 🟢 |
| Observability & Ops | 🟡 | 🟢 | 🟢 |

**Erwartetes Gesamtergebnis nach Wave 7:** 5× 🟢, 1× 🟡 (Tests — volle Behavioral Tests brauchen mehr Zeit)
**Nach Wave 8:** 6× 🟢

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
