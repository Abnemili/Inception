#!/bin/bash
set -e

for v in DOMAIN_NAME MYSQL_DATABASE MYSQL_USER MYSQL_PASSWORD WORDPRESS_TITLE \
         WORDPRESS_ADMIN_USER WORDPRESS_ADMIN_PASSWORD WORDPRESS_ADMIN_EMAIL \
         WORDPRESS_USER WORDPRESS_USER_PASSWORD WORDPRESS_USER_EMAIL; do
    if [ -z "${!v}" ]; then echo "[wordpress] $v is not set" >&2; exit 1; fi
done

WP=/var/www/wordpress
wp_cli() { wp --allow-root --path="$WP" "$@"; }


echo "[wordpress] waiting for MariaDB..."
for i in $(seq 30); do
    if mariadb -h mariadb -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
        -e 'SELECT 1;' >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[wordpress] cannot reach ${MYSQL_USER}@mariadb/${MYSQL_DATABASE} after 60s" >&2
        exit 1
    fi
    sleep 2
done

[ -f "$WP/wp-load.php" ] || wp_cli core download

[ -f "$WP/wp-config.php" ] || wp_cli config create --dbname="$MYSQL_DATABASE" \
    --dbuser="$MYSQL_USER" --dbpass="$MYSQL_PASSWORD" --dbhost=mariadb:3306

wp_cli core is-installed >/dev/null 2>&1 || wp_cli core install \
    --url="https://$DOMAIN_NAME" --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" --skip-email

wp_cli user get "$WORDPRESS_USER" >/dev/null 2>&1 || wp_cli user create \
    "$WORDPRESS_USER" "$WORDPRESS_USER_EMAIL" \
    --user_pass="$WORDPRESS_USER_PASSWORD" --role=author

chown -R www-data:www-data "$WP"

echo "[wordpress] starting php-fpm..."
exec php-fpm8.2 -F
