# ==============================================================================
# Stage 1: Builder (Keepalived Compilation)
# ==============================================================================
ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

RUN apk --no-cache add \
    bash curl gcc musl-dev make linux-headers openssl-dev \
    libnl3-dev iptables-dev ipset-dev libnfnetlink-dev autoconf automake

WORKDIR /build
RUN curl -o keepalived.zip -SL https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.zip \
    && unzip keepalived.zip \
    && cd keepalived-${KEEPALIVED_VERSION} \
    && ./autogen.sh \
    && ./configure --disable-dynamic-linking \
    && make \
    && make install

# ==============================================================================
# Stage 2: Final Image (Ultra-light, No Python)
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Minimal runtime dependencies
# su-exec replaces the need for setuser.py
RUN apk --no-cache add \
    bash \
    curl \
    su-exec \
    libgcc \
    libnl3 \
    openssl \
    libnfnetlink \
    iptables \
    ipset \
    libip4tc \
    libip6tc

# Copy compiled binaries from builder
COPY --from=builder /usr/local/sbin/keepalived /usr/local/sbin/keepalived
COPY --from=builder /usr/local/etc/keepalived /usr/local/etc/keepalived

WORKDIR /container
COPY . /container

# Set permissions for our new Bash tools
RUN chmod +x /container/tool/run \
             /container/tool/setuser \
             /container/tool/install-service

# Bootstrap the container. 
# IMPORTANT: Ensure your build.sh DOES NOT contain 'apk add python3'
RUN chmod +x /container/build.sh && /container/build.sh

# Install services (Bash version)
RUN /container/tool/install-service

# The entrypoint is now our optimized Bash script
ENTRYPOINT ["/container/tool/run"]