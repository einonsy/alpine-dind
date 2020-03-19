FROM einonsy/alpine-base:latest
MAINTAINER JasonEinon

RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 19.03.5
ENV DOCEKR_ARCH x86_64
# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT 37498f009d8bf25fbb6199e8ccd34bed84f2874b
# https://github.com/docker-library/docker/pull/166
#   docker-entrypoint.sh uses DOCKER_TLS_CERTDIR for auto-generating TLS certificates
# (For this to work, at least the "client" subdirectory of this path needs to be shared between the client and server containers via a volume, "docker cp", or other means of data sharing.)
ENV DOCKER_TLS_CERTDIR=/certs

RUN set -x \
    && apk add --no-cache ca-certificates \
    && wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${DOCEKR_ARCH}/docker-${DOCKER_VERSION}.tgz" \
    && tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ \
    && rm -f docker.tgz \
    && dockerd --version \
    && docker --version \
    && apk add --no-cache \
          btrfs-progs \
          e2fsprogs \
          e2fsprogs-extra \
          iptables \
          openssl \
          shadow-uidmap \
          xfsprogs \
          xz \
          # pigz: https://github.com/moby/moby/pull/35697 (faster gzip implementation)
          pigz \
    && if zfs="$(apk info --no-cache --quiet zfs)" && [ -n "$zfs" ]; then \
      apk add --no-cache zfs; \
    fi \
    && wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" \
	  && chmod +x /usr/local/bin/dind \
    && addgroup -S dockremap \
    && adduser -S -G dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid

COPY modprobe.sh /usr/local/bin/modprobe
COPY docker-entrypoint.sh /usr/local/bin/
COPY supervisor.docker.conf /etc/supervisor/conf.d/docker.conf

RUN chmod +x /usr/local/bin/modprobe \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    # also, ensure the directory pre-exists and has wide enough permissions for "dockerd-entrypoint.sh" to create subdirectories, even when run in "rootless" mode
    && mkdir -p /certs/client && chmod 1777 /certs /certs/client
    # (doing both /certs and /certs/client so that if Docker does a "copy-up" into a volume defined on /certs/client, it will "do the right thing" by default in a way that still works for rootless users)

VOLUME /var/lib/docker
EXPOSE 2375 2376