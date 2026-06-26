# User Documentation

## 1. What this project provides

### Services in the stack

- **NGINX (TLS reverse proxy)**
  - Web server serving WordPress via HTTPS
  - Exposed ports: 443 (HTTPS), 80 (HTTP — redirects to HTTPS)

- **WordPress (PHP-FPM)**
  - WordPress application backend (PHP execution layer)
  - Exposed ports: 9000 (internal only — not accessible from outside)

- **MariaDB**
  - Database backend for WordPress data
  - Exposed ports: 3306 (internal only — not accessible from outside)

### How services connect
- Browser → NGINX → PHP-FPM (WordPress) → MariaDB
- Docker network: internal bridge network (`inception`)

## 2. Start / Stop
```sh
make up      # create data directories + start all services
make down    # stop and remove containers
make clean   # remove containers, volumes, and images
make fclean  # wipe everything including host data folders
```

## 3. Access

### Website
- URL: `https://jgueon.42.fr`
- Note: A self-signed certificate warning is expected — click "Accept the Risk and Continue" in your browser.

### WordPress Administration Panel
- URL: `https://jgueon.42.fr/wp-admin`
- Username: value from `secrets/wp_admin.txt`
- Password: value from `secrets/wp_admin_password.txt`

## 4. Configuration

### Non-sensitive configuration — `.env`

Located at `srcs/.env`. Edit these values before running the project:

| Variable | Description | Default |
|---|---|---|
| `DOMAIN_NAME` | Your site domain | `jgueon.42.fr` |
| `NGINX_HTTP_PORT` | HTTP port inside container | `80` |
| `NGINX_HTTP_PORT_HOST` | HTTP port on host machine | `80` |
| `NGINX_HTTPS_PORT` | HTTPS port inside container | `443` |
| `NGINX_HTTPS_PORT_HOST` | HTTPS port on host machine | `443` |
| `PHP_FPM_PORT` | PHP-FPM port (internal) | `9000` |
| `MARIADB_PORT` | MariaDB port (internal) | `3306` |
| `MARIADB_BIND_ADDRESS` | MariaDB bind address | `0.0.0.0` |
| `WORDPRESS_TITLE` | Title shown on the WordPress site | `jgueon_title` |
| `LOGIN` | Your Linux username (used for data paths) | `${USER}` |

### Sensitive configuration — `secrets/`

Located at `secrets/` (project root). Each file contains exactly one value — no quotes, no extra spaces.

| File | Description |
|---|---|
| `db_name.txt` | Name of the WordPress database |
| `db_user.txt` | MariaDB user for WordPress |
| `db_password.txt` | Password for the MariaDB user |
| `db_root_password.txt` | MariaDB root password |
| `wp_admin.txt` | WordPress admin username (must NOT contain "admin") |
| `wp_admin_password.txt` | WordPress admin password |
| `wp_admin_email.txt` | WordPress admin email |
| `wp_user.txt` | WordPress regular user username |
| `wp_user_password.txt` | WordPress regular user password |
| `wp_user_email.txt` | WordPress regular user email |

## 5. Check everything is running correctly

### Container status
```sh
make status
docker compose ps
```

### Healthchecks
- **MariaDB**: database is ready to accept connections
- **WordPress (PHP-FPM)**: `wp-login.php` file exists on the volume
- **NGINX**: serves WordPress over HTTPS on port 443

### Logs
```sh
make logs              # all services
make logs nginx        # nginx only
make logs wordpress    # wordpress only
make logs mariadb      # mariadb only
```

### Basic functional checks
```sh
# Test HTTPS is responding (-k ignores self-signed cert warning)
curl -k https://jgueon.42.fr

# Visit the admin panel in browser
https://jgueon.42.fr/wp-admin
```
