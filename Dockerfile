# ==============================================================================
# Stage 1: Builder
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
# Stage 2: Final Image (Python restored for run.py)
# ==============================================================================
FROM alpine:${ALPINE_VERSION}

# We need Python 3 and Py-YAML for the original run.py to work
RUN apk --no-cache add \
    bash \
    python3 \
    py3-yaml \
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

# Copy Keepalived from builder
COPY --from=builder /usr/local/sbin/keepalived /usr/local/sbin/keepalived
COPY --from=builder /usr/local/etc/keepalived /usr/local/etc/keepalived

WORKDIR /container
COPY . /container

# Ensure tools are executable
# We use your original run (python) but our new bash install-service/setuser
RUN chmod +x /container/tool/run \
             /container/tool/setuser \
             /container/tool/install-service

# Run bootstrap
RUN chmod +x /container/build.sh && /container/build.sh

# Run service installation
RUN /container/tool/install-service

# Back to original Python entrypoint
ENTRYPOINT ["/container/tool/run"]
