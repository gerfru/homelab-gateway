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
