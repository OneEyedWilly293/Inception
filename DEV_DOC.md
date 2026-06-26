# Developer Documentation

## 1. Prerequisites
- Docker
- Docker Compose
- Make

## 2. Configuration from scratch

### `.env`
Create `srcs/.env` with the following values (Values are already configured for jgueon.):
```sh
DOMAIN_NAME=jgueon.42.fr
NGINX_HTTP_PORT=80
NGINX_HTTP_PORT_HOST=80
NGINX_HTTPS_PORT=443
NGINX_HTTPS_PORT_HOST=443
PHP_FPM_PORT=9000
MARIADB_PORT=3306
MARIADB_BIND_ADDRESS=0.0.0.0
WORDPRESS_TITLE=jgueon_title
LOGIN=${USER}
```

### Secrets
Create plain text files in `./secrets/` — one value per file, no quotes:
```sh
mkdir -p secrets
echo "wordpress_db"           > secrets/db_name.txt
echo "wpuser"                 > secrets/db_user.txt
echo "somepassword"           > secrets/db_password.txt
echo "somerootpassword"       > secrets/db_root_password.txt
echo "myadmin"                > secrets/wp_admin.txt
echo "adminpassword"          > secrets/wp_admin_password.txt
echo "admin@jgueon.42.fr"  > secrets/wp_admin_email.txt
echo "wpuser"                 > secrets/wp_user.txt
echo "userpassword"           > secrets/wp_user_password.txt
echo "user@jgueon.42.fr"   > secrets/wp_user_email.txt
```

### Host data directories (bind mounts)
Created automatically by `make up`, or manually:
```sh
mkdir -p /home/$USER/data/mariadb
mkdir -p /home/$USER/data/wordpress
```

### Domain / hosts entry
Add a local DNS override so your browser resolves the domain to localhost:
```sh
echo "127.0.0.1 jgueon.42.fr" | sudo tee -a /etc/hosts
```
Verify:
```sh
ping jgueon.42.fr
curl -k https://jgueon.42.fr
```

## 3. Build and launch
```sh
make up      # create data dirs + build + start all services
make down    # stop and remove containers
make clean   # remove containers, volumes, and images
make fclean  # wipe everything including host data
make re      # full wipe and rebuild from scratch
```

## 4. Useful operational commands

### MariaDB
```sh
# Enter the MariaDB container shell
docker exec -it srcs-mariadb-1 sh

# Connect to MariaDB as the application user
mysql -u <db_user> -p

# List all databases
SHOW DATABASES;

# Switch to the WordPress database
USE wordpress_db;

# List all tables
SHOW TABLES;

# Show user privileges
SHOW GRANTS FOR '<db_user>'@'%';

# One-liner from host
docker exec srcs-mariadb-1 mysql -u root -p -e "SHOW DATABASES;"

# Check MariaDB is listening on port 3306
ss -tulnp | grep 3306
```

### Volumes and Networks
```sh
docker network ls
docker volume ls
docker volume inspect <volume_name>
```

## 5. Data persistence model

### Where data lives on the host
| Service | Host path |
|---|---|
| MariaDB databases | `/home/$USER/data/mariadb` |
| WordPress files | `/home/$USER/data/wordpress` |

### What is persisted vs ephemeral
**Persisted (on volume):**
- MariaDB databases and users
- WordPress core files, uploads, plugins, themes

**Ephemeral (lost on container removal):**
- Container filesystem outside mounted volumes
- Temporary and generated runtime files (logs, caches)

### Reset strategy
```sh
# Soft reset — restart containers, keep data
make down && make up

# Hard reset — wipe everything including data on host
make fclean
sudo rm -rf /home/$USER/data/*
make up
```

## 6. Debugging checklist

### NGINX / TLS
```sh
curl -vk https://jgueon.42.fr
openssl s_client -connect jgueon.42.fr:443
docker compose logs nginx
```

### WordPress / PHP-FPM
```sh
docker compose logs wordpress
ss -tulnp | grep 9000
```

### MariaDB
```sh
docker compose logs mariadb
docker compose exec mariadb mariadb -u root -p
```

### Permissions
```sh
ls -lah /home/$USER/data
docker exec srcs-wordpress-1 ls -lah /var/www/html
```

### Healthcheck status
```sh
docker inspect --format='{{json .State.Health}}' srcs-mariadb-1
docker inspect --format='{{json .State.Health}}' srcs-wordpress-1
```
