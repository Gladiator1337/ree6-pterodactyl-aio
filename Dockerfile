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

# Wings mounts its installer without an executable bit. Run shell scripts with
# Bash, forward other commands normally, and use the yolk startup when no
# command was supplied.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "-c", "if [ \"$#\" -gt 0 ]; then case \"$1\" in *.sh) exec /bin/bash \"$@\" ;; *) exec \"$@\" ;; esac; else exec /bin/bash /entrypoint.sh; fi", "--"]
CMD []
