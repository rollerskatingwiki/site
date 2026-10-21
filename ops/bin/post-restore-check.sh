#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
DOMAIN="${1:-}"

echo "[docker]"
docker ps --format 'table {{.Names}}\t{{.Status}}'

echo
echo "[nginx config test]"
docker exec wiki-web nginx -t

echo
echo "[versions]"
docker exec wiki php -r 'echo "PHP ", PHP_VERSION, PHP_EOL;'
echo 'echo "MediaWiki ", MW_VERSION, PHP_EOL;' | docker exec -i wiki php maintenance/run.php eval

echo
echo "[config]"
ls -la "${BASE}/app/config"

echo
echo "[images]"
ls -la "${BASE}/app/shared/images" | head -n 20

echo
echo "[local origin]"
# -f: a 502 from a dead PHP container fails the check
curl -fsS -o /dev/null -w '%{http_code}\n' -H 'Host: rollerskating.wiki' http://172.17.0.1:7734/wiki/Main_Page

if [[ -n "${DOMAIN}" ]]; then
  echo
  echo "[public domain]"
  curl -I "https://${DOMAIN}/"
fi

echo
echo "[background containers and timers]"
docker inspect wiki-jobrunner wiki-sitemap --format '{{.Name}} {{.State.Status}}' || true
systemctl is-enabled wiki-update.timer || true
systemctl is-enabled wiki-backup-db.timer || true
systemctl is-enabled wiki-backup-files.timer || true
systemctl is-enabled wiki-backup-xml.timer || true

echo "post-restore checks completed"
