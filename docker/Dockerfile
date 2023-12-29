#
# This is a dockerfile to build ator-protocol binaries on Debian host from ATOR git repository.
#

FROM debian:bookworm

# Makes the default apt answers be used for all questions
ARG DEBIAN_FRONTEND=noninteractive

# Sets which version of ator-protocol to use.
# See https://github.com/ATOR-Development/ator-protocol/tags for available tags.
ARG ATOR_VER="09aac22964b4873efe25b0eb818676675dedee16"
ARG ATOR_REPO="https://github.com/ATOR-Development/ator-protocol.git"

# Sets ator-protocol ports for build time
ARG BUILD_TOR_ORPORT=9001
ARG BUILD_TOR_DIRPORT=9030

# Allows to set ENV variables to override default ones.
# Make sure you also change exposed ports when running docker containers
# as they are evaluated at build time and cannot be changed using only ENV variables.
ENV TOR_ORPORT=${BUILD_TOR_ORPORT}
ENV TOR_DIRPORT=${BUILD_TOR_DIRPORT}

# Sets a default nickname.
# To set email field pass CONTACT_EMAIL env variable.
ENV TOR_NICKNAME=ATORv4

# Sets a user which will be used running ator-protocol
ENV TOR_USER=atord

# Install build dependencies, compile ator-protocol binaries and cleanup temporary dependencies
RUN apt-get update && \
    apt_build_deps="libssl-dev zlib1g-dev libevent-dev ca-certificates dh-apparmor libseccomp-dev debhelper" && \
    apt_runtime_deps="iputils-ping curl pwgen" && \
    apt_temps="build-essential automake git" && \
    apt-get -y --no-install-recommends install $apt_build_deps $apt_runtime_deps $apt_temps && \
    mkdir /src && cd /src && \
    git clone ${ATOR_REPO} && cd ator-protocol && git fetch origin ${ATOR_VER} && git switch --detach ${ATOR_VER} && \
    ./autogen.sh && \
    ./configure --disable-asciidoc && \
    make && \
    make install && \
    apt-get -y purge --auto-remove $apt_temps && \
    apt-get clean && rm -r /var/lib/apt/lists/* && \
    rm -rf /src/*

# Add ator user and create data directory with right permissions.
# Volume for /var/lib/tor should be mounted to persist all node data.
RUN adduser --quiet \
        --system \
        --disabled-password \
        --home /var/lib/tor \
        --no-create-home \
        --shell /bin/false \
        --group \
        $TOR_USER && \
        mkdir -p /var/lib/tor && \
        chown $TOR_USER:$TOR_USER /var/lib/tor && \
        chmod 02700 /var/lib/tor

# Copy Tor configuration file
COPY ./config/anonrc-example /etc/tor/anonrc

# Copy scripts including docker-entrypoint
COPY ./scripts/ /usr/local/bin/

# Expose ORPort, DirPort
EXPOSE ${BUILD_TOR_ORPORT} ${BUILD_TOR_DIRPORT}

ENTRYPOINT ["docker-entrypoint"]

CMD ["tor", "-f", "/etc/tor/anonrc"]
