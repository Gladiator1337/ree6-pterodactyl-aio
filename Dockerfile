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

# Wings passes the installer as CMD; forward it instead of running STARTUP.
# With no command, use the normal yolk startup script via Bash.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "-c", "if [ \"$#\" -gt 0 ]; then exec \"$@\"; else exec /bin/bash /entrypoint.sh; fi", "--"]
CMD []

