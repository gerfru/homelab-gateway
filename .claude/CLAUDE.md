# homelab-gateway

## CI: Secret Scanning

TruffleHog (nicht gitleaks) wird fuer Secret Scanning verwendet — sowohl als
pre-commit Hook als auch in der GitHub Actions CI Pipeline.

Grund: GitHub Secret Scanning ist auf free-tier private Repos nicht verfuegbar.
TruffleHog bietet gleichwertige Erkennung mit verified/unverified Filterung.

- Pre-commit: `.pre-commit-config.yaml` (trufflehog Hook)
- CI: `.github/workflows/ci.yml` (secret-scan Job)
