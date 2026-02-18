# Copilot Instructions for tour41.net

## Project Overview

**tour41.net** is a production-ready WordPress site running on Docker with a custom theme and plugin architecture. This is a Docker Compose stack designed for deployment behind Traefik reverse proxy on a homelab network.

### Key Technologies
- **WordPress**: 6.7.2 with PHP 8.3 (php-fpm variant)
- **Web Server**: Nginx 1.27.4-alpine (proxies to php-fpm)
- **Database**: MariaDB 11.7.2
- **Cache**: Redis 7.4.2-alpine (object cache)
- **Reverse Proxy**: Traefik (external, not in this repo)
- **Container Registry**: GitHub Container Registry (ghcr.io)

## Repository Structure

```
.
├── docker-compose.yml          # Main stack orchestration
├── .env.example                # Environment variable template (NEVER commit .env)
├── nginx/
│   └── default.conf            # Nginx configuration for WordPress
├── wordpress/
│   ├── Dockerfile              # Custom WP image with theme + plugins baked in
│   ├── themes/tour41/          # Custom theme (immutable, baked into image)
│   │   ├── style.css           # Theme metadata and styles
│   │   ├── functions.php       # Theme setup and hooks
│   │   └── index.php           # Main template file
│   └── plugins/                # Custom/manual plugins (baked into image)
│       └── .gitkeep            # Placeholder (no plugins yet)
├── scripts/
│   └── backup.sh               # Database backup utility
└── .github/workflows/
    └── build.yml               # CI: builds and pushes Docker image to GHCR
```

## Architecture & Design Principles

### Immutable Infrastructure
- **Themes and plugins are baked into the Docker image** at build time
- Nothing is uploaded to the server manually or via WordPress admin
- Deploys are reproducible and version-controlled
- The custom WordPress image is built in CI and stored in GitHub Container Registry

### Service Communication
```
Internet → Traefik (TLS termination) → Nginx (port 80) → WordPress (php-fpm:9000)
                                                            ↓
                                                        MariaDB + Redis
```

### Networks
- `backend`: Internal network for WordPress, MariaDB, Redis, Nginx
- `homelab_network`: External network (must exist) for Traefik integration

### Volumes
- `db_data`: MariaDB database files
- `wp_data`: WordPress files (wp-content/uploads, etc.)
- `redis_data`: Redis persistence

## Development Workflow

### Making Code Changes

1. **Theme Changes**: Edit files in `wordpress/themes/tour41/`
2. **Plugin Changes**: Add plugin directories under `wordpress/plugins/`
3. **Nginx Config**: Edit `nginx/default.conf`
4. **Stack Changes**: Edit `docker-compose.yml`

### Testing Changes Locally

#### Build the Custom WordPress Image
```bash
cd wordpress
docker build -t test-tour41-wp:local .
```

**Expected outcome**: Build completes successfully with Redis extension installed and theme/plugins copied.

#### Test with Docker Compose (requires external dependencies)
```bash
# Note: This requires homelab_network and Traefik to exist
# For local testing without full stack, use docker build only
docker compose build wordpress
```

**Note**: Full `docker compose up` testing requires:
- `homelab_network` Docker network to exist
- Traefik running and attached to that network
- `.env` file with database credentials

These are typically NOT available in CI/sandboxed environments, so rely on Docker build verification only.

## CI/CD Pipeline

### GitHub Actions Workflow

**File**: `.github/workflows/build.yml`

**Triggers**:
- Push to `main` branch with changes to `wordpress/**`
- Manual dispatch via GitHub Actions UI

**What it does**:
1. Checks out the repository
2. Logs into GitHub Container Registry (GHCR)
3. Builds the custom WordPress image from `wordpress/Dockerfile`
4. Tags the image with:
   - `ghcr.io/tour41-phil/tour41.net:latest` (if main branch)
   - `ghcr.io/tour41-phil/tour41.net:sha-<commit-sha>`
5. Pushes both tags to GHCR

**Permissions Required**:
- `contents: read` - to checkout code
- `packages: write` - to push to GHCR

### Verifying CI Success

```bash
# Check recent workflow runs
gh run list --workflow=build.yml --limit 5

# View logs of a specific run
gh run view <run-id> --log
```

**Expected CI behavior**:
- Changes to `wordpress/**` trigger a build
- Changes to other files do NOT trigger the workflow
- Build completes in ~1-2 minutes
- Image is pushed to `ghcr.io/tour41-phil/tour41.net`

## Deployment (Production/VPS)

This repository is designed for deployment on a VPS or homelab server. The deployment process is documented in `README.md` but here's the summary:

1. Pull the latest image: `docker compose pull wordpress`
2. Recreate the container: `docker compose up -d wordpress`

**Important**: Deployment happens on the production server, not in CI. The CI pipeline only builds and publishes the image.

## Common Tasks

### Adding a New Plugin

1. Create directory: `mkdir -p wordpress/plugins/<plugin-name>`
2. Add plugin files to that directory
3. Commit and push to `main`
4. CI will build and push a new image
5. On production: `docker compose pull wordpress && docker compose up -d wordpress`

### Adding Theme Templates

1. Add new PHP template file to `wordpress/themes/tour41/` (e.g., `single.php`, `page.php`, `header.php`, `footer.php`)
2. Follow WordPress template hierarchy conventions
3. Commit and push to trigger CI build

### Updating WordPress Core Version

1. Edit `wordpress/Dockerfile`
2. Change `FROM wordpress:6.7.2-php8.3-fpm` to desired version
3. Test build locally: `cd wordpress && docker build .`
4. Commit and push to `main`

### Updating Service Versions

1. Edit `docker-compose.yml`
2. Update image tags for `nginx`, `mariadb`, or `redis`
3. Pin to specific versions (never use `latest`)
4. Test locally if possible
5. Deploy on production: `docker compose pull && docker compose up -d`

## Code Style & Conventions

### PHP (WordPress Theme)

- **WordPress Coding Standards**: Follow [WordPress PHP Coding Standards](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/)
- **Security**: Always use `ABSPATH` check at the top of PHP files
- **Escaping**: Use proper escaping functions (`esc_html`, `esc_url`, `esc_attr`, `wp_kses`)
- **Sanitization**: Sanitize all user inputs
- **Namespacing**: Theme functions prefixed with `tour41_`
- **Documentation**: Use PHPDoc blocks for functions

Example from existing code:
```php
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

function tour41_setup() {
    // Theme setup code
}
add_action( 'after_setup_theme', 'tour41_setup' );
```

### Docker & Configuration

- **Pin versions**: All Docker images use specific version tags (never `latest`)
- **Environment variables**: Use `${VAR:-default}` syntax in `docker-compose.yml`
- **Comments**: Use clear section headers in configuration files
- **Health checks**: All services have health checks defined

### Git Workflow

- **Never commit**: `.env` files (use `.env.example` as template)
- **Never commit**: Build artifacts, `node_modules`, `vendor` directories
- **Gitignore**: Already configured for common WordPress and Docker artifacts

## Troubleshooting

### Docker Build Fails

**Problem**: `pecl install redis` fails or times out

**Solution**: This is usually a network or package mirror issue. The Redis PHP extension is required for WordPress object caching. If the build fails:
1. Check the build logs for the specific error
2. The redis extension is installed via PECL in the Dockerfile
3. Verify the base WordPress image version is still available

**Problem**: `COPY themes/tour41/` or `COPY plugins/` fails

**Solution**: Ensure the directories exist. The theme must have at least `style.css`, `functions.php`, and `index.php`. The plugins directory can be empty (has `.gitkeep`).

### CI Build Not Triggering

**Problem**: Pushed changes but CI didn't run

**Check**:
1. Did you push to `main` branch?
2. Did your changes include files under `wordpress/**`?
3. Check `.github/workflows/build.yml` path filters

**Solution**: The workflow only triggers on changes to `wordpress/**`. Changes to other files won't trigger a build (this is intentional).

### Local Testing Limitations

**Problem**: Can't run full `docker compose up` locally

**Reason**: The stack requires:
- External Docker network `homelab_network` 
- Traefik running and configured
- `.env` file with credentials

**Solution**: For local development testing:
1. Test Docker builds only: `cd wordpress && docker build .`
2. Don't attempt to run the full stack in CI or sandboxed environments
3. Verify syntax and structure instead of runtime testing

### PHP Linting

**No automated linting currently configured**. If you need to add PHP linting:

1. Consider adding `composer.json` with WordPress Coding Standards:
```bash
composer require --dev wp-coding-standards/wpcs
```

2. Add GitHub Actions workflow to run PHPCS

**Current state**: No linting tools configured. Code review relies on manual inspection and CI build success.

## Security Considerations

### Secrets Management

- **Database passwords**: Stored in `.env` (never committed)
- **GITHUB_TOKEN**: Automatically provided by GitHub Actions
- **No hardcoded secrets**: All sensitive values use environment variables

### WordPress Security

- **Object cache**: Redis object cache configured (improves performance, reduces DB load)
- **File uploads**: Max 64MB configured in Nginx
- **Dotfiles**: Nginx blocks access to dotfiles except `.well-known`
- **TLS**: Handled by Traefik (not in this stack)

### Docker Security

- **Non-root**: WordPress image runs as www-data user
- **Read-only volumes**: Nginx config and wp_data mounted as `:ro` where appropriate
- **Health checks**: All services have health checks to detect issues
- **Restart policy**: `unless-stopped` for automatic recovery

## Environment Variables

Required in `.env` (never commit this file):

```bash
# Domain name
DOMAIN=tour41.net

# Database credentials (CHANGE THESE!)
# These MYSQL_* variables are used by both MariaDB service and mapped
# to WORDPRESS_DB_* variables for the WordPress container
MYSQL_ROOT_PASSWORD=strong_random_password
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=another_strong_password

# WordPress settings
WP_TABLE_PREFIX=wp_

# Traefik settings
CERT_RESOLVER=letsencrypt

# Optional: Override default image
# WP_IMAGE=ghcr.io/tour41-phil/tour41.net:sha-abc1234
```

## Testing Checklist

When making changes, verify:

- [ ] Docker build completes: `cd wordpress && docker build .`
- [ ] No syntax errors in PHP files
- [ ] No syntax errors in Nginx config (can test with `nginx -t` in container)
- [ ] `.env.example` is up-to-date if you added new variables
- [ ] Changes to `wordpress/**` will trigger CI build
- [ ] No secrets or credentials committed
- [ ] `.gitignore` prevents committing sensitive files

## Useful Commands Reference

```bash
# Build custom WordPress image locally
cd wordpress && docker build -t test-tour41-wp:local .

# Check Docker Compose syntax
docker compose config

# View generated compose configuration with variables
docker compose config --resolve-image-digests

# Test nginx configuration (requires running container)
docker compose exec nginx nginx -t

# View logs
docker compose logs -f wordpress
docker compose logs -f nginx

# Database backup (on production server)
./scripts/backup.sh

# Check PHP syntax
find wordpress/themes/tour41 -name "*.php" -exec php -l {} \;
```

## Important Notes for AI Agents

1. **Don't try to run the full stack**: The stack requires Traefik and homelab_network which won't exist in CI/sandboxed environments. Only test Docker builds.

2. **Theme files are immutable**: The theme is baked into the image. Changes require rebuilding and redeploying the image.

3. **No package managers in theme**: The theme is vanilla PHP/HTML/CSS - no npm, webpack, or build steps.

4. **WordPress admin not used for code**: All code changes happen via git, not WordPress admin.

5. **Database not in version control**: Only the schema/structure is defined. Backups are done separately.

6. **Minimal theme**: This is a very simple starter theme. It may be extended with more templates over time.

## Getting Help

- **WordPress Documentation**: https://developer.wordpress.org/
- **Docker Compose Reference**: https://docs.docker.com/compose/
- **Nginx Configuration**: https://nginx.org/en/docs/
- **Repository Issues**: https://github.com/tour41-phil/tour41.net/issues

## Stored Repository Memories

The following facts have been verified and stored for this repository:

1. **Project Structure**: WordPress-on-Docker with php-fpm, Nginx, MariaDB, Redis behind Traefik
2. **CI/CD**: Custom WordPress image built by `.github/workflows/build.yml` and pushed to GHCR on changes to `wordpress/**`
3. **Deployment**: Production deployment happens on VPS by pulling new images, not via CI

These facts should be re-verified if the repository structure changes significantly.
