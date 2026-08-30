FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx openssl \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=755 tools/setup.sh /usr/local/bin/setup.sh

EXPOSE 443
ENTRYPOINT ["/usr/local/bin/setup.sh"]
