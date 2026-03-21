#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
ENV_FILE="${BASE}/infra/.env"
DB_FILE="${1:-}"

if [[ -z "${DB_FILE}" ]]; then
  DB_FILE="$(find "${BASE}/backups/db" -maxdepth 1 -type f -name '*.sql.gz' -print | sort | tail -n 1)"
fi

if [[ -z "${DB_FILE}" || ! -f "${DB_FILE}" ]]; then
  echo "missing database backup file" >&2
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "missing ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

zcat "${DB_FILE}" | docker exec -i -e MYSQL_PWD="${MARIADB_PASSWORD}" wiki-mariadb \
  mariadb -umediawiki mediawiki

echo "restored ${DB_FILE}"
