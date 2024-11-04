ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION}

# Keepalived version
ARG KEEPALIVED_VERSION=2.3.1

# Download, build and install Keepalived
RUN apk update \
    && apk --no-cache upgrade \
    && apk --no-cache add \
    bash \
    autoconf \
    curl \
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
    && curl -o keepalived.tar.gz -SL http://keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz \
    && mkdir -p /container/keepalived-sources \
    && tar -xzf keepalived.tar.gz --strip 1 -C /container/keepalived-sources \
    && cd container/keepalived-sources \
    && /bin/bash ./configure --disable-dynamic-linking \
    && make && make install \
    && rm -f /keepalived.tar.gz \
    && rm -rf /container/keepalived-sources \
    && apk --no-cache del \
    bash \ 
    autoconf \
    gcc \
    ipset-dev \
    iptables-dev \
    libnfnetlink-dev \
    libnl3-dev \
    make \
    musl-dev \
    openssl-dev

# set keepalived as image entrypoint with --dont-fork and --log-console (to make it docker friendly)
# define /etc/keepalived/keepalived.conf as the configuration file to use
ENTRYPOINT ["/usr/local/sbin/keepalived","--dont-fork","--log-console", "-f","/usr/local/etc/keepalived/keepalived.conf"]
