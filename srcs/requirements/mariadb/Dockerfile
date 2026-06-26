# Start from Alpine Linux
FROM alpine:3.20.6

# Install MariaDB (database server), mariadb-client (CLI tools),
# and gettext (provides envsubst to render our config template)
RUN apk add --no-cache mariadb mariadb-client gettext

# Copy our MariaDB config TEMPLATE — has ${VARIABLE} placeholders
# that get filled in at container startup
COPY ./conf/mariadb.cnf.template /etc/my.cnf.template
RUN chmod 644 /etc/my.cnf.template

# Copy the init/startup script
COPY ./tools/mariadb-script.sh /usr/local/bin/mariadb-script.sh
RUN chmod +x /usr/local/bin/mariadb-script.sh

# When the container starts, run the init script
# The script will start mariadbd at the end
ENTRYPOINT ["sh", "/usr/local/bin/mariadb-script.sh"]
