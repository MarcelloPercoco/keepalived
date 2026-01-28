# ==============================================================================
# Stage 1: Builder
# Compiles Keepalived using the default /usr/local prefix to match existing scripts.
# ==============================================================================
ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

# Install build dependencies
RUN apk --no-cache add \
    bash \
    curl \
    gcc \
    musl-dev \
    make \
    linux-headers \
    openssl-dev \
    libnl3-dev \
    iptables-dev \
    ipset-dev \
    libnfnetlink-dev \
    autoconf \
    automake

WORKDIR /build

# Compile Keepalived with default prefix (/usr/local)
# This ensures compatibility with your run/startup scripts 
RUN curl -o keepalived.zip -SL https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.zip \
    && unzip keepalived.zip \
    && cd keepalived-${KEEPALIVED_VERSION} \
    && ./autogen.sh \
    && ./configure --disable-dynamic-linking \
    && make \
    && make install

# ==============================================================================
# Stage 2: Final Image
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Restore original environment variables 
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Install Runtime Dependencies including Python for YAML parsing 
RUN apk --no-cache add \
    bash \
    python3 \
    py3-yaml \
    curl \
    libgcc \
    libnl3 \
    openssl \
    libnfnetlink \
    iptables \
    ipset \
    libip4tc \
    libip6tc

# Copy the compiled binaries and default configs from builder [cite: 2, 3]
COPY --from=builder /usr/local/sbin/keepalived /usr/local/sbin/keepalived
COPY --from=builder /usr/local/etc/keepalived /usr/local/etc/keepalived

WORKDIR /container

# Copy repository files 
COPY . /container

# Run the bootstrap script 
# It handles symlinks and internal environment setup
RUN chmod +x /container/build.sh && /container/build.sh

# Install services using the tool provided in the repo [cite: 3]
RUN /container/tool/install-service

# The entrypoint uses the 'run' tool provided in the repository [cite: 4]
ENTRYPOINT ["/container/tool/run"]