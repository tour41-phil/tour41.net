# ==========================================================================
# tour41.net – backup service
# ==========================================================================
# Restic-based backup service with supercronic for scheduling
# Backs up MariaDB database and WordPress uploads to OCI Object Storage
# ==========================================================================

FROM alpine:3.23

# Install required packages
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gzip \
    mariadb-client \
    restic \
    git \
    && rm -rf /var/cache/apk/*

# Install supercronic for cron scheduling
# https://github.com/aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.43
ARG TARGETARCH

RUN set -eux; \
    arch="${TARGETARCH:-}"; \
    if [ -z "$arch" ]; then \
        apk_arch="$(apk --print-arch)"; \
        case "$apk_arch" in \
            x86_64) arch="amd64" ;; \
            aarch64) arch="arm64" ;; \
            armv7|armhf) arch="arm" ;; \
            x86) arch="386" ;; \
            *) echo "Unsupported apk architecture: $apk_arch" >&2; exit 1 ;; \
        esac; \
    fi; \
    case "$arch" in \
        amd64) supercronic_bin="supercronic-linux-amd64"; supercronic_sha1="f97b92132b61a8f827c3faf67106dc0e4467ccf2" ;; \
        arm64) supercronic_bin="supercronic-linux-arm64"; supercronic_sha1="5c6266786c2813d6f8a99965d84452faae42b483" ;; \
        arm) supercronic_bin="supercronic-linux-arm"; supercronic_sha1="9d222afc7875bff33bb3623dd88b390f51d9d81e" ;; \
        386) supercronic_bin="supercronic-linux-386"; supercronic_sha1="bfd002ca7a9eb146e80d31addfb93435db0db229" ;; \
        *) echo "Unsupported TARGETARCH: $arch" >&2; exit 1 ;; \
    esac; \
    supercronic_url="https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${supercronic_bin}"; \
    curl -fsSLO "$supercronic_url"; \
    echo "${supercronic_sha1}  ${supercronic_bin}" | sha1sum -c -; \
    chmod +x "$supercronic_bin"; \
    mv "$supercronic_bin" /usr/local/bin/supercronic

# Create backup directories
RUN mkdir -p /backup/temp /backup/scripts

# Copy backup scripts
COPY scripts/ /backup/scripts/
RUN chmod +x /backup/scripts/*.sh

# Copy crontab
COPY crontab /backup/crontab

# Set working directory
WORKDIR /backup

# Use entrypoint script for dynamic configuration
ENTRYPOINT ["/backup/scripts/entrypoint.sh"]
