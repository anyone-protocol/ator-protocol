FROM debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive

ARG ANON_VER="8a729c50a87974b78822227c14c03f3fb6be514e"
ARG ANON_REPO="https://github.com/ATOR-Development/ator-protocol.git"

ENV ANON_NICKNAME=ATORv4

ENV ANON_USER=atord

RUN apt-get update && \
    apt_build_deps="libssl-dev zlib1g-dev libevent-dev ca-certificates dh-apparmor libseccomp-dev debhelper" && \
    apt_runtime_deps="iputils-ping curl pwgen" && \
    apt_temps="build-essential automake git" && \
    apt-get -y --no-install-recommends install $apt_build_deps $apt_runtime_deps $apt_temps && \
    mkdir /src && cd /src && \
    git clone ${ANON_REPO} && cd anon && git fetch origin ${ANON_VER} && git switch --detach ${ANON_VER}

# Copy actual list of da to rebuild the image with correct one
COPY /auth_dirs.inc /src/anon/src/app/config/auth_dirs.inc
COPY /fallback_dirs.inc /src/anon/src/app/config/fallback_dirs.inc

RUN cd /src/anon && \
    ./autogen.sh && \
    ./configure --disable-asciidoc && \
    make && \
    make install && \
    apt-get -y purge --auto-remove $apt_temps && \
    apt-get clean && rm -r /var/lib/apt/lists/* && \
    rm -rf /src/*

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

COPY ./anonrc-da /etc/anonrc

COPY ./scripts/ /usr/local/bin/

EXPOSE 9001 9030

ENTRYPOINT ["docker-entrypoint"]

CMD ["tor", "-f", "/etc/anon/anonrc"]
