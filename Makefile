.PHONY: help dev down logs clean install-loki-plugin check-loki-socket restart-docker install-ssl-certificates

.DEFAULT_GOAL := help

DOCKER := $(shell which docker 2>/dev/null)
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)
ifeq ($(DOCKER_COMPOSE),)
	DOCKER_COMPOSE := $(DOCKER) compose
endif

DOMAIN ?= abimania.local
DOMAIN_URL := https://$(DOMAIN)
PWD := $(CURDIR)
CERTS_DIR := $(PWD)/caddy/certs
CERT_PEM_FILE := $(CERTS_DIR)/local.cert.pem
KEY_PEM_FILE := $(CERTS_DIR)/local.key.pem
ARCH := $(shell uname -m)

ENV_FILE ?= .env.development
include $(ENV_FILE)
export $(shell sed 's/=.*//' $(ENV_FILE))

TEMPLATE_FILES := $(PWD)/pretix/config/pretix.template.cfg
CFG_FILES := $(TEMPLATE_FILES:.template.cfg=.cfg)

help: ## Zeige diese Hilfsnachricht
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

config: $(CFG_FILES) ## Generiere Konfigurationsdateien aus Templates
	@echo "Alle Konfigurationsdateien wurden generiert."

$(PWD)/pretix/config/%.cfg: $(PWD)/pretix/config/%.template.cfg $(ENV_FILE)
	@echo "Erstelle Konfigurationsdatei $@ aus Template $< mit envsubst..."
	envsubst < $< > $@

dev: check-loki-socket $(CFG_FILES) ## Starte die Entwicklungsumgebung
	MY_UID="$(shell id -u)" MY_GID="$(shell id -g)" \
	$(DOCKER_COMPOSE) --env-file $(ENV_FILE) \
		-f ./docker-compose.yml \
		-f docker-compose.dev.yml \
		-f docker-compose.logging.yml up

down: ## Stoppe und entferne alle Container
	$(DOCKER_COMPOSE) down

logs: ## Zeige die Logs der Container
	$(DOCKER_COMPOSE) logs -f

clean: ## Entferne ungenutzte Docker-Daten (Images, Container, Volumes)
	$(DOCKER) system prune -a --force
	$(DOCKER) volume prune --force

install-loki-plugin: ## Installiere das Loki Docker Plugin
	@echo "Erkannte Architektur: $(ARCH)"
	@if [ "$(ARCH)" = "x86_64" ]; then \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions || true; \
	elif [ "$(ARCH)" = "aarch64" ]; then \
		$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions || true; \
	else \
		echo "Nicht unterstützte Architektur: $(ARCH). Bitte installiere das Plugin manuell."; \
		exit 1; \
	fi

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
	@echo "-- Erstelle und installiere lokale SSL-Zertifikate für Domain: $(DOMAIN) + *.$(DOMAIN) ..."
	mkcert -cert-file $(CERT_PEM_FILE) -key-file $(KEY_PEM_FILE) "$(DOMAIN)" "*.$(DOMAIN)"
	@echo "-- Fertig!"
	@echo
	@echo "- Jetzt kannst du ausführen: $(DOCKER_COMPOSE) up"
	@echo "- Öffne den Browser unter: $(DOMAIN_URL)"

rm-all:
	docker rm -f $(shell docker ps -a -q)