# Backup System Testing Guide

This guide walks through testing the backup system before deploying to production.

## Prerequisites

- Docker and Docker Compose installed
- Oracle Cloud account with Object Storage configured
- `.env` file with OCI credentials

## Test Checklist

### 1. Build the Backup Container

```bash
cd /opt/tour41.net
docker compose build backup
```

**Expected**: Build completes successfully, showing restic and supercronic installation.

### 2. Start the Backup Service

```bash
docker compose up -d backup
```

**Expected**: Container starts and stays running.

```bash
# Check status
docker compose ps backup

# Should show "running" status
```

### 3. Check Logs

```bash
docker compose logs backup
```

**Expected output**:
- "Using default backup schedule from crontab" (or custom if BACKUP_CRON is set)
- "Active backup schedule: 30 3 * * *"
- "Starting supercronic..."

No errors should appear.

### 4. Initialize Restic Repository

On first run, initialize the restic repository:

```bash
docker compose exec backup /backup/scripts/backup.sh --init-only
```

**Expected output**:
```
[timestamp] Initializing restic repository only...
created restic repository <repo-id> at s3:https://...
[timestamp] Repository initialized successfully
```

**Troubleshooting**:
- If you get "connection refused" or "timeout", check `OCI_S3_ENDPOINT` and network
- If you get "access denied", verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- If you get "bucket not found", verify `OCI_BUCKET_NAME` exists in OCI Console

### 5. Run First Backup

```bash
docker compose exec backup /backup/scripts/backup.sh
```

**Expected output**:
1. "Starting backup: tour41.net"
2. "Checking restic repository..." (should detect existing repo)
3. "Backing up MariaDB database..." + size
4. "Generating metadata..."
5. "Uploading to restic repository..."
6. "Backing up wp-content/uploads..."
7. "Applying retention policy..."
8. "Verifying repository integrity..."
9. "Backup completed successfully!"
10. List of latest snapshots

**Duration**: First backup takes 1-5 minutes depending on database and uploads size.

**Common issues**:
- Database connection errors → Check `MYSQL_PASSWORD` in `.env`
- "database.sql.gz: No such file" → Normal, script creates temp files
- Slow upload → Normal for first backup (includes all data)

### 6. Verify Backup in OCI Console

1. Log in to Oracle Cloud Console
2. Navigate to **Object Storage → Buckets → [your-bucket]**
3. You should see directories:
   - `config`
   - `data/`
   - `index/`
   - `keys/`
   - `locks/`
   - `snapshots/`

These are created by restic (encrypted).

### 7. List Snapshots

```bash
docker compose exec backup restic snapshots
```

**Expected**: Shows at least one snapshot with tags "database" and "uploads".

Example output:
```
repository opened successfully
ID        Time                 Host         Tags
----------------------------------------------------------------------
a1b2c3d4  2026-02-18 03:30:15  tour41.net   database, automated
e5f6g7h8  2026-02-18 03:30:25  tour41.net   uploads, automated
----------------------------------------------------------------------
2 snapshots
```

### 8. Check Repository Stats

```bash
docker compose exec backup restic stats
```

**Expected**: Shows total size, compression ratio, and snapshot count.

### 9. Verify Repository Integrity

```bash
docker compose exec backup restic check
```

**Expected**: "no errors were found"

For a more thorough check (slower):
```bash
docker compose exec backup restic check --read-data-subset=100%
```

### 10. Test Restore (Non-Destructive)

```bash
docker compose exec backup /backup/scripts/restore.sh latest
```

**Expected**:
1. Restores latest snapshot to `/restore` directory
2. Shows backup metadata
3. Displays instructions for database and uploads restore

**Verify files were restored**:
```bash
docker compose exec backup find /restore -type f -name "*.sql.gz"
docker compose exec backup find /restore -type d -name "uploads"
```

### 11. Test Scheduled Backup

To test the cron schedule without waiting, temporarily change the schedule:

```bash
# Stop backup service
docker compose stop backup

# Edit .env and set:
# BACKUP_CRON=* * * * *  # Runs every minute (for testing only!)

# Restart backup service
docker compose up -d backup

# Watch logs
docker compose logs -f backup
```

**Expected**: Backup runs every minute. You'll see "Starting backup" in logs.

**IMPORTANT**: Change `BACKUP_CRON` back to `30 3 * * *` after testing!

### 12. Test Startup Backup (Optional)

```bash
# Stop backup service
docker compose stop backup

# Edit .env and set:
# BACKUP_RUN_ON_STARTUP=true

# Start backup service
docker compose up -d backup

# Watch logs
docker compose logs -f backup
```

**Expected**: Backup runs immediately on startup before entering cron loop.

### 13. Test Manual Trigger with Helper Script

```bash
./scripts/backup-helper.sh run
```

**Expected**: Same output as manual backup command.

### 14. Test Retention Policy

After running multiple backups, test the forget policy:

```bash
# See current snapshots
docker compose exec backup restic snapshots

# Run backup again to test pruning
docker compose exec backup /backup/scripts/backup.sh

# Verify old snapshots are removed based on retention policy
docker compose exec backup restic snapshots
```

**Expected**: Older snapshots are removed according to retention policy.

### 15. Load Testing (Optional)

Test with larger dataset:

```bash
# Check current sizes
docker compose exec wordpress du -sh /var/www/html/wp-content/uploads
docker compose exec mariadb sh -c 'du -sh /var/lib/mysql'

# Run backup and time it
time docker compose exec backup /backup/scripts/backup.sh
```

## Production Deployment Checklist

Before deploying to production:

- [ ] Backup container builds successfully
- [ ] Restic repository initialized without errors
- [ ] First backup completes successfully
- [ ] Snapshots visible in OCI Console
- [ ] `restic check` passes
- [ ] Test restore completes successfully
- [ ] Verified restored database dump is valid SQL
- [ ] Scheduled backup tested (manually trigger or wait for schedule)
- [ ] `RESTIC_PASSWORD` stored safely (password manager, encrypted file)
- [ ] `BACKUP_CRON` set to desired schedule (default: `30 3 * * *`)
- [ ] `BACKUP_RUN_ON_STARTUP=false` (don't run on every restart)
- [ ] Retention policy configured appropriately
- [ ] Monitoring/alerting set up (optional, see below)

## Monitoring and Alerts (Optional)

### Check Last Backup

Add to your monitoring system:

```bash
# Get last snapshot timestamp
docker compose exec backup restic snapshots --latest 1 --json | jq -r '.[0].time'
```

Alert if last backup is older than 25 hours (missed daily backup).

### Check Repository Health

```bash
# Exit code 0 = healthy, non-zero = problems
docker compose exec backup restic check
echo $?
```

### Check Backup Service Health

```bash
# Check if container is running
docker compose ps backup | grep -q "running"
echo $?
```

## Backup Recovery Testing

**CRITICAL**: Test your backups regularly!

**Suggested schedule**: Test restore monthly.

### Minimal Recovery Test

```bash
# 1. Restore latest backup
docker compose exec backup /backup/scripts/restore.sh latest

# 2. Verify database dump is valid SQL
docker compose exec backup sh -c \
  'gunzip -t /restore/backup/temp/*/database.sql.gz'

# Expected: "OK" or no output (success)

# 3. Check uploads directory
docker compose exec backup find /restore -name "uploads" -type d

# Expected: Path to uploads directory
```

### Full Recovery Test (Separate Environment)

Periodically test full disaster recovery:

1. Spin up a fresh VPS or local VM
2. Clone the repository
3. Configure `.env` with OCI credentials
4. Start the stack: `docker compose up -d`
5. Restore from backup
6. Verify the site works

This ensures your backup/restore process actually works end-to-end.

## Troubleshooting Test Failures

### Build Fails

**Error**: `failed to fetch supercronic`

**Solution**: Check internet connectivity, or update `SUPERCRONIC_URL` to use a mirror.

### "Connection refused" to OCI

**Check**:
1. `OCI_S3_ENDPOINT` format: `https://{namespace}.compat.objectstorage.{region}.oraclecloud.com`
2. Network connectivity: `docker compose exec backup curl -I "$OCI_S3_ENDPOINT"`
3. Firewall rules in VPS provider and OCI

### "Access Denied"

**Check**:
1. Customer Secret Keys are correct (regenerate if needed)
2. Keys are enabled (not deleted in OCI Console)
3. Bucket name is correct

### "Bucket not found"

**Check**:
1. Bucket name matches exactly (case-sensitive)
2. Bucket is in the correct region
3. Bucket exists: OCI Console → Object Storage → Buckets

### Database Connection Failed

**Check**:
1. `MYSQL_PASSWORD` in `.env` matches database
2. MariaDB service is running: `docker compose ps mariadb`
3. Database service is healthy: `docker compose exec mariadb healthcheck.sh --connect`

### Container Exits Immediately

**Check logs**:
```bash
docker compose logs backup
```

**Common causes**:
- Syntax error in scripts (check with `bash -n script.sh`)
- Missing environment variables
- Permission issues

### Slow Backups

**Normal**: First backup is slow (all data uploaded).

**Subsequent backups** should be much faster (incremental).

**If always slow**:
- Check upload bandwidth to OCI
- Consider choosing a closer OCI region
- Check if uploads directory has huge files

## Test Logs Example

Successful test run should look like:

```
[2026-02-18 03:30:15] ==> Starting backup: tour41.net
[2026-02-18 03:30:15] Repository: s3:https://namespace.compat...
[2026-02-18 03:30:15] Checking restic repository...
[2026-02-18 03:30:16] Backing up MariaDB database...
[2026-02-18 03:30:18] Database dump created: 2.4M
[2026-02-18 03:30:18] Generating metadata...
[2026-02-18 03:30:18] Metadata file created
[2026-02-18 03:30:18] Uploading to restic repository...
Files:           2 new,     0 changed,     0 unmodified
Dirs:            1 new,     0 changed,     0 unmodified
Added to the repository: 2.5 MiB
[2026-02-18 03:30:25] Backing up wp-content/uploads...
Files:          45 new,     0 changed,     0 unmodified
Dirs:            5 new,     0 changed,     0 unmodified
Added to the repository: 8.3 MiB
[2026-02-18 03:30:32] Applying retention policy...
[2026-02-18 03:30:32]   Keep daily: 7
[2026-02-18 03:30:32]   Keep weekly: 4
[2026-02-18 03:30:32]   Keep monthly: 6
Applying Policy: keep 7 daily, 4 weekly, 6 monthly snapshots
[2026-02-18 03:30:33] Verifying repository integrity...
using temporary cache in /tmp/restic-check-cache-123456
load indexes
check all packs
check snapshots, trees and blobs
no errors were found
[2026-02-18 03:30:40] ==> Backup completed successfully!
[2026-02-18 03:30:40] Latest snapshots:
ID        Time                 Host         Tags
----------------------------------------------------------------------
a1b2c3d4  2026-02-18 03:30:25  tour41.net   database, automated
e5f6g7h8  2026-02-18 03:30:32  tour41.net   uploads, automated
----------------------------------------------------------------------
2 snapshots
```

## Performance Benchmarks

Typical backup times (will vary based on data size and network):

| Data Size | First Backup | Incremental | Notes |
|-----------|--------------|-------------|-------|
| Small (DB: 10MB, Uploads: 50MB) | 1-2 min | 10-30 sec | Fast |
| Medium (DB: 100MB, Uploads: 500MB) | 3-5 min | 30-60 sec | Typical |
| Large (DB: 1GB, Uploads: 5GB) | 10-20 min | 1-3 min | Depends on changes |

Restore times are similar to first backup (must download all data).

## Cleanup After Testing

```bash
# Remove test restore directories
docker compose exec backup rm -rf /restore/*

# View backup service logs one more time
docker compose logs backup

# If everything looks good, you're ready for production!
```
