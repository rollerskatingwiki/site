#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DOMAIN="${1:-}"

echo "[docker]"
docker ps --format 'table {{.Names}}\t{{.Status}}'

echo
echo "[nginx config test]"
nginx -t

echo
echo "[current release]"
readlink -f "${BASE}/app/current"

echo
echo "[config]"
ls -la "${BASE}/app/config"

echo
echo "[images]"
ls -la "${BASE}/app/shared/images" | head -n 20

echo
echo "[local origin]"
curl -I http://127.0.0.1:8081/

if [[ -n "${DOMAIN}" ]]; then
  echo
  echo "[public domain]"
  curl -I "https://${DOMAIN}/"
fi

echo
echo "[timers]"
systemctl is-enabled wiki-jobs.timer || true
systemctl is-enabled wiki-backup-db.timer || true
systemctl is-enabled wiki-backup-files.timer || true

echo "post-restore checks completed"
