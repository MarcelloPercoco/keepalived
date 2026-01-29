# ==============================================================================
# STAGE 1: Builder
# ==============================================================================
ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

# Install build dependencies
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    bash curl gcc musl-dev make linux-headers openssl-dev \
    libnl3-dev iptables-dev ipset-dev libnfnetlink-dev libmnl-dev \
    autoconf automake libtool tar

WORKDIR /build

# Download, autogen and compile
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
    && make install

# ==============================================================================
# STAGE 2: Runtime
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Install runtime dependencies
# We add iptables-dev ONLY to pull in the symlinks for libip4tc.so and libip6tc.so
# which are often missing in the bare 'iptables' package on Alpine 3.23
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    bash \
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
    iptables-dev

# Copy binary from builder
COPY --from=builder /usr/sbin/keepalived /usr/sbin/keepalived

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Verify - This must pass now because iptables-dev provides the missing .so files
RUN ldd /usr/sbin/keepalived

ENTRYPOINT ["/entrypoint.sh"]
