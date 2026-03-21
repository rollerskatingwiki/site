#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
ENV_FILE="${BASE}/infra/.env"
DEST_DIR="${BASE}/backups/db"
TS="$(date +%F-%H%M%S)"
DEST_FILE="${DEST_DIR}/mediawiki-${TS}.sql.gz"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "missing ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

mkdir -p "${DEST_DIR}"

docker exec -e MYSQL_PWD="${MARIADB_PASSWORD}" wiki-mariadb \
  mariadb-dump \
  --single-transaction \
  --quick \
  --skip-lock-tables \
  -umediawiki \
  mediawiki | gzip -9 > "${DEST_FILE}"

echo "wrote ${DEST_FILE}"

RETAIN_DAYS="${RETAIN_DAYS:-14}"
find "${DEST_DIR}" -maxdepth 1 -name '*.sql.gz' -type f -mtime "+${RETAIN_DAYS}" -delete
echo "pruned backups older than ${RETAIN_DAYS} days"
