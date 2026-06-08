.PHONY: generate up down status logs test-dns clean dns-up dns-down dns-status dns-logs

include .env
export

UNAME := $(shell uname)
REPO_DIR := $(shell pwd)
ZONE_FILE := $(REPO_DIR)/dns/home.lab.zone

# --- Generate DNS config from templates ---

generate:
ifeq ($(UNAME),Darwin)
	@echo "Generating DNS config (macOS — native CoreDNS)..."
	@ZONE_FILE=$(ZONE_FILE) envsubst '$$DOMAIN $$TAILSCALE_IP $$ZONE_FILE' < dns/Corefile.macos.tmpl > dns/Corefile
else
	@echo "Generating DNS config (Linux — Docker CoreDNS)..."
	@envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/Corefile.tmpl > dns/Corefile
endif
	@envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/home.lab.zone.tmpl > dns/home.lab.zone
	@envsubst '$$DOMAIN' < Caddyfile.tmpl > Caddyfile
	@echo "Done. Generated:"
	@echo "  dns/Corefile"
	@echo "  dns/home.lab.zone"
	@echo "  Caddyfile"
	@echo ""
	@echo "Run 'make up' to start the gateway."

# --- Start/Stop everything ---

up: generate dns-up
	@echo "Starting Caddy..."
ifeq ($(UNAME),Darwin)
	docker compose up -d
else
	COMPOSE_PROFILES=linux docker compose up -d
endif
	@echo ""
	@echo "Gateway running. Test with: make test-dns"

down: dns-down
	docker compose down

# --- CoreDNS (OS-aware) ---

dns-up:
ifeq ($(UNAME),Darwin)
	@echo "Starting CoreDNS natively (macOS)..."
	@if ! command -v coredns >/dev/null 2>&1; then \
		echo "CoreDNS not found. Installing via brew..."; \
		brew install coredns; \
	fi
	@echo "Ensuring macOS firewall allows CoreDNS..."
	@sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add $$(which coredns) >/dev/null 2>&1 || true
	@sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp $$(which coredns) >/dev/null 2>&1 || true
	@if pgrep -x coredns >/dev/null 2>&1; then \
		echo "CoreDNS already running — reloading config..."; \
		sudo pkill -HUP coredns || true; \
	else \
		echo "Starting CoreDNS (port 53 requires sudo)..."; \
		sudo sh -c 'nohup coredns -conf $(REPO_DIR)/dns/Corefile > /tmp/coredns.log 2>&1 & echo $$! > /tmp/coredns.pid'; \
		sleep 1; \
		if pgrep -x coredns >/dev/null 2>&1; then \
			echo "CoreDNS started (PID: $$(cat /tmp/coredns.pid))"; \
		else \
			echo "ERROR: CoreDNS failed to start. Check /tmp/coredns.log"; \
			cat /tmp/coredns.log; \
			exit 1; \
		fi; \
	fi
else
	@echo "CoreDNS will start via Docker Compose (linux profile)."
endif

dns-down:
ifeq ($(UNAME),Darwin)
	@echo "Stopping CoreDNS (macOS)..."
	@if [ -f /tmp/coredns.pid ]; then \
		sudo kill $$(cat /tmp/coredns.pid) 2>/dev/null || true; \
		sudo rm -f /tmp/coredns.pid; \
		echo "CoreDNS stopped."; \
	elif pgrep -x coredns >/dev/null 2>&1; then \
		sudo pkill coredns; \
		echo "CoreDNS stopped."; \
	else \
		echo "CoreDNS not running."; \
	fi
else
	@echo "CoreDNS stops with Docker Compose."
endif

dns-status:
ifeq ($(UNAME),Darwin)
	@if pgrep -x coredns >/dev/null 2>&1; then \
		echo "CoreDNS: running (PID: $$(pgrep -x coredns))"; \
	else \
		echo "CoreDNS: not running"; \
	fi
else
	docker compose ps coredns
endif

dns-logs:
ifeq ($(UNAME),Darwin)
	@echo "CoreDNS log (macOS): /tmp/coredns.log"
	@tail -50 /tmp/coredns.log 2>/dev/null || echo "No log file found."
else
	docker compose logs -f coredns
endif

# --- Docker Compose shortcuts ---

status:
	docker compose ps
	@echo ""
	@make dns-status

logs:
	docker compose logs -f

logs-caddy:
	docker compose logs -f caddy

logs-dns: dns-logs

# --- DNS testing ---

test-dns:
	@echo "Testing DNS resolution for *.$(DOMAIN) via $(TAILSCALE_IP)..."
	@echo ""
	@echo "niles.$(DOMAIN):"
	@dig @$(TAILSCALE_IP) niles.$(DOMAIN) +short
	@echo "garmin.$(DOMAIN):"
	@dig @$(TAILSCALE_IP) garmin.$(DOMAIN) +short
	@echo "vikunja.$(DOMAIN):"
	@dig @$(TAILSCALE_IP) vikunja.$(DOMAIN) +short
	@echo "random.$(DOMAIN) (wildcard test):"
	@dig @$(TAILSCALE_IP) random.$(DOMAIN) +short

# --- Cleanup ---

clean: dns-down
	docker compose down -v
	rm -f dns/Corefile dns/home.lab.zone Caddyfile
