#!/usr/bin/env bash
# ==========================================================================
# tour41.net – database backup script
# ==========================================================================
# Usage:
#   ./scripts/backup.sh              # creates timestamped gzipped SQL dump
#   ./scripts/backup.sh /path/dir    # custom output directory
#
# Recommended: add a cron job on the host, e.g.
#   0 3 * * * /opt/tour41.net/scripts/backup.sh /opt/tour41.net/backups
# ==========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source .env for database credentials
if [ -f "$PROJECT_DIR/.env" ]; then
    # shellcheck source=/dev/null
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

BACKUP_DIR="${1:-$PROJECT_DIR/backups}"
mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/tour41_db_${TIMESTAMP}.sql.gz"

echo "Backing up database to $BACKUP_FILE ..."

docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T mariadb \
    mariadb-dump \
        -u "${MYSQL_USER:-wordpress}" \
        -p"${MYSQL_PASSWORD}" \
        "${MYSQL_DATABASE:-wordpress}" \
    | gzip > "$BACKUP_FILE"

echo "Backup complete: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Prune backups older than 30 days
find "$BACKUP_DIR" -name "tour41_db_*.sql.gz" -mtime +30 -delete
echo "Old backups (>30 days) pruned."
