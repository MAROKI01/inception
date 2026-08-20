#!/bin/sh

set -e

echo "Starting WordPress setup..."

# --------------------------------------------------
# Check required environment variables
# --------------------------------------------------

if [ -z "$MYSQL_DATABASE" ] ||
   [ -z "$MYSQL_USER" ] ||
   [ -z "$MYSQL_HOST" ] ||
   [ -z "$MYSQL_PORT" ] ||
   [ -z "$DOMAIN_NAME" ] ||
   [ -z "$WP_TITLE" ] ||
   [ -z "$WP_ADMIN_USER" ] ||
   [ -z "$WP_ADMIN_EMAIL" ] ||
   [ -z "$WP_USER" ] ||
   [ -z "$WP_USER_EMAIL" ]; then

    echo "Error: required WordPress environment variables are not set."
    exit 1
fi

echo "WordPress environment variables are set."

# --------------------------------------------------
# Read secrets
# --------------------------------------------------

if [ ! -f /run/secrets/db_password ] ||
   [ ! -f /run/secrets/credentials ]; then

    echo "Error: required WordPress secrets are missing."
    exit 1
fi

MYSQL_PASSWORD=$(cat /run/secrets/db_password)

WP_ADMIN_PASSWORD=$(grep '^WP_ADMIN_PASSWORD=' \
    /run/secrets/credentials | cut -d '=' -f2-)

WP_USER_PASSWORD=$(grep '^WP_USER_PASSWORD=' \
    /run/secrets/credentials | cut -d '=' -f2-)

if [ -z "$MYSQL_PASSWORD" ] ||
   [ -z "$WP_ADMIN_PASSWORD" ] ||
   [ -z "$WP_USER_PASSWORD" ]; then

    echo "Error: one or more secrets are empty."
    exit 1
fi

# --------------------------------------------------
# Validate administrator username
# --------------------------------------------------

case "$WP_ADMIN_USER" in
    *admin*|*Admin*|*ADMIN*)
        echo "Error: administrator username cannot contain 'admin'."
        exit 1
        ;;
esac

case "$WP_ADMIN_USER" in
    *administrator*|*Administrator*|*ADMINISTRATOR*)
        echo "Error: administrator username cannot contain 'administrator'."
        exit 1
        ;;
esac

echo "Administrator username is valid."

# --------------------------------------------------
# Wait for MariaDB
# --------------------------------------------------

echo "Waiting for MariaDB..."

until mariadb-admin \
    --host="$MYSQL_HOST" \
    --user="$MYSQL_USER" \
    --port="$MYSQL_PORT" \
    --password="$MYSQL_PASSWORD" \
    --silent \
    ping
do
    echo "MariaDB is not ready yet..."
    sleep 2
done

echo "MariaDB is ready."

# --------------------------------------------------
# Prepare WordPress directory
# --------------------------------------------------

mkdir -p /var/www/html

# --------------------------------------------------
# Download WordPress
# --------------------------------------------------

if [ ! -f "/var/www/html/wp-settings.php" ]; then

    echo "Downloading WordPress..."

    curl -fsSL \
        https://wordpress.org/latest.tar.gz \
        -o /tmp/wordpress.tar.gz

    tar -xzf /tmp/wordpress.tar.gz \
        --strip-components=1 \
        -C /var/www/html

    rm -f /tmp/wordpress.tar.gz

    echo "WordPress downloaded."

else

    echo "WordPress already exists."

fi

# --------------------------------------------------
# Configure WordPress
# --------------------------------------------------

if [ ! -f "/var/www/html/wp-config.php" ]; then

    echo "Creating wp-config.php..."

    wp config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="$MYSQL_HOST:$MYSQL_PORT" \
        --path=/var/www/html \
        --skip-check \
        --allow-root

    echo "wp-config.php created."

else

    echo "wp-config.php already exists."

fi

# --------------------------------------------------
# Install WordPress
# --------------------------------------------------

if ! wp core is-installed \
    --path=/var/www/html \
    --allow-root
then

    echo "Installing WordPress..."

    wp core install \
        --path=/var/www/html \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root

    echo "WordPress installation completed."

else

    echo "WordPress is already installed."

fi

# --------------------------------------------------
# Create second WordPress user
# --------------------------------------------------

if ! wp user get "$WP_USER" \
    --path=/var/www/html \
    --allow-root >/dev/null 2>&1
then

    echo "Creating second WordPress user..."

    wp user create \
        "$WP_USER" \
        "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=subscriber \
        --path=/var/www/html \
        --allow-root

    echo "Second WordPress user created."

else

    echo "Second WordPress user already exists."

fi

# --------------------------------------------------
# Configure PHP-FPM
# --------------------------------------------------

echo "Configuring PHP-FPM..."

mkdir -p /run/php

sed -i 's|^listen = .*|listen = 0.0.0.0:9000|' \
    /etc/php/8.2/fpm/pool.d/www.conf

# --------------------------------------------------
# Fix permissions
# --------------------------------------------------

chown -R www-data:www-data /var/www/html

# --------------------------------------------------
# Start PHP-FPM as PID 1
# --------------------------------------------------

echo "Starting PHP-FPM..."

exec php-fpm8.2 -F