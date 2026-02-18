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
  local wp_var_name=$2
  local config_key=$3

  # First, try WordPress environment variables (WORDPRESS_DB_*)
  if [ -n "${!wp_var_name:-}" ]; then
    echo "${!wp_var_name}"
    return 0
  fi

  # Then try generic environment variables
  if [ -n "${!var_name:-}" ]; then
    echo "${!var_name}"
    return 0
  fi

  return 1
}

log "Detecting database credentials..."

# Try WordPress standard environment variables first, then generic ones
DB_NAME=$(get_db_config "DB_NAME" "WORDPRESS_DB_NAME" "DB_NAME" || true)
DB_USER=$(get_db_config "DB_USER" "WORDPRESS_DB_USER" "DB_USER" || true)
DB_PASS=$(get_db_config "DB_PASSWORD" "WORDPRESS_DB_PASSWORD" "DB_PASSWORD" || true)
DB_HOST=$(get_db_config "DB_HOST" "WORDPRESS_DB_HOST" "DB_HOST" || true)

# Default DB_HOST if not set
DB_HOST="${DB_HOST:-db}"

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
  error "Could not determine database credentials from environment variables"
fi

log "Using database: $DB_NAME @ $DB_HOST (user: $DB_USER)"

# --- 1. DATABASE RESTORATION (OPTIONAL) ---
log "-----------------------------------"
log "Checking for database backups..."

# Use find for reliable file detection (more reliable than ls globs)
DB_ZIP=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "backup_*_db.zip" | head -n 1 || true)
DB_GZ=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "backup_*_db.gz" | head -n 1 || true)
DB_SQL=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "backup_*_db" ! -name "*.*" | head -n 1 || true)

log "DEBUG: Found DB_ZIP=$DB_ZIP"
log "DEBUG: Found DB_GZ=$DB_GZ"
log "DEBUG: Found DB_SQL=$DB_SQL"

if [ -n "$DB_ZIP" ] || [ -n "$DB_GZ" ] || [ -n "$DB_SQL" ]; then
  log "Database backup found. Starting restoration..."

  # If we have a ZIP, unzip it first
  if [ -f "$DB_ZIP" ]; then
    log "Unzipping database archive: $(basename "$DB_ZIP")"
    unzip -o "$DB_ZIP" -d "$BACKUP_PATH"
    # Re-check for .gz or plain SQL after unzip
    DB_GZ=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "*.gz" | head -n 1 || true)
    if [ -z "$DB_GZ" ]; then
      DB_SQL=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "backup_*_db" ! -name "*.*" | head -n 1 || true)
    fi
  fi

  # Import the database file (plain SQL, gzipped, or other format)
  if [ -f "$DB_GZ" ]; then
    log "Importing database from gzipped file: $(basename "$DB_GZ")"
    
    # Build mysql connection args
    mysql_args=()
    if [ -n "${DB_HOST:-}" ]; then
      mysql_args+=("-h" "$DB_HOST")
    fi
    mysql_args+=("-u" "$DB_USER")
    if [ -n "${DB_PASS:-}" ]; then
      mysql_args+=("-p${DB_PASS}")
    fi

    zcat "$DB_GZ" | mysql "${mysql_args[@]}" "$DB_NAME" || error "Database import failed"
    log "Database import complete."
  elif [ -f "$DB_SQL" ]; then
    log "Importing database from SQL file: $(basename "$DB_SQL")"
    
    # Build mysql connection args
    mysql_args=()
    if [ -n "${DB_HOST:-}" ]; then
      mysql_args+=("-h" "$DB_HOST")
    fi
    mysql_args+=("-u" "$DB_USER")
    if [ -n "${DB_PASS:-}" ]; then
      mysql_args+=("-p${DB_PASS}")
    fi

    cat "$DB_SQL" | mysql "${mysql_args[@]}" "$DB_NAME" || error "Database import failed"
    log "Database import complete."
  else
    error "Database backup found but could not locate importable file (checked for .gz and plain SQL)"
  fi
else
  log "No database backup files found. Skipping DB restoration."
fi

# --- 2. UPLOADS RESTORATION (OPTIONAL) ---
log "-----------------------------------"
log "Checking for uploads backups..."

UPLOADS_ZIPS=$(find "$BACKUP_PATH" -maxdepth 1 -type f -name "backup_*_uploads*.zip" | sort)

log "DEBUG: Found uploads files: $UPLOADS_ZIPS"

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

# Fix uploads directory ownership and permissions (limit depth to avoid hanging on large dirs)
if [ -d "$WP_PATH/wp-content/uploads" ]; then
  chown -R "$WEB_USER:$WEB_USER" "$WP_PATH/wp-content/uploads" || true
  find "$WP_PATH/wp-content/uploads" -maxdepth 5 -type d -exec chmod 755 {} \; 2>/dev/null || true
  find "$WP_PATH/wp-content/uploads" -maxdepth 5 -type f -exec chmod 644 {} \; 2>/dev/null || true
  log "Uploads directory permissions fixed."
fi

# Fix wp-content ownership (be careful not to break plugins/themes)
if [ -d "$WP_PATH/wp-content" ]; then
  chown -R "$WEB_USER:$WEB_USER" "$WP_PATH/wp-content" || true
  find "$WP_PATH/wp-content" -maxdepth 3 -type d -exec chmod 755 {} \; 2>/dev/null || true
  find "$WP_PATH/wp-content" -maxdepth 3 -type f -exec chmod 644 {} \; 2>/dev/null || true
fi

log "-----------------------------------"
log "Restore complete!"
exit 0
