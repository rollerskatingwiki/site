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

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

# Live server has no infra/.env; MediaWiki's own db.php is the source of truth
DB_SECRETS="${BASE}/app/config/secrets/db.php"
if [[ -z "${MARIADB_PASSWORD:-}" && -f "${DB_SECRETS}" ]]; then
  MARIADB_PASSWORD="$(php -r 'include $argv[1]; echo $wgDBpassword;' "${DB_SECRETS}")"
fi

if [[ -z "${MARIADB_PASSWORD:-}" ]]; then
  echo "no DB password: set MARIADB_PASSWORD in ${ENV_FILE} or provide ${DB_SECRETS}" >&2
  exit 1
fi

zcat "${DB_FILE}" | docker exec -i -e MYSQL_PWD="${MARIADB_PASSWORD}" wiki-mariadb \
  mariadb -umediawiki mediawiki

echo "restored ${DB_FILE}"
