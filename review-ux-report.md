# UX Review: homelab-gateway (Operator Experience)

Date: 2026-06-09
Framework basis: HAX (18 Guidelines) · PAIR (23 Patterns) · CHI 2024 (6 Principles) · NNG
Adaptiert für: CLI/DevOps-Tool (kein AI-System — Frameworks auf Operator Experience angewandt)

---

## Detected Context

| Feld | Wert |
|------|------|
| Type | CLI/DevOps-Tool (IaC via Docker Compose + Makefile) |
| AI involvement | Keine — reine Infrastruktur |
| User type | Self-hosting DevOps-Operators (Experten); bei Weiterverkauf: potenziell weniger technische Admins |
| Phase | Production (deployed, in Benutzung) |
| Channel | Terminal/CLI (Makefile) + Web-Dashboards (Grafana, Uptime Kuma, Prometheus) |

**Hinweis:** Da kein AI-System vorliegt, werden die HAX/PAIR/CHI-Dimensionen 1-5 auf die **Operator Experience** adaptiert: Onboarding, Feedback, Fehlerbehandlung, Kontrolle, Langzeitwartung. Dimension 6 (Anti-Patterns) und 7 (Dark Patterns) bleiben unverändert.

---

## Positive Highlights

Bevor die Findings kommen — was bereits gut funktioniert:

- **README-Qualität**: Exzellentes Opening ("Your infrastructure. Your network. One `make up`."), klare ASCII-Architekturdiagramme, vollständige Commands-Tabelle, "Adding a service"-Anleitung, Rollback-Sektion. Besser als 90% der Self-hosted-Projekte auf GitHub.
- **OS-Transparenz**: `make up` erkennt macOS/Linux automatisch und erklärt warum (`Platform notes`-Tabelle). Kein "works on my machine"-Problem.
- **Test-Feedback**: `test-dns.sh`, `test-smoke.sh` und `test-generate.sh` liefern klare PASS/FAIL-Ausgaben pro Check mit diff-Output bei Fehlern.
- **Fail-Fast-Prinzip**: `set -euo pipefail` in allen Scripts, `check-env` als Prerequisite von `make up`.
- **Template-System**: `envsubst`-basierte Konfiguration (Caddyfile.tmpl, Corefile.tmpl, zone.tmpl) ist verständlich und debugbar.
- **Sicherheits-Kommunikation**: README Security-Sektion, PR-Template mit Security-Checkliste, .env.example mit klaren Kommentaren.

---

## Resolution Status (Stand: Wave 6, PR #57)

| # | Finding | Severity | Status | Resolved in |
|---|---------|----------|:------:|-------------|
| U-01 | Kein `make help` | High | ✅ | Wave 2, PR #51 |
| U-02 | `make clean` ohne Bestaetigung | High | ✅ | Wave 2, PR #51 |
| U-03 | `include .env` fresh clone | High | ✅ | Wave 2, PR #51 |
| U-04 | CADDY_AUTH Onboarding | High | ✅ | Wave 2, PR #51 |
| U-05 | Prerequisites fehlen | Medium | ✅ | Wave 2, PR #51 |
| U-06 | `make up` kein Status | Medium | ✅ | Wave 6, PR #57 |
| U-07 | `make generate` ueberschreibt | Medium | ✅ | Wave 6, PR #57 |
| U-08 | `check-env` unvollstaendig | Medium | ✅ | Wave 2, PR #51 |
| U-09 | Kein Dry-Run | Medium | — | Wave 7 |
| U-10 | Kein Fehlerkontext | Medium | ✅ | Wave 6, PR #57 |
| U-11 | test-dns CoreDNS-Check | Medium | ✅ | Wave 5, PR #55 |
| U-12 | sudo ohne Vorwarnung | Medium | ✅ | Wave 2, PR #51 |
| U-13 | Kein Upgrade-Pfad | Medium | ✅ | Wave 6, PR #57 |
| U-14 | Kein Backup/Restore | Medium | ✅ | Wave 6, PR #57 |
| U-15 | Tailscale-Admin-Berechtigung | Low | ✅ | Wave 6, PR #57 |
| U-16 | `make down` ohne Feedback | Low | ✅ | Wave 6, PR #57 |
| U-17 | Kein CHANGELOG | Low | — | Wave 7 |
| U-18 | UPTIME_KUMA Credentials misleading | Low | ✅ | Wave 6, PR #57 |

**Resolved: 15/17 (88%)** — Verbleibend: U-09 (Dry-Run), U-17 (CHANGELOG)

---

## Traffic Light Overview

| Dimension | Status | #High | #Medium | Meistverletzte Guideline |
|-----------|--------|-------|---------|--------------------------|
| 1 — Expectations & Mental Models | 🟢 | 0 | 0 | Alle behoben (Prerequisites, CADDY_AUTH, Tailscale-Admin) |
| 2 — Trust & Transparency | 🟢 | 0 | 0 | Alle behoben (clean Bestaetigung, GENERATED Header) |
| 3 — Feedback & User Control | 🟢 | 0 | 0 | Alle behoben (make help, Service-URLs, Fehlerkontext) |
| 4 — Error Handling & Graceful Failure | 🟢 | 0 | 0 | Alle behoben (-include .env, CoreDNS-Check, Troubleshooting) |
| 5 — Long-term & Adaptation | 🟢 | 0 | 1 | U-09 Dry-Run (Wave 7) |
| 6 — Anti-Pattern Check | 🟢 | 0 | 0 | — |
| 7 — Dark Patterns | 🟢 | 0 | 0 | — |

---

## Top-3 Quick Wins

1. **`make help` Target** · HAX G17 · Effort: S (15 Zeilen) · Automatisch generierte Kommando-Übersicht direkt im Terminal — eliminiert den häufigsten Friktionspunkt für neue User.

2. **`-include .env` statt `include .env`** · PAIR P18 · Effort: S (1 Zeichen) · Verhindert den sofortigen Fehler auf frischem Clone — der häufigste Erstnutzer-Abbruchgrund.

3. **`make clean` mit Bestätigung** · HAX G11 · Effort: S (5 Zeilen) · `read -p "Destroy all volumes? [y/N]"` vor `docker compose down -v` — verhindert versehentlichen Datenverlust.

---

## Full Finding List

### High (4)

---

**[U-01] Kein `make help` — Operatoren haben keine Kommando-Discovery**
HAX G17 (Global Controls) · High

**Finding:** `make` ohne Target gibt einen Fehler. Es gibt kein `help`-Target. Neue Operatoren müssen README oder Makefile-Source lesen, um verfügbare Kommandos zu entdecken. Die README Commands-Tabelle ist gut, aber im Terminal nicht verfügbar.

**Fix:**
```makefile
.DEFAULT_GOAL := help

help: ## Show available commands
	@echo "homelab-gateway — available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
		| awk -F ':.*## ' '{printf "  make %-20s %s\n", $$1, $$2}'
```

Dann jeden Target kommentieren: `up: check-env generate dns-up ## Start gateway (CoreDNS + Caddy + monitoring)`

---

**[U-02] `make clean` zerstört alle Volumes ohne Bestätigung**
HAX G11 (Consequences) · High

**Finding:** `make clean` führt `docker compose down -v` aus — löscht unwiderruflich alle Named Volumes: grafana-data (Dashboards, Alerting-Config), prometheus-data (30 Tage Metriken), loki-data (Logs), uptime-kuma-data (Monitore + Status-Historie), caddy_data (TLS-Zertifikate), tempo-data (Traces). Kein Bestätigungs-Prompt, kein `--dry-run`, keine Warnung.

**Für Weiterverkauf:** Ein Operator, der "aufräumen" will, verliert die gesamte Monitoring-Historie.

**Fix:**
```makefile
clean: dns-down ## Stop + remove all data (DESTRUCTIVE — asks for confirmation)
	@echo "WARNING: This will delete ALL monitoring data:"
	@echo "  - Grafana dashboards and alert history"
	@echo "  - Prometheus metrics (30d)"
	@echo "  - Loki logs"
	@echo "  - Uptime Kuma monitors and history"
	@echo "  - Caddy TLS certificates"
	@echo ""
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && \
		[ "$$confirm" = "yes" ] || (echo "Aborted."; exit 1)
	docker compose down -v
	rm -f dns/Corefile dns/home.lab.zone Caddyfile
```

---

**[U-03] `include .env` scheitert auf frischem Clone**
PAIR P18 (Graceful Fallback) · High

**Finding:** Makefile Zeile 3: `include .env`. Auf einem frischen `git clone` existiert `.env` nicht. Make gibt `Makefile:3: .env: No such file or directory` aus und bricht ab — noch bevor der User irgendetwas tun kann. Dies ist der wahrscheinlichste erste Kontakt mit dem Projekt und er scheitert sofort.

**Fix:**
```makefile
-include .env    # Optionales Include — fehlt .env, funktioniert make help trotzdem
export DOMAIN TAILSCALE_IP
```

Zusätzlich: `make up` und `make generate` sollten prüfen, ob `.env` existiert:
```makefile
check-env:
	@if [ ! -f .env ]; then \
		echo "ERROR: .env not found. Run: cp .env.example .env"; \
		exit 1; \
	fi
	@if grep -qE '(changeme|CHANGE_ME_BEFORE_DEPLOY)' .env; then \
		echo "ERROR: Default passwords detected in .env — please change before deploying."; \
		exit 1; \
	fi
```

---

**[U-04] CADDY_AUTH-Wichtigkeit im Onboarding nicht kommuniziert**
HAX G2 (Communicate Quality/Limitations) · High

**Finding:** In `.env.example` sind `CADDY_AUTH_USER` und `CADDY_AUTH_PASS_HASH` auskommentiert mit dem Kommentar "Optional". Im README Quickstart werden sie nur als "Optional: basicauth" erwähnt. Die Konsequenz (Prometheus und Caddy-Metriken ohne Authentifizierung zugänglich) wird nicht kommuniziert. Der User überspringt sie, weil "optional" = "unwichtig" signalisiert.

**Für Weiterverkauf:** Operator exponiert ungeschützte Prometheus-UI mit Hostnamen, IPs, Container-Infos.

**Fix:**
README Quickstart ergänzen:
```markdown
# Required for secure monitoring access:
CADDY_AUTH_USER=admin
CADDY_AUTH_PASS_HASH='<generate with command below>'
# ⚠️ Without these, prometheus.home.lab and metrics.home.lab are accessible without password
```

---

### Medium (9)

---

**[U-05] Prerequisites nicht aufgelistet**
HAX G1 (Capabilities) · Medium

**Finding:** README Quickstart beginnt mit `cp .env.example .env` ohne Prerequisites-Sektion. Benötigt werden: Docker (+ Compose v2), Tailscale (installiert + verbunden), `envsubst` (Teil von gettext), `dig` (für test-dns), `jq` (für test-smoke), `brew` (macOS für CoreDNS). Ein User auf einem frischen System weiß nicht, was zu installieren ist.

**Fix:**
```markdown
## Prerequisites

- [Docker](https://docs.docker.com/install/) with Compose v2
- [Tailscale](https://tailscale.com/download) (installed, logged in, connected)
- `envsubst` (usually pre-installed; macOS: `brew install gettext`)
- `dig` + `jq` (for tests only: `brew install bind jq` / `apt install dnsutils jq`)
```

---

**[U-06] `make up` gibt keinen Status-Überblick**
HAX G16 (Show Consequences of Actions) · Medium

**Finding:** Nach `make up` sieht der User nur "Gateway running. Test with: make test-dns". Keine Information darüber, welche Container gestartet wurden, ob alle gesund sind, oder welche URLs verfügbar sind. Vergleich: `docker compose up` zeigt Container-Erstellung.

**Fix:**
```makefile
up: check-env generate dns-up
	...
	docker compose --env-file .env up -d
	@echo ""
	@echo "Gateway running. Services:"
	@echo "  https://logs.$(DOMAIN)        Grafana"
	@echo "  https://status.$(DOMAIN)      Uptime Kuma"
	@echo "  https://prometheus.$(DOMAIN)  Prometheus"
	@echo ""
	@echo "Verify: make test-dns"
	@echo "Status: make status"
```

---

**[U-07] `make generate` überschreibt stillschweigend**
HAX G11 (Consequences) · Medium

**Finding:** `make generate` überschreibt Caddyfile, dns/Corefile und dns/home.lab.zone ohne Warnung. Wenn ein User manuell an den generierten Dateien editiert hat (z.B. Quick-Fix in der Caddyfile), gehen die Änderungen verloren. Es gibt keinen Hinweis, dass diese Dateien generiert sind und nicht manuell editiert werden sollen.

**Fix:**
1. Generierte Dateien mit Header kommentieren:
```
# GENERATED FILE — do not edit. Modify Caddyfile.tmpl instead.
# Regenerate with: make generate
```
2. Alternativ: Warnung wenn Datei manuell modifiziert wurde (Checksum-Vergleich).

---

**[U-08] `check-env` unvollständig — prüft nicht alle Pflichtfelder**
HAX G10 (Restrict when uncertain) · Medium

**Finding:** `check-env` prüft nur auf `CHANGE_ME_BEFORE_DEPLOY`/`changeme`. Nicht geprüft werden: fehlende `.env`-Datei (siehe U-03), leere `TAILSCALE_IP`, leere `DOMAIN`, fehlende `GF_ADMIN_*`-Variablen, ungültiges IP-Format. Ein User mit `TAILSCALE_IP=100.x.x.x` (Placeholder!) passiert den Check und bekommt einen kryptischen Docker-Fehler.

**Fix:**
```makefile
check-env:
	@if [ ! -f .env ]; then echo "ERROR: .env not found. Run: cp .env.example .env"; exit 1; fi
	@if grep -qE '(changeme|CHANGE_ME_BEFORE_DEPLOY)' .env; then \
		echo "ERROR: Default passwords in .env"; exit 1; fi
	@if grep -q 'TAILSCALE_IP=100\.x\.x\.x' .env; then \
		echo "ERROR: TAILSCALE_IP still contains placeholder. Run: tailscale ip -4"; exit 1; fi
```

---

**[U-09] Kein Dry-Run-Modus**
PAIR P17 (Automation Level) · Medium

**Finding:** `make up` deployt sofort. Kein Preview, was passieren wird (welche Container starten, welche Ports belegt werden, welche Netzwerke erstellt werden). Für kommerzielle Kunden relevant: Operatoren wollen vor dem Deployment validieren.

**Fix:**
```makefile
dry-run: check-env generate ## Preview what 'make up' would do
	@echo "Dry run — the following would be deployed:"
	@docker compose --env-file .env config --services | sort
	@echo ""
	@echo "Ports:"
	@docker compose --env-file .env config --format json | jq -r '.services[].ports[]? | "\(.published):\(.target)"' 2>/dev/null || true
	@echo ""
	@echo "Run 'make up' to deploy."
```

---

**[U-10] Kein Fehlerkontext bei Docker-Compose-Fehlern**
PAIR P18 (Graceful Failure) · Medium

**Finding:** Wenn `docker compose up -d` fehlschlägt (Port-Konflikt, Image-Pull-Fehler, OOM), gibt das Makefile den Docker-Fehler weiter — aber keine Guidance. Der User sieht z.B. `bind: address already in use` ohne zu wissen, welcher Prozess Port 443 belegt.

**Fix:**
```makefile
up: check-env generate dns-up
	...
	docker compose --env-file .env up -d || { \
		echo ""; \
		echo "Deployment failed. Common causes:"; \
		echo "  - Port 443 already in use: lsof -i :443"; \
		echo "  - Docker not running: docker info"; \
		echo "  - Image pull failed: docker compose pull"; \
		echo "  - Logs: docker compose logs --tail=20"; \
		exit 1; \
	}
```

---

**[U-11] `make test-dns` prüft nicht ob CoreDNS läuft**
PAIR P18 (Graceful Failure) · Medium

**Finding:** `test-dns.sh` erfordert einen laufenden CoreDNS. Ist er nicht gestartet, gibt `dig` einen kryptischen Timeout-Fehler ohne Hinweis, dass `make dns-up` zuerst nötig ist.

**Fix:**
```bash
# Am Anfang von test-dns.sh:
if ! dig +short +timeout=2 "@${TAILSCALE_IP}" "${DOMAIN}" >/dev/null 2>&1; then
  echo "ERROR: CoreDNS not reachable at ${TAILSCALE_IP}:53"
  echo "  Start it with: make dns-up"
  exit 1
fi
```

---

**[U-12] sudo-Prompt ohne Vorwarnung auf macOS**
HAX G3 (Timing) · Medium

**Finding:** `make up` auf macOS triggert `dns-up`, welches `sudo sh -c '...'` aufruft — ein Passwort-Prompt erscheint mitten im Deployment ohne vorherige Ankündigung. Der User weiß nicht, warum sudo gebraucht wird (Port 53 < 1024 erfordert root).

**Fix:**
```makefile
dns-up:
ifeq ($(UNAME),Darwin)
	@echo "Starting CoreDNS natively (macOS)..."
	@echo "Note: Port 53 requires sudo — you may be prompted for your password."
```

---

**[U-13] Kein Upgrade-Pfad dokumentiert**
HAX G18 (Communicate Changes) · Medium

**Finding:** Wie aktualisiert man homelab-gateway selbst? `git pull && make generate && make up`? Muss man vorher `make down` machen? Werden Volumes kompatibel sein? Keine Dokumentation. Für den Weiterverkauf besonders relevant.

**Fix:** README-Sektion "Upgrading":
```markdown
## Upgrading

git pull origin main
make generate
make up    # Docker Compose recreates only changed containers
```

---

**[U-14] Kein Backup/Restore dokumentiert**
HAX G12 (History) · Medium

**Finding:** 7 Docker Volumes mit persistentem State (Grafana-Dashboards, Prometheus-Metriken, Loki-Logs, Uptime-Kuma-Monitore, TLS-Zertifikate, Traces). Kein `make backup` / `make restore` Target, keine Dokumentation wie man die Daten sichert. Für Weiterverkauf: essentiell.

**Fix:**
```makefile
backup: ## Backup all persistent data to ./backups/
	@mkdir -p backups
	@echo "Backing up volumes..."
	@docker run --rm -v grafana-data:/data -v $(PWD)/backups:/backup alpine \
		tar czf /backup/grafana-data-$(shell date +%Y%m%d).tar.gz -C /data .
	# ... analog für andere Volumes
	@echo "Backup complete in ./backups/"
```

---

### Low (4)

---

**[U-15] Tailscale-Admin-Berechtigung nicht erwähnt**
HAX G1 · Low

**Finding:** Quickstart Step 3 ("Configure Tailscale Split DNS") erfordert Admin-Zugriff auf die Tailscale-Admin-Konsole. Ein normaler Tailnet-Benutzer ohne Admin-Rolle kann diese Konfiguration nicht durchführen. Nicht erwähnt.

---

**[U-16] `make down` ohne Feedback**
HAX G16 · Low

**Finding:** `make down` führt `docker compose down` aus — keine Ausgabe was gestoppt wurde, kein Hinweis ob CoreDNS auch gestoppt wurde (wird über dns-down erledigt, aber kein zusammenfassendes Feedback).

---

**[U-17] Kein CHANGELOG**
HAX G18 (Communicate Changes) · Low

**Finding:** Kein CHANGELOG.md — Nutzer des Public Repos sehen nur Git-Log für Änderungen. Für Weiterverkauf: Kunden erwarten ein Changelog.

---

**[U-18] UPTIME_KUMA-Credentials in .env misleading**
NNG (Mental Model Mismatch) · Low

**Finding:** `.env.example` enthält `UPTIME_KUMA_USERNAME` und `UPTIME_KUMA_PASSWORD`, die für `setup-uptime-monitors.sh` gedacht sind. Aber im `docker-compose.yml` werden diese Variablen nicht an den Container übergeben. Der User erwartet, dass diese Credentials beim Container-Start verwendet werden — tatsächlich muss das Passwort manuell im Uptime-Kuma-UI gesetzt werden.

---

## Nicht evaluiert / Annahmen

- **[Assumption]** Grafana- und Uptime-Kuma-Web-UIs wurden nicht auditiert (keine Screenshots/Zugang). Findings beziehen sich nur auf CLI/Operator-Experience.
- **[Assumption]** Die Web-UIs werden von Upstream-Projekten bereitgestellt — ein UX-Audit dieser Dashboards wäre ein separater Scope.
- **[To be verified]** Verhalten von `make up` bei bereits laufendem Stack (Docker Compose recreate-Verhalten) — sollte safe sein, aber nicht dokumentiert.

---

## Bewertung nach Einsatzszenario

| Finding | Public Repo | Self-hosted VPN | Weiterverkauf |
|---------|:-----------:|:---------------:|:-------------:|
| U-01 Kein make help | 🟠 High | 🟡 Medium | 🔴 Critical |
| U-02 clean ohne Bestätigung | 🟡 Medium | 🟡 Medium | 🔴 Critical |
| U-03 include .env fresh clone | 🔴 Critical | 🔴 Critical | 🔴 Critical |
| U-04 CADDY_AUTH Onboarding | 🟡 Medium | 🟡 Medium | 🟠 High |
| U-05 Prerequisites | 🟠 High | 🔵 Low | 🟠 High |
| U-06 make up Status | 🔵 Low | 🔵 Low | 🟡 Medium |
| U-09 Dry-Run | 🔵 Low | 🔵 Low | 🟡 Medium |
| U-13 Upgrade-Pfad | 🟡 Medium | 🟡 Medium | 🔴 Critical |
| U-14 Backup/Restore | 🔵 Low | 🟡 Medium | 🔴 Critical |

---

## Statistics

| Severity | Findings | Resolved |
|----------|----------|:--------:|
| 🔴 Critical | 0 | — |
| 🟠 High | 4 | 4/4 ✅ |
| 🟡 Medium | 9 | 8/9 |
| 🔵 Low | 4 | 3/4 |
| ⚪ Info | 1 (Positive Highlights) | — |
| **Gesamt** | **17 + 1** | **15/17 (88%)** |

---

*Generated with AI assistance (Claude Code + dev-best-practices plugin).
Findings should be verified — not a substitute for manual usability testing with real users.*
