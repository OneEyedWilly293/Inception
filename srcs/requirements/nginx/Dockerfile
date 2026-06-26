# Start from Alpine Linux version 3.20.6
FROM alpine:3.20.6

# Install nginx (web server), openssl (for SSL certificates), gettext (for envsubst)
# --no-cache means don't store package lists — keeps image size small
RUN apk add --no-cache nginx openssl gettext

# Copy our nginx config TEMPLATE into the container
# (It's a template because it has ${VARIABLE} placeholders filled in at runtime)
COPY ./conf/nginx.conf.template /etc/nginx/nginx.conf.template

# Copy our startup script into the container
COPY ./tools/entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh && chmod 644 /etc/nginx/nginx.conf.template

# Create the www-data user/group (nginx workers run as this user for security)
# We check first with 'getent' — don't crash if user already exists
RUN getent group www-data >/dev/null || addgroup -S www-data && \
    getent passwd www-data >/dev/null || adduser -S -D -H -s /sbin/nologin -G www-data www-data

# When the container starts, run entrypoint.sh first
ENTRYPOINT ["/entrypoint.sh"]

# After entrypoint.sh, run nginx in the foreground (daemon off = stay in foreground)
# Containers die if PID 1 exits — so nginx must NOT go into the background
CMD ["nginx", "-g", "daemon off;"]
