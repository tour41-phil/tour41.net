#!/usr/bin/env bash
# ==========================================================================
# tour41.net – restic backup script
# ==========================================================================
# Performs automated backups to OCI Object Storage using restic
# 
# This script:
# - Dumps MariaDB database to compressed SQL
# - Backs up wp-content/uploads from wp_data volume
# - Generates metadata file with version info
# - Uploads everything to restic repository on OCI
# - Applies retention policy (forget + prune)
# ==========================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
BACKUP_NAME="${BACKUP_NAME:-tour41.net}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/backup/temp/${TIMESTAMP}"

# Restic repository (OCI S3-compatible endpoint)
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:${OCI_S3_ENDPOINT}/${OCI_BUCKET_NAME}}"
export RESTIC_REPOSITORY

# AWS credentials for OCI S3 compatibility
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

# Retention policy
RESTIC_KEEP_DAILY="${RESTIC_KEEP_DAILY:-7}"
RESTIC_KEEP_WEEKLY="${RESTIC_KEEP_WEEKLY:-4}"
RESTIC_KEEP_MONTHLY="${RESTIC_KEEP_MONTHLY:-6}"

# Database credentials
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

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        log "Cleaning up temporary directory..."
        rm -rf "$TEMP_DIR"
    fi
}

# ── Main backup process ───────────────────────────────────────────────────
main() {
    log "==> Starting backup: $BACKUP_NAME"
    log "Repository: $RESTIC_REPOSITORY"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    trap cleanup EXIT
    
    # ── Initialize restic repository if needed ────────────────────────────
    log "Checking restic repository..."
    if ! restic snapshots >/dev/null 2>&1; then
        log "Initializing new restic repository..."
        restic init
    fi
    
    # ── Database backup ───────────────────────────────────────────────────
    log "Backing up MariaDB database..."
    DB_FILE="$TEMP_DIR/database.sql.gz"
    
    mariadb-dump \
        --host="$DB_HOST" \
        --user="$DB_USER" \
        --password="$DB_PASSWORD" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        "$DB_NAME" \
        | gzip > "$DB_FILE"
    
    log "Database dump created: $(du -h "$DB_FILE" | cut -f1)"
    
    # ── Generate metadata ─────────────────────────────────────────────────
    log "Generating metadata..."
    METADATA_FILE="$TEMP_DIR/backup-metadata.txt"
    
    {
        echo "Backup Metadata"
        echo "==============="
        echo ""
        echo "Timestamp: $(date -Iseconds)"
        echo "Backup Name: $BACKUP_NAME"
        echo "Domain: ${DOMAIN:-unknown}"
        echo ""
        
        # Git info (if available)
        if command -v git >/dev/null 2>&1 && [ -d "/repo/.git" ]; then
            echo "Git Commit: $(git -C /repo rev-parse HEAD 2>/dev/null || echo 'unknown')"
            echo "Git Branch: $(git -C /repo rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
        else
            echo "Git Commit: not available (not in git context)"
        fi
        
        echo ""
        echo "Database: $DB_NAME"
        echo "Database Size: $(du -h "$DB_FILE" | cut -f1)"
        echo ""
        
        # WordPress version (try to detect from wp_data volume)
        if [ -f "/wp_data/wp-includes/version.php" ]; then
            WP_VERSION=$(grep "wp_version = " /wp_data/wp-includes/version.php | cut -d "'" -f 2 || echo "unknown")
            echo "WordPress Version: $WP_VERSION"
        else
            echo "WordPress Version: unknown (version.php not found)"
        fi
        
        echo ""
        echo "Backup Contents:"
        echo "  - MariaDB database dump (compressed)"
        echo "  - wp-content/uploads directory"
        echo "  - This metadata file"
    } > "$METADATA_FILE"
    
    log "Metadata file created"
    
    # ── Restic backup ─────────────────────────────────────────────────────
    log "Uploading to restic repository..."
    
    # Backup database dump and metadata
    restic backup \
        --tag "database" \
        --tag "automated" \
        --host "$BACKUP_NAME" \
        "$TEMP_DIR"
    
    # Backup WordPress uploads directory
    if [ -d "/wp_data/wp-content/uploads" ]; then
        log "Backing up wp-content/uploads..."
        restic backup \
            --tag "uploads" \
            --tag "automated" \
            --host "$BACKUP_NAME" \
            /wp_data/wp-content/uploads
    else
        log "WARNING: /wp_data/wp-content/uploads not found, skipping"
    fi
    
    # ── Retention policy ──────────────────────────────────────────────────
    log "Applying retention policy..."
    log "  Keep daily: $RESTIC_KEEP_DAILY"
    log "  Keep weekly: $RESTIC_KEEP_WEEKLY"
    log "  Keep monthly: $RESTIC_KEEP_MONTHLY"
    
    restic forget \
        --keep-daily "$RESTIC_KEEP_DAILY" \
        --keep-weekly "$RESTIC_KEEP_WEEKLY" \
        --keep-monthly "$RESTIC_KEEP_MONTHLY" \
        --prune \
        --host "$BACKUP_NAME"
    
    # ── Verification ──────────────────────────────────────────────────────
    log "Verifying repository integrity..."
    restic check --read-data-subset=5%
    
    # ── Summary ───────────────────────────────────────────────────────────
    log "==> Backup completed successfully!"
    log "Latest snapshots:"
    restic snapshots --latest 3 --host "$BACKUP_NAME"
}

# ── Entry point ───────────────────────────────────────────────────────────
if [ $# -gt 0 ] && [ "$1" = "--init-only" ]; then
    log "Initializing restic repository only..."
    export RESTIC_REPOSITORY
    restic init
    log "Repository initialized successfully"
    exit 0
fi

main "$@"
