*This project has been created as part of the 42 curriculum by abnemili.*

# Inception — a WordPress stack from scratch with Docker

**A small production-style web infrastructure: nginx, WordPress and MariaDB, each in its own container built from my own Dockerfile, connected on a private network and started with one `make`.** No ready-made images: every service starts from `debian:bookworm`.

![Docker](https://img.shields.io/badge/Docker-2496ed?logo=docker&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Docker_Compose-2496ed?logo=docker&logoColor=white)
![nginx](https://img.shields.io/badge/nginx-009639?logo=nginx&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?logo=mariadb&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759b?logo=wordpress&logoColor=white)
![Debian](https://img.shields.io/badge/Debian_bookworm-a81d33?logo=debian&logoColor=white)

## Description

Three services, one container each, all from my own Dockerfiles:

* **nginx**: TLSv1.2/1.3 only, port 443. The only container reachable from the host.
* **wordpress + php-fpm**: port 9000, internal only.
* **mariadb**: port 3306, internal only.

```text
              host
               │  https :443  (the only open port)
               ▼
        ┌─────────────┐   FastCGI :9000   ┌──────────────────┐    SQL :3306    ┌───────────┐
        │    nginx    │ ────────────────► │ wordpress + fpm  │ ──────────────► │  mariadb  │
        │  TLS 1.2/1.3│                   │                  │                 │           │
        └─────────────┘                   └──────────────────┘                 └───────────┘
               │                                   │                                 │
               └──────── wordpress_data ───────────┘                          mariadb_data
                    (shared site files)                                  (database files)

                      all three on the private "inception_network" bridge
```

Site files and the database live on two named volumes under `/home/abnemili/data`, so they survive restarts and rebuilds.

### Highlights

* **Real PID 1 processes.** Each entrypoint ends in `exec`, so nginx, php-fpm and mysqld receive signals directly, and `restart: always` actually works. There are no `tail -f` or `sleep infinity` tricks.
* **Idempotent setup.** The first start installs WordPress and creates the database and users. Later starts detect the existing data and reuse it.
* **No secrets in images.** Every password comes from `srcs/.env`, which is gitignored. `srcs/.env.example` lists only the key names.
* **One way in.** Only port 443 is published. The database and php-fpm are reachable only inside the Docker network, by service name.

## Instructions

```bash
echo "127.0.0.1  abnemili.42.fr" | sudo tee -a /etc/hosts
cp srcs/.env.example srcs/.env      # then fill in every value
chmod 600 srcs/.env
make
```

Open https://abnemili.42.fr and accept the self-signed certificate. Other
targets: down, logs, ps, clean, fclean, re. See USER_DOC.md and DEV_DOC.md.

## Project structure and design choices

srcs/docker-compose.yml declares the services, the network and the volumes.
Each service has a folder in srcs/requirements/ holding its Dockerfile, its
config in conf/ and its entrypoint in tools/. The Makefile wraps docker compose.

Design choices:

* Every image is FROM debian:bookworm, penultimate stable Debian, pinned by tag
  because the latest tag is forbidden.
* Each entrypoint ends in exec, so mysqld, php-fpm and nginx run as PID 1 in
  the foreground. Signals reach them, a crash exits the container, and that is
  what makes restart: always work. No tail -f, sleep infinity or while true.
* The setup scripts are idempotent, so a restart reuses the site instead of
  reinstalling it.
* No password in any Dockerfile. Everything comes from srcs/.env, gitignored.

### Virtual Machines vs Docker

A VM boots its own kernel on a hypervisor. A container shares the host kernel
and isolates only the process view with namespaces and cgroups, so it starts in
milliseconds, costs megabytes not gigabytes, and rebuilds from a Dockerfile.
The price is weaker isolation: a kernel exploit escapes a container, not a VM.
Here the containers run inside a VM, so the VM gives the security boundary and
the containers give cheap reproducible services.

### Secrets vs Environment Variables

I use environment variables from srcs/.env, as the subject requires. They are
simple but they leak: visible in docker inspect, in /proc/<pid>/environ, and to
every process in the container. Docker secrets are files under /run/secrets,
readable only by the service that asks for them, never baked into the image,
and rotatable without a rebuild, which is why the subject recommends them. My
mitigation is that srcs/.env is gitignored and chmod 600, and .env.example
carries only the key names.

### Docker Network vs Host Network

The containers share inception_network, a user-defined bridge declared in the
compose file. Docker runs DNS on it, so wordpress reaches the database at the
hostname mariadb and nginx reaches php-fpm at wordpress:9000. Only published
ports leave the network, which is how 443 stays the single way in.
network_mode: host would break name resolution and expose 3306 and 9000 on the
host, so nginx would no longer be the only entrypoint. The subject forbids it.

### Docker Volumes vs Bind Mounts

A bind mount maps a host path into a container; Docker neither creates nor
tracks it. A named volume is an object Docker manages by name, listed by docker
volume ls, with its own lifecycle. The subject wants named volumes, forbids bind
mounts, and still wants the data in /home/abnemili/data. driver_opts does both:

```yaml
volumes:
  mariadb_data:
    driver_opts:
      type: none
      o: bind
      device: /home/abnemili/data/mariadb
```

mariadb_data is a real named volume, declared under volumes: and mounted by
name, whose backing store is the required directory. What I avoided is the
forbidden service-level form, - /home/abnemili/data/mariadb:/var/lib/mysql.

## Resources

* Docker docs: Dockerfile and compose file references, volumes, networking
* MariaDB Knowledge Base: mariadb-install-db, --init-file, system variables
* WP-CLI handbook: core install, config create, user create
* nginx docs: ssl_protocols, FastCGI parameters
* php-fpm pool configuration in the PHP manual

AI use: I used an AI assistant to check my steps against the subject and to learn
the commands faster. I reviewed and tested everything myself, and the design
choices above are mine to defend.

