# Security Code Review Report — homelab-gateway

Sprache: Shell/Bash, Python 3, YAML, Caddyfile | Framework: Docker Compose, CoreDNS, Caddy, Grafana/Loki/Prometheus | Datum: 2026-06-05

## Gesamtbewertung

🟠 **HIGH** — Das Projekt zeigt gute Grundlagen (Secrets-Scanning, PII-Hook, Image-Pinning, Resource-Limits), hat aber mehrere mittlere bis hohe Findings: eine echte Tailscale-IP im versionierten `.env.example`, fehlende Application-Layer-Authentifizierung auf mehreren Services, Docker-Socket-Mount, und Container die als Root laufen.

---

## Findings

### 🟠 High (3)

---

### [🟠 HIGH] Reale Tailscale-IP in versioniertem `.env.example`

**Category:** Security
**Location:** [.env.example:3](.env.example#L3)
**CWE:** CWE-200 (Exposure of Sensitive Information)

**What:** Die `.env.example` enthält die echte Tailscale-IP `100.85.159.70` statt eines Platzhalters. Diese Datei ist versioniert und damit in der Git-Historie permanent gespeichert.

**Why it matters:** Die Tailscale-IP identifiziert den konkreten Host im Tailnet. Ein Angreifer, der Zugang zum Tailnet erlangt (kompromittiertes Gerät, gestohlener Auth-Key), kann diesen Host direkt adressieren. Da alle Services ohne Application-Layer-Auth laufen (s.u.), bedeutet Kenntnis der IP sofortigen Zugriff auf DNS, Grafana, Loki, etc. Selbst nach Korrektur bleibt die IP in `git log` sichtbar — ein `git filter-branch` oder BFG Repo-Cleaner wäre nötig, um sie vollständig zu entfernen.

**Fix:**
```bash
# .env.example — nur Platzhalter
TAILSCALE_IP=100.x.y.z
DOMAIN=home.lab
UPTIME_KUMA_USERNAME=admin
UPTIME_KUMA_PASSWORD=changeme
```
Zusätzlich: Die aktuelle IP aus der Git-Historie entfernen (z.B. mit `git filter-repo` oder BFG Repo-Cleaner), falls das Repository jemals öffentlich war oder wird.

**Learn more:** [MIT 6.566 Lec 6](https://css.csail.mit.edu/6.858/2024/) — Privilege separation; Secrets Management

---

### [🟠 HIGH] Grafana ohne Authentifizierung (Anonymous Viewer)

**Category:** Security
**Location:** [docker-compose.yml:91-92](docker-compose.yml#L91-L92)
**CWE:** CWE-306 (Missing Authentication for Critical Function)

**What:** Grafana ist mit `GF_AUTH_ANONYMOUS_ENABLED=true` und `GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer` konfiguriert. Jeder im Tailnet kann ohne Login alle Dashboards, Logs und Metriken einsehen.

**Why it matters:** Grafana-Dashboards und die Loki-Explore-Funktion können sensible Informationen preisgeben: Container-Logs (die API-Keys, Fehler mit Stack Traces, Benutzerdaten enthalten können), System-Metriken (CPU, Memory, Disk — nützlich für Reconnaissance), und Service-URLs. Ein kompromittiertes Tailnet-Gerät (z.B. ein Smartphone) gibt sofort Zugang zu allen Observability-Daten. Defense-in-Depth erfordert, dass auch interne Services authentifiziert sind.

**Fix:**
```yaml
# docker-compose.yml — Grafana environment
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_AUTH_BASIC_ENABLED=true
  # Alternativ: Tailscale Auth Proxy oder OAuth
  - GF_SERVER_ROOT_URL=https://logs.home.lab
```

**Learn more:** [MIT 6.566 Lec 17](https://css.csail.mit.edu/6.858/2024/) — User authentication

---

### [🟠 HIGH] Docker-Socket-Mount in Promtail

**Category:** Security
**Location:** [docker-compose.yml:69](docker-compose.yml#L69)
**CWE:** CWE-269 (Improper Privilege Management)

**What:** Promtail mountet `/var/run/docker.sock:/var/run/docker.sock:ro`. Obwohl read-only, gewährt dies dem Container Zugriff auf die Docker-API.

**Why it matters:** Über den Docker-Socket (selbst read-only) kann ein Container alle laufenden Container auflisten, deren Environment-Variablen lesen (einschließlich Secrets wie `UPTIME_KUMA_PASSWORD`), Logs aller Container lesen, und Image-Details inspizieren. Eine Schwachstelle in Promtail (z.B. CVE in der Grafana-Promtail-Codebase) könnte dazu führen, dass ein Angreifer diese Informationen exfiltriert. Für Log-Collection gibt es sicherere Alternativen.

**Fix:**
Zwei Optionen:
1. **Docker-Log-Dateien direkt mounten** (ohne Socket):
```yaml
volumes:
  - /var/lib/docker/containers:/var/lib/docker/containers:ro
# Docker-Socket-Mount entfernen, stattdessen statische Targets nutzen
```
2. **Promtail durch einen Socket-Proxy absichern** (z.B. `tecnativa/docker-socket-proxy`) der nur bestimmte API-Endpunkte erlaubt.

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/) | [MIT 6.566 Lec 2-3](https://css.csail.mit.edu/6.858/2024/) — Container isolation

---

### 🟡 Medium (5)

---

### [🟡 MEDIUM] Node Exporter: Host-Root-Filesystem und PID-Namespace

**Category:** Security
**Location:** [docker-compose.yml:121-123](docker-compose.yml#L121-L123)
**CWE:** CWE-269 (Improper Privilege Management)

**What:** Node Exporter mountet das gesamte Host-Root-Filesystem (`/:/host:ro`) und teilt den Host-PID-Namespace (`pid: host`).

**Why it matters:** Obwohl read-only, hat der Container Lesezugriff auf alle Dateien des Hosts: `/etc/shadow`, SSH-Keys, `.env`-Dateien, TLS-Zertifikate. Bei einer RCE-Schwachstelle in Node Exporter könnte ein Angreifer alle Host-Dateien lesen. Der `pid: host`-Namespace ermöglicht das Auflisten aller Host-Prozesse und deren Kommandozeilen-Argumente (die manchmal Secrets enthalten).

**Fix:**
```yaml
node-exporter:
  # ...
  volumes:
    - /proc:/host/proc:ro
    - /sys:/host/sys:ro
    - /:/host/rootfs:ro  # Wenn voller Zugriff wirklich nötig
  command:
    - "--path.procfs=/host/proc"
    - "--path.sysfs=/host/sys"
    - "--path.rootfs=/host/rootfs"
    - "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+)($$|/)"
  # Security-Hardening:
  security_opt:
    - no-new-privileges:true
  read_only: true
```
[Schlussfolgerung] Der volle Root-Mount ist der übliche Ansatz für Node Exporter. Das Risiko ist akzeptabel, wenn die Container-Isolation intakt bleibt. Dennoch empfohlen: `read_only: true` und `no-new-privileges`.

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/)

---

### [🟡 MEDIUM] Loki ohne Authentifizierung

**Category:** Security
**Location:** [monitoring/loki-config.yml:1](monitoring/loki-config.yml#L1)
**CWE:** CWE-306 (Missing Authentication for Critical Function)

**What:** Loki läuft mit `auth_enabled: false`. Jeder Service im `monitoring`-Docker-Netzwerk kann Logs lesen, schreiben und löschen.

**Why it matters:** Ein kompromittierter Container im `monitoring`-Netzwerk kann: (1) alle Logs lesen (die PII, API-Keys, oder Fehlermeldungen enthalten können), (2) falsche Log-Einträge injizieren (Log-Tampering — erschwert Forensik nach einem Vorfall), (3) Logs löschen (über die Loki-API). Obwohl Loki nur auf `127.0.0.1:3100` gebunden ist (nicht extern erreichbar), ist die Docker-interne Erreichbarkeit via `loki:3100` ohne Auth ein Risiko.

**Fix:**
```yaml
# loki-config.yml
auth_enabled: true
# Dann in promtail-config.yml und Grafana-Datasource den Tenant-Header setzen:
# X-Scope-OrgID: homelab
```

**Learn more:** [MIT 6.566 Lec 6](https://css.csail.mit.edu/6.858/2024/) — Privilege separation

---

### [🟡 MEDIUM] Alle Container laufen als Root

**Category:** Security
**Location:** [docker-compose.yml](docker-compose.yml) (global)
**CWE:** CWE-250 (Execution with Unnecessary Privileges)

**What:** Keiner der Container definiert einen nicht-privilegierten User (`user:`-Direktive fehlt). Alle Prozesse laufen als UID 0 (root) innerhalb der Container.

**Why it matters:** Falls ein Container-Escape gelingt (z.B. über eine Kernel-Schwachstelle wie CVE-2019-5736 / runc escape), läuft der entflohene Prozess als root auf dem Host. Wenn Container als non-root User laufen, wird ein Escape deutlich weniger kritisch, da der Host-User keine Privilegien hat.

**Fix:**
```yaml
# Für jeden Container, wo möglich:
services:
  loki:
    user: "10001:10001"
    # ...
  promtail:
    user: "10001:10001"
    # ...
  grafana:
    user: "472:0"  # Grafana's offizieller non-root User
    # ...
  prometheus:
    user: "65534:65534"  # nobody
    # ...
```
Hinweis: Grafana (`grafana/grafana`) unterstützt offiziell non-root. Prometheus und Loki ebenfalls. Node Exporter und CoreDNS benötigen ggf. spezifische Capabilities.

**Learn more:** [MIT 6.566 Lec 6](https://css.csail.mit.edu/6.858/2024/) — Privilege separation

---

### [🟡 MEDIUM] Secrets als Environment-Variablen in Containern

**Category:** Security
**Location:** [docker-compose.yml:91-93](docker-compose.yml#L91-L93), [Makefile:4](Makefile#L4)
**CWE:** CWE-526 (Exposure of Sensitive Information Through Environmental Variables)

**What:** Das Makefile lädt `.env` via `include .env` / `export` — alle Variablen (inkl. `UPTIME_KUMA_PASSWORD`) werden als Environment-Variablen exportiert. Grafana erhält seine Konfiguration ebenfalls via Environment-Variablen.

**Why it matters:** Environment-Variablen sind einsehbar über: `docker inspect`, `/proc/<pid>/environ` auf dem Host, Crash-Dumps, und — wie oben beschrieben — über den Docker-Socket. Ein Angreifer mit Zugriff auf Promtail (Docker-Socket) kann `docker inspect gateway-grafana` ausführen und alle Environment-Variablen lesen.

**Fix:**
Für Docker Compose: Docker Secrets oder Config-Files verwenden statt Environment-Variablen für sensitive Daten.
```yaml
# docker-compose.yml
secrets:
  uptime_kuma_password:
    file: ./secrets/uptime_kuma_password.txt

services:
  # In Scripts: aus Datei lesen statt aus Env-Variable
```

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/)

---

### [🟡 MEDIUM] TLS-Verifizierung global deaktiviert in Uptime Kuma Monitors

**Category:** Security
**Location:** [scripts/provision-uptime-kuma.py:107](scripts/provision-uptime-kuma.py#L107)
**CWE:** CWE-295 (Improper Certificate Validation)

**What:** Alle HTTP/Keyword-Monitors werden mit `ignoreTls=True` erstellt. Die TLS-Zertifikat-Validierung ist vollständig deaktiviert.

**Why it matters:** Da Caddy `tls internal` (selbstsignierte Zertifikate) nutzt, ist `ignoreTls=True` funktional nachvollziehbar. Allerdings wird dadurch auch eine Man-in-the-Middle-Attacke innerhalb des Docker-Netzwerks nicht erkannt. Ein besserer Ansatz wäre, die interne CA von Caddy in Uptime Kuma zu importieren.

**Fix:**
Die Caddy-interne CA (`/data/caddy/pki/authorities/local/root.crt`) als Trusted CA in Uptime Kuma konfigurieren, statt TLS-Validierung komplett zu deaktivieren. Dies erfordert:
1. Das Caddy-CA-Zertifikat aus dem `caddy_data`-Volume extrahieren
2. In Uptime Kuma als Custom CA setzen

**Learn more:** [Stanford CS255 Lec 16](https://crypto.stanford.edu/~dabo/cs255/syllabus.html) — TLS

---

### 🔵 Low / ⚪ Info (6)

---

### [🔵 LOW] Keine Security-Hardening-Direktiven in Containern

**Category:** Quality
**Location:** [docker-compose.yml](docker-compose.yml) (global)
**CWE:** CWE-269

**What:** Keiner der Container nutzt `security_opt: [no-new-privileges:true]`, `read_only: true`, oder `cap_drop: [ALL]`.

**Why it matters:** Diese Direktiven sind Defense-in-Depth-Maßnahmen: `no-new-privileges` verhindert Privilege Escalation via SUID-Binaries im Container, `read_only` verhindert, dass ein Angreifer Dateien im Container modifiziert, `cap_drop: ALL` entfernt alle Linux-Capabilities (nur die wirklich benötigten wieder hinzufügen).

**Fix:**
```yaml
services:
  caddy:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Für Port 443
    read_only: true
    tmpfs:
      - /tmp
```

**Learn more:** [ISEC Cloud Operating Systems](https://www.isec.tugraz.at/course/cloud-operating-systems-705050-sommersemester-2026/)

---

### [🔵 LOW] Grafana Image nicht SHA-pinned

**Category:** Security
**Location:** [docker-compose.yml:87](docker-compose.yml#L87)
**CWE:** CWE-1395 (Dependency on Vulnerable Third-Party Component)

**What:** `grafana/grafana:11.6.0` nutzt nur einen Version-Tag, keinen SHA256-Digest. Alle anderen Images (Loki, Promtail, Uptime Kuma) sind korrekt SHA-pinned.

**Why it matters:** Ein Tag kann nachträglich überschrieben werden (Tag-Squatting, kompromittiertes Registry). SHA256-Pinning stellt sicher, dass exakt das erwartete Image geladen wird.

**Fix:**
```yaml
grafana:
  image: grafana/grafana:11.6.0@sha256:<aktueller-digest>
```
Den Digest ermitteln: `docker pull grafana/grafana:11.6.0 && docker inspect --format='{{index .RepoDigests 0}}' grafana/grafana:11.6.0`

---

### [🔵 LOW] Caddy Image nicht SHA-pinned

**Category:** Security
**Location:** [docker-compose.yml:18](docker-compose.yml#L18)
**CWE:** CWE-1395

**What:** `caddy:2-alpine` nutzt einen Floating-Tag, keinen SHA256-Digest.

**Fix:**
```yaml
caddy:
  image: caddy:2-alpine@sha256:<aktueller-digest>
```

---

### [🔵 LOW] Claude Code Action nutzt unpinned Action-Version

**Category:** Security
**Location:** [.github/workflows/claude.yml:31-32](.github/workflows/claude.yml#L31-L32)
**CWE:** CWE-1395 (Supply Chain)

**What:** `actions/checkout@v6` und `anthropics/claude-code-action@v1` nutzen Floating-Tags statt SHA-Pins. Die CI-Workflow (`ci.yml`) pinnt korrekt via SHA.

**Why it matters:** Floating-Tags bei GitHub Actions ermöglichen Supply-Chain-Attacken: Wird das Tag überschrieben, wird bei jedem Workflow-Run anderer Code ausgeführt. Die CI-Workflow macht es vorbildlich mit SHA-Pinning.

**Fix:**
```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd  # v6.0.2
- uses: anthropics/claude-code-action@<sha>  # v1.x.x
```

---

### [⚪ INFO] Tailscale MagicDNS-Hostname im Caddyfile

**Category:** Security
**Location:** [Caddyfile:17](Caddyfile#L17)
**CWE:** —

**What:** Das Caddyfile enthält `niles.tail1d4a0f.ts.net` — einen echten Tailscale MagicDNS-Hostnamen. Dieser ist versioniert.

**Why it matters:** Der MagicDNS-Hostname enthält die Tailnet-ID (`tail1d4a0f`). Dies ist ein Informationsleak, allerdings mit geringem direktem Risiko, da der Hostname nur innerhalb des Tailnets auflösbar ist. Das `check-pii.sh`-Script sollte dieses Pattern eigentlich erkennen — es wurde vermutlich vor Aktivierung des Hooks committed.

**Fix:** Den MagicDNS-Hostnamen über eine Template-Variable (`${NILES_TAILSCALE_HOSTNAME}`) aus der `.env` beziehen und das Caddyfile ebenfalls als Template behandeln.

---

### [⚪ INFO] `pip3 install` ohne Version-Pinning im Makefile

**Category:** Quality
**Location:** [Makefile:141](Makefile#L141)
**CWE:** CWE-1395

**What:** `pip3 install -q uptime-kuma-api pyyaml` installiert ohne Version-Pinning und ohne Hash-Verifizierung.

**Why it matters:** Bei jedem `make provision-uptime` wird die neueste Version aus PyPI installiert. Eine kompromittierte oder inkompatible Version würde sofort deployed. Dependency Confusion (ein gleichnamiges Paket auf einem internen Registry) ist bei PyPI ebenfalls ein bekannter Angriffsvektor.

**Fix:**
```makefile
provision-uptime:
	@pip3 install -q -r requirements.txt
```
Mit einer `requirements.txt`:
```
uptime-kuma-api==1.2.1
pyyaml==6.0.2
```

---

## Compliance-Findings

### [⚪ COMPLIANCE] ISO 27001 A.8.15 — Logging-Integrität

**Regulation:** ISO 27001:2022 A.8.15
**Finding:** Logs werden über Promtail/Loki gesammelt, aber es gibt keinen Mechanismus zur Log-Integrity-Verification. Logs können über die Loki-API (auth_enabled: false) von jedem Container im Monitoring-Netzwerk manipuliert werden.
**Risk:** Bei einem Sicherheitsvorfall könnten manipulierte Logs die forensische Analyse unmöglich machen.
**Remediation:** Loki-Auth aktivieren, Log-Retention-Policy dokumentieren, optional: Log-Forwarding an einen unveränderlichen externen Speicher (z.B. S3 mit Object Lock).
**Evidence needed:** Dokumentierte Log-Retention-Policy, Nachweis dass Logs nicht nachträglich veränderbar sind.

### [⚪ COMPLIANCE] ISO 27001 A.8.9 — Configuration Management / Default Credentials

**Regulation:** ISO 27001:2022 A.8.9
**Finding:** Grafana nutzt Default-Konfiguration mit anonymem Zugang. Uptime Kuma-Credentials werden in einer `.env`-Datei im Klartext gespeichert.
**Risk:** Nicht dokumentierte Konfigurationsentscheidungen und fehlende Härtung widersprechen dem Configuration-Management-Control.
**Remediation:** Grafana-Auth aktivieren, Secrets-Management implementieren, Konfigurationsentscheidungen in einem ADR (Architecture Decision Record) dokumentieren.
**Evidence needed:** Dokumentiertes Security-Baseline-Dokument, Nachweis dass Default-Credentials geändert wurden.

### [⚪ COMPLIANCE] GDPR Art. 32 — Angemessene technische Maßnahmen

**Regulation:** DSGVO Art. 32
**Finding:** Falls personenbezogene Daten über die geproxten Services verarbeitet werden (z.B. WhatsApp-Nachrichten über Evolution API, Gesundheitsdaten über PulseBase/Garmin), fehlen angemessene Zugriffskontrollen auf Application-Layer-Ebene. Tailscale allein als Trust-Boundary reicht nicht aus, wenn ein einzelnes kompromittiertes Gerät Zugang zu allen Services gibt.
**Risk:** Bei Kompromittierung eines Tailnet-Geräts: Zugriff auf alle Services und potenzielle personenbezogene Daten ohne weitere Authentifizierung.
**Remediation:** Application-Layer-Auth für Services die personenbezogene Daten verarbeiten. Tailscale ACLs nutzen, um den Zugriff auf bestimmte Geräte zu beschränken.
**Evidence needed:** Tailscale ACL-Konfiguration, Dokumentation der Datenschutzmaßnahmen pro Service.

---

## Statistik

| Severity     | Security | Quality | Compliance |
| ------------ | -------- | ------- | ---------- |
| 🔴 Critical  | 0        | 0       | 0          |
| 🟠 High      | 3        | 0       | 0          |
| 🟡 Medium    | 4        | 1       | 0          |
| 🔵 Low       | 3        | 1       | 0          |
| ⚪ Info       | 1        | 1       | 3          |

**Gesamt: 17 Findings** (3 High, 5 Medium, 4 Low, 5 Info/Compliance)

---

## Top 3 Sofortmaßnahmen

1. **Reale Tailscale-IP aus `.env.example` entfernen** und durch Platzhalter ersetzen. Falls das Repository öffentlich ist/war: IP aus Git-History entfernen.

2. **Grafana-Authentifizierung aktivieren** (`GF_AUTH_ANONYMOUS_ENABLED=false`). Alternativ: Tailscale Serve/Funnel mit Authentication oder einen Auth-Proxy (z.B. Caddy mit `basicauth` oder Tailscale Auth Header) verwenden.

3. **Docker-Container härten**: Mindestens `security_opt: [no-new-privileges:true]` und `cap_drop: [ALL]` für alle Container hinzufügen. Wo möglich `user:` setzen und `read_only: true` aktivieren.

---

## Positiv-Highlights

Das Projekt implementiert bereits mehrere Security-Best-Practices:

- **Image-SHA-Pinning** für Loki, Promtail und Uptime Kuma
- **TruffleHog** als Pre-Commit-Hook und in CI
- **Custom PII-Detection** (`check-pii.sh`) mit Allowlist
- **Security Headers** im Caddyfile (HSTS, X-Content-Type-Options, X-Frame-Options, Permissions-Policy)
- **Resource Limits** auf allen Containern (CPU + Memory)
- **Log-Rotation** mit JSON-Driver und Size-Caps
- **Localhost-Binding** für interne Services (Loki auf 127.0.0.1, Uptime Kuma auf 127.0.0.1)
- **Read-Only Mounts** für Konfigurationsdateien (`:ro`)
- **CI-Pipeline** mit Lint, Hadolint, Secret-Scan, und Caddyfile-Validation
- **GitHub Actions SHA-Pinning** in der CI-Workflow

---

*Erstellt mit KI-Unterstützung (Claude Code + dev-best-practices Plugin).
Findings sind zu verifizieren — kein Ersatz für manuelle Penetrationstests.*
