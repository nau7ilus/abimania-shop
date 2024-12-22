# https://gist.github.com/mpneuried/0594963ad38e68917ef189b4e6a269db
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

DOCKER := $(shell which docker 2>/dev/null)
DOCKER_COMPOSE := $(shell which docker-compose 2>/dev/null)

ifeq ($(DOCKER_COMPOSE),)
	DOCKER_COMPOSE := $(DOCKER) compose
endif

ARCH := $(shell uname -m)

# DOCKER TASKS
dev: ## TODO
	MY_UID="$(id -u)" MY_GID="$(id -g)" $(DOCKER_COMPOSE) --env-file .env.development \
		-f ./docker-compose.yml \
		-f docker-compose.dev.yml \
		-f docker-compose.logging.yml up

down: ## Stops and removes all containers
	$(DOCKER_COMPOSE) down

logs: ## View the logs from the containers
	$(DOCKER_COMPOSE) logs -f

open: ## Opens website
	open http://localhost:3000/

clean:
	$(DOCKER) system prune -aF
	$(DOCKER) volume prune -f

install-loki-plugin: ## Installs the loki-docker-driver for Docker based on architecture
ifeq ($(ARCH),x86_64)
	@echo "Detected architecture: amd64"
	$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-amd64 --alias loki --grant-all-permissions || true
else ifeq ($(ARCH),aarch64)
	@echo "Detected architecture: arm64"
	$(DOCKER) plugin install grafana/loki-docker-driver:3.3.2-arm64 --alias loki --grant-all-permissions || true
else
	@echo "Unsupported architecture: $(ARCH). Please install the plugin manually."
	exit 1
endif

check-loki-socket: ## Checks if Loki plugin socket exists
	@if [ -e "/run/docker/plugins/loki.sock" ]; then \
		echo "Loki plugin socket found."; \
	else \
		echo "Loki plugin socket not found. Reinstalling Loki plugin..."; \
		$(MAKE) install-loki-plugin; \
	fi

restart-docker: ## Restarts Docker service
	sudo systemctl restart docker