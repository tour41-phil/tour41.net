# ---------------------------------------------------------------------------
# Patched PHP source image
# ---------------------------------------------------------------------------
FROM php:8.5.12-fpm AS php8512

# ---------------------------------------------------------------------------
# Custom WordPress image – php-fpm variant with theme + plugins baked in
# ---------------------------------------------------------------------------
# Pin to a specific minor version for reproducibility.  Bump deliberately and
# rebuild through CI when upgrading WordPress.
FROM wordpress:7.1.3-php8.5-fpm

# Make patched PHP available for the conditional upgrade.
COPY --from=php8512 /usr/local/ /tmp/php8512/

# Upgrade PHP only when the base image contains exactly 8.5.11.
RUN set -eux; \
    current="$(php -r 'echo PHP_VERSION;')"; \
    if [ "$current" = "8.5.11" ]; then \
        echo "PHP $current detected; upgrading to 8.5.12"; \
        test "$( /tmp/php8512/bin/php -r 'echo PHP_VERSION;' )" = "8.5.12"; \
        cp -a /tmp/php8512/. /usr/local/; \
        test "$(php -r 'echo PHP_VERSION;')" = "8.5.12"; \
        echo "PHP successfully upgraded to 8.5.12"; \
    else \
        echo "PHP $current detected; skipping conditional upgrade"; \
    fi; \
    rm -rf /tmp/php8512

# Tools needed to unpack theme/plugin zip archives + Redis PHP
# extension (required by object-cache drop-in) + GZip runtime (for GEOIP) + MariaDB
# client (for database import/export) + image revision marker.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip zlib1g mariadb-client ca-certificates curl build-essential autoconf pkg-config; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL https://github.com/phpredis/phpredis/archive/refs/tags/6.3.0.tar.gz -o /tmp/phpredis.tar.gz; \
    mkdir -p /tmp/phpredis; \
    tar -xzf /tmp/phpredis.tar.gz -C /tmp/phpredis --strip-components=1; \
    cd /tmp/phpredis; \
    phpize; \
    ./configure; \
    make -j"$(nproc)"; \
    make install; \
    docker-php-ext-enable redis; \
    rm -rf /tmp/phpredis /tmp/phpredis.tar.gz; \
    date -u +%Y-%m-%dT%H:%M:%SZ > /usr/src/wordpress/.tour41-baked-revision

# ── PHP Optimization ──────────────────────────────────────────────────────
# Configure memory and execution limits for WordPress operations (Demo Import,
# Elementor, etc.) and ensure GZip compatibility for GEOIP databases.
RUN set -eux; \
    { \
        echo 'memory_limit = 512M'; \
        echo 'post_max_size = 256M'; \
        echo 'upload_max_filesize = 256M'; \
        echo 'max_execution_time = 3000'; \
        echo 'max_input_time = 3000'; \
        echo 'max_input_vars = 3000'; \
    } > /usr/local/etc/php/conf.d/uploads.ini

# ── WP-CLI Installation ────────────────────────────────────────────────────
# Required for search-replace functionality in legacy backup restoration.
# Note: Must use --allow-root flag when running as www-data user.
RUN set -eux; \
    curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
    chmod +x /usr/local/bin/wp; \
    /usr/local/bin/wp --info

# ── Custom theme ──────────────────────────────────────────────────────────
# Supports either directories OR .zip archives under wordpress/themes/.
COPY themes/ /opt/tour41/themes-src/

# ── Manual / custom plugins ──────────────────────────────────────────────
# Each sub-directory under plugins/ becomes a WP plugin.
# Place plugin folders here; they will be copied into the image at build time.
# Supports either directories OR .zip archives under wordpress/plugins/.
COPY plugins/ /opt/tour41/plugins-src/

RUN set -eux; \
        install_from_src_dir() { \
            src_dir="$1"; \
            dest_dir="$2"; \
            mkdir -p "$dest_dir"; \
            if [ ! -d "$src_dir" ]; then \
                return 0; \
            fi; \
            for item in "$src_dir"/*; do \
                [ -e "$item" ] || continue; \
                base="$(basename "$item")"; \
                case "$base" in \
                    .DS_Store|.gitkeep) \
                        continue \
                        ;; \
                esac; \
                if [ -d "$item" ]; then \
                    # Plain directory: copy as-is.
                    rm -rf "$dest_dir/$base"; \
                    cp -a "$item" "$dest_dir/$base"; \
                    continue; \
                fi; \
                case "$base" in \
                    *.zip) \
                        # Zip archive: extract safely.
                        name="${base%.zip}"; \
                        tmp="$(mktemp -d)"; \
                        unzip -q "$item" -d "$tmp"; \
                        # If the zip contains exactly one meaningful top-level dir, use it.
                        # (Ignore macOS metadata like __MACOSX and dotfiles.)
                        top_dir="$(find "$tmp" \
                            -mindepth 1 -maxdepth 1 \
                            -type d ! -name '__MACOSX' ! -name '.*' \
                            -print | head -n 1)"; \
                        top_count="$(find "$tmp" \
                            -mindepth 1 -maxdepth 1 \
                            ! -name '__MACOSX' ! -name '.*' \
                            -print | wc -l | tr -d ' ')"; \
                        if [ "$top_count" = "1" ] && [ -n "$top_dir" ]; then \
                            top_name="$(basename "$top_dir")"; \
                            rm -rf "$dest_dir/$top_name"; \
                            cp -a "$top_dir" "$dest_dir/$top_name"; \
                        else \
                            # Otherwise, extract into a folder named after the zip.
                            rm -rf "$dest_dir/$name"; \
                            mkdir -p "$dest_dir/$name"; \
                            find "$tmp" \
                                -mindepth 1 -maxdepth 1 \
                                ! -name '__MACOSX' ! -name '.*' \
                                -exec cp -a {} "$dest_dir/$name/" \;; \
                        fi; \
                        rm -rf "$tmp"; \
                        ;; \
                    *) \
                        # Ignore other stray files (e.g., index.php placeholders).
                        ;; \
                esac; \
            done; \
        }; \
        install_from_src_dir /opt/tour41/themes-src /usr/src/wordpress/wp-content/themes; \
        install_from_src_dir /opt/tour41/plugins-src /usr/src/wordpress/wp-content/plugins; \
        rm -rf /opt/tour41/themes-src /opt/tour41/plugins-src

# The upstream entrypoint copies /usr/src/wordpress → /var/www/html on first
# run, so everything we put in /usr/src/wordpress is automatically deployed.

# Wrapper entrypoint: when /var/www/html is a persistent volume, upstream only
# seeds files on first run. This ensures core + baked-in plugins/themes are
# refreshed after an image update without deleting user-installed additions.
COPY tour41-entrypoint.sh /usr/local/bin/tour41-entrypoint.sh
COPY fs-method-entrypoint.sh /usr/local/bin/fs-method-entrypoint.sh
RUN chmod +x /usr/local/bin/tour41-entrypoint.sh /usr/local/bin/fs-method-entrypoint.sh

# Legacy backup restoration script for UpdraftPlus backups
# Allows importing database and uploads from UpdraftPlus archives
COPY legacy-restore.sh /usr/local/bin/legacy-restore.sh
RUN chmod +x /usr/local/bin/legacy-restore.sh

ENTRYPOINT ["fs-method-entrypoint.sh", "tour41-entrypoint.sh"]

# Be explicit: run php-fpm by default.
CMD ["php-fpm"]
