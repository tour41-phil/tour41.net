# ---------------------------------------------------------------------------
# Custom WordPress image – php-fpm variant with theme + plugins baked in
# ---------------------------------------------------------------------------
# Pin to a specific minor version for reproducibility.  Bump deliberately and
# rebuild through CI when upgrading WordPress.
FROM wordpress:6.9.1-php8.3-fpm

# ── Redis PHP extension (required by object-cache drop-in) ────────────────
RUN pecl install redis \
    && docker-php-ext-enable redis

# ── Custom theme ──────────────────────────────────────────────────────────
COPY themes/tour41/ /usr/src/wordpress/wp-content/themes/tour41/

# ── Manual / custom plugins ──────────────────────────────────────────────
# Each sub-directory under plugins/ becomes a WP plugin.
# Place plugin folders here; they will be copied into the image at build time.
COPY plugins/ /usr/src/wordpress/wp-content/plugins/

# The upstream entrypoint copies /usr/src/wordpress → /var/www/html on first
# run, so everything we put in /usr/src/wordpress is automatically deployed.
