ARG ALPINE_VERSION=3.22
ARG KEEPALIVED_VERSION=2.3.4

# -----------------------------------------
#   STAGE 1: Build Keepalived from source
# -----------------------------------------
FROM alpine:${ALPINE_VERSION} AS builder

# Install all build dependencies (removed later via multi-stage build)
RUN apk add --no-cache \
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
    openssl-dev

WORKDIR /tmp/src

# Download Keepalived source (tar.gz avoids unzip dependency)
RUN curl -SL \
      "https://github.com/acassen/keepalived/archive/refs/tags/v${KEEPALIVED_VERSION}.tar.gz" \
      -o keepalived.tar.gz \
    && tar xzf keepalived.tar.gz \
    && cd keepalived-${KEEPALIVED_VERSION} \
    # Prepare the autotools build system
    && ./autogen.sh \
    # Configure the project (static linking disabled per your settings)
    && ./configure --disable-dynamic-linking \
    # Build and install into the builder environment
    && make \
    && make install

# -----------------------------------------
#   STAGE 2: Final runtime container
# -----------------------------------------
FROM alpine:${ALPINE_VERSION}

# Copy application files
COPY . /container

# Install only the runtime dependencies (much smaller footprint)
RUN apk add --no-cache \
    bash \
    libgcc \
    libip4tc \
    libip6tc \
    ipset \
    iptables \
    libnfnetlink \
    libnl3 \
    openssl

# Copy Keepalived binaries from the builder image
COPY --from=builder /usr/local/sbin/keepalived /usr/local/sbin/keepalived
COPY --from=builder /usr/local/etc/keepalived /usr/local/etc/keepalived

# Set locale-related environment variables
# (Note: Alpine uses musl, not glibc; this is only for consistency, not locale generation)
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Add your service definitions
ADD service /container/service
RUN /container/tool/install-service

# Default environment variables
ADD environment /container/environment/99-default

ENTRYPOINT ["/container/tool/run"]
