FROM gliderlabs/alpine:3.1

RUN apk --update add curl wget bash git perl openssh-client iptables

ADD chdocker.sh /usr/bin/chdocker
RUN DOCKER_VERSION=1.8.2 DOCKER_COMPOSE=1.4.2 chdocker

ENTRYPOINT ["chdocker", "--entrypoint"]
CMD ["bash"]