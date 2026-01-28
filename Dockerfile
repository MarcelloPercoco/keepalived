# ==============================================================================
# Stage 1: Builder
# Compiles Keepalived from source to keep the final image small and clean.
# ==============================================================================
ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION} AS builder

ARG KEEPALIVED_VERSION=2.3.4

# Install build dependencies (compilers, headers, tools)
# These will be discarded in the final stage.
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

# Download, unzip, and compile Keepalived
# We use --prefix=/usr to ensure binaries land in standard paths
RUN curl -o keepalived.zip -SL https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.zip \
    && unzip keepalived.zip \
    && cd keepalived-${KEEPALIVED_VERSION} \
    && ./autogen.sh \
    && ./configure --disable-dynamic-linking --prefix=/usr --sysconfdir=/etc \
    && make \
    && make install

# ==============================================================================
# Stage 2: Final Image (Runtime)
# Contains only the compiled binary and runtime dependencies.
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# Set basic environment variables
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Install Runtime Dependencies
# 1. Keepalived libs: libnl3, openssl, iptables, ipset, etc.
# 2. Tools from build.sh: bash, python3, py-yaml (moved here for better caching)
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

# Copy the compiled Keepalived binary from the builder stage
COPY --from=builder /usr/sbin/keepalived /usr/sbin/keepalived

# Create the working directory
WORKDIR /container

# Copy the repository content to the container.
# This is done near the end to optimize layer caching.
COPY . /container

# Execute build.sh to setup the environment
# (Symlinks, users, permissions, and environment file generation)
# Since we pre-installed packages above, this step is fast.
RUN chmod +x /container/build.sh && /container/build.sh

# Use the install-service tool from the copied files
# https://github.com/osixia/docker-light-baseimage/blob/stable/image/tool/install-service
RUN /container/tool/install-service

# Define the entrypoint script
ENTRYPOINT ["/container/tool/run"]