#!/bin/bash
set -e



# Ensure required directories exist and are owned by www-data
for dir in /var/www/html/wp-content/upgrade /var/www/html/wp-content/temp; do
    mkdir -p "$dir"
    chown -R www-data:www-data "$dir"
    chmod 775 "$dir"
done

# Patch wp-config.php to enforce trust chain, memory, and FS settings if not already present
WP_CONFIG="/var/www/html/wp-config.php"
if [ -f "$WP_CONFIG" ]; then
    # Only append if not already present (prevents duplicate warnings)
    grep -q "X_FORWARDED_PROTO" "$WP_CONFIG" || \
    echo -e "if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { \n    \$_SERVER['HTTPS'] = 'on';\n}" >> "$WP_CONFIG"

    grep -q "define('WP_MEMORY_LIMIT'" "$WP_CONFIG" || echo "define('WP_MEMORY_LIMIT', '256M');" >> "$WP_CONFIG"
    grep -q "define('WP_MAX_MEMORY_LIMIT'" "$WP_CONFIG" || echo "define('WP_MAX_MEMORY_LIMIT', '512M');" >> "$WP_CONFIG"
    grep -q "define('FS_METHOD'" "$WP_CONFIG" || echo "define('FS_METHOD', 'direct');" >> "$WP_CONFIG"
    grep -q "define('WP_TEMP_DIR'" "$WP_CONFIG" || echo "define('WP_TEMP_DIR', dirname(__FILE__) . '/wp-content/temp/');" >> "$WP_CONFIG"
fi

# Ensure correct ownership
chown -R www-data:www-data /var/www/html

exec "$@"
