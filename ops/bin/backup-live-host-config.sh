#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DOCKER_DIR="${DOCKER_DIR:-/home/assisr/dev/docker}"
DEST_DIR="${BASE}/backups/files"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/live-host-config-${TS}.tar.gz"

mkdir -p "${DEST_DIR}"

# The wiki runs in Docker: its build files and compose service live in the shared
# Docker stack; only backup/update timers remain on the host.
paths=(
  "${DOCKER_DIR}/docker-compose-wiki.yml"
  "${DOCKER_DIR}/wiki"
  "${DOCKER_DIR}/caddy/Caddyfile"
  "/etc/systemd/system/wiki-update.service"
  "/etc/systemd/system/wiki-update.timer"
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
