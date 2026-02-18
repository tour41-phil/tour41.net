#!/usr/bin/env bash
# ==========================================================================
# tour41.net – restic restore script
# ==========================================================================
# Restores backups from OCI Object Storage using restic
# 
# Usage:
#   ./restore.sh                    # Interactive: lists snapshots & prompts
#   ./restore.sh latest             # Restore latest snapshot
#   ./restore.sh <snapshot-id>      # Restore specific snapshot
#   ./restore.sh --list             # List available snapshots
# ==========================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
BACKUP_NAME="${BACKUP_NAME:-tour41.net}"
RESTORE_DIR="${RESTORE_DIR:-/restore}"

# Restic repository (OCI S3-compatible endpoint)
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:${OCI_S3_ENDPOINT}/${OCI_BUCKET_NAME}}"
export RESTIC_REPOSITORY

# AWS credentials for OCI S3 compatibility
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

# Database credentials (for restore)
DB_HOST="${DB_HOST:-mariadb}"
DB_NAME="${MYSQL_DATABASE:-wordpress}"
DB_USER="${MYSQL_USER:-wordpress}"
DB_PASSWORD="${MYSQL_PASSWORD}"

# ── Functions ─────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

require_env() {
    local name="$1"
    local val="${!name-}"
    if [ -z "$val" ]; then
        error "Missing required environment variable: $name"
        return 1
    fi
}

validate_config() {
    require_env OCI_S3_ENDPOINT
    require_env OCI_BUCKET_NAME
    require_env AWS_ACCESS_KEY_ID
    require_env AWS_SECRET_ACCESS_KEY
    require_env RESTIC_PASSWORD
}

list_snapshots() {
    validate_config
    log "Available snapshots for $BACKUP_NAME:"
    restic snapshots --host "$BACKUP_NAME" --compact
}

restore_snapshot() {
    local snapshot_id="$1"

    validate_config
    
    log "==> Starting restore from snapshot: $snapshot_id"
    log "Repository: $RESTIC_REPOSITORY"
    log "Restore directory: $RESTORE_DIR"
    
    # Create restore directory
    mkdir -p "$RESTORE_DIR"
    
    # ── Restore from restic ───────────────────────────────────────────────
    log "Restoring snapshot to $RESTORE_DIR..."
    restic restore "$snapshot_id" \
        --host "$BACKUP_NAME" \
        --target "$RESTORE_DIR"
    
    log "Snapshot restored to $RESTORE_DIR"
    
    # ── Display metadata ──────────────────────────────────────────────────
    if [ -f "$RESTORE_DIR/backup/temp/"*/backup-metadata.txt ]; then
        METADATA_FILE=$(find "$RESTORE_DIR" -name "backup-metadata.txt" | head -1)
        log "Backup metadata:"
        cat "$METADATA_FILE"
    fi
    
    # ── Find database dump ────────────────────────────────────────────────
    DB_FILE=$(find "$RESTORE_DIR" -name "database.sql.gz" | head -1)
    
    if [ -z "$DB_FILE" ]; then
        error "Database dump not found in restored snapshot"
        log "Restore completed, but manual intervention required"
        return 1
    fi
    
    log "Database dump found: $DB_FILE"
    log ""
    log "==> Restore completed successfully!"
    log ""
    log "Next steps:"
    log "  1. To restore the database, run:"
    log "     gunzip -c \"$DB_FILE\" | mariadb -h \$DB_HOST -u \$DB_USER -p\$DB_PASSWORD \$DB_NAME"
    log ""
    log "  2. To restore WordPress uploads, copy from:"
    log "     $RESTORE_DIR/wp_data/wp-content/uploads/ -> /wp_data/wp-content/uploads/"
    log ""
    log "  3. Restart WordPress after restore:"
    log "     docker compose restart wordpress"
}

interactive_restore() {
    log "Interactive restore mode"
    log ""
    list_snapshots
    log ""
    echo -n "Enter snapshot ID to restore (or 'latest' for most recent): "
    read -r snapshot_id
    
    if [ -z "$snapshot_id" ]; then
        error "No snapshot ID provided"
        exit 1
    fi
    
    restore_snapshot "$snapshot_id"
}

# ── Main ──────────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    interactive_restore
elif [ "$1" = "--list" ]; then
    list_snapshots
else
    restore_snapshot "$1"
fi
