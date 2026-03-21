#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DEST_DIR="${BASE}/backups/xml"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/wiki-full-${TS}.xml"

mkdir -p "${DEST_DIR}"

sudo -u wiki php "${BASE}/app/current/maintenance/run.php" dumpBackup --full > "${DEST_FILE}"

echo "wrote ${DEST_FILE}"
