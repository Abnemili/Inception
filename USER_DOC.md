# User documentation

Run everything from the repository root.

## Services

* nginx: the web server, and the only container reachable from the host. It
  handles TLS on 443 and passes PHP on to wordpress.
* wordpress: WordPress with php-fpm. No web server of its own.
* mariadb: the database. Not reachable from the host.

Site files and database are stored on the host in /home/abnemili/data, so they
survive stopping the stack and rebooting.

## Start and stop

```bash
make          # build if needed, then start
make down     # stop, data kept
make re       # delete the data too, then rebuild
```

Before the first start, check the domain resolves and the env file exists:

```bash
grep abnemili.42.fr /etc/hosts     # expect 127.0.0.1  abnemili.42.fr
ls -l srcs/.env                    # not in the repo, you create it
```

If srcs/.env is missing, copy srcs/.env.example and fill it in. The containers
refuse to start on an incomplete file and name the missing variable.

The first build takes a few minutes. make re asks for your sudo password,
because the stored data belongs to the containers' users.

## Website and admin panel

* site: https://abnemili.42.fr
* admin: https://abnemili.42.fr/wp-admin

The certificate is self-signed, as the subject asks, so the browser warns you
once. In Firefox: Advanced, then accept the risk.

There are two accounts: an administrator, and a second account that can only
write posts.

## Credentials

All of them are in srcs/.env and nowhere else: DOMAIN_NAME, the MYSQL_* values
for the database, the WORDPRESS_ADMIN_* values for the administrator and the
WORDPRESS_USER_* values for the second account.

That file is gitignored and chmod 600. Never commit it. To change a password,
edit it and run make re, because the old values are already in the database.

## Check it is running

```bash
make ps
curl -sk -o /dev/null -w '%{http_code}\n' https://abnemili.42.fr/
```

All three containers should say Up, and only nginx should list a port
(0.0.0.0:443->443/tcp). The curl should print 200, which means nginx, php-fpm,
WordPress and MariaDB are all answering.

Use make logs, or docker logs wordpress, to look into a failure. Two things are
normal: the certificate warning, and a short 502 if you load the page in the
first seconds after make, while php-fpm is still starting. Refresh once.
