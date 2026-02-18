# tour41.net – WordPress on Docker

Production-ready Docker Compose stack for **tour41.net** running behind
[Traefik](https://traefik.io/).

| Service   | Image                                          | Role                        |
|-----------|-------------------------------------------------|-----------------------------|
| wordpress | `ghcr.io/tour41-phil/tour41.net:latest` (custom) | PHP-FPM + theme & plugins   |
| nginx     | `nginx:1.27.4-alpine`                           | HTTP server → php-fpm       |
| mariadb   | `mariadb:11.7.2`                                | Database                    |
| redis     | `redis:7.4.2-alpine`                            | Object cache                |

## Repository layout

```
.
├── docker-compose.yml        # Stack definition
├── .env.example              # Template for environment variables
├── nginx/
│   └── default.conf          # Nginx vhost config
├── wordpress/
│   ├── Dockerfile            # Custom WP image (php-fpm + theme + plugins)
│   ├── themes/tour41/        # Custom theme (baked into image)
│   └── plugins/              # Custom / manual plugins (baked into image)
├── scripts/
│   └── backup.sh             # Database backup script
└── .github/workflows/
    └── build.yml             # CI – build & push image to GHCR
```

## Quick start

```bash
# 1. Clone the repo on your VPS
git clone https://github.com/tour41-phil/tour41.net.git /opt/tour41.net
cd /opt/tour41.net

# 2. Create .env from the template and set real passwords
cp .env.example .env
# Edit .env – at minimum set MYSQL_ROOT_PASSWORD and MYSQL_PASSWORD

# 3. Ensure the external Traefik network exists
docker network inspect homelab_network >/dev/null 2>&1 || \
  echo "ERROR: homelab_network must exist (created by your Traefik stack)"

# 4. Pull images and start
docker compose pull
docker compose up -d
```

## Adding themes & plugins

Custom themes and plugins are **baked into the Docker image** so deploys are
reproducible and nothing needs to be copied to the server manually.

1. Place theme files under `wordpress/themes/<theme-name>/`.
2. Place plugin directories under `wordpress/plugins/<plugin-name>/`.
3. Push to `main` — GitHub Actions will build and push a new image to GHCR.
4. On the VPS, pull the new image and recreate the container:

```bash
docker compose pull wordpress
docker compose up -d wordpress
```

> **Tip:** To install a Redis object-cache drop-in (e.g. from the
> [redis-cache](https://wordpress.org/plugins/redis-cache/) plugin), add its
> files to `wordpress/plugins/redis-cache/` and it will be included in the
> next build.

## Updating image versions

All images are **pinned** in `docker-compose.yml` and the `Dockerfile`.
To upgrade:

1. Update the tag in the relevant file (e.g. `wordpress:6.7.2-php8.3-fpm`).
2. Commit, push to `main`.
3. On the VPS: `docker compose pull && docker compose up -d`.

## Backups

The repository includes a fully automated backup system using **restic** and **Oracle Cloud Object Storage (OCI)**.

### Features

- 🔐 **Encrypted backups** with restic (AES-256)
- ☁️ **Off-site storage** on Oracle Cloud (10GB free tier)
- ⏰ **Automated scheduling** via containerized cron
- 🔄 **Retention policy** with automatic pruning
- 💾 **Full disaster recovery** capability

### Quick Start

1. **Set up Oracle Cloud Object Storage** (free tier)
2. **Configure credentials** in `.env`:
   ```bash
   OCI_S3_ENDPOINT=https://namespace.compat.objectstorage.region.oraclecloud.com
   OCI_BUCKET_NAME=tour41-backups
   AWS_ACCESS_KEY_ID=your_access_key
   AWS_SECRET_ACCESS_KEY=your_secret_key
   RESTIC_PASSWORD=your_encryption_password
   ```
3. **Deploy backup service**:
   ```bash
   docker compose up -d backup
   ```

### Backup Contents

- ✅ MariaDB database (compressed SQL dump)
- ✅ WordPress uploads (wp-content/uploads)
- ✅ Metadata (timestamp, versions, git commit)

### Manual Backup & Restore

```bash
# Run backup now
docker compose exec backup /backup/scripts/backup.sh

# List snapshots
docker compose exec backup restic snapshots

# Restore latest backup
docker compose exec backup /backup/scripts/restore.sh latest
```

### Full Documentation

See **[BACKUP.md](BACKUP.md)** for complete setup guide, restore procedures, troubleshooting, and disaster recovery.

See **[BACKUP-TESTING.md](BACKUP-TESTING.md)** for comprehensive testing procedures before production deployment.

---

## Legacy Backup Script

The old host-based backup script (`scripts/backup.sh`) is still available for manual database dumps, but the containerized restic solution is recommended for production use.

## Traefik integration

The `nginx` service carries Traefik labels that register a router for the
configured `$DOMAIN`. Traefik must already be running and attached to the
`homelab_network` Docker network. TLS is terminated by Traefik using the
configured cert resolver (default: `letsencrypt`).

No changes to the Traefik configuration are required.
