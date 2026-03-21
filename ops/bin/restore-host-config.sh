#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
PHP_VERSION="${PHP_VERSION:-8.3}"

install -D -m 0644 "${BASE}/ops/nginx/wiki.conf.example" /etc/nginx/sites-available/wiki.conf
ln -sfn /etc/nginx/sites-available/wiki.conf /etc/nginx/sites-enabled/wiki.conf
install -D -m 0644 "${BASE}/ops/php-fpm/wiki.conf.example" "/etc/php/${PHP_VERSION}/fpm/pool.d/wiki.conf"
install -D -m 0644 "${BASE}/ops/php-fpm/10-opcache.ini.example" "/etc/php/${PHP_VERSION}/fpm/conf.d/10-opcache.ini"

install -D -m 0644 "${BASE}/ops/systemd/wiki-jobs.service" /etc/systemd/system/wiki-jobs.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-jobs.timer" /etc/systemd/system/wiki-jobs.timer
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-db.service" /etc/systemd/system/wiki-backup-db.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-db.timer" /etc/systemd/system/wiki-backup-db.timer
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-files.service" /etc/systemd/system/wiki-backup-files.service
install -D -m 0644 "${BASE}/ops/systemd/wiki-backup-files.timer" /etc/systemd/system/wiki-backup-files.timer

systemctl daemon-reload
echo "restored host configuration"
