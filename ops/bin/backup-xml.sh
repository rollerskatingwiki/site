#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DEST_DIR="${BASE}/backups/xml"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/wiki-full-${TS}.xml"

mkdir -p "${DEST_DIR}"

sudo -u wiki php "${BASE}/app/current/maintenance/run.php" dumpBackup --full > "${DEST_FILE}"

echo "wrote ${DEST_FILE}"

RETAIN_DAYS="${RETAIN_DAYS:-14}"
find "${DEST_DIR}" -maxdepth 1 -name '*.xml' -type f -mtime "+${RETAIN_DAYS}" -delete
echo "pruned backups older than ${RETAIN_DAYS} days"
