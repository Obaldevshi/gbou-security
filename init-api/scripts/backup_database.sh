#!/bin/sh
set -eu

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL is required" >&2
  exit 1
fi

BACKUP_DIR="${BACKUP_DIR:-/app/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
mkdir -p "$BACKUP_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="$BACKUP_DIR/gbou_security_$STAMP.dump"
pg_dump --format=custom --no-owner --no-privileges --file="$TARGET" "$DATABASE_URL"
find "$BACKUP_DIR" -type f -name 'gbou_security_*.dump' -mtime "+$BACKUP_RETENTION_DAYS" -delete
echo "$TARGET"
