FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Debian ships a default vhost on port 80; drop it so 443 is the only listener.
RUN rm -f /etc/nginx/sites-enabled/default

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY tools/setup.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/setup.sh"]
