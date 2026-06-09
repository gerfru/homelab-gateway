.PHONY: generate up down status logs test-dns clean dns-up dns-down dns-status dns-logs logs-caddy logs-dns check-env test test-generate test-smoke test-update-golden

include .env
export DOMAIN TAILSCALE_IP

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

check-env:
	@if grep -qE '(changeme|CHANGE_ME_BEFORE_DEPLOY)' .env; then \
		echo "ERROR: Default passwords detected in .env — please change before deploying."; \
		exit 1; \
	fi

up: check-env generate dns-up
	@echo "Starting Caddy..."
ifeq ($(UNAME),Darwin)
	docker compose --env-file .env up -d
else
	COMPOSE_PROFILES=linux docker compose --env-file .env up -d
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
	@$(MAKE) dns-status

logs:
	docker compose logs -f

logs-caddy:
	docker compose logs -f caddy

logs-dns: dns-logs

# --- Testing ---

test: test-generate
	@echo ""
	@echo "Offline tests passed. For stack tests: make test-dns test-smoke"

test-generate:
	@echo "Running template generation tests..."
	@bash tests/test-generate.sh

test-dns:
	@echo "Running DNS resolution tests..."
	@bash tests/test-dns.sh

test-smoke:
	@echo "Running stack smoke tests..."
	@bash tests/test-smoke.sh

test-update-golden:
	@echo "Regenerating golden files..."
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN' < Caddyfile.tmpl > tests/golden/Caddyfile
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/Corefile.tmpl > tests/golden/Corefile.linux
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 ZONE_FILE=/repo/dns/home.lab.zone envsubst '$$DOMAIN $$TAILSCALE_IP $$ZONE_FILE' < dns/Corefile.macos.tmpl > tests/golden/Corefile.macos
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/home.lab.zone.tmpl > tests/golden/home.lab.zone
	@echo "Golden files updated in tests/golden/"

# --- Cleanup ---

clean: dns-down
	docker compose down -v
	rm -f dns/Corefile dns/home.lab.zone Caddyfile
