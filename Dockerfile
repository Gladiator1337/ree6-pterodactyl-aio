FROM ghcr.io/pterodactyl/yolks:java_21

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git gosu jq mariadb-client mariadb-server \
        nodejs npm tini fontconfig fonts-dejavu-core fonts-noto-core \
    && npm install --global n \
    && n 22 \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/* /var/lib/mysql \
    && mkdir -p /home/container \
    && chown -R container:container /home/container

USER root
WORKDIR /home/container

# Wings mounts /mnt/install/install.sh as root-only and invokes the configured
# egg entrypoint as CMD. Run that one command as root. All normal server paths
# drop back to the unprivileged container user.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "-c", "if [ \"$#\" -ge 2 ] && [ \"$1\" = bash ] && [ \"$2\" = /mnt/install/install.sh ]; then exec /bin/bash /mnt/install/install.sh; elif [ \"$#\" -gt 0 ]; then exec /usr/sbin/gosu container \"$@\"; else exec /usr/sbin/gosu container /bin/bash /entrypoint.sh; fi", "--"]
CMD []
