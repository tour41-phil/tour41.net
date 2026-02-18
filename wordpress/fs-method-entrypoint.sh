#!/bin/bash
set -e


# Patch wp-config.php to enforce trust chain, memory, and FS settings if not already present
WP_CONFIG="/var/www/html/wp-config.php"
if [ -f "$WP_CONFIG" ]; then
    # Ensure HTTPS is recognized behind reverse proxies
    grep -q "X_FORWARDED_PROTO" "$WP_CONFIG" || \
    echo -e "if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { \n    \$_SERVER['HTTPS'] = 'on';\n}" >> "$WP_CONFIG"

    # Set memory limits for heavy plugins
    grep -q "WP_MEMORY_LIMIT" "$WP_CONFIG" || \
    echo "define('WP_MEMORY_LIMIT', '256M');" >> "$WP_CONFIG"
    grep -q "WP_MAX_MEMORY_LIMIT" "$WP_CONFIG" || \
    echo "define('WP_MAX_MEMORY_LIMIT', '512M');" >> "$WP_CONFIG"

    # Force direct filesystem access
    grep -q "FS_METHOD" "$WP_CONFIG" || \
    echo "define('FS_METHOD', 'direct');" >> "$WP_CONFIG"

    # Set a dedicated temp directory
    grep -q "WP_TEMP_DIR" "$WP_CONFIG" || \
    echo "define('WP_TEMP_DIR', dirname(__FILE__) . '/wp-content/temp/');" >> "$WP_CONFIG"
fi

# Ensure correct ownership
chown -R www-data:www-data /var/www/html

exec "$@"
