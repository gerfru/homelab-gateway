# homelab-gateway

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

## Renovate: Ausfuehrung

Renovate laeuft NICHT als Daemon, sondern als einmaliger Run ueber das
Docker Compose `tools`-Profil:

```bash
docker compose --profile tools run --rm renovate
```

Fuer automatische Ausfuehrung: Host-Cron (`crontab -e`).
