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

A database backup script is included:

```bash
# Run manually
./scripts/backup.sh

# Or schedule via cron (daily at 03:00)
echo "0 3 * * * /opt/tour41.net/scripts/backup.sh /opt/tour41.net/backups" \
  | crontab -
```

Backups older than 30 days are automatically pruned. The `wp_data` volume
(uploads, etc.) should also be backed up – consider a volume snapshot or
`rsync` from the Docker volume mount point.

## Traefik integration

The `nginx` service carries Traefik labels that register a router for the
configured `$DOMAIN`. Traefik must already be running and attached to the
`homelab_network` Docker network. TLS is terminated by Traefik using the
configured cert resolver (default: `letsencrypt`).

No changes to the Traefik configuration are required.
