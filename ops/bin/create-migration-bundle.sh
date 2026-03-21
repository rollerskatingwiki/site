#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DEST_DIR="${BASE}/backups/migration"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/mediawiki-migration-bundle-${TS}.tar.gz"

mkdir -p "${DEST_DIR}"

required=(
  "${BASE}/backups"
  "${BASE}/docs"
  "${BASE}/ops"
  "${BASE}/README.md"
  "${BASE}/infra/.env"
  "${BASE}/app/config/LocalSettings.php"
  "${BASE}/app/config/secrets/db.php"
)

existing=()
for path in "${required[@]}"; do
  if [[ -e "${path}" ]]; then
    existing+=("${path}")
  else
    echo "warning: missing ${path}" >&2
  fi
done

if [[ ${#existing[@]} -eq 0 ]]; then
  echo "nothing to bundle" >&2
  exit 1
fi

tar -czf "${DEST_FILE}" "${existing[@]}"
echo "wrote ${DEST_FILE}"
