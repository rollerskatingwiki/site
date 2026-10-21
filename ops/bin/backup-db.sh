#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
ENV_FILE="${BASE}/infra/.env"
DB_SECRETS="${BASE}/app/config/secrets/db.php"
DEST_DIR="${BASE}/backups/db"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/mediawiki-${TS}.sql.gz"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

# Live server has no infra/.env; MediaWiki's own db.php is the source of truth
if [[ -z "${MARIADB_PASSWORD:-}" && -f "${DB_SECRETS}" ]]; then
  MARIADB_PASSWORD="$(php -r 'include $argv[1]; echo $wgDBpassword;' "${DB_SECRETS}")"
fi

if [[ -z "${MARIADB_PASSWORD:-}" ]]; then
  echo "no DB password: set MARIADB_PASSWORD in ${ENV_FILE} or provide ${DB_SECRETS}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

# Write to a temp file so a failed dump never looks like the latest backup
docker exec -e MYSQL_PWD="${MARIADB_PASSWORD}" wiki-mariadb \
  mariadb-dump \
  --single-transaction \
  --quick \
  --skip-lock-tables \
  -umediawiki \
  mediawiki | gzip -9 > "${DEST_FILE}.tmp"
mv "${DEST_FILE}.tmp" "${DEST_FILE}"

echo "wrote ${DEST_FILE}"

RETAIN_DAYS="${RETAIN_DAYS:-14}"
find "${DEST_DIR}" -maxdepth 1 -name '*.sql.gz' -type f -mtime "+${RETAIN_DAYS}" -delete
echo "pruned backups older than ${RETAIN_DAYS} days"
