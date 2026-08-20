#!/bin/sh

set -e

# --------------------------------------------------
# Check required environment variables and secrets
# --------------------------------------------------

if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_USER" ]; then
    echo "Error: required MariaDB environment variables are not set."
    exit 1
fi

if [ ! -f /run/secrets/db_password ] || \
   [ ! -f /run/secrets/db_root_password ]; then
    echo "Error: MariaDB secrets are missing."
    exit 1
fi

MYSQL_PASSWORD=$(cat /run/secrets/db_password)
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

# --------------------------------------------------
# Prepare runtime directory
# --------------------------------------------------

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# --------------------------------------------------
# Initialize MariaDB data directory if necessary
# --------------------------------------------------

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql
fi

# --------------------------------------------------
# Start MariaDB temporarily
# --------------------------------------------------

echo "Starting MariaDB temporarily..."

mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --skip-networking \
    --socket=/run/mysqld/mysqld.sock &

TEMP_PID=$!

# --------------------------------------------------
# Wait for MariaDB
# --------------------------------------------------

echo "Waiting for MariaDB to be ready..."

until mariadb-admin \
    --no-defaults \
    --socket=/run/mysqld/mysqld.sock \
    ping \
    --silent
do
    sleep 1
done

echo "MariaDB is ready."

# --------------------------------------------------
# First-time database/user initialization
# --------------------------------------------------

if [ ! -f "/var/lib/mysql/.initialized" ]; then

    echo "Creating database and users..."

    mariadb \
        --no-defaults \
        --socket=/run/mysqld/mysqld.sock \
        -u root <<EOF

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%';

ALTER USER '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES
    ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';

ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

FLUSH PRIVILEGES;

EOF

    touch /var/lib/mysql/.initialized

    echo "MariaDB initialization completed."

else

    echo "MariaDB already initialized."

fi

# --------------------------------------------------
# Stop temporary MariaDB
# --------------------------------------------------

echo "Stopping temporary MariaDB server..."

mariadb-admin \
    --no-defaults \
    --socket=/run/mysqld/mysqld.sock \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    shutdown 2>/dev/null || true

# Wait specifically for the temporary MariaDB process
wait "$TEMP_PID"

# --------------------------------------------------
# Start MariaDB as PID 1
# --------------------------------------------------

echo "Starting MariaDB..."

exec mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql