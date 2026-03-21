#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <mediawiki-version>" >&2
  exit 1
fi

VERSION="$1"
BASE="/home/wiki/dev/wiki"
NEW_RELEASE="${BASE}/app/releases/mediawiki-${VERSION}"
CURRENT_TARGET="$(readlink -f "${BASE}/app/current" || true)"

if [[ -z "${CURRENT_TARGET}" ]]; then
  echo "current release is not set" >&2
  exit 1
fi

echo "before upgrading, take DB and file backups"
"${BASE}/ops/bin/deploy-core.sh" "${VERSION}"

if [[ -d "${CURRENT_TARGET}/extensions" ]]; then
  rsync -a "${CURRENT_TARGET}/extensions/" "${NEW_RELEASE}/extensions/"
fi

if [[ -d "${CURRENT_TARGET}/skins" ]]; then
  rsync -a "${CURRENT_TARGET}/skins/" "${NEW_RELEASE}/skins/"
fi

php "${NEW_RELEASE}/maintenance/run.php" update
ln -sfn "${NEW_RELEASE}" "${BASE}/app/current"

echo "upgraded current to ${NEW_RELEASE}"
echo "verify the site, then remove the old release manually when satisfied"
