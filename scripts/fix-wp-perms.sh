#!/bin/bash
# Fix permissions for WordPress Docker volume
# Usage: ./scripts/fix-wp-perms.sh [container_name]

CONTAINER="${1:-wordpress}"
WP_PATH="/var/www/html"

# Ensure www-data owns all relevant files and directories

docker exec -it "$CONTAINER" chown -R www-data:www-data "$WP_PATH/wp-content"
docker exec -it "$CONTAINER" chown -R www-data:www-data "$WP_PATH/wp-content/upgrade"
docker exec -it "$CONTAINER" chown -R www-data:www-data "$WP_PATH/wp-content/temp"

docker exec -it "$CONTAINER" chmod 775 "$WP_PATH/wp-content/upgrade"
docker exec -it "$CONTAINER" chmod 775 "$WP_PATH/wp-content/temp"

echo "Permissions fixed for $CONTAINER at $WP_PATH/wp-content, upgrade, and temp."
