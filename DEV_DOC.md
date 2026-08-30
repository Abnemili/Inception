# Developer documentation

## Layout

```
Makefile                      wraps docker compose
srcs/docker-compose.yml       services, network, volumes
srcs/.env                     real credentials, gitignored
srcs/.env.example             same keys, placeholder values
srcs/requirements/<service>/  Dockerfile, conf/, tools/setup.sh
```

## Setup from scratch

Needs Docker with the compose plugin, make, and sudo for the hosts line and for
make fclean.

```bash
git clone git@github.com:Abnemili/Inception.git && cd Inception
echo "127.0.0.1  abnemili.42.fr" | sudo tee -a /etc/hosts
cp srcs/.env.example srcs/.env && chmod 600 srcs/.env
$EDITOR srcs/.env
make
```

srcs/.env is the only file you create, and it is deliberately not in the repo.
Each entrypoint validates its variables first and exits naming the missing one.
The admin username cannot contain admin or administrator, so it is boss.

## Build and launch

make runs docker compose -f srcs/docker-compose.yml up -d --build.

```
make          mkdir the data dirs, then build and start
make down     compose down, data kept
make logs     compose logs -f
make ps       compose ps
make clean    compose down --rmi local --volumes --remove-orphans
make fclean   clean, then sudo rm -rf the two data dirs
make re       fclean then make
```

clean uses --rmi local, so it only removes images built here. fclean needs sudo
because the files belong to the containers' mysql and www-data users. To wipe
them without a password, use a throwaway container:

```bash
docker run --rm -v /home/abnemili/data:/data debian:bookworm \
  rm -rf /data/mariadb /data/wordpress
```

## Containers and volumes

```bash
docker exec -it mariadb bash
docker logs -f nginx
docker compose -f srcs/docker-compose.yml restart wordpress
docker compose -f srcs/docker-compose.yml build --no-cache nginx
docker volume ls
docker volume inspect srcs_mariadb_data          # shows the host device
docker network inspect srcs_inception_network
docker exec wordpress wp user list --allow-root --path=/var/www/wordpress
```

WordPress lives in /var/www/wordpress, not /var/www/html, so wp always needs
--path.

## Where the data lives

```
srcs_mariadb_data    /var/lib/mysql       /home/abnemili/data/mariadb
srcs_wordpress_data  /var/www/wordpress   /home/abnemili/data/wordpress
```

nginx mounts wordpress_data as well, since it serves the static files itself and
only forwards .php to php-fpm.

The volumes outlive the containers. make down keeps them, so the next make finds
an installed site and skips both installs. make clean drops the volume
definitions and make fclean deletes the host directories. To check persistence,
run make down && make, then:

```bash
docker exec wordpress wp core is-installed --allow-root --path=/var/www/wordpress
```

These are named volumes, not bind mounts; the README explains why driver_opts
satisfies both halves of the subject.

## Not obvious

* The MariaDB init file runs every boot on purpose: mariadb-server already
  initialises /var/lib/mysql at build time, so a first-boot guard would never
  fire. The SQL is idempotent.
* WordPress waits on SELECT 1 as the app user, not a ping, which would succeed
  before the user and database exist. It gives up after 30 tries, 2s apart.
* ${!v} is bash indirect expansion: $v holds a name, ${!v} its value, so one
  loop checks eleven variables.
* fastcgi_param HTTPS on is required because php-fpm only sees the FastCGI
  request, not the TLS nginx already terminated. Without it WordPress writes
  http:// links and wp-admin redirect-loops.
