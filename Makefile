.PHONY: all build up down stop start clean fclean re status logs

all: build

build:
	@docker-compose -f srcs/docker-compose.yml build

# Create data folders on the host, then start all containers in the background
# -d = detached mode (runs in background, terminal is free)
up:
	@mkdir -p /home/$(USER)/data/wordpress
	@mkdir -p /home/$(USER)/data/mariadb
	@docker-compose -f srcs/docker-compose.yml up -d

# Stop and remove containers (but keep volumes and images)
# --remove-orphans = also remove containers not in docker-compose.yml
down:
	@docker-compose -f srcs/docker-compose.yml down --remove-orphans

# Pause containers (keeps them, just stops them)
stop:
	@docker-compose -f srcs/docker-compose.yml stop

# Resume paused containers
start:
	@docker-compose -f srcs/docker-compose.yml start

# Stop containers AND delete volumes AND delete images
# Use this when you want a completely fresh rebuild
clean:
	@docker-compose -f srcs/docker-compose.yml down -v --rmi all --remove-orphans

# Full nuclear clean — runs clean, then ALSO deletes the data folders
# on the host (/home/yourlogin/data) — wipes all database and WordPress files
fclean: clean
	@sudo rm -rf /home/$(USER)/data

# Full reset — down → fclean → build → (you then run 'make up')
re: down fclean all

# ── Extra quality-of-life targets ─────────────────────────────────────

# These allow passing extra words to 'make status' and 'make logs'
# e.g. 'make logs nginx' shows only nginx logs
KNOWN_TARGETS := all up down stop start clean fclean re status logs
SERVICES := $(filter-out $(KNOWN_TARGETS),$(MAKECMDGOALS))

# Show running containers and their status
status:
	@docker-compose -f srcs/docker-compose.yml ps $(SERVICES)

# Stream live logs from all containers (or a specific one)
# --tail=200 = show last 200 lines first
logs:
	@docker-compose -f srcs/docker-compose.yml logs -f --tail=200 $(SERVICES)

# This is a catch-all rule — any unknown target (e.g. 'nginx' in 'make logs nginx')
# becomes a no-op instead of an error
%:
	@:
