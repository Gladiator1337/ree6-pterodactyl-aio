FROM maven:3.9.11-amazoncorretto-21 AS ree6-builder

ARG REE6_VERSION=4.0.12

RUN yum install -y git \
    && yum clean all \
    && git clone --depth 1 --branch "${REE6_VERSION}" \
        https://github.com/Ree6-Applications/Ree6.git /build/ree6

COPY patches/ree6-temporal-voice-name.patch /tmp/ree6-temporal-voice-name.patch

RUN cd /build/ree6 \
    && git apply /tmp/ree6-temporal-voice-name.patch \
    && mvn -B -DskipTests package \
    && mkdir -p /opt/ree6-aio \
    && cp target/*-jar-with-dependencies.jar /opt/ree6-aio/Ree6.jar \
    && printf '%s\n' "${REE6_VERSION}" > /opt/ree6-aio/bot-version

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

COPY --from=ree6-builder /opt/ree6-aio /opt/ree6-aio

USER root
WORKDIR /home/container

# Wings mounts /mnt/install/install.sh as root-only and invokes the configured
# egg entrypoint as CMD. The normal Wings runtime already overrides the user;
# only drop privileges when this process still has UID 0.
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "-c", "if [ \"$#\" -ge 2 ] && [ \"$1\" = bash ] && [ \"$2\" = /mnt/install/install.sh ]; then exec /bin/bash /mnt/install/install.sh; elif [ \"$#\" -gt 0 ]; then if [ \"$(id -u)\" -eq 0 ]; then exec /usr/sbin/gosu container \"$@\"; else exec \"$@\"; fi; else if [ \"$(id -u)\" -eq 0 ]; then exec /usr/sbin/gosu container /bin/bash /entrypoint.sh; else exec /bin/bash /entrypoint.sh; fi; fi", "--"]
CMD []
