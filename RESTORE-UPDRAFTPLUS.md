# UpdraftPlus Legacy Backup Restoration

This guide explains how to restore backups from UpdraftPlus into the WordPress container.

## Overview

The `restore-updraftplus-backup.sh` script is integrated into the WordPress image and can restore:
- Database backups (`backup_*_db.zip` or `backup_*_db.gz`)
- Media uploads (`backup_*_uploads*.zip`)
- Optionally run URL search-replace if migrating domains

## Prerequisites

1. **Backup files from UpdraftPlus**: Ensure you have the backup files from your old site
2. **Running Docker stack**: Your tour41.net stack should be running with a bound volume for backups
3. **Database credentials**: Should be auto-detected from `wp-config.php` or environment variables

## Quick Start

### 1. Copy Backup Files to Host

```bash
# Create a backup directory on your host
mkdir -p /path/to/backups

# Copy UpdraftPlus backup files there
# Expect files like:
#   backup_2025-02-18_db.gz
#   backup_2025-02-18_uploads.zip
#   etc.
```

### 2. Run the Restore Script

```bash
# Basic restore (database + uploads)
docker compose exec \
  -e BACKUP_PATH=/backups \
  wordpress /usr/local/bin/restore-updraftplus-backup.sh

# With URL migration (old site URL → new site URL)
docker compose exec \
  -e BACKUP_PATH=/backups \
  -e OLD_URL="https://oldsite.com" \
  -e NEW_URL="https://tour41.net" \
  wordpress /usr/local/bin/restore-updraftplus-backup.sh

# Custom WordPress path (if not /var/www/html)
docker compose exec \
  -e WP_PATH=/custom/wordpress/path \
  -e BACKUP_PATH=/backups \
  wordpress /usr/local/bin/restore-updraftplus-backup.sh
```

### 3. Update docker-compose.yml (One-Time Setup)

To easily bind the backup directory, add a volume to your `docker-compose.yml`:

```yaml
services:
  wordpress:
    volumes:
      # ... existing volumes ...
      - /path/on/host/with/backups:/backups  # Add this line
```

Then restart:

```bash
docker compose up -d wordpress
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_PATH` | `/backups` | Directory containing backup files |
| `WP_PATH` | `/var/www/html` | WordPress installation path |
| `OLD_URL` | (none) | Original site URL for search-replace |
| `NEW_URL` | (none) | New site URL for search-replace |
| `DB_NAME` | (auto-detect) | Database name |
| `DB_USER` | (auto-detect) | Database user |
| `DB_PASSWORD` | (auto-detect) | Database password |
| `DB_HOST` | (auto-detect) | Database host/IP |

Database credentials are auto-detected from `wp-config.php` if not explicitly set.

## What the Script Does

1. **Validates paths** - Checks that WordPress and backup directories exist
2. **Detects credentials** - Reads database config from environment or `wp-config.php`
3. **Restores database** - Imports `backup_*_db.gz` or unzips/imports `backup_*_db.zip`
4. **Extracts uploads** - Unzips `backup_*_uploads*.zip` files into `wp-content/uploads/`
5. **URL replacement** (optional) - Uses WP-CLI to search-replace old→new URLs
6. **Fixes permissions** - Sets proper ownership to www-data user

## Example Workflow

### Migrating from Old Server to Docker

```bash
# Step 1: Export UpdraftPlus backup files from old site
# Download from old WordPress admin or use SFTP

# Step 2: Copy to host machine
mkdir -p ~/tour41-backups
# Copy files there

# Step 3: Update docker-compose.yml to bind the directory
# Add:  - ~/tour41-backups:/backups

# Step 4: Restart stack
docker compose up -d

# Step 5: Run restore with URL migration
docker compose exec \
  -e BACKUP_PATH=/backups \
  -e OLD_URL="https://oldserver.com" \
  -e NEW_URL="https://tour41.net" \
  wordpress /usr/local/bin/restore-updraftplus-backup.sh

# Step 6: Verify in browser
# Check that:
#   - Database has been imported
#   - Media uploads appear
#   - URLs have been updated
#   - No broken image links
```

## Troubleshooting

### "Backup path does not exist"

Ensure the directory is properly bound in `docker-compose.yml`:

```bash
# Test from inside container
docker compose exec wordpress ls -la /backups
```

### "Could not determine database credentials"

If `wp-config.php` isn't readable, explicitly set environment variables:

```bash
docker compose exec \
  -e DB_NAME=wordpress \
  -e DB_USER=wordpress \
  -e DB_PASSWORD=your_password \
  -e DB_HOST=db \
  -e BACKUP_PATH=/backups \
  wordpress /usr/local/bin/restore-updraftplus-backup.sh
```

### "WP-CLI not found" (when using URL replacement)

This is not a critical error. The script will skip URL replacement. Install WP-CLI:

```bash
docker compose exec wordpress curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
docker compose exec wordpress chmod +x wp-cli.phar
docker compose exec wordpress mv wp-cli.phar /usr/local/bin/wp
```

Then retry with URL replacement.

### Database import fails with "access denied"

Verify database credentials are correct:

```bash
# Test MySQL connection
docker compose exec wordpress mysql \
  -h db \
  -u wordpress \
  -p'your_password' \
  -e "SELECT 1;"
```

### Permission errors after restore

The script attempts to fix permissions automatically. If issues persist, manually run:

```bash
docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content
```

## Manual Cleanup

After successful restore, you may want to clean up backup files:

```bash
# From host
rm -rf ~/tour41-backups/*

# Or from inside container
docker compose exec wordpress rm -rf /backups/*
```

## Docker Build

When the WordPress image is rebuilt, the script is automatically included:

```bash
cd wordpress
docker build -t test-tour41-wp:local .

# Verify script is in image
docker run --rm test-tour41-wp:local ls -la /usr/local/bin/restore-*
```

## Notes

- The script uses `set -euo pipefail` for safety; it exits on any error
- Database imports are streamed via `zcat | mysql` to minimize disk usage
- All database credentials are logged to stderr for debugging
- The script is idempotent (safe to run multiple times on the same backups)
- File permissions are fixed to `644` for files and `755` for directories
