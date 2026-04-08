#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-backup}"

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "Fehler: Weder 'docker compose' noch 'docker-compose' gefunden." >&2
    exit 1
  fi
}

check_service() {
  if ! compose_cmd ps --services --status running | grep -Fxq "$SERVICE_NAME"; then
    echo "Fehler: Service '$SERVICE_NAME' läuft nicht." >&2
    exit 1
  fi
}

run_in_backup() {
  compose_cmd exec -T "$SERVICE_NAME" sh -lc "$1"
}

check_service

echo "Prüfe Restic-Repository über Service '$SERVICE_NAME' ..."
echo

STATUS_JSON="$(
run_in_backup '
set -euo pipefail

# Genauso wie im echten Backup-Script:
RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-s3:${OCI_S3_ENDPOINT}/${OCI_BUCKET_NAME}}"
export RESTIC_REPOSITORY
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"
BACKUP_NAME="${BACKUP_NAME:-tour41.net}"
export BACKUP_NAME

all_snapshots_json="$(restic snapshots --json --host "$BACKUP_NAME")"
raw_json="$(restic stats --mode raw-data --json --host "$BACKUP_NAME")"
restore_json="$(restic stats --mode restore-size --json --host "$BACKUP_NAME")"

printf "{"
printf "\"snapshots\":%s," "$all_snapshots_json"
printf "\"raw\":%s," "$raw_json"
printf "\"restore\":%s" "$restore_json"
printf "}"
' 2>/dev/null || true
)"

if [[ -z "${STATUS_JSON}" ]]; then
  echo "Konnte keine Snapshot-Informationen lesen."
  echo "Mögliche Ursachen:"
  echo "  - Repository nicht erreichbar"
  echo "  - Zugangsdaten fehlen oder sind falsch"
  echo "  - Es existieren noch keine Backups für den konfigurierten Host"
  exit 1
fi

python3 - <<'PY' "$STATUS_JSON"
import json
import sys
from datetime import datetime, timezone

data = json.loads(sys.argv[1])

snapshots = data.get("snapshots") or []
raw_stats = data.get("raw") or {}
restore_stats = data.get("restore") or {}

def parse_time(ts):
    if not ts:
        return None
    ts = ts.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def human_age(dt):
    if dt is None:
        return "unbekannt"
    now = datetime.now(timezone.utc)
    diff = now - dt.astimezone(timezone.utc)
    seconds = int(diff.total_seconds())
    if seconds < 0:
        return "in der Zukunft?"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes or not parts:
        parts.append(f"{minutes}m")
    return " ".join(parts)

def human_bytes(num):
    if num is None:
        return "unbekannt"
    value = float(num)
    units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024.0

if not snapshots:
    print("Es wurden keine Backups für den konfigurierten Host gefunden.")
    sys.exit(1)

def snapshot_sort_key(s):
    dt = parse_time(s.get("time"))
    if dt is None:
        return datetime.min.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)

latest = max(snapshots, key=snapshot_sort_key)
latest_time = parse_time(latest.get("time"))

oldest = min(snapshots, key=snapshot_sort_key)
oldest_time = parse_time(oldest.get("time"))

snapshot_id = latest.get("short_id") or latest.get("id") or "unbekannt"
hostname = latest.get("hostname", "unbekannt")
paths = latest.get("paths") or []

# restic stats liefert je nach Version unterschiedliche Felder;
# total_size ist das wichtigste, fallbacks sind absichtlich defensiv.
raw_size = (
    raw_stats.get("total_size")
    or raw_stats.get("total_size_bytes")
    or raw_stats.get("total_blob_size")
)
restore_size = (
    restore_stats.get("total_size")
    or restore_stats.get("total_size_bytes")
    or restore_stats.get("total_blob_size")
)

def human_span(start, end):
    if start is None or end is None:
        return "unbekannt"
    diff = end.astimezone(timezone.utc) - start.astimezone(timezone.utc)
    seconds = int(diff.total_seconds())
    if seconds < 0:
        return "unbekannt"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes or not parts:
        parts.append(f"{minutes}m")
    return " ".join(parts)

print("Backup-Status")
print("=============")
print(f"Letztes Backup:   {latest.get('time', 'unbekannt')}")
print(f"Alter:            {human_age(latest_time)}")
print(f"Ältestes Backup:  {oldest.get('time', 'unbekannt')}")
print(f"Zurück bis:       {human_age(oldest_time)}")
print(f"Backup-Spanne:    {human_span(oldest_time, latest_time)}")
print(f"Neueste ID:       {latest.get('short_id') or latest.get('id') or 'unbekannt'}")
print(f"Älteste ID:       {oldest.get('short_id') or oldest.get('id') or 'unbekannt'}")
print(f"Host:             {latest.get('hostname', 'unbekannt')}")
print(f"Pfade:            {', '.join(latest.get('paths') or []) or 'unbekannt'}")
print()
print("Speichernutzung")
print("================")
print(f"Gesicherte Daten: {human_bytes(raw_size)}")
print(f"Restore-Größe:    {human_bytes(restore_size)}")
print()
print(f"Snapshots im Repo (Host-Filter): {len(snapshots)}")
PY
