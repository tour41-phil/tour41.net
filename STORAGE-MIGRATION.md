# Storage Optimization: Moving Uploads to VPS Storage

## Overview

This document outlines the migration strategy to move WordPress uploads from the limited block volume (`/mnt/docker_data`) to the VPS's own storage (`/dev/sda1`), specifically to `/opt/tour41.net-uploads`.

### Storage Layout After Migration

```
/dev/sdb (Block Volume, /mnt/docker_data)
├── db_data/          ← MariaDB database (KEEP HERE - critical)
├── wp_data/          ← WordPress core + theme/plugins (KEEP HERE - critical)
└── redis_data/       ← Redis cache (KEEP HERE - small, important)

/dev/sda1 (VPS Root Filesystem)
├── /opt/tour41.net-uploads/   ← WordPress uploads (MOVE HERE - large, less critical)
```

### Rationale

- **db_data**: Database files must be persistent and backed up regularly - stays on block volume
- **wp_data**: WordPress core and theme files are critical and often small - stays on block volume
- **redis_data**: Cache is small and important for performance - stays on block volume
- **uploads**: Media files are large, non-critical (recoverable from backups), and grow continuously - moved to VPS storage

### Disk Space Saved

Typical WordPress upload directory: **50GB - 500GB+ depending on media library**

By moving uploads to `/dev/sda1`, you free up proportional space on the block volume for other uses or for growth of more critical volumes.

## Pre-Migration Checklist

Before starting the migration:

- [ ] Verify `/opt` exists and has sufficient free space: `df -h /opt`
- [ ] Ensure you have a recent backup
- [ ] Plan for downtime (move will require stopping containers)
- [ ] SSH access to the VPS with sudo privileges

## Migration Steps

### Step 1: Backup Current State

```bash
# On the VPS
cd /mnt/docker_data
sudo tar czf /tmp/uploads-backup-$(date +%Y%m%d).tar.gz wp_data/wp-content/uploads/
```

### Step 2: Create Target Directory

```bash
# On the VPS
sudo mkdir -p /opt/tour41.net-uploads
sudo chown 33:33 /opt/tour41.net-uploads  # www-data:www-data
sudo chmod 0755 /opt/tour41.net-uploads
```

Verify the directory was created:
```bash
ls -ld /opt/tour41.net-uploads
```

Expected output:
```
drwxr-xr-x  2 www-data www-data  4096 Feb 18 10:00 /opt/tour41.net-uploads
```

### Step 3: Update docker-compose.yml

The docker-compose.yml has already been updated in this commit with the following changes:

**WordPress service**:
```yaml
volumes:
  - wp_data:/var/www/html
  - /opt/tour41.net-uploads:/var/www/html/wp-content/uploads  # NEW
  - ${BACKUP_HOST_PATH:-.}/updraft:/backups
```

**Nginx service**:
```yaml
volumes:
  - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
  - wp_data:/var/www/html:ro
  - /opt/tour41.net-uploads:/var/www/html/wp-content/uploads:ro  # NEW
```

**Backup service**:
```yaml
volumes:
  - wp_data:/wp_data:ro
  - db_data:/db_data:ro
  - /opt/tour41.net-uploads:/opt/tour41.net-uploads:ro  # NEW
  - ./.git:/repo/.git:ro
```

### Step 4: Stop Containers

```bash
# On the VPS, in the tour41.net directory
cd /path/to/tour41.net
docker compose down
```

### Step 5: Migrate Existing Uploads

If you have existing uploads in the wp_data volume, you need to copy them:

```bash
# On the VPS, as root or with sudo

# Create a temporary container to access the wp_data volume
docker run --rm -v wp_data:/wp_data -v /opt/tour41.net-uploads:/target alpine \
  sh -c "cp -r /wp_data/wp-content/uploads/* /target/ 2>/dev/null || true && \
         chown -R 33:33 /target"
```

This copies any existing uploads from the volume to the new directory.

**Note**: If this is a fresh installation with no existing uploads, you can skip this step.

### Step 6: Verify Migration

```bash
# List contents of new uploads directory
ls -la /opt/tour41.net-uploads/

# Check disk usage
du -sh /opt/tour41.net-uploads/

# Verify permissions
stat /opt/tour41.net-uploads/
```

### Step 7: Start Containers

```bash
# On the VPS, in the tour41.net directory
docker compose up -d
```

### Step 8: Verify WordPress Access

1. Visit the WordPress site: `https://tour41.net`
2. Log in to WordPress admin
3. Go to **Media Library** and verify images load correctly
4. Upload a test image to verify the new path works
5. Check the container logs for any errors:

```bash
docker compose logs -f wordpress nginx
```

### Step 9: Clean Up (Optional)

After verifying everything works, you can remove the old uploads from the volume:

```bash
# On the VPS, as root or with sudo

# Create a temporary container and delete uploads from wp_data volume
docker run --rm -v wp_data:/wp_data alpine \
  rm -rf /wp_data/wp-content/uploads

# This frees up space on the block volume
```

**Note**: Only do this after Step 8 verification is complete.

## Updating Backup Configuration

The backup container now includes `/opt/tour41.net-uploads` in its mount points. Ensure your backup script includes this path:

```bash
# In your backup script, verify these paths are backed up:
# - /wp_data            (WordPress core, themes, plugins)
# - /db_data            (Database)
# - /opt/tour41.net-uploads  (Uploads - if using restic/script backup)
```

If using restic backups, verify the backup includes:
```bash
restic snapshots | grep tour41.net
restic ls <snapshot-id> | grep "opt/tour41.net-uploads"
```

## Rollback Procedure

If you need to rollback to the old configuration:

### Step 1: Stop Containers

```bash
docker compose down
```

### Step 2: Revert docker-compose.yml

```bash
# Remove the mount points for uploads
git checkout docker-compose.yml
# Or manually remove these lines:
# - /opt/tour41.net-uploads:/var/www/html/wp-content/uploads
```

### Step 3: Copy Uploads Back to Volume

```bash
docker run --rm -v wp_data:/wp_data -v /opt/tour41.net-uploads:/source alpine \
  sh -c "cp -r /source/* /wp_data/wp-content/uploads/ 2>/dev/null || true && \
         chown -R 33:33 /wp_data/wp-content/uploads"
```

### Step 4: Start Containers

```bash
docker compose up -d
```

## Performance Considerations

### Before Migration
- **Uploads volume**: Slower (network-attached block storage)
- **All I/O**: Through Docker volume layer

### After Migration
- **Uploads**: Faster (local VPS storage, direct filesystem mount)
- **Database**: Still on block volume (appropriate for transactional I/O)
- **WordPress core**: Still on block volume (rarely changes)

### Expected Benefits
- Faster media uploads and downloads
- Faster image serving (nginx directly reads from local filesystem)
- Better separation of concerns (critical data vs. media assets)
- More efficient use of limited block volume space

## Monitoring Disk Space

After migration, monitor both disks:

```bash
# Monitor block volume (should now have more free space)
watch -n 60 'df -h /mnt/docker_data && echo && du -sh /mnt/docker_data/*'

# Monitor VPS root filesystem
watch -n 60 'df -h / && echo && du -sh /opt/tour41.net-uploads'

# Alert if VPS root filesystem gets low
df -h / | tail -1 | awk '{print $5}' | sed 's/%//' | awk '{if ($1 > 80) print "WARNING: Disk 80% full"}'
```

## Troubleshooting

### Issue: WordPress can't upload images after migration

**Check**:
```bash
# Verify directory exists
ls -ld /opt/tour41.net-uploads

# Verify permissions are www-data
stat /opt/tour41.net-uploads | grep Uid

# Check WordPress error log
docker compose exec wordpress tail -f /var/www/html/wp-content/debug.log
```

**Fix**: Ensure directory is writable by www-data:
```bash
sudo chown 33:33 /opt/tour41.net-uploads
sudo chmod 0755 /opt/tour41.net-uploads
```

### Issue: Images don't display after migration

**Check**:
```bash
# Verify uploads directory is mounted in containers
docker compose exec nginx ls -la /var/www/html/wp-content/uploads

# Check nginx can read the files
docker compose exec nginx stat /var/www/html/wp-content/uploads
```

**Fix**: Ensure nginx has read access (it does - directory is `:ro` mounted)

### Issue: Backup doesn't include uploads

**Check**:
```bash
# Verify backup container can see uploads
docker compose exec backup ls -la /opt/tour41.net-uploads
```

**Fix**: Ensure `/opt/tour41.net-uploads` is mounted in backup container volume config

## Questions?

Refer to the main README.md for general troubleshooting, or check Docker logs:

```bash
docker compose logs backup  # Backup issues
docker compose logs wordpress  # Upload issues
docker compose logs nginx  # Serving issues
```
