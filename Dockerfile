# ==============================================================================
# STAGE 1: Builder
# Compiles Keepalived from source to keep the final image slim.
# ==============================================================================
ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

# Install build dependencies
RUN apk add --no-cache \
    bash curl gcc musl-dev make linux-headers openssl-dev \
    libnl3-dev iptables-dev ipset-dev libnfnetlink-dev autoconf automake tar

WORKDIR /build

# Download source and compile
# Using tar.gz for better compression and permission preservation
RUN curl -o keepalived.tar.gz -SL https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.tar.gz \
    && tar -xzf keepalived.tar.gz \
    && cd keepalived-${KEEPALIVED_VERSION} \
    && ./autogen.sh \
    && ./configure --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin --sysconfdir=/etc --disable-dynamic-linking \
    && make \
    && make install

# ==============================================================================
# STAGE 2: Runtime
# Final lightweight image containing only the binary and network tools.
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Install runtime dependencies and essential networking tools
RUN apk add --no-cache \
    bash \
    iproute2 \
    iputils \
    libgcc \
    libnl3 \
    openssl \
    libnfnetlink \
    iptables \
    ipset

# Copy compiled binary from builder stage
COPY --from=builder /usr/sbin/keepalived /usr/sbin/keepalived

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Keepalived needs net_admin/net_raw capabilities to manage VIPs
ENTRYPOINT ["/entrypoint.sh"]
