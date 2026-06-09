.PHONY: help generate up down status logs test-dns clean dns-up dns-down dns-status dns-logs logs-caddy logs-dns check-env test test-generate test-smoke test-update-golden

-include .env
export DOMAIN TAILSCALE_IP

UNAME := $(shell uname)
REPO_DIR := $(shell pwd)
ZONE_FILE := $(REPO_DIR)/dns/home.lab.zone

.DEFAULT_GOAL := help

help: ## Show available targets
	@echo "homelab-gateway — available targets:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Run 'make up' to start the gateway."

# --- Generate DNS config from templates ---

generate: ## Generate DNS + Caddy config from templates
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

check-env: ## Verify .env configuration
	@if [ ! -f .env ]; then \
		echo "ERROR: .env file not found. Copy .env.example to .env and configure it:"; \
		echo "  cp .env.example .env"; \
		exit 1; \
	fi
	@if grep -qE '(changeme|CHANGE_ME_BEFORE_DEPLOY)' .env; then \
		echo "ERROR: Default passwords detected in .env — please change before deploying."; \
		exit 1; \
	fi
	@if grep -qE '^TAILSCALE_IP=100\.x\.x\.x' .env; then \
		echo "ERROR: TAILSCALE_IP is still the placeholder (100.x.x.x). Set your actual Tailscale IP:"; \
		echo "  tailscale ip -4"; \
		exit 1; \
	fi
	@if [ ! -f secrets/gf_admin_user ] || [ ! -f secrets/gf_admin_password ]; then \
		echo "ERROR: Grafana secrets missing. Create them:"; \
		echo "  mkdir -p secrets"; \
		echo '  echo -n "admin" > secrets/gf_admin_user'; \
		echo '  echo -n "your-password" > secrets/gf_admin_password'; \
		exit 1; \
	fi
	@if ! grep -qE '^CADDY_AUTH_USER=' .env || ! grep -qE '^CADDY_AUTH_PASS_HASH=' .env; then \
		echo "WARNING: CADDY_AUTH not set — Prometheus and metrics subdomains will be unprotected."; \
	fi

up: check-env generate dns-up ## Start the full gateway stack
	@echo "Starting Caddy..."
ifeq ($(UNAME),Darwin)
	docker compose --env-file .env up -d
else
	COMPOSE_PROFILES=linux docker compose --env-file .env up -d
endif
	@echo ""
	@echo "Gateway running. Test with: make test-dns"

down: dns-down ## Stop all services
	docker compose down

# --- CoreDNS (OS-aware) ---

dns-up: ## Start CoreDNS (native on macOS, Docker on Linux)
ifeq ($(UNAME),Darwin)
	@echo "Starting CoreDNS natively (macOS)..."
	@echo "Note: Port 53 requires sudo — you may be prompted for your password."
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

dns-down: ## Stop CoreDNS
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

dns-status: ## Check CoreDNS status
ifeq ($(UNAME),Darwin)
	@if pgrep -x coredns >/dev/null 2>&1; then \
		echo "CoreDNS: running (PID: $$(pgrep -x coredns))"; \
	else \
		echo "CoreDNS: not running"; \
	fi
else
	docker compose ps coredns
endif

dns-logs: ## Show CoreDNS logs
ifeq ($(UNAME),Darwin)
	@echo "CoreDNS log (macOS): /tmp/coredns.log"
	@tail -50 /tmp/coredns.log 2>/dev/null || echo "No log file found."
else
	docker compose logs -f coredns
endif

# --- Docker Compose shortcuts ---

status: ## Show container + DNS status
	docker compose ps
	@echo ""
	@$(MAKE) dns-status

logs: ## Live logs (all services)
	docker compose logs -f

logs-caddy: ## Live Caddy logs
	docker compose logs -f caddy

logs-dns: dns-logs ## Alias for dns-logs

# --- Testing ---

test: test-generate ## Run offline tests
	@echo ""
	@echo "Offline tests passed. For stack tests: make test-dns test-smoke"

test-generate: ## Run template golden-file tests
	@echo "Running template generation tests..."
	@bash tests/test-generate.sh

test-dns: ## Run DNS resolution tests (requires running stack)
	@echo "Running DNS resolution tests..."
	@bash tests/test-dns.sh

test-smoke: ## Run stack smoke tests (requires running stack)
	@echo "Running stack smoke tests..."
	@bash tests/test-smoke.sh

test-update-golden: ## Regenerate golden test files
	@echo "Regenerating golden files..."
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN' < Caddyfile.tmpl > tests/golden/Caddyfile
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/Corefile.tmpl > tests/golden/Corefile.linux
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 ZONE_FILE=/repo/dns/home.lab.zone envsubst '$$DOMAIN $$TAILSCALE_IP $$ZONE_FILE' < dns/Corefile.macos.tmpl > tests/golden/Corefile.macos
	@DOMAIN=test.example TAILSCALE_IP=100.64.0.1 envsubst '$$DOMAIN $$TAILSCALE_IP' < dns/home.lab.zone.tmpl > tests/golden/home.lab.zone
	@echo "Golden files updated in tests/golden/"

# --- Cleanup ---

clean: dns-down ## Remove containers, volumes, and generated files
	@echo "WARNING: This will destroy all containers, volumes (including data), and generated files."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || { echo "Aborted."; exit 1; }
	docker compose down -v
	rm -f dns/Corefile dns/home.lab.zone Caddyfile
	@echo "Clean complete."
