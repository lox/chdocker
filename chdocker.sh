#!/bin/bash

set -e
set -u

: ${DOCKER_VERSION="1.8.2"}
: ${DOCKER_COMPOSE_VERSION="1.4.2"}
: ${DOCKER_BUCKET="get.docker.com"}
: ${DOCKER_DAEMON_ARGS="--storage-driver=vfs -H unix:///var/run/docker.sock"}
: ${CHDOCKER_DIR="$HOME/.chdocker"}

version_gt() {
  if [[ -f /bin/busybox ]] ; then
    test "$(echo "$@" | tr " " "\n" | busybox sort -t '.' -g | tail -n 1)" == "$1"
  else
    test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"
  fi
}

DOCKER_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/docker"
DOCKER_DIND_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/dind"
DOCKER_COMPOSE_BIN="${CHDOCKER_DIR}/compose/${DOCKER_COMPOSE_VERSION}/docker-compose"

# install the docker binary
if [[ ! -f $DOCKER_BIN ]] ; then
  mkdir -p $(dirname $DOCKER_BIN)
  echo "Downloading docker ${DOCKER_VERSION}"
  curl --silent -fL "https://${DOCKER_BUCKET}/builds/Linux/x86_64/docker-${DOCKER_VERSION}" -o $DOCKER_BIN
  chmod +x $DOCKER_BIN
fi

# install the docker dind script
if [[ ! -f $DOCKER_DIND_BIN ]] ; then
  if version_gt $DOCKER_VERSION "1.6.2" ; then
    DIND_COMMIT=4e899d64e020a67ca05f913d354aa8d99a341a7b
  else
    DIND_COMMIT=723d43387a5c04ef8588c7e1557aa163e268581c
  fi
  echo "Downloading dind for ${DOCKER_VERSION}"
  curl --silent -fL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o $DOCKER_DIND_BIN
  chmod +x $DOCKER_DIND_BIN
fi

# install docker-compose
if [[ ! -f $DOCKER_COMPOSE_BIN ]] ; then
  mkdir -p $(dirname $DOCKER_COMPOSE_BIN)
  echo "Downloading docker-compose ${DOCKER_COMPOSE_VERSION}"
  curl --silent -fL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_BIN
  chmod +x $DOCKER_COMPOSE_BIN
fi

# link things into the correct spots
ln -sf $DOCKER_BIN /usr/bin/docker
ln -sf $DOCKER_DIND_BIN /usr/sbin/dind
ln -sf $DOCKER_COMPOSE_BIN /usr/local/bin/docker-compose

if [ "${1:-}" == "--entrypoint" ] ; then
  shift
  if version_gt $DOCKER_VERSION "1.6.2" ; then
    docker daemon $DOCKER_DAEMON_ARGS &
  else
    docker -d $DOCKER_DAEMON_ARGS &
  fi
  (( timeout = 60 + SECONDS ))
  until docker info >/dev/null 2>&1 ; do
    if (( SECONDS >= timeout )); then
      echo 'Timed out trying to connect to internal docker host.' >&2
      exit 1
    fi
    sleep 1
  done
  exec "$@"
fi