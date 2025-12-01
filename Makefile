
# Configuration & Variables


# Load environment variables if .env exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Define Compose Files
COMPOSE_DEV  := docker/compose.development.yaml
COMPOSE_PROD := docker/compose.production.yaml

# Default Mode (dev or prod)
MODE ?= dev

# Determine which compose file to use based on MODE
ifeq ($(MODE), prod)
    COMPOSE_FILE := $(COMPOSE_PROD)
    PROJECT_NAME := ecommerce_prod
else
    COMPOSE_FILE := $(COMPOSE_DEV)
    PROJECT_NAME := ecommerce_dev
endif

# Base Docker Compose Command
COMPOSE_CMD := docker compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME)

# Default Service (can be overridden, e.g., make logs SERVICE=gateway)
SERVICE ?=


# Docker Services

.PHONY: up down build logs restart shell ps

# up - Start services
# Usage: make up [service...]
# Example: make up
# Example: make up SERVICE=backend
# Example: make up MODE=prod ARGS="--build"
up:
	@echo "Starting services in $(MODE) mode..."
	$(COMPOSE_CMD) up -d $(ARGS) $(SERVICE)

# down - Stop services
# Usage: make down [service...]
# Example: make down MODE=prod ARGS="--volumes"
down:
	@echo "Stopping services in $(MODE) mode..."
	$(COMPOSE_CMD) down $(ARGS) $(SERVICE)

# build - Build containers
# Usage: make build [service...]
build:
	@echo "Building images in $(MODE) mode..."
	$(COMPOSE_CMD) build $(ARGS) $(SERVICE)

# logs - View logs
# Usage: make logs [service]
# Example: make logs SERVICE=backend MODE=prod
logs:
	$(COMPOSE_CMD) logs -f $(ARGS) $(SERVICE)

# restart - Restart services
# Usage: make restart [service...]
restart:
	$(COMPOSE_CMD) restart $(ARGS) $(SERVICE)

# shell - Open shell in container
# Usage: make shell [service] (default: backend)
shell:
	@echo "Opening shell in $(or $(SERVICE),backend)..."
	$(COMPOSE_CMD) exec $(or $(SERVICE),backend) /bin/sh

# ps - Show running containers
ps:
	$(COMPOSE_CMD) ps $(ARGS)

# -----------------------------------------------------------------------------
# Convenience Aliases (Development)
# -----------------------------------------------------------------------------

.PHONY: dev-up dev-down dev-build dev-logs dev-restart dev-shell dev-ps backend-shell gateway-shell mongo-shell

dev-up:
	$(MAKE) up MODE=dev

dev-down:
	$(MAKE) down MODE=dev

dev-build:
	$(MAKE) build MODE=dev

dev-logs:
	$(MAKE) logs MODE=dev

dev-restart:
	$(MAKE) restart MODE=dev

dev-shell:
	$(MAKE) shell SERVICE=backend MODE=dev

dev-ps:
	$(MAKE) ps MODE=dev

backend-shell:
	$(MAKE) shell SERVICE=backend

gateway-shell:
	$(MAKE) shell SERVICE=gateway

mongo-shell:
	@echo "Connecting to MongoDB shell..."
	$(COMPOSE_CMD) exec mongo mongosh -u $(MONGO_INITDB_ROOT_USERNAME) -p $(MONGO_INITDB_ROOT_PASSWORD)


# Convenience Aliases (Production)


.PHONY: prod-up prod-down prod-build prod-logs prod-restart

prod-up:
	$(MAKE) up MODE=prod

prod-down:
	$(MAKE) down MODE=prod

prod-build:
	$(MAKE) build MODE=prod

prod-logs:
	$(MAKE) logs MODE=prod

prod-restart:
	$(MAKE) restart MODE=prod


# Backend (Local Development)

.PHONY: backend-build backend-install backend-type-check backend-dev

backend-install:
	cd backend && npm install

backend-build:
	cd backend && npm run build

backend-type-check:
	cd backend && npm run type-check

# Run backend locally (requires local MongoDB or port forwarding)
backend-dev:
	cd backend && npm run dev


# Database Operations


.PHONY: db-reset db-backup

# Reset Database (WARNING: Deletes volume data)
db-reset:
	@echo "WARNING: This will destroy the $(MODE) database volume. Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	$(COMPOSE_CMD) down --volumes
	@echo "Database reset complete."

# Backup Database to local ./backups folder
db-backup:
	@mkdir -p backups
	@echo "Creating backup for $(MODE) database..."
	$(COMPOSE_CMD) exec -T mongo mongodump \
		--username $(MONGO_INITDB_ROOT_USERNAME) \
		--password $(MONGO_INITDB_ROOT_PASSWORD) \
		--authenticationDatabase admin \
		--archive --gzip > backups/mongo_backup_$(MODE)_$$(date +%Y%m%d_%H%M%S).gz
	@echo "Backup saved to backups/ directory"


# Cleanup


.PHONY: clean clean-all clean-volumes

# Remove containers and networks for current mode
clean:
	$(COMPOSE_CMD) down --remove-orphans

# Remove everything (containers, networks, images, volumes) for BOTH modes
clean-all:
	docker compose -f $(COMPOSE_DEV) -p ecommerce_dev down --volumes --rmi local --remove-orphans
	docker compose -f $(COMPOSE_PROD) -p ecommerce_prod down --volumes --rmi local --remove-orphans

# Just remove volumes
clean-volumes:
	docker volume rm mongo-data-dev mongo-data-prod 2>/dev/null || true


# Utilities


.PHONY: status health help

status: ps

# Check health of Gateway and Backend
health:
	@echo "Checking Gateway Health..."
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:$(GATEWAY_PORT)/health | grep 200 > /dev/null && echo "Gateway: OK" || echo "Gateway: DOWN"
	@echo "Checking Backend (via Gateway)..."
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:$(GATEWAY_PORT)/api/health | grep 200 > /dev/null && echo "Backend: OK" || echo "Backend: DOWN"

help:
	@awk 'BEGIN {FS = ":.*#"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?#/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^# [a-zA-Z]/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 3) }' $(MAKEFILE_LIST)