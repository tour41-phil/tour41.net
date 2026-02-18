#!/bin/bash

# Restore UpdraftPlus backup into WordPress
#
# This script imports database and uploads from UpdraftPlus backup archives.
# Intended to be run inside the WordPress container with backup files bind-mounted.
#
# Usage:
#   docker compose exec wordpress /usr/local/bin/restore-updraftplus-backup.sh [OPTIONS]
#
# Environment Variables:
#   WP_PATH           - Path to WordPress installation (default: /var/www/html)
#   BACKUP_PATH       - Path where backup files are located (default: /backups)
#   OLD_URL           - (Optional) Old site URL for search-replace
#   NEW_URL           - (Optional) New site URL for search-replace
#   DB_NAME           - Database name (auto-detected from wp-config.php if not set)
#   DB_USER           - Database user (auto-detected from wp-config.php if not set)
#   DB_PASSWORD       - Database password (auto-detected from wp-config.php if not set)
#   DB_HOST           - Database host (auto-detected from wp-config.php if not set)
#
# Example:
#   # Bind backup directory and run restore
#   docker compose exec -e BACKUP_PATH=/backups wordpress \
#     /usr/local/bin/restore-updraftplus-backup.sh

set -euo pipefail

# --- DEFAULTS & ENV ---
WP_PATH="${WP_PATH:-/var/www/html}"
BACKUP_PATH="${BACKUP_PATH:-/backups}"

log() {
  printf '[restore-updraftplus] %s\n' "$*" >&2
}

error() {
  printf '[restore-updraftplus] ERROR: %s\n' "$*" >&2
  exit 1
}

log "-----------------------------------"
log "Initializing Configuration..."
log "WP Path: $WP_PATH"
log "Backup Path: $BACKUP_PATH"

# Verify paths exist
if [ ! -d "$WP_PATH" ]; then
  error "WordPress path does not exist: $WP_PATH"
fi

if [ ! -d "$BACKUP_PATH" ]; then
  error "Backup path does not exist: $BACKUP_PATH"
fi

# --- DATABASE CREDENTIALS LOGIC ---
get_db_config() {
  local var_name=$1
  local config_key=$2

  # If environment variable is set, use it
  if [ -n "${!var_name:-}" ]; then
    echo "${!var_name}"
    return 0
  fi

  # Try to extract from wp-config.php
  if [ -f "$WP_PATH/wp-config.php" ]; then
    local value
    value=$(grep "define.*$config_key" "$WP_PATH/wp-config.php" | head -n1 | cut -d\' -f4 || true)
    if [ -n "$value" ]; then
      echo "$value"
      return 0
    fi
  fi

  return 1
}

log "Detecting database credentials..."

DB_NAME=$(get_db_config "DB_NAME" "DB_NAME" || true)
DB_USER=$(get_db_config "DB_USER" "DB_USER" || true)
DB_PASS=$(get_db_config "DB_PASSWORD" "DB_PASSWORD" || true)
DB_HOST=$(get_db_config "DB_HOST" "DB_HOST" || true)

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
  error "Could not determine database credentials from environment or wp-config.php"
fi

log "Using database: $DB_NAME@$DB_HOST"

# --- 1. DATABASE RESTORATION (OPTIONAL) ---
log "-----------------------------------"
log "Checking for database backups..."

DB_ZIP=$(ls "$BACKUP_PATH"/backup_*_db.zip 2>/dev/null | head -n 1 || true)
DB_GZ=$(ls "$BACKUP_PATH"/backup_*_db.gz 2>/dev/null | head -n 1 || true)

if [ -n "$DB_ZIP" ] || [ -n "$DB_GZ" ]; then
  log "Database backup found. Starting restoration..."

  # If we have a ZIP, unzip it first
  if [ -f "$DB_ZIP" ]; then
    log "Unzipping database archive: $(basename "$DB_ZIP")"
    unzip -o "$DB_ZIP" -d "$BACKUP_PATH"
    DB_GZ=$(ls "$BACKUP_PATH"/backup_*_db.gz 2>/dev/null | head -n 1 || true)
  fi

  # Import the GZ file
  if [ -f "$DB_GZ" ]; then
    log "Importing database: $(basename "$DB_GZ")"
    
    # Build mysql connection args
    local mysql_args=()
    if [ -n "${DB_HOST:-}" ]; then
      mysql_args+=("-h" "$DB_HOST")
    fi
    mysql_args+=("-u" "$DB_USER")
    if [ -n "${DB_PASS:-}" ]; then
      mysql_args+=("-p${DB_PASS}")
    fi

    zcat "$DB_GZ" | mysql "${mysql_args[@]}" "$DB_NAME" || error "Database import failed"
    log "Database import complete."
  else
    error "Database backup found but no .gz file created after extraction"
  fi
else
  log "No database backup files found. Skipping DB restoration."
fi

# --- 2. UPLOADS RESTORATION (OPTIONAL) ---
log "-----------------------------------"
log "Checking for uploads backups..."

UPLOADS_ZIPS=$(ls "$BACKUP_PATH"/backup_*_uploads*.zip 2>/dev/null || true)

if [ -n "$UPLOADS_ZIPS" ]; then
  log "Uploads backup(s) found. Starting extraction..."
  
  # Ensure uploads directory exists
  mkdir -p "$WP_PATH/wp-content/uploads"
  
  for zipfile in $UPLOADS_ZIPS; do
    log "Extracting: $(basename "$zipfile")"
    unzip -q -o "$zipfile" -d "$WP_PATH/wp-content/" || error "Failed to extract $(basename "$zipfile")"
  done
  
  log "Uploads extraction complete."
else
  log "No uploads backup files found. Skipping uploads restoration."
fi

# --- 3. SEARCH AND REPLACE ---
if [ -n "${OLD_URL:-}" ] && [ -n "${NEW_URL:-}" ] && [ "$OLD_URL" != "$NEW_URL" ]; then
  log "-----------------------------------"
  log "Running search and replace: $OLD_URL -> $NEW_URL"
  
  if command -v wp &>/dev/null; then
    (
      cd "$WP_PATH"
      wp search-replace "$OLD_URL" "$NEW_URL" --allow-root || error "WP-CLI search-replace failed"
      wp cache flush --allow-root || true
    )
    log "Search and replace complete."
  else
    log "WARNING: WP-CLI not found. URL replacement skipped."
  fi
else
  if [ -n "${OLD_URL:-}" ] || [ -n "${NEW_URL:-}" ]; then
    log "Skipping search and replace (both OLD_URL and NEW_URL must be set)"
  fi
fi

# --- 4. PERMISSION FIXES ---
log "-----------------------------------"
log "Fixing permissions..."

# Detect web user (www-data in standard PHP-FPM setup)
WEB_USER="www-data"
if ! id "$WEB_USER" &>/dev/null; then
  # Fallback detection
  WEB_USER=$(ps aux | grep -E '[a]pache|[h]ttpd|[n]ginx|[p]hp-fpm' | grep -v root | head -n1 | awk '{print $1}' || true)
  if [ -z "$WEB_USER" ]; then
    WEB_USER="www-data"
  fi
fi

log "Setting ownership to $WEB_USER..."

# Fix uploads directory ownership and permissions
if [ -d "$WP_PATH/wp-content/uploads" ]; then
  chown -R "$WEB_USER:$WEB_USER" "$WP_PATH/wp-content/uploads"
  find "$WP_PATH/wp-content/uploads" -type d -exec chmod 755 {} \;
  find "$WP_PATH/wp-content/uploads" -type f -exec chmod 644 {} \;
  log "Uploads directory permissions fixed."
fi

# Fix wp-content ownership (be careful not to break plugins/themes)
if [ -d "$WP_PATH/wp-content" ]; then
  chown -R "$WEB_USER:$WEB_USER" "$WP_PATH/wp-content"
  find "$WP_PATH/wp-content" -type d -exec chmod 755 {} \;
  find "$WP_PATH/wp-content" -type f -exec chmod 644 {} \;
fi

log "-----------------------------------"
log "Restore complete!"
