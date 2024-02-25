#
# This is a dockerfile to build anon binaries on Debian host from ATOR git repository.
#

FROM debian:bookworm

# Makes the default apt answers be used for all questions
ARG DEBIAN_FRONTEND=noninteractive

# Sets which version of anon to use.
# See https://github.com/ATOR-Development/ator-protocol/tags for available tags.
ARG ANON_VER="75780710e36daf53a0361164e1ecbe9d51019a77"
ARG ANON_REPO="https://github.com/ATOR-Development/ator-protocol.git"
ARG ANON_ENV=stage

# Sets anon ports for build time
ARG BUILD_ANON_ORPORT=9001
ARG BUILD_ANON_DIRPORT=9030

# Allows to set ENV variables to override default ones.
# Make sure you also change exposed ports when running docker containers
# as they are evaluated at build time and cannot be changed using only ENV variables.
ENV ANON_ORPORT=${BUILD_ANON_ORPORT}
ENV ANON_DIRPORT=${BUILD_ANON_DIRPORT}

# Sets a default nickname.
# To set email field pass CONTACT_EMAIL env variable.
ENV ANON_NICKNAME=ANONv4

# Sets a user which will be used running anon
ENV ANON_USER=anond

# Install build dependencies, compile anon binaries and cleanup temporary dependencies
RUN apt-get update && \
    apt_build_deps="libssl-dev zlib1g-dev libevent-dev ca-certificates dh-apparmor libseccomp-dev debhelper" && \
    apt_runtime_deps="iputils-ping curl pwgen" && \
    apt_temps="build-essential automake git" && \
    apt-get -y --no-install-recommends install $apt_build_deps $apt_runtime_deps $apt_temps && \
    mkdir /src && cd /src && \
    git clone ${ANON_REPO} && cd ator-protocol && git fetch origin ${ANON_VER} && git switch --detach ${ANON_VER} && \
    ./scripts/ci/update-env.sh ${ANON_ENV} && \
    ./autogen.sh && \
    ./configure --disable-asciidoc && \
    make && \
    make install && \
    apt-get -y purge --auto-remove $apt_temps && \
    apt-get clean && rm -r /var/lib/apt/lists/* && \
    rm -rf /src/*

# Add ator user and create data directory with right permissions.
# Volume for /var/lib/anon should be mounted to persist all node data.
RUN adduser --quiet \
        --system \
        --disabled-password \
        --home /var/lib/anon \
        --no-create-home \
        --shell /bin/false \
        --group \
        $ANON_USER && \
        mkdir -p /var/lib/anon && \
        chown $ANON_USER:$ANON_USER /var/lib/anon && \
        chmod 02700 /var/lib/anon

# Copy Tor configuration file
COPY ./config/anonrc-example /etc/anon/anonrc

# Copy scripts including docker-entrypoint
COPY ./scripts/ /usr/local/bin/

# Expose ORPort, DirPort
EXPOSE ${BUILD_ANON_ORPORT} ${BUILD_ANON_DIRPORT}

ENTRYPOINT ["docker-entrypoint"]

CMD ["anon", "-f", "/etc/anon/anonrc"]
