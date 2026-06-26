#!/bin/sh

# Exit on error, treat unset variables as errors
set -eu

echo "==> Setting up WordPress..."

# ── STEP 1: Tweak PHP settings at runtime ────────────────────────────
# WordPress with plugins can use a lot of memory
# We append this to php.ini instead of hardcoding it in the image
echo "memory_limit = 512M" >> /etc/php83/php.ini

# ── STEP 2: Go to the WordPress folder ───────────────────────────────
WP_PATH=/var/www/html
cd "$WP_PATH"

chmod +x /usr/local/bin/wp

# ── STEP 3: Validate env vars + render PHP-FPM config ────────────────
: "${PHP_FPM_PORT:?missing PHP_FPM_PORT}"

# Replace ${PHP_FPM_PORT} in the template → write the real www.conf
envsubst '${PHP_FPM_PORT}' \
  < /etc/php83/php-fpm.d/www.conf.template > /etc/php83/php-fpm.d/www.conf

# ── STEP 4: Read Docker secrets ───────────────────────────────────────
# Same read_secret() helper as MariaDB — reads /run/secrets/<name>
# and strips newlines. Falls back to env var if secret file is missing.
read_secret() {
   name="$1"
   path="/run/secrets/$name"
   if [ -f "$path" ]; then
     tr -d '\r\n' < "$path"
   else
     return 1
   fi
}

# Read all secrets — prefer secret files, fall back to env vars
export MYSQL_DATABASE="$(read_secret db_name        || printf '%s' "${MYSQL_DATABASE:-}")"
export MYSQL_USER="$(read_secret db_user             || printf '%s' "${MYSQL_USER:-}")"
export MYSQL_PASSWORD="$(read_secret db_password     || printf '%s' "${MYSQL_PASSWORD:-}")"
export MYSQL_ROOT_PASSWORD="$(read_secret db_root_password || printf '%s' "${MYSQL_ROOT_PASSWORD:-}")"
export WP_USER="$(read_secret wp_user                || printf '%s' "${WP_USER:-}")"
export WP_USER_PASSWORD="$(read_secret wp_user_password || printf '%s' "${WP_USER_PASSWORD:-}")"
export WP_USER_EMAIL="$(read_secret wp_user_email    || printf '%s' "${WP_USER_EMAIL:-}")"
export WP_ADMIN="$(read_secret wp_admin              || printf '%s' "${WP_ADMIN:-}")"
export WP_ADMIN_PASSWORD="$(read_secret wp_admin_password || printf '%s' "${WP_ADMIN_PASSWORD:-}")"
export WP_ADMIN_EMAIL="$(read_secret wp_admin_email  || printf '%s' "${WP_ADMIN_EMAIL:-}")"

# Crash with a clear message if any required value is missing
: "${MYSQL_DATABASE:?missing db_name}"
: "${MYSQL_USER:?missing db_user}"
: "${MYSQL_PASSWORD:?missing db_password}"
: "${WP_USER:?missing wp_user}"
: "${WP_USER_PASSWORD:?missing wp_user_password}"
: "${WP_USER_EMAIL:?missing wp_user_email}"
: "${WP_ADMIN:?missing wp_admin}"
: "${WP_ADMIN_PASSWORD:?missing wp_admin_password}"
: "${WP_ADMIN_EMAIL:?missing wp_admin_email}"
: "${DOMAIN_NAME:?missing DOMAIN_NAME in .env}"
: "${WORDPRESS_TITLE:?missing WORDPRESS_TITLE in .env}"

# ── STEP 5: Wait for MariaDB ──────────────────────────────────────────
# WordPress CANNOT install if the DB isn't ready
# mariadb-admin ping retries for up to 300 seconds before giving up
# 'mariadb' here is the Docker service name — Docker DNS resolves it
echo "==> Waiting for MariaDB..."
mariadb-admin ping --protocol=tcp --host=mariadb \
  -u $MYSQL_USER --password=$MYSQL_PASSWORD --wait=300

# ── STEP 6: Ensure correct permissions ───────────────────────────────
mkdir -p "$WP_PATH/wp-content"
chown -R www-data:www-data "$WP_PATH"

# ── STEP 7: Helper — run WP-CLI commands as www-data (not root) ───────
# This is important: files created by WP-CLI must be owned by www-data
# so PHP-FPM and nginx can read/write them
# su -s /bin/sh -c "..." www-data = run this command AS the www-data user
wp_as_www_data() {
  su -s /bin/sh -c "$*" www-data
}

# ── STEP 8: Build the site URL from env vars ──────────────────────────
# Default: https://yourdomain.42.fr
# If HTTPS port is not 443, include it: https://yourdomain.42.fr:8443
SITEURL="https://${DOMAIN_NAME}"
if [ -n "${NGINX_HTTPS_PORT_HOST}" ] && [ "${NGINX_HTTPS_PORT_HOST}" != "443" ]; then
    SITEURL="https://${DOMAIN_NAME}:${NGINX_HTTPS_PORT_HOST}"
fi

# ── STEP 9: First-time WordPress installation ─────────────────────────
# wp-config.php is created by WP-CLI on first run
# If it already exists → WordPress is already installed → skip this block
if [ ! -f "$WP_PATH/wp-config.php" ]; then

    # Download WordPress core files into the volume
    echo "==> Downloading WordPress core..."
    wp_as_www_data "wp core download --path='$WP_PATH'"

    # Create wp-config.php with database credentials
    # --dbhost='mariadb' = Docker service name, not localhost!
    # --skip-check = don't try to connect to DB yet (it may still be starting)
    echo "==> Creating wp-config.php..."
    wp_as_www_data "wp config create --path='$WP_PATH' \
        --dbname='$MYSQL_DATABASE' \
        --dbuser='$MYSQL_USER' \
        --dbpass='$MYSQL_PASSWORD' \
        --dbhost='mariadb' \
        --skip-check"

    # Install WordPress — creates all DB tables, sets title, admin account
    # --skip-email = don't send a confirmation email
    echo "==> Installing WordPress..."
    wp_as_www_data "wp core install --path='$WP_PATH' \
        --url='${SITEURL}' \
        --title='${WORDPRESS_TITLE}' \
        --admin_user='${WP_ADMIN}' \
        --admin_password='${WP_ADMIN_PASSWORD}' \
        --admin_email='${WP_ADMIN_EMAIL}' \
        --skip-email"

else
    echo "==> wp-config.php already exists; assuming WordPress is configured."
fi

# ── STEP 10: Always force the correct site URL ────────────────────────
# Even on restarts — ensures the URL in the DB matches reality
wp_as_www_data "wp option update siteurl '${SITEURL}' --path='$WP_PATH'"
wp_as_www_data "wp option update home '${SITEURL}' --path='$WP_PATH'"

# ── STEP 11: Patch wp-config.php for HTTPS behind a reverse proxy ─────
# NGINX sits in front of WordPress. WordPress needs to know the connection
# is HTTPS even though PHP-FPM only sees an HTTP connection from NGINX.
# NGINX sends HTTP_X_FORWARDED_PROTO and HTTP_X_FORWARDED_PORT headers.
# This code reads those headers and tells WordPress "yes, this is HTTPS"
FIXLINE="HTTP_X_FORWARDED_PORT"
if ! grep -q "$FIXLINE" "$WP_PATH/wp-config.php"; then
  sed -i "/^\/* That's all, stop editing! Happy publishing. \*\//i\\
if (\\
    isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) &&\\
    \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https'\\
) {\\
    \$_SERVER['HTTPS'] = 'on';\\
}\\
if (\\
    isset(\$_SERVER['HTTP_X_FORWARDED_PORT']) &&\\
    \$_SERVER['HTTP_X_FORWARDED_PORT'] !== '443'\\
) {\\
    \$_SERVER['SERVER_PORT'] = \$_SERVER['HTTP_X_FORWARDED_PORT'];\\
}" "$WP_PATH/wp-config.php"
  echo "Patched wp-config.php for proxy port handling!"
fi

# ── STEP 12: Create the non-admin WordPress user ─────────────────────
# The subject requires 2 users: an admin and a regular user
# This block checks if the user already exists before creating them
# (idempotent = safe to run on every container restart)
echo "==> Ensuring extra user exists..."
if wp_as_www_data "wp user get '${WP_USER}' --path='${WP_PATH}' >/dev/null 2>&1"; then
    echo "==> Extra user '${WP_USER}' already exists."
elif wp_as_www_data "wp user list --field=user_email --path='${WP_PATH}' | grep -Fxq '${WP_USER_EMAIL}'"; then
    echo "==> A user with email '${WP_USER_EMAIL}' already exists; skipping create."
else
    # role=subscriber = regular user (can read/comment, cannot write posts)
    wp_as_www_data "wp user create '${WP_USER}' '${WP_USER_EMAIL}' \
        --user_pass='${WP_USER_PASSWORD}' \
        --role=subscriber \
        --path='${WP_PATH}'"
fi

# ── STEP 13: Final permission fix ────────────────────────────────────
# Normalize ownership and permissions on the whole WordPress folder
# 755 = owner can read/write/execute, everyone else can read/execute
chown -R www-data:www-data "$WP_PATH"
chmod -R 755 "$WP_PATH"

# ── STEP 14: Start PHP-FPM as PID 1 ──────────────────────────────────
# -F = run in the foreground (don't daemonize)
# exec replaces the shell with php-fpm83 so it becomes PID 1
echo "==> Running PHP-FPM in the foreground..."
echo "==> www.conf contents:"	#delete later
cat /etc/php83/php-fpm.d/www.conf # delte later
exec php-fpm83 -F
