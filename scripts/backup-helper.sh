#!/usr/bin/env bash
# ==========================================================================
# tour41.net – manual backup helper
# ==========================================================================
# Convenience script to trigger manual backup operations
# Run from the project root directory
# ==========================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

show_help() {
    cat <<EOF
Usage: $0 [COMMAND]

Manual backup operations for tour41.net

Commands:
  run              Run backup now
  init             Initialize restic repository only
  list             List all snapshots
  status           Show repository status
  restore          Start interactive restore
  restore-latest   Restore latest snapshot
  check            Verify repository integrity
  stats            Show repository statistics
  logs             View backup service logs
  help             Show this help message

Examples:
  $0 run           # Run backup immediately
  $0 list          # See all available backups
  $0 restore       # Interactive restore process

EOF
}

check_service() {
    if ! docker compose ps backup | grep -q "running"; then
        echo "ERROR: Backup service is not running"
        echo "Start it with: docker compose up -d backup"
        exit 1
    fi
}

case "${1:-help}" in
    run)
        echo "Running backup now..."
        docker compose exec backup /backup/scripts/backup.sh
        ;;
    
    init)
        echo "Initializing restic repository..."
        docker compose exec backup /backup/scripts/backup.sh --init-only
        ;;
    
    list)
        check_service
        echo "Available snapshots:"
        docker compose exec backup restic snapshots
        ;;
    
    status)
        check_service
        echo "Repository statistics:"
        docker compose exec backup restic stats
        echo ""
        echo "Latest snapshots:"
        docker compose exec backup restic snapshots --latest 5
        ;;
    
    restore)
        check_service
        docker compose exec backup /backup/scripts/restore.sh
        ;;
    
    restore-latest)
        check_service
        docker compose exec backup /backup/scripts/restore.sh latest
        ;;
    
    check)
        check_service
        echo "Checking repository integrity..."
        docker compose exec backup restic check --read-data-subset=10%
        ;;
    
    stats)
        check_service
        docker compose exec backup restic stats
        ;;
    
    logs)
        docker compose logs -f backup
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo "ERROR: Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
