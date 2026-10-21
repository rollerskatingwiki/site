#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"

echo "stopping background jobs"
systemctl stop wiki-update.timer || true
docker stop wiki-jobrunner wiki-sitemap || true

echo "running backups"
"${BASE}/ops/bin/backup-db.sh"
"${BASE}/ops/bin/backup-files.sh"
"${BASE}/ops/bin/backup-xml.sh"

echo "exporting deployment inventory"
"${BASE}/ops/bin/export-inventory.sh"

echo "backing up live host config"
"${BASE}/ops/bin/backup-live-host-config.sh"

echo "verifying backups"
"${BASE}/ops/bin/verify-backups.sh"

echo "creating migration bundle"
"${BASE}/ops/bin/create-migration-bundle.sh"

echo "pre-migration checks completed"
