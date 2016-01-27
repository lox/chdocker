#!/bin/bash

set -e
set -u

: ${DOCKER_VERSION="1.9.1"}
: ${DOCKER_COMPOSE_VERSION="1.4.2"}
: ${DOCKER_MACHINE_VERSION="0.5.6"}
: ${DOCKER_INSTALL_URL="https://get.docker.com"}
: ${DOCKER_DAEMON_ARGS="--storage-driver=vfs -H unix:///var/run/docker.sock"}
: ${CHDOCKER_DIR="$HOME/.chdocker"}

version_gt() {
  if command gsort &> /dev/null ; then
    alias sort=gsort
  fi
  if [[ -f /bin/busybox ]] ; then
    test "$(echo "$@" | tr " " "\n" | busybox sort -t '.' -g | tail -n 1)" == "$1"
  else
    test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"
  fi
}

symlink_bin(){
  if [[ -e $2 && ! -h $2 ]] ; then
    printf "Error: %s is not a symlink, cowardly refusing to replace it\n" "$2"
    exit 1
  fi
  echo "Linking $(human_version $1) => $2"
  ln -sf "$1" "$2"
}

human_version(){
  printf "%s (v%s)" $(basename $1) $(basename $(dirname $1))
}

dind_and_exec(){
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
}

DOCKER_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/docker"
DOCKER_DIND_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/dind"
DOCKER_MACHINE_BIN="${CHDOCKER_DIR}/machine/${DOCKER_MACHINE_VERSION}/docker-machine"
DOCKER_COMPOSE_BIN="${CHDOCKER_DIR}/compose/${DOCKER_COMPOSE_VERSION}/docker-compose"

os=$(uname -s)
os_lower=$(tr '[:upper:]' '[:lower:]' <<< $os)
machine=$(uname -m)
machine_amd=${machine/x86_64/amd64}

# download the docker binary
if [[ ! -f $DOCKER_BIN ]] ; then
  mkdir -p $(dirname $DOCKER_BIN)
  echo "Downloading docker ${DOCKER_VERSION} from ${DOCKER_INSTALL_URL}"
  curl -fL "${DOCKER_INSTALL_URL}/builds/${os}/${machine}/docker-${DOCKER_VERSION}" -o $DOCKER_BIN
  chmod +x $DOCKER_BIN
fi

# download the docker dind script
if [[ ! -f $DOCKER_DIND_BIN ]] ; then
  if version_gt $DOCKER_VERSION "1.6.2" ; then
    DIND_COMMIT=4e899d64e020a67ca05f913d354aa8d99a341a7b
  else
    DIND_COMMIT=723d43387a5c04ef8588c7e1557aa163e268581c
  fi
  echo "Downloading dind for ${DOCKER_VERSION}"
  curl -fL "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -o $DOCKER_DIND_BIN
  chmod +x $DOCKER_DIND_BIN
fi

# download docker-compose
if [[ ! -f $DOCKER_COMPOSE_BIN ]] ; then
  mkdir -p $(dirname $DOCKER_COMPOSE_BIN)
  echo "Downloading docker-compose ${DOCKER_COMPOSE_VERSION}"
  curl -fL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${os}-${machine}" -o $DOCKER_COMPOSE_BIN
  chmod +x $DOCKER_COMPOSE_BIN
fi

# download docker-machine
if [[ ! -f $DOCKER_MACHINE_BIN ]] ; then
  mkdir -p $(dirname $DOCKER_MACHINE_BIN)
  echo "Downloading docker-machine ${DOCKER_MACHINE_VERSION}"
  curl -fL "https://github.com/docker/machine/releases/download/v${DOCKER_MACHINE_VERSION}/docker-machine_${os_lower}-${machine_amd}" -o $DOCKER_MACHINE_BIN
  chmod +x $DOCKER_MACHINE_BIN
fi

if [ "${1:-}" == "alias" ] ; then
  printf "alias %s=%s\n" docker "$DOCKER_BIN"
  printf "alias %s=%s\n" dind "$DOCKER_DIND_BIN"
  printf "alias %s=%s\n" docker-compose "$DOCKER_COMPOSE_BIN"
  printf "alias %s=%s" docker-machine "$DOCKER_MACHINE_BIN"
elif [ "${1:-}" == "install" ] ; then
  symlink_bin "$DOCKER_BIN" /usr/local/bin/docker
  symlink_bin "$DOCKER_DIND_BIN" /usr/local/bin/dind
  symlink_bin "$DOCKER_COMPOSE_BIN" /usr/local/bin/docker-compose
  symlink_bin "$DOCKER_MACHINE_BIN" /usr/local/bin/docker-machine
else
  echo "usage: $0 (alias|install|exec)"
  echo
  echo "The following environment variables are used to set the versions used:"
  echo "DOCKER_VERSION, DOCKER_COMPOSE_VERSION, DOCKER_MACHINE_VERSION"
  echo
  echo "DOCKER_INSTALL_URL can be used to set the source used for docker (get, test or experimental)"
  exit 1
fi