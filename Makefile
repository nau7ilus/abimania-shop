.PHONY: help dev down logs clean install-loki-plugin check-loki-socket restart-docker install-ssl-certificates

# Default Goal
.DEFAULT_GOAL := help

DOCKER := $(shell which docker 2>/dev/null)
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)

DOMAIN ?= abimania.local
DOMAIN_URL := https://$(DOMAIN)
PWD := $(CURDIR)
CERTS_DIR := $(PWD)/caddy/certs
CERT_PEM_FILE := $(CERTS_DIR)/local.cert.pem
KEY_PEM_FILE := $(CERTS_DIR)/local.key.pem

ifeq ($(DOCKER_COMPOSE),)
	DOCKER_COMPOSE := $(DOCKER) compose
endif

ARCH := $(shell uname -m)

# Help Task
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Docker Tasks
dev: ## Start development environment with docker-compose
	MY_UID="$(shell id -u)" MY_GID="$(shell id -g)" \
	$(DOCKER_COMPOSE) --env-file .env.development \
		-f ./docker-compose.yml \
		-f docker-compose.dev.yml \
		-f docker-compose.logging.yml up

down: ## Stop and remove all containers
	$(DOCKER_COMPOSE) down

logs: ## View the logs from the containers
	$(DOCKER_COMPOSE) logs -f

clean: ## Remove unused Docker data (images, containers, volumes)
	$(DOCKER) system prune -a --force
	$(DOCKER) volume prune --force

install-loki-plugin: ## Install the Loki Docker driver based on architecture
	@echo "Detected architecture: $(ARCH)"
	@if [ "$(ARCH)" = "x86_64" ]; then \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions || true; \
	elif [ "$(ARCH)" = "aarch64" ]; then \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions || true; \
	else \
		echo "Unsupported architecture: $(ARCH). Please install the plugin manually."; \
		exit 1; \
	fi

check-loki-socket: ## Verify if the Loki plugin socket exists
	@if [ -e "/run/docker/plugins/loki.sock" ]; then \
		echo "Loki plugin socket found."; \
	else \
		echo "Loki plugin socket not found. Reinstalling Loki plugin..."; \
		$(MAKE) install-loki-plugin; \
	fi

restart-docker: ## Restart the Docker service
	sudo systemctl restart docker

install-ssl-certificates: ## Install local SSL certificates for the given domain
	@echo "-- Installing mkcert ..."
	mkcert -install
	mkdir -p $(CERTS_DIR)
	@echo "-- Creating and installing local SSL certificates for domain: $(DOMAIN) + *.$(DOMAIN) ..."
	mkcert -cert-file $(CERT_PEM_FILE) -key-file $(KEY_PEM_FILE) "$(DOMAIN)" "*.$(DOMAIN)"
	@echo "-- Complete!"
	@echo
	@echo "- Now you can run: $(DOCKER_COMPOSE) up"
	@echo "- Open browser to domain: $(DOMAIN_URL)"