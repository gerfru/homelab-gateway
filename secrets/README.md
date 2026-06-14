# Secrets Directory

Place Docker Secret files here (one value per file, no trailing newline).

## Required Files

| File | Purpose |
|------|---------|
| `gf_admin_user` | Grafana admin username |
| `gf_admin_password` | Grafana admin password |
| `gitea_db_password` | Gitea PostgreSQL database password |
| `gitea_admin_password` | Gitea admin user password |
| `renovate_token` | Gitea API token for Renovate Bot (optional) |
| `act_runner_token` | Gitea Actions runner registration token |

## Setup

```bash
# Grafana
echo -n "admin" > secrets/gf_admin_user
echo -n "your-strong-password" > secrets/gf_admin_password

# Gitea
echo -n "your-db-password" > secrets/gitea_db_password
echo -n "your-admin-password" > secrets/gitea_admin_password

# Renovate (create a Gitea API token after first Gitea login)
echo -n "your-gitea-api-token" > secrets/renovate_token

# Gitea Actions Runner registration token
# Get it: Gitea → Site Administration → Runners → Create Runner Token
echo -n "your-runner-registration-token" > secrets/act_runner_token
```

## Migration from .env

If you previously had `GF_ADMIN_USER` and `GF_ADMIN_PASSWORD` in `.env`:

```bash
grep -oP '(?<=GF_ADMIN_USER=).*' .env | tr -d '\n' > secrets/gf_admin_user
grep -oP '(?<=GF_ADMIN_PASSWORD=).*' .env | tr -d '\n' > secrets/gf_admin_password
```

Then remove `GF_ADMIN_USER` and `GF_ADMIN_PASSWORD` from your `.env` file.

## arbscanner Secrets

Required for the arbscanner prediction market arbitrage scanner.

| File | Purpose |
|------|---------|
| `kalshi_api_key_id` | Kalshi API Key ID (UUID string) |
| `kalshi_private_key` | Kalshi RSA private key (PEM format) |

### Setup (interactive)

```bash
make setup-arbscanner-secrets
```

### Setup (manual)

```bash
# API Key ID — no trailing newline
printf '%s' 'your-kalshi-key-id-uuid' > secrets/kalshi_api_key_id
chmod 600 secrets/kalshi_api_key_id

# RSA private key — copy your .pem file
cp /path/to/kalshi-key.pem secrets/kalshi_private_key
chmod 600 secrets/kalshi_private_key
```

Both files are mounted read-only into the arbscanner container via Docker Secrets
(`/run/secrets/kalshi_api_key_id` and `/run/secrets/kalshi_private_key`).
They never appear in environment variables or image layers.

## Note

All files in this directory (except this README) are gitignored.
