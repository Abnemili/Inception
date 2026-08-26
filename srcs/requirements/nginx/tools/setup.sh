#!/bin/bash
set -e

: "${DOMAIN_NAME:?DOMAIN_NAME is not set}"

CERT_DIR=/etc/nginx/ssl

mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_DIR/nginx.crt" ]; then
    echo "[nginx] generating self-signed certificate for ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_DIR/nginx.key" \
        -out "$CERT_DIR/nginx.crt" \
        -subj "/C=MA/ST=Benguerir/L=Benguerir/O=42/OU=42/CN=${DOMAIN_NAME}" \
        2> /dev/null
fi

echo "[nginx] starting nginx..."
exec nginx -g "daemon off;"
