#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-backup}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Fehler: docker ist nicht installiert oder nicht im PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Fehler: python3 ist nicht installiert oder nicht im PATH." >&2
  exit 1
fi

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

if ! compose_cmd ps --status running "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "Fehler: Service '$SERVICE_NAME' läuft nicht." >&2
  exit 1
fi

run_in_backup() {
  compose_cmd exec -T "$SERVICE_NAME" sh -lc "$1"
}

echo "Prüfe Restic-Repository über Service '$SERVICE_NAME' ..."
echo

SNAPSHOTS_JSON="$(run_in_backup 'restic snapshots --json' 2>/dev/null || true)"
if [[ -z "${SNAPSHOTS_JSON}" ]]; then
  echo "Konnte keine Snapshot-Informationen lesen."
  echo "Mögliche Ursachen:"
  echo "  - Repository nicht erreichbar"
  echo "  - Zugangsdaten fehlen oder sind falsch"
  echo "  - Es existieren noch keine Backups"
  exit 1
fi

RAW_STATS_JSON="$(run_in_backup 'restic stats --mode raw-data --json' 2>/dev/null || true)"
RESTORE_STATS_JSON="$(run_in_backup 'restic stats --mode restore-size --json' 2>/dev/null || true)"

python3 - <<'PY' "$SNAPSHOTS_JSON" "$RAW_STATS_JSON" "$RESTORE_STATS_JSON"
import json
import sys
from datetime import datetime, timezone

snapshots_json = sys.argv[1]
raw_stats_json = sys.argv[2] if len(sys.argv) > 2 else ""
restore_stats_json = sys.argv[3] if len(sys.argv) > 3 else ""

def parse_json(text, fallback=None):
    if not text.strip():
        return fallback
    try:
        return json.loads(text)
    except Exception:
        return fallback

def parse_time(ts):
    if not ts:
        return None
    ts = ts.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(ts)
    except Exception:
        return None

def human_bytes(num):
    if num is None:
        return "unbekannt"
    units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
    value = float(num)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024.0

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

snapshots = parse_json(snapshots_json, fallback=[])
if not isinstance(snapshots, list) or not snapshots:
    print("Es wurden keine Backups gefunden.")
    sys.exit(1)

latest = max(snapshots, key=lambda s: s.get("time", ""))
latest_time = parse_time(latest.get("time"))

raw_stats = parse_json(raw_stats_json, fallback={}) or {}
restore_stats = parse_json(restore_stats_json, fallback={}) or {}

raw_size = raw_stats.get("total_size")
restore_size = restore_stats.get("total_size")

hostname = latest.get("hostname", "unbekannt")
paths = latest.get("paths") or []
short_id = latest.get("short_id") or latest.get("id") or "unbekannt"

print("Backup-Status")
print("=============")
print(f"Letztes Backup:   {latest.get('time', 'unbekannt')}")
print(f"Alter:            {human_age(latest_time)}")
print(f"Snapshot-ID:      {short_id}")
print(f"Host:             {hostname}")
print(f"Pfade:            {', '.join(paths) if paths else 'unbekannt'}")
print()
print("Speichernutzung")
print("================")
print(f"Gesicherte Daten: {human_bytes(raw_size)}")
print(f"Restore-Größe:    {human_bytes(restore_size)}")
print()
print(f"Anzahl Snapshots: {len(snapshots)}")
PY
