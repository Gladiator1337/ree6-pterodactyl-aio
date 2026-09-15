FROM ghcr.io/pterodactyl/yolks:java_21

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git jq mariadb-client mariadb-server \
        nodejs npm tini fontconfig fonts-dejavu-core fonts-noto-core \
    && npm install --global n \
    && n 22 \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql \
    && mkdir -p /home/container \
    && chown -R container:container /home/container

USER container
WORKDIR /home/container

# The inherited yolk script is readable but may not have its executable bit set.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/entrypoint.sh"]

