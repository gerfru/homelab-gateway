# homelab-gateway

## Golden Files: Caddyfile-Test

Bei jeder Aenderung an `Caddyfile.tmpl` muessen die Golden Files aktualisiert werden:

```bash
make test-update-golden
```

Sonst schlaegt `test-generate` in CI fehl. Golden Files liegen in `tests/golden/`.

## CI: Secret Scanning

TruffleHog (nicht gitleaks) wird fuer Secret Scanning verwendet — sowohl als
pre-commit Hook als auch in der GitHub Actions CI Pipeline.

Grund: GitHub Secret Scanning ist auf free-tier private Repos nicht verfuegbar.
TruffleHog bietet gleichwertige Erkennung mit verified/unverified Filterung.

- Pre-commit: `.pre-commit-config.yaml` (trufflehog Hook)
- CI: `.github/workflows/ci.yml` (secret-scan Job)

## Loki: Auth-Modell

Loki verwendet `auth_enabled: true` mit Tenant-ID `homelab` (Single-Tenant).
Das ist adaequat fuer ein Single-User-Homelab-Setup:

- Tenant-ID `homelab` in Promtail (`X-Scope-OrgID`) und Grafana Datasource
- Port nur auf `127.0.0.1:3100` gebunden (nicht von aussen erreichbar)
- Monitoring-Network isoliert (kein externes Routing)
- Kein API-Gateway oder Multi-Tenant-Auth noetig

Konfiguration:

- `monitoring/loki-config.yml`: `auth_enabled: true`
- `monitoring/promtail-config.yml`: `tenant_id: homelab`
- `monitoring/grafana/provisioning/datasources/loki.yml`: `X-Scope-OrgID: homelab`

## Gitea + PostgreSQL: Container-Hardening

PostgreSQL (`gitea-db`) und Gitea verwenden `su-exec`/`gosu` fuer User-Switching
(root -> postgres / root -> git). Das erfordert `setuid`, weshalb
`security_opt: no-new-privileges:true` NICHT gesetzt werden kann.

Akzeptiertes Risiko, dokumentiert in `docker-compose.yml` mit `ACCEPTED RISK`
Kommentaren. Beide Services haben trotzdem `cap_drop: ALL` mit minimal
notwendigen `cap_add` (CHOWN, FOWNER, SETGID, SETUID, DAC_READ_SEARCH).

Gitea kann auch kein `read_only: true` verwenden — es schreibt in diverse
Verzeichnisse unter `/data` (Avatare, LFS, Sessions, etc.).

## Gitea: Volume-Trennung

Drei separate Volumes fuer Gitea:

- `gitea-data` — App-Daten (Avatare, LFS, Attachments, Sessions)
- `gitea-repos` — Git-Repositories (mounted at `/data/git/repositories`)
- `gitea-db-data` — PostgreSQL-Daten

Der Pfad `/data/git/repositories` ist Gitea's Default — NICHT `/data/gitea/repositories`.

## Caddy: Security-Header-Snippets

Drei Snippets — das richtige haengt davon ab ob die App einen eigenen CSP mitbringt:

- `security_headers` — Standard, setzt statischen CSP (`default-src 'self'` etc.)
- `security_headers_relaxed` — Third-Party-Apps die `unsafe-inline` benoetigen (Vikunja, Grafana, Gitea)
- `security_headers_app_csp` — Apps mit eigenem nonce-basiertem CSP (Niles, PulseBase); Gateway setzt KEINEN CSP, App-CSP wird unveraendert durchgereicht

`security_headers_app_csp` importiert nur `common_security` (HSTS, X-Frame-Options,
X-Content-Type-Options, etc.) — kein `Content-Security-Policy` Header vom Gateway.

Grund: Caddys `header`-Direktive wuerde den Upstream-CSP sonst ersetzen, was
nonce-basierte CSPs bricht.

## Loki: Retention-Konfiguration

Retention wird ausschliesslich ueber `monitoring/loki-config.yml` konfiguriert
(`limits_config.retention_period`, `compactor.retention_enabled`).

Der fruehher verwendete CLI-Flag `-limits.retention-period` existiert in
Loki 3.x NICHT mehr — nur Config-File verwenden.

## Watchtower: Healthcheck

Watchtower (`containrrr/watchtower`) ist ein scratch/distroless Image — kein `/bin/sh`.
`CMD-SHELL`-Healthchecks schlagen daher immer fehl.

Healthcheck ist deaktiviert (`healthcheck: disable: true`). Prozess-Liveness
wird durch `restart: unless-stopped` sichergestellt.

Im Smoke-Test: `assert_running watchtower` statt `assert_healthy`.

## Smoke-Test: Security-Header-Checks

`assert_header` in `tests/test-smoke.sh` verwendet `--resolve` statt IP-URL + Host-Header:

```bash
curl -sk --resolve "${fqdn}:443:${TAILSCALE_IP}" "https://${fqdn}/"
```

Grund: Caddy verwendet `tls internal` (SNI-basiert). curl mit IP-URL sendet
keinen SNI — TLS-Handshake schlaegt fehl. `--resolve` setzt SNI korrekt.

## Releases: Automatischer Prozess

Releases entstehen automatisch durch release-please nach jedem Merge auf `main`.
KEIN manuelles Tagging noetig.

Ablauf:

1. PR mit Conventional Commits auf `main` mergen (`fix:`, `feat:`, `chore:` etc.)
2. release-please oeffnet/aktualisiert einen Release-PR (Version-Bump + Changelog)
3. Release-PR mergen → GitHub Release + Git-Tag werden automatisch erstellt

Versionierung: `fix:` → Patch, `feat:` → Minor, `feat!:` / `BREAKING CHANGE:` → Major.

Workflow: `.github/workflows/release-please.yml`

## Renovate: Ausfuehrung

Renovate laeuft NICHT als Daemon, sondern als einmaliger Run ueber das
Docker Compose `tools`-Profil:

```bash
docker compose --profile tools run --rm renovate
```

Fuer automatische Ausfuehrung: Host-Cron (`crontab -e`).
