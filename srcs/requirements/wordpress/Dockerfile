FROM alpine:3.20.6

# Install everything WordPress (PHP) needs to run:
# - mariadb-client    → lets the script wait for DB to be ready
# - php83             → the PHP interpreter itself
# - php83-fpm         → PHP-FPM: the process manager that handles PHP requests
# - php83-phar        → needed to run WP-CLI (a .phar file)
# - php83-curl        → WordPress uses curl for HTTP requests
# - php83-mysqli      → PHP extension to talk to MariaDB/MySQL
# - php83-iconv       → character encoding (WordPress requires it)
# - php83-json        → JSON support
# - php83-posix       → WP-CLI requires this
# - wget, curl        → for downloading files
# - gettext           → provides envsubst for config template rendering
# - bash              → WP-CLI needs bash

RUN apk add --no-cache mariadb-client \
    php83 \
    php83-fpm \
    php83-phar \
    php83-curl \
    php83-mysqli \
    php83-iconv \
    php83-json \
    php83-posix \
    wget \
    curl \
    gettext \
    bash && \
    # Alpine names the binary 'php83' — create a symlink so 'php' works everywhere
    ln -sf /usr/bin/php83 /usr/bin/php && \
    ln -sf /usr/sbin/php-fpm83 /usr/sbin/php-fpm

# Install CA certificates so HTTPS downloads (like WP-CLI) work correctly
# Without this, curl would reject HTTPS connections as untrusted
RUN apk add --no-cache curl ca-certificates && update-ca-certificates

# Download WP-CLI — a command-line tool that lets you install/configure
# WordPress without clicking through the browser UI
# We download it at build time so it's baked into the image
# --info at the end verifies it works correctly
RUN curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp \
    && /usr/local/bin/wp --info

# Create the directory where WordPress files will live
# The actual files come from the shared volume at runtime — not built into the image
RUN mkdir -p /var/www/html

# Copy the PHP-FPM pool config template
# PHP-FPM needs a "pool" config that tells it what port to listen on
COPY ./conf/www.conf.template /etc/php83/php-fpm.d/www.conf.template
RUN chmod 644 /etc/php83/php-fpm.d/www.conf.template

# Copy and make executable the startup script
COPY ./tools/wordpress-script.sh /usr/local/bin/wordpress-script.sh
RUN chmod +x /usr/local/bin/wordpress-script.sh

# Create the www-data user/group — PHP-FPM and nginx both run as this user
# so they share file ownership on the volume
RUN getent group www-data >/dev/null || addgroup -S www-data && \
    getent passwd www-data >/dev/null || adduser -S -D -H -s /sbin/nologin \
    -G www-data www-data && \
    mkdir -p /home/www-data && \
    chown -R www-data:www-data /home/www-data

# Give www-data ownership of /var/www before the volume is mounted
RUN chown -R www-data:www-data /var/www

# Run the startup script on container start
ENTRYPOINT ["/usr/local/bin/wordpress-script.sh"]
# Note: no CMD here — the script starts php-fpm itself at the end
