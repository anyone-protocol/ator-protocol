# ATOR Protocol Docker

This directory contains configs to build and run ATOR protocol binaries using docker

**Important!** 
`This docker image will be built with dummy directory authorities, production ready DAs will be introduced later.`

## Building Docker Image

Build an image:
```sh
docker build -t ator-protocol .
```

## Building Docker Image with a specific tag (version of the protocol)

Build an image with a specific tag:
```sh
docker build -t ator-protocol . --build-arg="ANON_VER=${TAG}"
```
Both lightweight and annotated git tags are applicable.

## Extracting multi-arch binaries

You can use `./extract-multi-arch.sh` script to build and extract binaries for different architectures using docker.

If you did not configure buildx for multi-arch build, run:
```sh
docker buildx create --use
```

Example for `linux/arm64`:
```sh
ATOR_PLATFORMS=linux/arm64 \
    ./extract-multi-arch.sh
```

Example for `linux/arm64` and `linux/amd64`:
```sh
ATOR_PLATFORMS=linux/arm64,linux/amd64 \
    ./extract-multi-arch.sh
```

Resulting binaries will be available in `build/` directory.

## Running in Docker Compose

### Configuration File

Before running the container, make sure you copy `./config/anonrc-example` to `./anonrc` and set all the required variables depending on the mode in which you want to run your node (relay, directory authority, etc.). Docker-compose will use it to mount it inside a docker container.

### External IP

Ensure that your container ports are accessible from outside and that the `Address` parameter in `anonrc` corresponds to your external IP address. Otherwise, other nodes will not be able to use your node as a Relay or Directory Authority.

### Secrets

Secret keys should be mounted if you intend to use specific keys. They are located in the `/var/lib/anon/keys/` directory inside the container.

### Start container

After everything is configured you are ready to start a container:

```sh
docker-compose up
```
