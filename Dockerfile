# ==============================================================================
# STAGE 1: Builder
# ==============================================================================
ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

# Install build dependencies
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    curl gcc musl-dev make linux-headers openssl-dev \
    libnl3-dev iptables-dev ipset-dev libnfnetlink-dev libmnl-dev \
    autoconf automake libtool tar

WORKDIR /build

# Download, autogen, compile AND strip debug symbols
RUN curl -L https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.tar.gz -o keepalived.tar.gz \
    && tar -xzf keepalived.tar.gz \
    && cd keepalived-${KEEPALIVED_VERSION} \
    && ./autogen.sh \
    && ./configure \
    --prefix=/usr \
    --exec-prefix=/usr \
    --bindir=/usr/bin \
    --sbindir=/usr/sbin \
    --sysconfdir=/etc \
    --disable-dynamic-linking \
    && make \
    && make install \
    && strip /usr/sbin/keepalived

# ==============================================================================
# STAGE 2: Runtime
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Install runtime dependencies, manually link .so to avoid iptables-dev, and check ldd linking
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    curl \
    iproute2 \
    iputils \
    libgcc \
    libnl3 \
    openssl \
    libnfnetlink \
    libmnl \
    iptables \
    ipset \
    libxtables \
    libip4tc \
    libip6tc && \
    mkdir -p /etc/keepalived

# Copy binary from builder
COPY --link --from=builder /usr/sbin/keepalived /usr/sbin/keepalived

# Copy entrypoint script directly with execution permissions
COPY --link --chmod=755 entrypoint.sh /entrypoint.sh

# Verify linking (will crash the build if symlinks failed or dependencies are lost)
RUN ldd /usr/sbin/keepalived

ENTRYPOINT ["/entrypoint.sh"]