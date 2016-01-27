#!/bin/bash

set -e
set -u

: ${DOCKER_VERSION="1.9.1"}
: ${DOCKER_COMPOSE_VERSION="1.5.2"}
: ${DOCKER_MACHINE_VERSION="0.5.6"}
: ${CHDOCKER_DIR="$HOME/.chdocker"}

version_gt() {
  sort_cmd="sort -V"

  if hash gsort &>/dev/null ; then
    sort_cmd="gsort -V"
  elif [[ -f /bin/busybox ]] || hash busybox &>/dev/null ; then
    sort_cmd="sort -t '.' -g"
  fi

  test "$(echo "$@" | tr " " "\n" | $sort_cmd | tail -n 1)" == "$1"
}

symlink_bin(){
  if [[ -e $2 && ! -h $2 ]] ; then
    printf "Error: %s is not a symlink, cowardly refusing to replace it\n" "$2"
    exit 1
  fi
  echo "Linking $(human_version $1) => $2"
  ln -sf "$1" "$2"
}

list_versions(){
  if [[ -d ${CHDOCKER_DIR}/$1 ]] ; then
    find ${CHDOCKER_DIR}/$1 -type d -depth 1 -print0 | while IFS= read -r -d $'\0' f; do
      version=$(basename $f)
      active=""
      [[ $version == "$2" ]] && active="(active)"
      printf '%-10s %-12s %s\n' "$1" "$version" "$active"
    done
  else
    echo "$1 none"
  fi
}

human_version(){
  printf "%s (v%s)" $(basename $1) $(basename $(dirname $1))
}

get_latest_github_stable() {
  local version=$(curl -Lfs https://api.github.com/repos/$1/$2/releases/latest | grep '"tag_name":' | head -n1 | cut -d\" -f4 | sed 's/v//')
  if [[ -z $version ]] ; then
    echo "Failed to find a latest stable release for $1/$2"
    exit 2
  fi
  echo $version
}

get_latest_github_prerelease() {
  local version=$(curl -Lfs https://api.github.com/repos/$1/$2/releases | grep '"tag_name":' | head -n1 | cut -d\" -f4 | sed 's/v//')
  if [[ -z $version ]] ; then
    echo "Failed to find a latest stable release for $1/$2"
    exit 2
  fi
  echo $version
}

if [[ ! ${1:-} =~ (alias|install|download|list) ]]; then
  echo "usage: $0 (alias|install|download|list)"
  echo
  echo "The following environment variables are used to set the versions used:"
  echo "DOCKER_VERSION, DOCKER_COMPOSE_VERSION, DOCKER_MACHINE_VERSION"
  echo
  echo "These can contain either absolute versions or latest or prerelease"
  exit 1
fi

if [ "${1:-}" == "list" ] ; then
  list_versions "docker" $DOCKER_VERSION
  list_versions "compose" $DOCKER_COMPOSE_VERSION
  list_versions "machine" $DOCKER_MACHINE_VERSION
  exit 0
fi

[[ $DOCKER_VERSION == "prerelease" ]] && DOCKER_VERSION=$(get_latest_github_prerelease docker docker)
[[ $DOCKER_MACHINE_VERSION == "prerelease" ]] && DOCKER_MACHINE_VERSION=$(get_latest_github_prerelease docker machine)
[[ $DOCKER_COMPOSE_VERSION == "prerelease" ]] && DOCKER_COMPOSE_VERSION=$(get_latest_github_prerelease docker compose)

[[ $DOCKER_VERSION == "latest" ]] && DOCKER_VERSION=$(get_latest_github_stable docker docker)
[[ $DOCKER_MACHINE_VERSION == "latest" ]] && DOCKER_MACHINE_VERSION=$(get_latest_github_stable docker machine)
[[ $DOCKER_COMPOSE_VERSION == "latest" ]] && DOCKER_COMPOSE_VERSION=$(get_latest_github_stable docker compose)

DOCKER_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/docker"
DOCKER_DIND_BIN="${CHDOCKER_DIR}/docker/${DOCKER_VERSION}/dind"
DOCKER_MACHINE_BIN="${CHDOCKER_DIR}/machine/${DOCKER_MACHINE_VERSION}/docker-machine"
DOCKER_COMPOSE_BIN="${CHDOCKER_DIR}/compose/${DOCKER_COMPOSE_VERSION}/docker-compose"
DOCKER_INSTALL_URL="https://get.docker.com"

if [[ $DOCKER_VERSION =~ rc ]] ; then
  DOCKER_INSTALL_URL="https://test.docker.com"
fi

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
  printf "alias %s=%s\nexport DOCKER_VERSION=%s\n" docker "$DOCKER_BIN" "$DOCKER_VERSION"
  printf "alias %s=%s\n" dind "$DOCKER_DIND_BIN"
  printf "alias %s=%s\nexport DOCKER_COMPOSE_VERSION=%s\n" docker-compose "$DOCKER_COMPOSE_BIN" "$DOCKER_COMPOSE_VERSION"
  printf "alias %s=%s\nexport DOCKER_MACHINE_VERSION=%s" docker-machine "$DOCKER_MACHINE_BIN" "$DOCKER_MACHINE_VERSION"
elif [ "${1:-}" == "install" ] ; then
  symlink_bin "$DOCKER_BIN" /usr/local/bin/docker
  symlink_bin "$DOCKER_DIND_BIN" /usr/local/bin/dind
  symlink_bin "$DOCKER_COMPOSE_BIN" /usr/local/bin/docker-compose
  symlink_bin "$DOCKER_MACHINE_BIN" /usr/local/bin/docker-machine
fi