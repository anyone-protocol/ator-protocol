#!/bin/bash

#
# Script allows to build anon binaries for different linux architectures using docker
#

set -o errexit

ANON_PLATFORMS="${ANON_PLATFORMS:-linux/arm64,linux/amd64}"
ANON_ROOT="${ANON_ROOT:-..}"
ANON_BUILD_DIR="${ANON_BUILD_DIR:-build}"

if [ ! -f 'Dockerfile' ]; then
    echo "Dockerfile not found"
    exit 1
fi

# Build images for specified platforms
docker buildx build -f Dockerfile --platform $ANON_PLATFORMS -t anon $ANON_ROOT

IFS=', ' read -r -a platforms <<< "$ANON_PLATFORMS"

# Extract binaries from each platform
for platform in "${platforms[@]}"
do
    echo "[$platform] Extracting binaries"

    mkdir -p $ANON_BUILD_DIR/$platform/

    echo "[$platform] Creating container"
    CONTAINER=`docker create anon --platform $platform --name ator-build-container`

    echo "[$platform] Copying binaries"
    docker cp $CONTAINER:/usr/local/bin/tor $ANON_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/anon-gencert $ANON_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/anon-print-ed-signing-cert $ANON_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/anon-resolve $ANON_BUILD_DIR/$platform/
    docker cp $CONTAINER:/usr/local/bin/anonify $ANON_BUILD_DIR/$platform/

    echo "[$platform] Removing container"
    docker rm -v $CONTAINER
done
