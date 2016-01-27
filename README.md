# chdocker

Easily download and switch to different versions of docker, docker-compose and docker-machine.

```bash
eval "$(DOCKER_VERSION=1.8.2 DOCKER_COMPOSE=1.4.2 DOCKER_MACHINE=0.5.6 chdocker.sh alias)"
```

Or alternately, symlink them permanently:

```bash
DOCKER_VERSION=1.8.2 DOCKER_COMPOSE=1.4.2 DOCKER_MACHINE=0.5.6 sudo chdocker.sh install
```