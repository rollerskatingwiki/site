#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"

latest_file() {
  local dir="$1"
  local pattern="$2"
  find "${dir}" -maxdepth 1 -type f -name "${pattern}" -print | sort | tail -n 1
}

DB_FILE="$(latest_file "${BASE}/backups/db" '*.sql.gz')"
FILES_FILE="$(latest_file "${BASE}/backups/files" '*.tar.gz')"
XML_FILE="$(latest_file "${BASE}/backups/xml" '*.xml')"

if [[ -z "${DB_FILE}" || -z "${FILES_FILE}" || -z "${XML_FILE}" ]]; then
  echo "missing one or more backup artifacts" >&2
  echo "db=${DB_FILE:-missing}" >&2
  echo "files=${FILES_FILE:-missing}" >&2
  echo "xml=${XML_FILE:-missing}" >&2
  exit 1
fi

echo "verifying ${DB_FILE}"
gzip -t "${DB_FILE}"
zcat "${DB_FILE}" | head -n 20 > /dev/null

echo "verifying ${FILES_FILE}"
tar -tzf "${FILES_FILE}" | head -n 50 > /dev/null

echo "verifying ${XML_FILE}"
head -n 20 "${XML_FILE}" > /dev/null

echo "verified:"
echo "  db: ${DB_FILE}"
echo "  files: ${FILES_FILE}"
echo "  xml: ${XML_FILE}"
