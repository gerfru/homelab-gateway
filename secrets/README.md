# Secrets Directory

Place Docker Secret files here (one value per file, no trailing newline).

## Required Files

| File | Purpose |
|------|---------|
| `gf_admin_user` | Grafana admin username |
| `gf_admin_password` | Grafana admin password |

## Setup

```bash
echo -n "admin" > secrets/gf_admin_user
echo -n "your-strong-password" > secrets/gf_admin_password
```

## Migration from .env

If you previously had `GF_ADMIN_USER` and `GF_ADMIN_PASSWORD` in `.env`:

```bash
grep -oP '(?<=GF_ADMIN_USER=).*' .env | tr -d '\n' > secrets/gf_admin_user
grep -oP '(?<=GF_ADMIN_PASSWORD=).*' .env | tr -d '\n' > secrets/gf_admin_password
```

Then remove `GF_ADMIN_USER` and `GF_ADMIN_PASSWORD` from your `.env` file.

## Note

All files in this directory (except this README) are gitignored.
