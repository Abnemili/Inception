#!/bin/bash
set -e

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is not set}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is not set}"
: "${MYSQL_USER:?MYSQL_USER is not set}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is not set}"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Only reached when the data directory is genuinely empty, which with these
# named volumes is rare: see the note below.
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "[mariadb] initialising data directory..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null
fi

# Applied on every boot, not only the first one.
#
# A "first boot only" guard cannot be trusted here. When a named volume is
# empty Docker pre-populates it from the image, and installing mariadb-server
# already initialised /var/lib/mysql at build time. So /var/lib/mysql/mysql
# exists from the very first start and a guarded block would never run at all,
# leaving the server with no database, no user and no root password.
#
# Every statement below is idempotent, so applying them on each boot is safe
# and the database, the user and the root password are always present.
INIT_FILE=/etc/mysql/init.sql
cat > "$INIT_FILE" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
chown mysql:mysql "$INIT_FILE"

echo "[mariadb] starting server..."
exec mysqld --user=mysql --init-file="$INIT_FILE"
