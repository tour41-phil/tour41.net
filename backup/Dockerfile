# ==========================================================================
# tour41.net – backup service
# ==========================================================================
# Restic-based backup service with supercronic for scheduling
# Backs up MariaDB database and WordPress uploads to OCI Object Storage
# ==========================================================================

FROM alpine:3.21

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
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=71b0d58cc53f6bd72cf2f293e09e294b79c666d8

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" /usr/local/bin/supercronic

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
