# Security Code Review Report — homelab-gateway

Language: Bash, YAML, Caddyfile, DNS Zone | Framework: Docker Compose IaC (11 Container) | Date: 2026-06-09

Scope: Drei Einsatzszenarien — (1) Public GitHub Repository, (2) Self-hosted hinter Tailscale VPN, (3) Weiterverkauf an Kunden.
ASVS Level: L1 (Solo-Homelab-Infrastructure)

---

## Overall Assessment

🟢 **LOW** — Nach 6 Implementierungs-Waves ist der Stack umfassend gehaertet. Alle Critical- und High-Findings behoben: Docker Secrets statt Env-Vars (S-01/S-07), Trivy blocking (S-02), Watchtower monitor-only (S-03), SQL-Injection gefixt (S-04), Security-Event-Logging via AuthFailures-Alert (S-05). Alle Medium-Findings ebenfalls behoben: CSP per Subdomain (S-06), check-env erweitert (S-08), PII-Labels vollstaendig (S-09), Alerting funktional (S-10), IPv4+IPv6 PII-Regex (S-11). Verbleibend: 2 Low (S-12 mTLS, S-14 CoreDNS PID) fuer Wave 7.

---

## Resolution Status (Stand: Wave 6, PR #57)

| # | Finding | Severity | Status | Resolved in |
|---|---------|----------|:------:|-------------|
| S-01 | Docker Socket Proxy Credentials | Critical | ✅ | Wave 1, PR #51 |
| S-02 | Trivy non-blocking | Critical | ✅ | Wave 1, PR #51 |
| S-03 | Watchtower Supply-Chain-Bypass | High | ✅ | Wave 1, PR #51 |
| S-04 | SQL-Injection | High | ✅ | Wave 4, PR #54 |
| S-05 | Kein Security-Event-Logging | High | ✅ | Wave 3, PR #53 |
| S-06 | CSP unsafe-inline | Medium | ✅ | Wave 4, PR #54 |
| S-07 | Env-Var Credentials | Medium | ✅ | Wave 1, PR #51 |
| S-08 | Insecure Defaults Basicauth | Medium | ✅ | Wave 2, PR #51 |
| S-09 | PII 4/11 Container | Medium | ✅ | Wave 3, PR #53 |
| S-10 | Alerting-Pipeline nicht funktional | Medium | ✅ | Wave 3, PR #53 |
| S-11 | PII-IP-Regex zu breit | Medium | ✅ | Wave 4, PR #54 |
| S-12 | Interner Traffic unverschluesselt | Low | — | Wave 7 (mTLS) |
| S-13 | Grafana GID 0 | Low | ✅ | Wave 4, PR #54 |
| S-14 | TOCTOU CoreDNS PID | Low | — | Wave 7 |
| S-15 | Uptime Kuma SETUID/SETGID | Low | ✅ | Wave 4, PR #54 |
| S-16 | node-exporter pid:host | Low | ✅ | Wave 4, PR #54 |
| C-01 | GDPR Art. 32 PII-Redaktion | Info | ✅ | Wave 3+4 |
| C-02 | ISO 27001 Security-Logging | Info | ✅ | Wave 3, PR #53 |
| C-03 | ISO 27001 Security-Testing | Info | ⚠️ | Wave 1+5 (kein DAST) |
| C-04 | GDPR Art. 33 Breach-Notification | Info | ✅ | Wave 3, PR #53 |

**Resolved: 17/20 (85%)** — Verbleibend: S-12, S-14, C-03 (DAST)

---

## Findings

### 🔴 Critical (2)

---

### [CRITICAL] S-01: Docker Socket Proxy gibt Container-Credentials über API preis

**Category:** Security
**Location:** docker-compose.yml, Zeilen 126-128 (socket-proxy `CONTAINERS: 1`)
**CWE:** CWE-284 (Improper Access Control), CWE-269 (Improper Privilege Management)

**What:** Die Socket-Proxy-Konfiguration `CONTAINERS=1` erlaubt GET-Requests auf `/containers/{id}/json`, was die vollständige Container-Konfiguration einschließlich aller Umgebungsvariablen (Passwörter, Tokens) zurückgibt.

**Why it matters:** Der Docker-API-Endpunkt `/containers/{id}/json` liefert das `Config.Env`-Array jedes Containers — also `GF_ADMIN_PASSWORD`, `CADDY_AUTH_PASS_HASH`, `ALERTING_WEBHOOK_URL`. Jeder Container im `monitoring`-Netzwerk (Promtail, Loki, Prometheus, Tempo, Grafana, node-exporter) kann per HTTP-GET an `http://socket-proxy:2375/containers/gateway-grafana/json` alle Secrets auslesen. Ein Angreifer, der einen einzigen Monitoring-Container kompromittiert (z.B. über eine Loki-/Promtail-CVE), erhält sofort Zugriff auf alle Credentials im Stack.

Exploit-Szenario (Weiterverkauf): Kunde deployt Stack auf Shared-VPN mit mehreren Teilnehmern. Angreifer kompromittiert eine verwundbare Promtail-Version → HTTP-GET an Socket-Proxy → liest Grafana-Admin-Passwort → übernimmt Grafana → Zugriff auf alle Logs/Metriken.

**Fix:**

Sofort-Maßnahme: Alle Secrets aus Docker-Env-Vars in Docker Secrets oder Bind-Mount-Files migrieren (dann ist der Container-Inspect harmlos). Siehe auch S-07.

```yaml
# docker-compose.yml — Grafana mit File-based Secrets
grafana:
  environment:
    - GF_SECURITY_ADMIN_USER__FILE=/run/secrets/gf_admin_user
    - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/gf_admin_password
  secrets:
    - gf_admin_user
    - gf_admin_password

secrets:
  gf_admin_user:
    file: ./secrets/gf_admin_user.txt
  gf_admin_password:
    file: ./secrets/gf_admin_password.txt
```

Langfristig: Prüfen ob tecnativa/docker-socket-proxy eine Pfad-Filterung für `/containers/{id}/json` → Config.Env bietet, oder Wechsel auf einen Proxy mit granularer Filterung.

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/) | [MIT 6.566 Lec 2-3](https://css.csail.mit.edu/6.858/2024/) — Privilege separation, Container isolation

---

### [CRITICAL] S-02: Trivy Container-Scan blockiert Pipeline nicht

**Category:** Security
**Location:** .github/workflows/ci.yml, Zeilen 112-113
**CWE:** CWE-1395 (Dependency on Vulnerable Third-Party Component)

**What:** Der Trivy-Scan verwendet `--exit-code 0` und `|| true`, wodurch kritische Container-Vulnerabilities die CI-Pipeline nie blockieren.

**Why it matters:** Container-Images mit bekannten CRITICAL-CVEs (Remote Code Execution, Container Escape) werden ohne Warnung deployed. Trivy erkennt z.B. CVE-2024-21626 (runc Container Escape) — aber mit `--exit-code 0` passiert nichts. Der Scan ist rein informativ und wird in den klappbaren GitHub-Actions-Gruppen leicht übersehen. Im Weiterverkaufs-Szenario liefert man dem Kunden potenziell verwundbare Container aus.

**Fix:**

```yaml
# .github/workflows/ci.yml — Trivy scan
- name: Scan container images
  run: |
    FAILED=0
    grep 'image:' docker-compose.yml \
      | awk '{print $2}' | sort -u \
      | while read -r img; do
      echo "::group::Scanning: $img"
      if ! trivy image \
        --severity CRITICAL,HIGH \
        --ignore-unfixed \
        --scanners vuln \
        --exit-code 1 \
        "$img"; then
        FAILED=1
      fi
      echo "::endgroup::"
    done
    if [[ "$FAILED" -eq 1 ]]; then
      echo "::error::Trivy found critical/high vulnerabilities"
      exit 1
    fi
```

**Learn more:** [MIT 6.566 Lec 2](https://css.csail.mit.edu/6.858/2024/) — Software supply chain security

---

### 🟠 High (3)

---

### [HIGH] S-03: Watchtower umgeht Digest-Pinning (Supply-Chain-Bypass)

**Category:** Security
**Location:** docker-compose.yml, Zeilen 386-414 (watchtower service)
**CWE:** CWE-1395 (Dependency on Vulnerable Third-Party Component)

**What:** Watchtower aktualisiert Container per Tag (`caddy:2-alpine`), ignoriert dabei die im `docker-compose.yml` gepinnten Digest-Hashes (`@sha256:...`) und deployt automatisch jedes neue Image unter dem Tag — einschließlich kompromittierter.

**Why it matters:** Der Stack verwendet Digest-Pinning und Renovate für kontrollierte Updates via Pull Requests — ein vorbildliches Supply-Chain-Modell. Watchtower untergräbt dieses Modell vollständig: Um 04:00 Uhr (`WATCHTOWER_SCHEDULE=0 0 4 * * *`) pullt es automatisch den neuesten Tag-Stand, ohne den Digest zu prüfen. Ein Angreifer, der einen Docker-Hub-Tag kompromittiert (wie beim XZ-Utils-Vorfall 2024 — Social Engineering über Jahre), hat ein 4-Stunden-Fenster bis zur automatischen Deployment. Die Renovate-PRs mit Code-Review werden umgangen.

Für Weiterverkauf: Kunden verlassen sich auf die Digest-Pinning-Sicherheit — aber Watchtower hebt sie auf.

**Fix:**

Option A — Watchtower nur für Benachrichtigungen nutzen:
```yaml
watchtower:
  environment:
    - WATCHTOWER_MONITOR_ONLY=true   # Nur benachrichtigen, nicht updaten
    - WATCHTOWER_NOTIFICATIONS=shoutrrr
    - WATCHTOWER_NOTIFICATION_URL=${WATCHTOWER_NOTIFY_URL:-}
```

Option B — Watchtower entfernen, nur Renovate verwenden:
```yaml
# Watchtower-Service komplett entfernen
# Renovate erstellt PRs mit aktualisierten Digests → Review → Merge → make up
```

**Learn more:** [MIT 6.566 Lec 2](https://css.csail.mit.edu/6.858/2024/) — Software supply chain, reproducible builds

---

### [HIGH] S-04: SQL-Injection in Uptime-Kuma-Provisioning-Skript

**Category:** Security
**Location:** scripts/setup-uptime-monitors.sh, Zeilen 56-63
**CWE:** CWE-89 (SQL Injection)

**What:** Das INSERT-Statement interpoliert `${NAME}` und `${URL}` direkt in den SQL-String ohne Escaping oder Parametrisierung.

**Why it matters:** Die Variablen `NAME` und `URL` werden aus `Caddyfile.tmpl` extrahiert und durch `grep -oE '^[a-z]+\.\$\{DOMAIN\}'` natürlich eingegrenzt. Aber `DOMAIN` stammt aus `.env` (Zeile 21) und wird nicht validiert. Ein manipulierter `.env`-Eintrag wie `DOMAIN="home.lab'); DROP TABLE monitor;--"` erzeugt eine SQL-Injection in der SQLite-Datenbank von Uptime Kuma. Im Weiterverkaufs-Szenario kontrolliert der Kunde die `.env` — das Skript muss auch bei unerwarteten Eingaben sicher sein.

**Fix:**

```bash
# Input-Validierung vor SQL
if [[ ! "$DOMAIN" =~ ^[a-z0-9][a-z0-9.-]*[a-z0-9]$ ]]; then
  echo "ERROR: Invalid DOMAIN format: $DOMAIN" >&2
  exit 1
fi

# Zusätzlich: Single-Quotes im SQL-Wert escapen
safe_sql_string() {
  echo "${1//\'/\'\'}"
}

SAFE_NAME=$(safe_sql_string "$NAME")
SAFE_URL=$(safe_sql_string "$URL")

docker exec "$CONTAINER" sqlite3 "$DB_PATH" \
  "INSERT INTO monitor ... VALUES ('${SAFE_NAME}', 1, 1, 60, '${SAFE_URL}', ...);"
```

**Learn more:** [Stanford CS253](https://cs253.stanford.edu/) — Web security, SQL injection | [MIT 6.566 Lec 9](https://css.csail.mit.edu/6.858/2024/) — Injection attacks

---

### [HIGH] S-05: Kein Security-Event-Logging / kein Audit-Trail

**Category:** Quality (→ Security & Compliance)
**Location:** Gesamter Stack (kein dediziertes Security-Logging konfiguriert)
**CWE:** CWE-778 (Insufficient Logging)

**What:** Der Stack loggt keine sicherheitsrelevanten Ereignisse: fehlgeschlagene Authentifizierungsversuche (401/403), Admin-Aktionen, Container-Neustarts, oder Watchtower-Updates werden weder gesammelt noch alarmiert.

**Why it matters:** Ohne Security-Event-Logging bleibt ein Angriff unerkannt. IBM Cost of a Data Breach 2023: durchschnittliche Erkennungszeit ohne Logging beträgt 204 Tage. Caddy erzeugt zwar JSON-Zugriffslogs (mit Status-Codes), aber es gibt keinen Grafana-Alert für auffällige Muster (z.B. > 10 x 401 in 5 Minuten). Watchtower loggt Updates in seinen eigenen Container-Log, aber ohne `monitoring=true`-Label wird dieser Log nicht von Promtail gesammelt.

Für Weiterverkauf: ISO 27001 A.8.15 verlangt explizit Security-Event-Logging.

**Fix:**

1. Grafana-Alert-Regel für fehlgeschlagene Authentifizierung:
```yaml
# monitoring/grafana/provisioning/alerting/rules.yaml — neue Regel
- uid: auth-failures
  title: AuthFailures
  condition: B
  data:
    - refId: A
      datasourceUid: loki
      model:
        expr: >-
          sum(count_over_time({service="caddy"}
          | json | status >= 401 and status <= 403 [5m]))
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: More than 10 authentication failures in 5 minutes
```

2. Watchtower mit `monitoring=true`-Label versehen:
```yaml
watchtower:
  labels:
    - "monitoring=true"
    - "com.centurylinklabs.watchtower.enable=true"
```

**Learn more:** [MIT 6.566 Lec 6](https://css.csail.mit.edu/6.858/2024/) — Audit logging, intrusion detection

---

### 🟡 Medium (6)

---

### [MEDIUM] S-06: CSP mit unsafe-inline / unsafe-eval entwertet XSS-Schutz

**Category:** Security
**Location:** Caddyfile.tmpl, Zeile 15
**CWE:** CWE-79 (Cross-Site Scripting)

**What:** Die Content-Security-Policy enthält `script-src 'self' 'unsafe-inline' 'unsafe-eval'`, was Inline-Skripte und `eval()` erlaubt und damit den Hauptzweck einer CSP — XSS-Prävention — aufhebt.

**Why it matters:** Grafana und Uptime Kuma benötigen `unsafe-inline` und teilweise `unsafe-eval` für ihre UIs. Das Problem: Eine globale CSP über das `(security_headers)`-Snippet wird auf ALLE Subdomains angewandt — auch auf Services wie niles, garmin, vikunja, die möglicherweise eine restriktivere CSP erlauben. Ein XSS in einem der proxied Services (z.B. durch eine CVE in Vikunja) wird durch die laxe CSP nicht abgefangen.

**Fix:**

Per-Subdomain CSP-Header statt globalem Snippet:
```caddyfile
# Für Services die unsafe-* brauchen (Grafana, Uptime Kuma):
logs.${DOMAIN} {
  header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; ..."
}

# Für andere Services — restriktive CSP:
vikunja.${DOMAIN} {
  header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; ..."
}
```

**Learn more:** [MIT 6.566 Lec 9](https://css.csail.mit.edu/6.858/2024/) — Content Security Policy, Web security model

---

### [MEDIUM] S-07: Credentials als Docker-Umgebungsvariablen sichtbar

**Category:** Security
**Location:** docker-compose.yml, Zeilen 197-201 (Grafana), Zeilen 50-51 (Caddy)
**CWE:** CWE-798 (Use of Hard-coded Credentials) + CWE-269 (Improper Privilege Management)

**What:** `GF_ADMIN_PASSWORD`, `GF_ADMIN_USER`, `CADDY_AUTH_PASS_HASH` und `ALERTING_WEBHOOK_URL` werden als Docker-Umgebungsvariablen übergeben. Diese sind via `docker inspect`, `/proc/1/environ` innerhalb des Containers und über den Socket-Proxy (siehe S-01) lesbar.

**Why it matters:** Docker-Umgebungsvariablen werden im Container-Metadata gespeichert und bei Crash-Reports, Orchestrator-Dashboards und API-Responses offengelegt. Dies ist ein bekanntes Anti-Pattern — die Docker-Dokumentation selbst empfiehlt Docker Secrets oder Bind-Mounted-Files für sensible Daten.

**Fix:**

```yaml
# docker-compose.yml — Grafana mit File-based Secrets
grafana:
  environment:
    - GF_SECURITY_ADMIN_USER__FILE=/run/secrets/gf_admin_user
    - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/gf_admin_password
  secrets:
    - gf_admin_user
    - gf_admin_password

secrets:
  gf_admin_user:
    file: ./secrets/gf_admin_user.txt
  gf_admin_password:
    file: ./secrets/gf_admin_password.txt
```

Hinweis: Grafana unterstützt `__FILE`-Suffixe für alle Umgebungsvariablen.

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/) | [MIT 6.566 Lec 2-3](https://css.csail.mit.edu/6.858/2024/) — Container isolation

---

### [MEDIUM] S-08: Insecure Defaults — leere Basicauth-Variablen

**Category:** Security
**Location:** docker-compose.yml, Zeilen 50-51; .env.example, Zeilen 22-23
**CWE:** CWE-1188 (Insecure Default Initialization of Resource)

**What:** `CADDY_AUTH_USER` und `CADDY_AUTH_PASS_HASH` haben in `docker-compose.yml` leere Defaults (`${CADDY_AUTH_USER:-}`) und sind in `.env.example` auskommentiert. Wenn nicht gesetzt, startet Caddy mit einer leeren Basicauth-Konfiguration auf den Prometheus- und Metrics-Endpunkten.

**Why it matters:** Ein Benutzer, der `.env.example` kopiert und die auskommentierten Caddy-Auth-Zeilen vergisst, deployt Prometheus und Caddy-Metriken ohne Authentifizierung. Prometheus gibt sensible Informationen preis: Hostnamen, IP-Adressen, Container-Namen, Ressourcennutzung. Das `check-env`-Target im Makefile prüft nur auf `CHANGE_ME_BEFORE_DEPLOY`, nicht auf fehlende Auth-Variablen.

**Fix:**

```makefile
# Makefile — check-env erweitern
check-env:
	@if grep -qE '(changeme|CHANGE_ME_BEFORE_DEPLOY)' .env; then \
		echo "ERROR: Default passwords detected in .env"; exit 1; \
	fi
	@if ! grep -q '^CADDY_AUTH_USER=' .env || ! grep -q '^CADDY_AUTH_PASS_HASH=' .env; then \
		echo "WARNING: CADDY_AUTH_USER/CADDY_AUTH_PASS_HASH not set."; \
		echo "  prometheus.DOMAIN and metrics.DOMAIN will be unprotected."; \
		echo "  Set them in .env or press Enter to continue..."; \
		read -r; \
	fi
```

Zusätzlich in `.env.example` nicht auskommentiert, sondern mit Platzhalter:
```bash
CADDY_AUTH_USER=admin
CADDY_AUTH_PASS_HASH=CHANGE_ME_BEFORE_DEPLOY
```

**Learn more:** [MIT 6.566 Lec 9](https://css.csail.mit.edu/6.858/2024/) — Web security, authentication

---

### [MEDIUM] S-09: PII-Redaktion deckt nur 4 von 11 Containern ab

**Category:** Compliance (GDPR Art. 32)
**Location:** monitoring/promtail-config.yml, Zeilen 18-20 (filter: `monitoring=true`)
**CWE:** CWE-532 (Insertion of Sensitive Information into Log File)

**What:** Promtails Docker-Service-Discovery filtert auf `monitoring=true`. Nur 4 von 11 Containern tragen dieses Label (Caddy, Grafana, Prometheus, Uptime Kuma). Die restlichen 7 Container (CoreDNS, Loki, socket-proxy, Promtail selbst, node-exporter, Tempo, Watchtower) werden nicht gescraped — und wenn zukünftig weitere Container mit dem Label hinzukommen, fehlt die Konfiguration für PII-Redaktion in deren Logs.

**Why it matters:** Die PII-Redaktion (IP- und E-Mail-Regex in der Pipeline, Zeilen 42-47) greift nur für Container, deren Logs über Promtail fließen. Wenn zukünftig ein Container mit PII-haltigen Logs das Label bekommt, werden dessen Logs unredaktiert an Loki gesendet. Umgekehrt: Werden Logs über einen anderen Pfad (z.B. Docker JSON-Logfiles auf dem Host) ausgewertet, fehlt die Redaktion komplett.

**Fix:**

1. Alle Container labeln, die potenziell PII loggen:
```yaml
# Empfehlung: Alle Container bis auf socket-proxy labeln
loki:
  labels:
    - "monitoring=true"
tempo:
  labels:
    - "monitoring=true"
watchtower:
  labels:
    - "monitoring=true"
```

2. Alternativ: PII-Redaktion als Loki-Ruler statt nur in Promtail-Pipeline.

**Learn more:** [ISEC Privacy Engineering](https://www.isec.tugraz.at/) — Data minimization, pseudonymization

---

### [MEDIUM] S-10: Alerting-Pipeline nicht funktional — Incidents gehen verloren

**Category:** Quality (→ Security)
**Location:** monitoring/prometheus.yml (kein Alertmanager), monitoring/grafana/provisioning/alerting/contactpoints.yaml, Zeile 9
**CWE:** CWE-778 (Insufficient Logging)

**What:** Prometheus evaluiert `alert-rules.yml` (4 Regeln), hat aber keinen Alertmanager konfiguriert — gefeuerte Alerts gehen ins Leere. Grafana hat einen Webhook-Kontaktpunkt, aber `ALERTING_WEBHOOK_URL` defaultet zu `http://localhost:9999` (nicht erreichbar).

**Why it matters:** CRITICAL-Alerts (DiskAlmostFull, TargetDown) werden korrekt evaluiert, erreichen aber niemanden. Der Operator bemerkt einen Festplatten-Überlauf oder ausgefallenen Service erst bei manuellem Check. Für den Weiterverkauf: Kunden erwarten, dass Alerting funktioniert.

**Fix:**

Option A — Prometheus-Alerting entfernen (nur Grafana Unified Alerting nutzen):
```yaml
# monitoring/prometheus.yml — rule_files-Block entfernen
# Nur Grafana evaluiert Alerts → vermeidet Duplikation
```

Option B — Alertmanager hinzufügen:
```yaml
# monitoring/prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]
```

In beiden Fällen: `ALERTING_WEBHOOK_URL` in `.env.example` als Pflichtfeld markieren.

**Learn more:** [Google SRE Book, Ch. 6](https://sre.google/sre-book/monitoring-distributed-systems/) — Monitoring and alerting

---

### [MEDIUM] S-11: PII-IP-Regex zu breit — ersetzt Versionsnummern, ignoriert IPv6

**Category:** Quality
**Location:** monitoring/promtail-config.yml, Zeile 43
**CWE:** CWE-185 (Incorrect Regular Expression)

**What:** Der IP-Redaktions-Regex `(\d{1,3}\.){3}\d{1,3}` matcht jede Folge von 4 Zahlengruppen mit Punkten — einschließlich Versionsnummern (`3.7.2`, `1.14.4`), Prometheus-Metriken und Container-Image-Tags. IPv6-Adressen werden nicht erfasst.

**Why it matters:** False Positives: Loki speichert Logzeilen wie `image: grafana/loki:[IP_REDACTED]` — unlesbar für Debugging. False Negatives: IPv6-Adressen (z.B. von Tailscale WireGuard `fd7a:115c:a1e0::1`) passieren unredaktiert.

**Fix:**

```yaml
pipeline_stages:
  # IPv4 — präziser (nur 0-255 pro Oktett, keine Versionsnummern)
  - replace:
      expression: '\b(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\b'
      replace: '[IP_REDACTED]'
  # IPv6 — abgekürzte und vollständige Formen
  - replace:
      expression: '(?i)(?:[0-9a-f]{1,4}:){7}[0-9a-f]{1,4}|(?:[0-9a-f]{1,4}:){1,7}:|::(?:[0-9a-f]{1,4}:){0,5}[0-9a-f]{1,4}'
      replace: '[IP_REDACTED]'
```

**Learn more:** [Stanford CS253](https://cs253.stanford.edu/) — Input validation, regex security

---

### 🔵 Low (5)

---

### [LOW] S-12: Interner Service-Traffic unverschlüsselt (HTTP)

**Category:** Security
**Location:** monitoring/prometheus.yml (alle scrape-targets via HTTP), monitoring/promtail-config.yml, Zeile 9 (Loki-Push via HTTP)
**CWE:** CWE-319 (Cleartext Transmission of Sensitive Information)

**What:** Prometheus scrapt alle Targets via HTTP. Promtail pusht Logs via HTTP an Loki. Grafana fragt Datasources via HTTP ab. Kein TLS innerhalb des Docker-Bridge-Netzwerks.

**Why it matters:** Auf einem einzelnen Docker-Host ist das monitoring-Netzwerk ein virtuelles Bridge-Netzwerk — der Traffic verlässt die Maschine nicht. Ein Angreifer müsste Root auf dem Host haben, um den Traffic mitzulesen (tcpdump auf br-*). Risiko: Niedrig für Self-hosted, aber relevant bei Multi-Node-Deployments oder für Weiterverkauf.

**Fix:** Für Weiterverkauf: mTLS zwischen Services konfigurieren (Caddy als Service-Mesh oder Traefik mit TLS-Backend).

**Learn more:** [MIT 6.566 Lec 15](https://css.csail.mit.edu/6.858/2024/) — Secure channels, TLS

---

### [LOW] S-13: Grafana läuft mit Root-Gruppenmitgliedschaft (GID 0)

**Category:** Security
**Location:** docker-compose.yml, Zeile 190 (`user: "472:0"`)
**CWE:** CWE-269 (Improper Privilege Management)

**What:** Grafana läuft als UID 472 mit GID 0 (root-Gruppe). Dies gibt Lesezugriff auf alle Dateien, die der root-Gruppe gehören.

**Why it matters:** In einem read-only Container mit einem einzigen Volume (`grafana-data`) ist der Blast-Radius begrenzt. GID 0 ist Grafanas Standard für OpenShift-Kompatibilität. Für den Weiterverkauf sollte ein dedizierter GID verwendet werden.

**Fix:**

```yaml
grafana:
  user: "472:472"
```

Hinweis: Erfordert `chown 472:472` auf dem grafana-data Volume.

**Learn more:** [MIT 6.566 Lec 6](https://css.csail.mit.edu/6.858/2024/) — Privilege separation

---

### [LOW] S-14: TOCTOU Race Condition in CoreDNS-PID-Management

**Category:** Quality
**Location:** Makefile, Zeile 67 (`/tmp/coredns.pid`), Zeile 85 (`sudo kill $(cat /tmp/coredns.pid)`)
**CWE:** CWE-367 (Time-of-Check Time-of-Use)

**What:** Die CoreDNS-PID-Datei liegt in `/tmp` (world-writable). Zwischen dem Lesen der PID und dem `kill`-Befehl könnte ein anderer Prozess die PID übernommen haben. Ein lokaler Angreifer könnte die PID-Datei manipulieren und einen Symlink-Angriff starten.

**Why it matters:** Auf einem Homelab-System ist das Risiko minimal — der Angreifer bräuchte lokalen Zugriff. Aber auf einem Mehrbenutzersystem (Weiterverkauf) ist `/tmp` ohne Sticky-Bit-Schutz angreifbar.

**Fix:**

```makefile
# PID-Datei in geschütztes Verzeichnis verschieben
PID_FILE := /var/run/coredns.pid
# Oder: /run/user/$(id -u)/coredns.pid für userspace
```

**Learn more:** [MIT 6.566 Lec 10](https://css.csail.mit.edu/6.858/2024/) — TOCTOU race conditions

---

### [LOW] S-15: Uptime Kuma mit SETUID/SETGID Capabilities

**Category:** Security
**Location:** docker-compose.yml, Zeilen 358-359
**CWE:** CWE-269 (Improper Privilege Management)

**What:** Uptime Kuma erhält nach `cap_drop: ALL` die Capabilities `SETGID` und `SETUID` zurück. Diese erlauben Prozessen im Container, ihre User-/Group-ID zu ändern — eine klassische Privilege-Escalation-Capability.

**Why it matters:** Uptime Kuma (Node.js) benötigt diese Capabilities für den internen Startup-Prozess (Wechsel von root zu nicht-privilegiertem User). Ohne sie startet der Container nicht. Das Risiko ist auf die Container-Isolation beschränkt — ein Ausbruch erfordert zusätzliche Kernel-Exploits.

**Fix:** Akzeptabler Trade-off. Dokumentieren, warum diese Capabilities notwendig sind (Kommentar in docker-compose.yml).

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/) — Linux capabilities

---

### [LOW] S-16: node-exporter teilt Host-PID-Namespace

**Category:** Security
**Location:** docker-compose.yml, Zeile 237 (`pid: host`)
**CWE:** CWE-284 (Improper Access Control)

**What:** `pid: host` gibt dem node-exporter Zugriff auf den Host-PID-Namespace — er sieht alle Prozesse auf dem Host mit Prozessnamen, Kommandozeilen und Ressourcenverbrauch.

**Why it matters:** Dies ist by design — node-exporter benötigt Host-PID für korrekte Prozessmetriken. Das Risiko: Prozess-Kommandozeilen können Secrets enthalten (z.B. `mysql -p password`). node-exporter exportiert `node_processes_*`-Metriken, die über Prometheus abfragbar sind.

**Fix:** Akzeptabler Trade-off für Homelab. Für Weiterverkauf: Dokumentieren und in Security-Docs aufnehmen.

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/) — Container namespaces

---

### ⚪ Info / Compliance (4)

---

### [INFO] C-01: GDPR Art. 32 — Technische Maßnahmen unvollständig

**Category:** Compliance
**Regulation:** DSGVO Art. 32 (Sicherheit der Verarbeitung)
**Finding:** Die PII-Redaktion greift nur für 4/11 Container (siehe S-09). Logs ohne Redaktion könnten personenbezogene Daten enthalten (IP-Adressen, E-Mail-Adressen). Keine Log-Retention-Policy in Loki konfiguriert — personenbezogene Daten werden potenziell unbegrenzt gespeichert.
**Risk:** Bei einer Datenschutzprüfung fehlt der Nachweis angemessener technischer Maßnahmen. Für Self-hosted hinter VPN: geringes Risiko (Eigennutzung). Für Weiterverkauf: DSGVO-Konformitätsnachweis erforderlich.
**Remediation:** (1) Alle Container in PII-Redaktion einbeziehen. (2) Loki-Retention konfigurieren: `limits_config.retention_period: 30d` in loki-config.yml. (3) Dokumentieren, welche personenbezogenen Daten verarbeitet werden.
**Evidence needed:** Verarbeitungsverzeichnis (Art. 30), Loki-Retention-Konfiguration, PII-Redaktion-Testprotokoll.

---

### [INFO] C-02: ISO 27001 A.8.15 — Kein Security-Event-Logging

**Category:** Compliance
**Regulation:** ISO 27001:2022 A.8.15 (Logging)
**Finding:** Keine dedizierten Security-Event-Logs. Fehlgeschlagene Authentifizierungsversuche, Admin-Aktionen, und Container-Lifecycle-Events werden nicht separat erfasst oder alarmiert (siehe S-05).
**Risk:** ISO-27001-Zertifizierung erfordert nachweisbares Security-Event-Logging mit Integritätsschutz.
**Remediation:** (1) Caddy-Access-Logs mit Status-Code-Filterung (401, 403, 500). (2) Dedizierter Loki-Label `security_event=true` für Security-relevante Logs. (3) Grafana-Dashboard für Security-Events.
**Evidence needed:** Log-Architektur-Diagramm, Grafana-Dashboard-Screenshots, Alert-Konfiguration.

---

### [INFO] C-03: ISO 27001 A.8.29 — Kein DAST/Penetrationstest in Pipeline

**Category:** Compliance
**Regulation:** ISO 27001:2022 A.8.29 (Security testing in development)
**Finding:** CI enthält SAST (Semgrep), Secret-Scanning (TruffleHog), IaC-Scanning (Checkov) — aber keinen DAST (Dynamic Application Security Testing) und keinen automatisierten Penetrationstest. Trivy ist zudem non-blocking (siehe S-02).
**Risk:** Für Self-hosted: kein unmittelbares Risiko. Für Weiterverkauf: ISO-27001-Konformität verlangt Security-Testing im Entwicklungsprozess.
**Remediation:** (1) Trivy auf blocking umstellen (S-02). (2) Optional: DAST mit OWASP ZAP als CI-Job (gegen laufenden Stack in CI).
**Evidence needed:** CI-Pipeline-Dokumentation mit Security-Gates, Trivy-Report-Archive.

---

### [INFO] C-04: GDPR Art. 33 — Breach-Notification-Mechanismus nicht funktional

**Category:** Compliance
**Regulation:** DSGVO Art. 33 (Meldung von Verletzungen an die Aufsichtsbehörde)
**Finding:** Die Alerting-Pipeline (Prometheus → kein Alertmanager, Grafana → localhost:9999) ist nicht funktional (siehe S-10). Ein Sicherheitsvorfall (z.B. Container-Kompromittierung, Datenexfiltration) löst keine Benachrichtigung aus.
**Risk:** DSGVO Art. 33 verlangt Meldung innerhalb von 72 Stunden. Ohne funktionales Alerting wird ein Vorfall möglicherweise erst nach Wochen bemerkt.
**Remediation:** (1) Alerting-Pipeline funktional machen (S-10). (2) Incident-Response-Runbook erstellen. (3) Für Weiterverkauf: SLA für Benachrichtigungszeit dokumentieren.
**Evidence needed:** Funktionsnachweis der Alerting-Kette (End-to-End-Test), Incident-Response-Dokumentation.

---

### EU AI Act

**Nicht anwendbar.** Der Stack enthält keine AI/ML-Systeme. Keine Code-Level-Verpflichtungen aus der EU-KI-Verordnung (Regulation (EU) 2024/1689).

---

## Statistics

| Severity     | Security | Quality | Compliance | Resolved |
|--------------|----------|---------|------------|:--------:|
| 🔴 Critical  | 2        | 0       | 0          | 2/2 ✅   |
| 🟠 High      | 2        | 1       | 0          | 3/3 ✅   |
| 🟡 Medium    | 4        | 1       | 1          | 6/6 ✅   |
| 🔵 Low       | 4        | 1       | 0          | 3/5      |
| ⚪ Info       | 0        | 0       | 4          | 3/4      |
| **Summe**    | **12**   | **3**   | **5**      | **17/20** |

**Gesamt: 20 Findings** (2 Critical, 3 High, 6 Medium, 5 Low, 4 Info) — **17 resolved (85%)**

---

## Bewertung nach Einsatzszenario

| Finding | Public Repo | Self-hosted VPN | Weiterverkauf |
|---------|:-----------:|:---------------:|:-------------:|
| S-01 Socket-Proxy Credentials | Dokumentation | 🟡 Medium | 🔴 Critical |
| S-02 Trivy non-blocking | 🔴 Critical | 🟡 Medium | 🔴 Critical |
| S-03 Watchtower Supply-Chain | 🟠 High | 🟡 Medium | 🔴 Critical |
| S-04 SQL-Injection | 🟠 High | 🟡 Medium | 🟠 High |
| S-05 Kein Security-Logging | 🟡 Medium | 🟡 Medium | 🔴 Critical |
| S-06 CSP unsafe-inline | 🟡 Medium | 🔵 Low | 🟠 High |
| S-07 Env-Var Credentials | 🟡 Medium | 🟡 Medium | 🟠 High |
| S-08 Leere Basicauth | 🟠 High | 🟡 Medium | 🔴 Critical |
| S-09 PII 4/11 Container | 🟡 Medium | 🔵 Low | 🟠 High |
| S-10 Alerting-Void | 🟡 Medium | 🟡 Medium | 🟠 High |

---

## Top 3 Immediate Actions

1. **Docker Socket Proxy + Secrets migrieren (S-01 + S-07):** Alle Passwörter aus Docker-Umgebungsvariablen in Docker Secrets oder Bind-Mount-Files verschieben. Damit wird der Container-Inspect über den Socket-Proxy harmlos.

2. **Trivy auf blocking umstellen (S-02):** `--exit-code 1` statt `--exit-code 0`, `|| true` entfernen. Sofort-Fix in einer Zeile — größte Wirkung für geringstes Risiko.

3. **Watchtower auf Monitor-Only oder entfernen (S-03):** `WATCHTOWER_MONITOR_ONLY=true` setzen, um den Supply-Chain-Bypass durch automatische Updates zu eliminieren. Renovate ist der sichere Update-Pfad.

---

*Generated with AI assistance (Claude Code + dev-best-practices plugin).
Findings should be verified — not a substitute for manual penetration testing.*
