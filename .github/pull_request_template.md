## Was ändert dieser PR?

<!-- Kurze Beschreibung der Änderung und warum sie gemacht wird -->

## Art der Änderung

- [ ] Bug fix
- [ ] Feature / Neuer Service
- [ ] Refactoring
- [ ] Security fix
- [ ] Docs / Config
- [ ] Dependency Update

## Test-Checkliste

- [ ] CI Pipeline läuft grün (lint, docker-compose-validate, secret-scan, caddyfile-validate)
- [ ] `docker compose config --quiet` lokal erfolgreich
- [ ] Bei Service-Änderungen: `make up` + `make test-dns` lokal getestet
- [ ] Bei Caddyfile-Änderungen: `make generate` erzeugt korrekte Config

## Security

- [ ] Keine Secrets im Code oder Logs
- [ ] Neue Ports/Bindings nur auf Tailscale IP oder localhost
- [ ] Docker Images mit SHA256 Digest gepinnt
