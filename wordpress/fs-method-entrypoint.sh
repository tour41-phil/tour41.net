#!/bin/bash
set -e

# Patch wp-config.php to force FS_METHOD=direct if not already present
WP_CONFIG="/var/www/html/wp-config.php"
if [ -f "$WP_CONFIG" ]; then
    grep -q "FS_METHOD" "$WP_CONFIG" || \
    echo "define('FS_METHOD', 'direct');" >> "$WP_CONFIG"
fi

# Ensure correct ownership
chown -R www-data:www-data /var/www/html

exec "$@"
