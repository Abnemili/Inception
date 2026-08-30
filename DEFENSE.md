# Inception — defense guide

Every command below has been checked against this repository. Run them from
the repository root.

## 0. One-time, before the evaluator arrives

Check that the domain resolves locally:

```bash
grep 42.fr /etc/hosts        # must show: 127.0.0.1  abnemili.42.fr
```

Confirm `srcs/.env` exists — it is gitignored, so a fresh clone will not have it:

```bash
ls -l srcs/.env
```

If it is missing, copy `srcs/.env.example` to `srcs/.env` and fill in the values.

## 1. The only four commands you need

```bash
cd ~/Desktop/Inception

make          # build the images and start everything
make down     # stop and remove the containers
make logs     # follow all logs (Ctrl-C to quit)
make ps       # show container status
```

`make clean` also removes this project's images and volumes, and nothing that
belongs to other projects on the machine. `make fclean` additionally deletes
`/home/abnemili/data` and **asks for your sudo password**. `make re` is
`fclean` followed by `make`.

The first build from nothing takes a few minutes: three Debian images plus the
WordPress download. After that, `make` takes seconds.

## 2. Start it, in front of them

```bash
make
make ps
```

Expect all three up, and only nginx with a published port. The `PORTS` column is
the one that matters:

```
NAME        SERVICE     STATUS    PORTS
mariadb     mariadb     Up ...    3306/tcp
wordpress   wordpress   Up ...    9000/tcp
nginx       nginx       Up ...    0.0.0.0:443->443/tcp, [::]:443->443/tcp
```

Open `https://abnemili.42.fr` in Firefox. The certificate warning is expected:
the certificate is self-signed, which is what the subject asks for. Advanced →
Accept the risk. The site loads.

## 3. Log in to WordPress

Go to `https://abnemili.42.fr/wp-admin`.

| role | username | password |
| --- | --- | --- |
| administrator | `boss` | `boss_password_123` |
| author | `student` | `student_password_123` |

If they ask why the administrator is not called `admin`: the subject forbids an
administrator name that contains `admin`.

## 4. "Show me you did not use a ready-made image"

```bash
grep FROM srcs/requirements/*/Dockerfile
```

All three read `FROM debian:bookworm`, the penultimate stable Debian. Each image
is built from that base by its own Dockerfile.

## 5. "Where are your credentials?"

```bash
grep -ri password srcs/requirements/*/Dockerfile   # prints nothing
cat srcs/.env                                      # everything lives here
cat .gitignore                                     # srcs/.env is ignored
git status                                         # .env never shows up
```

`srcs/.env.example` is what the repository carries, with placeholder values.

## 6. "Prove the database and the volumes are real"

```bash
docker exec -it mariadb mariadb -u root -psuper_root_pass
```

Then, inside the client:

```sql
SHOW DATABASES;                       -- wordpress_db is listed
SELECT user, host FROM mysql.user;    -- wp_user@% is listed
USE wordpress_db; SHOW TABLES;        -- 12 WordPress tables
exit
```

The volumes live under `/home/<login>/data`, as the subject demands:

```bash
ls /home/abnemili/data/wordpress    # wp-admin, wp-includes, wp-config.php...
ls /home/abnemili/data/mariadb      # wordpress_db, mysql, ibdata1...
```

## 7. "What happens if a container crashes?"

Use a *handled* signal, so the process really exits:

```bash
docker inspect -f '{{.RestartCount}}' wordpress    # 0
docker exec wordpress sh -c 'kill -QUIT 1'         # php-fpm quits
sleep 5
docker inspect -f '{{.RestartCount}}' wordpress    # 1 — docker restarted it
curl -sk -o /dev/null -w '%{http_code}\n' https://abnemili.42.fr/   # 200
```

The same works for the other two:

```bash
docker exec mariadb sh -c 'kill -TERM 1'
docker exec nginx   sh -c 'kill -QUIT 1'
```

Each container comes back on its own, and the site answers again in about two
seconds.

Two traps to avoid here:

- `docker kill wordpress` does **not** bring the container back on Docker 29.
  The daemon records it as a manual stop, so `restart: always` is deliberately
  skipped. It looks like a bug in the project when it is not one.
- `docker exec wordpress kill -9 1` does nothing at all: the kernel ignores
  SIGKILL sent to PID 1 from inside its own namespace.

## 8. "Does the data survive a restart?"

Publish a post in wp-admin, then:

```bash
make down
make up
```

Reload the site: the post is still there, and `docker logs wordpress` does not
say "downloading WordPress core", so nothing was reinstalled. The data lives in
`/home/abnemili/data`, not inside the containers.

## 9. TLS

```bash
curl -Ik https://abnemili.42.fr/                                            # 200
echo | openssl s_client -connect abnemili.42.fr:443 -tls1_2 | grep "New,"   # TLSv1.2
echo | openssl s_client -connect abnemili.42.fr:443 -tls1_3 | grep "New,"   # TLSv1.3
echo | openssl s_client -connect abnemili.42.fr:443 -tls1_1                 # fails
```

Only TLS 1.2 and 1.3 are accepted. Port 80 does not answer at all, because 443
is the only published port.

## 10. Other questions they tend to ask

- **No forbidden tricks.** `grep -rE 'tail -f|sleep infinity|network: host|links:' srcs/`
  prints nothing. Each container runs its real service as PID 1: `mysqld`,
  `php-fpm -F`, `nginx -g "daemon off;"`.
- **One service per container.** nginx has no PHP, the WordPress container has no
  web server, MariaDB has neither.
- **nginx is the only entry point.** It publishes 443; MariaDB and WordPress
  publish nothing and are reachable only over the `inception_network` bridge.
- **Why the database is created on every boot.** Docker fills an empty named
  volume from the image, and installing `mariadb-server` already initialised
  `/var/lib/mysql` at build time. A "first boot only" block would therefore never
  run, so `srcs/requirements/mariadb/tools/setup.sh` applies its SQL through
  `mysqld --init-file` on every start. Every statement is idempotent.

## If something goes wrong mid-defense

`make down && make up` — ten seconds, data intact. Only reach for
`make fclean && make` if you want a virgin first-boot demo: it needs your sudo
password and a few minutes.
