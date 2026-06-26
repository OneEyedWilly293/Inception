#!/bin/sh

# set -e = exit immediately if any command fails
# set -u = treat unset variables as errors
set -eu

# These are like "assert" checks — crash with a clear error message
# if any required environment variable is missing
: "${DOMAIN_NAME:?missing DOMAIN_NAME}"
: "${NGINX_HTTP_PORT:?missing NGINX_HTTP_PORT}"
: "${NGINX_HTTPS_PORT:?missing NGINX_HTTPS_PORT}"
# ... etc

# Create the SSL folder if it doesn't exist
mkdir -p /etc/nginx/ssl

# Generate a self-signed SSL certificate at runtime
# This means the domain name is baked in at startup — not hardcoded in the image
# -x509       = output a self-signed cert (not a signing request)
# -nodes      = no passphrase on the private key
# -days 365   = valid for 1 year
# -subj       = the certificate's identity info (Country, City, etc.)
if [ ! -f /etc/nginx/ssl/certificate.crt ] || [ ! -f /etc/nginx/ssl/private.key ]; then
  openssl req -x509 -nodes -days 365 \
    -out /etc/nginx/ssl/certificate.crt \
    -keyout /etc/nginx/ssl/private.key \
    -subj "/C=FI/ST=Uusimaa/L=Helsinki/O=42/OU=Hive/CN=${DOMAIN_NAME}"
fi

# envsubst replaces ${VARIABLE} placeholders in the template with real values
# The list in quotes restricts WHICH variables get replaced
# (so nginx's own $host, $uri variables are left untouched)
envsubst '${DOMAIN_NAME} ${NGINX_HTTP_PORT} ${NGINX_HTTP_PORT_HOST} ${NGINX_HTTPS_PORT} ${NGINX_HTTPS_PORT_HOST} ${PHP_FPM_PORT}' \
  < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# exec replaces the shell process with nginx
# This makes nginx PID 1 — required for Docker signals (stop/kill) to work correctly
exec "$@"
