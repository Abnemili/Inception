#!/bin/bash
set -e

: "${DOMAIN_NAME:?DOMAIN_NAME is not set}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is not set}"
: "${MYSQL_USER:?MYSQL_USER is not set}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is not set}"
: "${WORDPRESS_TITLE:?WORDPRESS_TITLE is not set}"
: "${WORDPRESS_ADMIN_USER:?WORDPRESS_ADMIN_USER is not set}"
: "${WORDPRESS_ADMIN_PASSWORD:?WORDPRESS_ADMIN_PASSWORD is not set}"
: "${WORDPRESS_ADMIN_EMAIL:?WORDPRESS_ADMIN_EMAIL is not set}"
: "${WORDPRESS_USER:?WORDPRESS_USER is not set}"
: "${WORDPRESS_USER_PASSWORD:?WORDPRESS_USER_PASSWORD is not set}"
: "${WORDPRESS_USER_EMAIL:?WORDPRESS_USER_EMAIL is not set}"

WP_PATH=/var/www/wordpress

wp_cli() {
    wp --allow-root --path="$WP_PATH" "$@"
}

# A real authenticated query against the target database: unlike a plain ping,
# this only succeeds once the user and the database actually exist. Bounded, so
# a misconfiguration fails the container instead of hanging forever.
echo "[wordpress] waiting for MariaDB..."
for i in $(seq 1 30); do
    if mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
        -e "SELECT 1;" > /dev/null 2>&1; then
        echo "[wordpress] MariaDB is ready."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[wordpress] ERROR: cannot reach ${MYSQL_USER}@mariadb/${MYSQL_DATABASE} after 60s." >&2
        exit 1
    fi
    sleep 2
done

if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "[wordpress] downloading WordPress core..."
    wp_cli core download
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "[wordpress] writing wp-config.php..."
    wp_cli config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --dbhost="mariadb:3306"
fi

if ! wp_cli core is-installed > /dev/null 2>&1; then
    echo "[wordpress] installing site..."
    wp_cli core install \
        --url="https://${DOMAIN_NAME}" \
        --title="$WORDPRESS_TITLE" \
        --admin_user="$WORDPRESS_ADMIN_USER" \
        --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
        --admin_email="$WORDPRESS_ADMIN_EMAIL" \
        --skip-email
fi

if ! wp_cli user get "$WORDPRESS_USER" > /dev/null 2>&1; then
    echo "[wordpress] creating user ${WORDPRESS_USER}..."
    wp_cli user create "$WORDPRESS_USER" "$WORDPRESS_USER_EMAIL" \
        --user_pass="$WORDPRESS_USER_PASSWORD" \
        --role=author
fi

chown -R www-data:www-data "$WP_PATH"

echo "[wordpress] starting php-fpm..."
exec php-fpm8.2 -F
