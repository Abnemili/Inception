FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       php8.2-fpm php8.2-cli php8.2-mysql php8.2-mbstring \
       php8.2-xml php8.2-zip php8.2-gd \
       mariadb-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/php /var/www/wordpress

RUN curl -fsSL -o /usr/local/bin/wp \
       https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY --chmod=755 tools/setup.sh /usr/local/bin/setup.sh

WORKDIR /var/www/wordpress
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/setup.sh"]
