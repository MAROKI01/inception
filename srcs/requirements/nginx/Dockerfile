FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        nginx \
        openssl \
        gettext-base && \
    rm -rf /var/lib/apt/lists/*

COPY conf/nginx.conf.template \
    /etc/nginx/nginx.conf.template

COPY tools/generate-certificate.sh \
    /usr/local/bin/generate-certificate.sh

RUN chmod +x /usr/local/bin/generate-certificate.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/generate-certificate.sh"]