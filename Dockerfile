ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION}

COPY . /container
RUN /container/build.sh

ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

ENTRYPOINT ["/container/tool/run"]

# Keepalived version
ARG KEEPALIVED_VERSION=2.3.1

# Download, build and install Keepalived
RUN apk update \
    && apk --no-cache upgrade \
    && apk --no-cache add \
    bash \
    autoconf \
    automake \
    curl \
    libgcc \
    libip4tc \
    libip6tc \
    gcc \
    ipset \
    ipset-dev \
    iptables \
    iptables-dev \
    libnfnetlink \
    libnfnetlink-dev \
    libnl3 \
    libnl3-dev \
    make \
    musl-dev \
    openssl \
    openssl-dev \
    && curl -o keepalived.zip -SL https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.zip \
    && mkdir -p /container/keepalived-sources \
    && unzip keepalived.zip -d container/keepalived-sources\
    && cd container/keepalived-sources/keepalived-${KEEPALIVED_VERSION} \
    && /bin/bash ./autogen.sh \
    && /bin/bash ./configure --disable-dynamic-linking \
    && make && make install \
    && cd / \
    && rm -rf /container/keepalived-sources \
    && rm -rf keepalived.zip \
    && apk --no-cache del \
    bash \ 
    autoconf \
    automake \
    gcc \
    ipset-dev \
    iptables-dev \
    libnfnetlink-dev \
    libnl3-dev \
    make \
    musl-dev \
    openssl-dev

# Add service directory to /container/service
ADD service /container/service

# Use baseimage install-service script
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/install-service
RUN /container/tool/install-service

# Add default env variables
ADD environment /container/environment/99-default
