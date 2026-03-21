#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DEST_DIR="${BASE}/backups/files"
PHP_VERSION="${PHP_VERSION:-8.3}"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/live-host-config-${TS}.tar.gz"

mkdir -p "${DEST_DIR}"

paths=(
  "/etc/nginx/sites-available/wiki.conf"
  "/etc/nginx/sites-enabled/wiki.conf"
  "/etc/php/${PHP_VERSION}/fpm/pool.d/wiki.conf"
  "/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"
  "/etc/systemd/system/wiki-jobs.service"
  "/etc/systemd/system/wiki-jobs.timer"
  "/etc/systemd/system/wiki-backup-db.service"
  "/etc/systemd/system/wiki-backup-db.timer"
  "/etc/systemd/system/wiki-backup-files.service"
  "/etc/systemd/system/wiki-backup-files.timer"
)

existing=()
for path in "${paths[@]}"; do
  if [[ -e "${path}" ]]; then
    existing+=("${path}")
  fi
done

if [[ ${#existing[@]} -eq 0 ]]; then
  echo "no live host config files found to archive" >&2
  exit 1
fi

tar -czf "${DEST_FILE}" "${existing[@]}"
echo "wrote ${DEST_FILE}"
