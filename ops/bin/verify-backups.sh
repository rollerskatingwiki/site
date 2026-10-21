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
# Read to the end: `| head` would SIGPIPE zcat and fail under pipefail
zcat "${DB_FILE}" | tail -n 1 | grep -q "Dump completed"

echo "verifying ${FILES_FILE}"
tar -tzf "${FILES_FILE}" > /dev/null

echo "verifying ${XML_FILE}"
tail -n 1 "${XML_FILE}" | grep -q "</mediawiki>"

echo "verified:"
echo "  db: ${DB_FILE}"
echo "  files: ${FILES_FILE}"
echo "  xml: ${XML_FILE}"
