#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DEST_DIR="${BASE}/backups/files"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/mediawiki-files-${TS}.tar.gz"

mkdir -p "${DEST_DIR}"

tar -czf "${DEST_FILE}" \
  "${BASE}/app/config" \
  "${BASE}/app/shared/images" \
  "${BASE}/infra" \
  "${BASE}/ops"

echo "wrote ${DEST_FILE}"

RETAIN_DAYS="${RETAIN_DAYS:-14}"
find "${DEST_DIR}" -maxdepth 1 -name '*.tar.gz' -type f -mtime "+${RETAIN_DAYS}" -delete
echo "pruned backups older than ${RETAIN_DAYS} days"
