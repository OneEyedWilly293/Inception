.PHONY: all build up down stop start clean fclean re status logs

all: build

build:
    @cd srcs && docker-compose build

# Create data folders on the host, then start all containers in the background
# -d = detached mode (runs in background, terminal is free)
up:
    @mkdir -p /home/$(USER)/data/wordpress
    @mkdir -p /home/$(USER)/data/mariadb
    @cd srcs && docker-compose up -d

# Stop and remove containers (but keep volumes and images)
# --remove-orphans = also remove containers not in docker-compose.yml
down:
    @cd srcs && docker-compose down --remove-orphans

# Pause containers (keeps them, just stops them)
stop:
    @cd srcs && docker-compose stop

# Resume paused containers
start:
    @cd srcs && docker-compose start

# Stop containers AND delete volumes AND delete images
# Use this when you want a completely fresh rebuild
clean:
    @cd srcs && docker-compose down -v --rmi all --remove-orphans

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
    @cd srcs && docker-compose ps $(SERVICES)

# Stream live logs from all containers (or a specific one)
# --tail=200 = show last 200 lines first
logs:
    @cd srcs && docker-compose logs -f --tail=200 $(SERVICES)

# This is a catch-all rule — any unknown target (e.g. 'nginx' in 'make logs nginx')
# becomes a no-op instead of an error
%:
    @:
