#!/bin/sh

set -e

echo "Starting NGINX setup..."

# --------------------------------------------------
# Check required environment variables
# --------------------------------------------------

if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: DOMAIN_NAME is not set."
    exit 1
fi

# --------------------------------------------------
# Generate NGINX configuration
# --------------------------------------------------

echo "Generating NGINX configuration..."

envsubst '${DOMAIN_NAME}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf

# --------------------------------------------------
# Prepare TLS directory
# --------------------------------------------------

mkdir -p /etc/nginx/ssl

# --------------------------------------------------
# Generate TLS certificate
# --------------------------------------------------

if [ ! -f /etc/nginx/ssl/server.crt ] ||
   [ ! -f /etc/nginx/ssl/server.key ]; then

    echo "Generating TLS certificate..."

    openssl req -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/server.key \
        -out /etc/nginx/ssl/server.crt \
        -subj "/C=MA/ST=Casablanca/L=Casablanca/O=Inception/OU=IT/CN=${DOMAIN_NAME}"

    chmod 600 /etc/nginx/ssl/server.key
    chmod 644 /etc/nginx/ssl/server.crt

    echo "TLS certificate generated."

else

    echo "TLS certificate already exists."

fi

# --------------------------------------------------
# Test NGINX configuration
# --------------------------------------------------

echo "Testing NGINX configuration..."

nginx -t

# --------------------------------------------------
# Start NGINX as PID 1
# --------------------------------------------------

echo "Starting NGINX..."

exec nginx -g "daemon off;"