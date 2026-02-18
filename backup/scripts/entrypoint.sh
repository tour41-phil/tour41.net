#!/usr/bin/env bash
# ==========================================================================
# tour41.net – backup service entrypoint
# ==========================================================================
# Handles dynamic crontab configuration and service startup
# ==========================================================================

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ── Configure crontab ─────────────────────────────────────────────────────
CRONTAB_FILE="/backup/crontab"

if [ -n "${BACKUP_CRON:-}" ]; then
    log "Using custom backup schedule: $BACKUP_CRON"
    echo "$BACKUP_CRON /backup/scripts/backup.sh" > "$CRONTAB_FILE"
else
    log "Using default backup schedule from crontab"
fi

# Display the active schedule
log "Active backup schedule:"
cat "$CRONTAB_FILE"

# ── Run initial backup if requested ───────────────────────────────────────
if [ "${RUN_ON_STARTUP:-false}" = "true" ]; then
    log "RUN_ON_STARTUP=true, running initial backup..."
    /backup/scripts/backup.sh || log "Initial backup failed (will retry on schedule)"
fi

# ── Start supercronic ─────────────────────────────────────────────────────
log "Starting supercronic..."
exec supercronic "$CRONTAB_FILE"
