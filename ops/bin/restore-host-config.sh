#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DOCKER_DIR="${DOCKER_DIR:-/home/assisr/dev/docker}"

# The Docker stack (docker-compose-wiki.yml, wiki/, caddy/Caddyfile) is restored from
# the live-host-config archive into ${DOCKER_DIR}; this installs the host timers.
install -D -m 0644 "${DOCKER_DIR}/wiki/systemd/wiki-update.service" /etc/systemd/system/wiki-update.service
install -D -m 0644 "${DOCKER_DIR}/wiki/systemd/wiki-update.timer" /etc/systemd/system/wiki-update.timer
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-db.service" /etc/systemd/system/wiki-backup-db.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-db.timer" /etc/systemd/system/wiki-backup-db.timer
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-files.service" /etc/systemd/system/wiki-backup-files.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-files.timer" /etc/systemd/system/wiki-backup-files.timer
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-xml.service" /etc/systemd/system/wiki-backup-xml.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-xml.timer" /etc/systemd/system/wiki-backup-xml.timer

systemctl daemon-reload
echo "restored host timers; start the stack with: cd ${DOCKER_DIR} && docker compose up -d mariadb wiki wiki-web wiki-jobrunner wiki-sitemap"
