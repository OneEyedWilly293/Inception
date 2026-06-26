#!/bin/sh

# Exit immediately on any error (-e)
# Treat unset variables as errors (-u)
set -eu

# ── STEP 1: Validate required environment variables ──────────────────
# These come from .env — crash with a clear message if any are missing
: "${MARIADB_PORT:?missing MARIADB_PORT}"
: "${MARIADB_BIND_ADDRESS:?missing MARIADB_BIND_ADDRESS}"

# ── STEP 2: Create required directories ──────────────────────────────
# /run/mysqld  = where MariaDB puts its socket file (PID file etc.)
# /var/lib/mysql = where the actual database data lives (our volume)
# chown = make the 'mysql' system user the owner — MariaDB refuses to
#         start if it doesn't own its own data directory
echo "==> Setting up MariaDB directory..."
mkdir -p /run/mysqld /var/lib/mysql
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# ── STEP 3: Render config template ───────────────────────────────────
# Replace ${MARIADB_BIND_ADDRESS} and ${MARIADB_PORT} in the template
# and write the real config file to /etc/my.cnf
envsubst '${MARIADB_BIND_ADDRESS} ${MARIADB_PORT}' \
  < /etc/my.cnf.template > /etc/my.cnf
chmod 644 /etc/my.cnf

# ── STEP 4: Read secrets ──────────────────────────────────────────────
# Docker mounts secrets as files at /run/secrets/<name>
# We define a helper function to read them cleanly
# tr -d '\r\n' strips trailing newlines (prevents subtle password bugs)
read_secret() {
  name="$1"
  path="/run/secrets/$name"
  [ -f "$path" ] && tr -d '\r\n' < "$path"
}

MYSQL_DATABASE="$(read_secret db_name)"
MYSQL_USER="$(read_secret db_user)"
MYSQL_PASSWORD="$(read_secret db_password)"
MYSQL_ROOT_PASSWORD="$(read_secret db_root_password)"

# Make these available as environment variables for the SQL below
export MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD MYSQL_ROOT_PASSWORD

# Crash if any secret file was missing or empty
: "${MYSQL_DATABASE:?missing db_name secret}"
: "${MYSQL_USER:?missing db_user secret}"
: "${MYSQL_PASSWORD:?missing db_password secret}"
: "${MYSQL_ROOT_PASSWORD:?missing db_root_password secret}"

# ── STEP 5: First-time database initialization ────────────────────────
# /var/lib/mysql/mysql is the system database folder that MariaDB creates
# on first run. If it DOESN'T exist, this is a fresh container.
# If it DOES exist, we skip this block — data already set up.
if [ ! -d "/var/lib/mysql/mysql" ]; then

    # Initialize the system tables into our data directory
    echo "==> Initializing MariaDB system tables..."
    mariadb-install-db --basedir=/usr --user=mysql --datadir=/var/lib/mysql/ >/dev/null

    # --bootstrap = run SQL commands without starting a full server
    # This is safe because no client can connect yet
    # <<- EOF = a "heredoc" — a way to write multi-line input directly in a script
    echo "==> Creating WordPress database and user..."
    mariadbd --user=mysql --bootstrap <<- EOF
    FLUSH PRIVILEGES;

    -- Set the root password (it's blank by default after install-db)
    ALTER USER 'root'@'localhost' IDENTIFIED BY "${MYSQL_ROOT_PASSWORD}";

    -- Create the WordPress database if it doesn't already exist
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

    -- Create the WordPress user (% means from any host/container)
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY "${MYSQL_PASSWORD}";

    -- Give that user full access to only the WordPress database
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';

    FLUSH PRIVILEGES;
EOF

else
    echo "==> MariaDB is already installed. Database and users are configured."
fi

# ── STEP 6: Start MariaDB as PID 1 ───────────────────────────────────
# exec replaces the shell process with mariadbd
# This makes mariadbd PID 1 — required so Docker stop/kill signals work
echo "==> Starting MariaDB server..."
exec mariadbd --user=mysql
