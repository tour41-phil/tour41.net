# Automated Backups with Restic and Oracle Cloud

This guide explains how to set up and use the automated backup system for tour41.net.

## Overview

The backup system uses:
- **[Restic](https://restic.net/)**: Fast, encrypted, incremental backups
- **Oracle Cloud Object Storage (OCI)**: Free-tier cloud storage (10GB)
- **Supercronic**: Reliable cron for Docker containers
- **Automated scheduling**: Daily backups without host dependencies

## What Gets Backed Up

1. **MariaDB Database**: Full compressed SQL dump
2. **WordPress Uploads**: wp-content/uploads directory
3. **Metadata**: Timestamps, git commit, WordPress version, domain info

Themes and plugins are **not** backed up because they're baked into the Docker image and version-controlled in git.

## Setup Guide

### 1. Create Oracle Cloud Account

1. Sign up for Oracle Cloud Free Tier: https://www.oracle.com/cloud/free/
2. You get 10GB of Object Storage (always free)

### 2. Set Up Object Storage

1. Log in to OCI Console: https://cloud.oracle.com/
2. Navigate to: **Storage** → **Object Storage & Archive Storage** → **Buckets**
3. Create a new bucket:
   - **Name**: `tour41-backups` (or your preferred name)
   - **Storage Tier**: Standard
   - **Encryption**: Use Oracle-managed keys
   - Click **Create**

### 3. Get Your OCI Credentials

#### Find your namespace and endpoint:

1. In OCI Console, note your **Object Storage Namespace** (shown at top of bucket list)
2. Note your **Region** (e.g., `us-ashburn-1`, shown in URL or region selector)
3. Your S3 endpoint will be: 
   ```
   https://{namespace}.compat.objectstorage.{region}.oraclecloud.com
   ```

#### Create Customer Secret Keys (for S3 compatibility):

1. Click your **profile icon** (top right) → **User Settings**
2. Scroll to **Resources** → **Customer Secret Keys**
3. Click **Generate Secret Key**
4. Give it a name (e.g., `tour41-backup`)
5. **Copy the Access Key and Secret Key** (you won't see the secret again!)

### 4. Configure Environment Variables

Edit your `.env` file (copy from `.env.example` if needed):

```bash
# OCI S3 endpoint (replace YOUR_NAMESPACE and YOUR_REGION)
OCI_S3_ENDPOINT=https://YOUR_NAMESPACE.compat.objectstorage.YOUR_REGION.oraclecloud.com

# OCI bucket name (the bucket you created)
OCI_BUCKET_NAME=tour41-backups

# Customer Secret Keys from OCI
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here

# Restic encryption password (generate a strong one!)
# IMPORTANT: Store this password safely - you need it to restore backups!
RESTIC_PASSWORD=your_strong_encryption_password
```

**Generate a strong restic password:**
```bash
openssl rand -base64 32
```

**⚠️ CRITICAL**: Store your `RESTIC_PASSWORD` in a safe place (password manager, encrypted file). Without it, your backups are **unrecoverable**.

### 5. Deploy the Backup Service

```bash
# Pull the pre-built backup image from GHCR
docker compose pull backup

# Start the backup service
docker compose up -d backup

# Check logs
docker compose logs -f backup
```

> If you're developing the backup image locally, you can still build it with:
> `docker compose build backup`

## Usage

### Manual Backup

Run a backup immediately (without waiting for the schedule):

```bash
docker compose exec backup /backup/scripts/backup.sh
```

### Initialize Repository (First Time)

If you need to manually initialize the restic repository:

```bash
docker compose exec backup /backup/scripts/backup.sh --init-only
```

### List Snapshots

View all available backups:

```bash
docker compose exec backup restic snapshots
```

### Check Repository Status

Verify backup integrity:

```bash
docker compose exec backup restic check
```

### View Repository Statistics

```bash
docker compose exec backup restic stats
```

## Restore

### List Available Snapshots

```bash
docker compose exec backup /backup/scripts/restore.sh --list
```

### Interactive Restore

```bash
docker compose exec backup /backup/scripts/restore.sh
```

This will:
1. Show available snapshots
2. Prompt for snapshot ID
3. Restore to `/restore` directory
4. Display instructions for database restore

### Restore Latest Snapshot

```bash
docker compose exec backup /backup/scripts/restore.sh latest
```

### Restore Specific Snapshot

```bash
docker compose exec backup /backup/scripts/restore.sh <snapshot-id>
```

### Complete Restore Process

After running the restore script:

1. **Restore Database:**
   ```bash
   # Find the database dump
   docker compose exec backup find /restore -name "database.sql.gz"
   
   # Restore to database
   docker compose exec backup sh -c \
     'gunzip -c /restore/backup/temp/*/database.sql.gz | \
      mariadb -h mariadb -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE'
   ```

2. **Restore Uploads:**
   ```bash
   # Copy uploads back to wp_data volume
   docker compose exec backup sh -c \
     'cp -r /restore/wp_data/wp-content/uploads/* /wp_data/wp-content/uploads/'
   ```

3. **Restart WordPress:**
   ```bash
   docker compose restart wordpress
   ```

## Configuration

### Backup Schedule

Change backup time (default: 03:30 daily):

```bash
# In .env file:
BACKUP_CRON=30 3 * * *
```

Cron format: `minute hour day month weekday`

Examples:
- `0 2 * * *` - Daily at 02:00
- `0 3 * * 0` - Weekly on Sunday at 03:00
- `0 4 1 * *` - Monthly on the 1st at 04:00

### Retention Policy

Control how many backups to keep:

```bash
# In .env file:
RESTIC_KEEP_DAILY=7      # Keep 7 daily backups
RESTIC_KEEP_WEEKLY=4     # Keep 4 weekly backups
RESTIC_KEEP_MONTHLY=6    # Keep 6 monthly backups
```

Restic automatically removes old backups based on this policy after each backup.

### Test Backup on Startup

For testing, run a backup immediately when the container starts:

```bash
# In .env file:
BACKUP_RUN_ON_STARTUP=true
```

## Monitoring

### View Backup Logs

```bash
# Real-time logs
docker compose logs -f backup

# Last 100 lines
docker compose logs --tail=100 backup
```

### Check Last Backup

```bash
docker compose exec backup restic snapshots --latest 1
```

### Verify Backup Health

```bash
# Quick check
docker compose exec backup restic check

# Full integrity check (reads all data - slow!)
docker compose exec backup restic check --read-data
```

## Disaster Recovery

If you need to restore to a **fresh VPS** from scratch:

### 1. Deploy the Stack

```bash
# Clone the repo
git clone https://github.com/tour41-phil/tour41.net.git /opt/tour41.net
cd /opt/tour41.net

# Create .env with your OCI credentials
cp .env.example .env
# Edit .env and add your OCI and restic credentials

# Start services
docker compose up -d
```

### 2. Restore from Backup

```bash
# List available snapshots
docker compose exec backup /backup/scripts/restore.sh --list

# Restore latest
docker compose exec backup /backup/scripts/restore.sh latest

# Follow the restore instructions displayed
```

### 3. Verify

Visit your site and verify everything works.

## Troubleshooting

### "repository does not exist" error

**Solution**: Initialize the repository first:
```bash
docker compose exec backup /backup/scripts/backup.sh --init-only
```

### "connection timeout" or "unable to connect"

**Possible causes**:
- Incorrect `OCI_S3_ENDPOINT` (check namespace and region)
- Incorrect `OCI_BUCKET_NAME`
- Network firewall blocking OCI

**Solution**: Test connectivity:
```bash
docker compose exec backup curl -I https://YOUR_NAMESPACE.compat.objectstorage.YOUR_REGION.oraclecloud.com
```

### "access denied" or "authentication failed"

**Possible causes**:
- Incorrect `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`
- Keys not enabled in OCI

**Solution**: Verify credentials in OCI Console → User Settings → Customer Secret Keys

### "wrong password" or "unable to open repository"

**Cause**: Incorrect `RESTIC_PASSWORD`

**Solution**: If you lost your password, you **cannot** recover the backups. You'll need to:
1. Delete the old repository (or use a new bucket)
2. Set a new `RESTIC_PASSWORD`
3. Initialize a new repository

### Backup takes too long

**Possible causes**:
- Large uploads directory
- Slow network to OCI

**Solutions**:
- Increase `initial_wait` timeout
- Check OCI region (choose one geographically close)
- Consider excluding large media files if not critical

### Check disk space

```bash
# Check backup temp directory usage
docker compose exec backup df -h /backup/temp

# Check volume sizes
docker system df -v
```

## Cost and Limits

### Oracle Cloud Free Tier

- **10GB** Object Storage (always free)
- Includes **50,000 API requests/month**
- No egress charges for first 10TB/month

### Estimate Your Backup Size

```bash
# Database size
docker compose exec mariadb sh -c \
  'du -sh /var/lib/mysql'

# Uploads size
docker compose exec wordpress sh -c \
  'du -sh /var/www/html/wp-content/uploads'

# Total backup size (after compression)
docker compose exec backup restic stats latest
```

### If You Exceed 10GB

Options:
1. Reduce retention policy (keep fewer backups)
2. Exclude large media files that can be regenerated
3. Upgrade to OCI paid tier (very cheap)

## Security Notes

1. **Restic encrypts all data** before upload (AES-256)
2. **Store RESTIC_PASSWORD safely** - treat it like a root password
3. **Rotate OCI Customer Secret Keys** periodically
4. **Use strong passwords** for database and restic
5. **Keep .env file secure** - never commit to git
6. **Test restores regularly** - backups are useless if you can't restore

## Advanced: Manual Restic Commands

You can run any restic command directly:

```bash
# Enter backup container
docker compose exec backup sh

# List snapshots
restic snapshots

# Show differences between snapshots
restic diff <snapshot1> <snapshot2>

# Mount repository as filesystem
mkdir -p /tmp/mount
restic mount /tmp/mount

# Unlock repository (if locked after crash)
restic unlock

# Rebuild index
restic rebuild-index

# Prune without forget
restic prune
```

## Support

- **Restic docs**: https://restic.readthedocs.io/
- **OCI docs**: https://docs.oracle.com/en-us/iaas/Content/Object/home.htm
- **Issues**: https://github.com/tour41-phil/tour41.net/issues

## Quick Reference

### Helper Script

A convenience script is provided for common operations:

```bash
# Run backup now
./scripts/backup-helper.sh run

# List snapshots
./scripts/backup-helper.sh list

# Check status
./scripts/backup-helper.sh status

# Interactive restore
./scripts/backup-helper.sh restore

# View logs
./scripts/backup-helper.sh logs

# Show all commands
./scripts/backup-helper.sh help
```

### Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `BACKUP_IMAGE` | No | `ghcr.io/tour41-phil/tour41.net-backup:latest` | Override the backup image tag (e.g. pin to `sha-...`) |
| `OCI_S3_ENDPOINT` | Yes | - | OCI S3-compatible endpoint URL |
| `OCI_BUCKET_NAME` | Yes | - | OCI bucket name for backups |
| `AWS_ACCESS_KEY_ID` | Yes | - | OCI Customer Secret Key (access key) |
| `AWS_SECRET_ACCESS_KEY` | Yes | - | OCI Customer Secret Key (secret) |
| `RESTIC_PASSWORD` | Yes | - | Restic repository encryption password |
| `BACKUP_CRON` | No | `30 3 * * *` | Backup schedule (cron format) |
| `BACKUP_RUN_ON_STARTUP` | No | `false` | Run backup on container start |
| `RESTIC_KEEP_DAILY` | No | `7` | Daily backups to keep |
| `RESTIC_KEEP_WEEKLY` | No | `4` | Weekly backups to keep |
| `RESTIC_KEEP_MONTHLY` | No | `6` | Monthly backups to keep |

### Common Restic Commands

```bash
# All commands run inside the backup container
docker compose exec backup [command]

# List snapshots
restic snapshots

# Show snapshot details
restic snapshots <snapshot-id>

# Compare two snapshots
restic diff <snapshot1> <snapshot2>

# Check repository
restic check

# Show repository statistics
restic stats

# List files in snapshot
restic ls <snapshot-id>

# Unlock repository (after crash/interruption)
restic unlock

# Rebuild index
restic rebuild-index

# Forget specific snapshot
restic forget <snapshot-id>

# Manual prune (remove unreferenced data)
restic prune
```
