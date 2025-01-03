.PHONY: help dev down logs clean install-loki-plugin check-loki-socket restart-docker install-ssl-certificates

.DEFAULT_GOAL := help

PWD := $(CURDIR)
CERTS_DIR := $(PWD)/caddy/certs
CERT_PEM_FILE := $(CERTS_DIR)/local.cert.pem
KEY_PEM_FILE := $(CERTS_DIR)/local.key.pem

ARCH := $(shell uname -m)

DOCKER := $(shell which docker 2>/dev/null)
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)
ifeq ($(DOCKER_COMPOSE),)
	DOCKER_COMPOSE := $(DOCKER) compose
endif

CADDY_BASE_DOMAIN ?= abimania.local
DOMAIN_URL := https://$(CADDY_BASE_DOMAIN)

ENVIRONMENT ?= production
ENV_FILE = .env$(if $(findstring development,$(ENVIRONMENT)),.development,)
include $(ENV_FILE)
export $(shell sed '/^\#/d; s/=.*//' $(ENV_FILE)) 

TEMPLATE_FILES := $(PWD)/pretix/config/pretix.template.cfg
CFG_FILES := $(TEMPLATE_FILES:.template.cfg=.cfg)

# Pretix Config
config: $(CFG_FILES) ## Generate configuration files from templates
	@echo "All configuration files have been generated."
	@set -a; . $(ENV_FILE); set +a;

# Rule to generate .cfg from .template.cfg using envsubst
$(PWD)/pretix/config/%.cfg: $(PWD)/pretix/config/%.template.cfg $(ENV_FILE)
	@set -a; . $(ENV_FILE); set +a; envsubst < $< > $@

dev: check-loki-socket $(CFG_FILES) ## Starte die Entwicklungsumgebung
	MY_UID="$(shell id -u)" MY_GID="$(shell id -g)" \
	$(DOCKER_COMPOSE) --env-file $(ENV_FILE) \
	-f docker-compose.dev.yml up

down: ## Stoppe und entferne alle Container 
	@echo "Stoppe $(ENVIRONMENT)-Umgebung..."
	@if [ "$(ENVIRONMENT)" = "development" ]; then \
		$(DOCKER_COMPOSE) -f docker-compose.dev.yml down; \
	else \
		echo "Unbekannte Umgebung: $(ENVIRONMENT). Fällt auf Produktion zurück."; \
		$(DOCKER_COMPOSE) -f docker-compose.logging.yml -f docker-compose.yml down; \
	fi

logs: ## Zeige die Logs der Container
	@if [ -z "$(CONTAINERS)" ]; then \
		echo "Zeige Logs für alle Container..."; \
		$(DOCKER_COMPOSE) logs -f; \
	else \
		echo "Zeige Logs für die Container: $(CONTAINERS)..."; \
		$(DOCKER_COMPOSE) logs -f $(CONTAINERS); \
	fi

install-loki-plugin: ## Install Loki Docker Plugin
	@echo "Detected architecture: $(ARCH)"
	$(if $(findstring x86_64, $(ARCH)), \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions || true, \
	$(if $(findstring aarch64,$(ARCH))$(findstring arm64,$(ARCH)), \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions || true, \
		echo "Unsupported architecture: $(ARCH). Please install the plugin manually." && exit 1))

check-loki-socket: ## Überprüfe, ob der Loki Plugin Socket existiert
	@if [ -e "/run/docker/plugins/loki.sock" ]; then \
		echo "Loki Plugin Socket gefunden."; \
	else \
		echo "Loki Plugin Socket nicht gefunden. Installiere das Loki Plugin neu..."; \
		$(MAKE) install-loki-plugin; \
	fi

restart-docker: ## Starte den Docker-Dienst neu
	sudo systemctl restart docker

install-ssl-certificates: ## Installiere lokale SSL-Zertifikate
	@echo "-- Installiere mkcert ..."
	mkcert -install
	mkdir -p $(CERTS_DIR)
	@echo "-- Erstelle und installiere lokale SSL-Zertifikate für Domain: $(CADDY_BASE_DOMAIN) + *.$(CADDY_BASE_DOMAIN) ..."
	mkcert -cert-file $(CERT_PEM_FILE) -key-file $(KEY_PEM_FILE) "$(CADDY_BASE_DOMAIN)" "*.$(CADDY_BASE_DOMAIN)"
	@echo "-- Fertig!"
	@echo
	@echo "- Jetzt kannst du ausführen: $(DOCKER_COMPOSE) up"
	@echo "- Öffne den Browser unter: $(DOMAIN_URL)"

rm-all: ## Lösche alle aktive Docker-Prozesse
	docker rm -f $(shell docker ps -a -q)

update-submodules: ## Installiere alle Git Submodules
	git submodule foreach git pull origin main

PRETIX_CRON_JOB=15,45 * * * * /usr/bin/docker exec pretix pretix cron
pretix-addcron: ## Cron für pretix hinzufügen
	@{ crontab -l 2>/dev/null | grep -Fxq "$(PRETIX_CRON_JOB)" || { \
		crontab -l 2>/dev/null; \
		echo "$(PRETIX_CRON_JOB)"; \
	}; } | crontab -

clean: ## Entferne ungenutzte Docker-Daten (Images, Container, Volumes)
	$(DOCKER) system prune -a --force
	$(DOCKER) volume prune --force

help: ## Zeige diese Hilfsnachricht
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
