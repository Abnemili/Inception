#!/bin/bash
set -e

if [ -z "$DOMAIN_NAME" ]; then echo "[nginx] DOMAIN_NAME is not set" >&2; exit 1; fi

if [ ! -f /etc/nginx/ssl/nginx.crt ]; then
    echo "[nginx] generating self-signed certificate for ${DOMAIN_NAME}..."
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt \
        -subj "/C=MA/ST=Benguerir/L=Benguerir/O=42/OU=42/CN=${DOMAIN_NAME}" 2>/dev/null
fi

echo "[nginx] starting nginx..."
exec nginx -g "daemon off;"
