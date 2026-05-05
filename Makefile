.PHONY: generate up down status logs test-dns clean

include .env
export

generate:
	@echo "Generating DNS config from templates..."
	@envsubst < dns/Corefile.tmpl > dns/Corefile
	@envsubst < dns/home.lab.zone.tmpl > dns/home.lab.zone
	@echo "Done. Generated:"
	@echo "  dns/Corefile"
	@echo "  dns/home.lab.zone"
	@echo ""
	@echo "Run 'make up' to start the gateway."

up:
	docker compose up -d

down:
	docker compose down

status:
	docker compose ps

logs:
	docker compose logs -f

logs-caddy:
	docker compose logs -f caddy

logs-dns:
	docker compose logs -f coredns

test-dns:
	@echo "Testing DNS resolution for *.${DOMAIN} via ${TAILSCALE_IP}..."
	@echo ""
	@echo "niles.${DOMAIN}:"
	@dig @${TAILSCALE_IP} niles.${DOMAIN} +short
	@echo "garmin.${DOMAIN}:"
	@dig @${TAILSCALE_IP} garmin.${DOMAIN} +short
	@echo "vikunja.${DOMAIN}:"
	@dig @${TAILSCALE_IP} vikunja.${DOMAIN} +short
	@echo "random.${DOMAIN} (wildcard test):"
	@dig @${TAILSCALE_IP} random.${DOMAIN} +short

clean:
	docker compose down -v
	rm -f dns/Corefile dns/home.lab.zone
