#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <mediawiki-version> [--switch]" >&2
  exit 1
fi

VERSION="$1"
SWITCH="${2:-}"
BASE="${BASE:-/home/wiki/dev/wiki}"
NEW_RELEASE="${BASE}/app/releases/mediawiki-${VERSION}"
CURRENT_TARGET="$(readlink -f "${BASE}/app/current" || true)"

if [[ -z "${CURRENT_TARGET}" ]]; then
  echo "current release is not set" >&2
  exit 1
fi

if [[ "${SWITCH}" == "--switch" ]]; then
  if [[ ! -d "${NEW_RELEASE}" ]]; then
    echo "release does not exist: ${NEW_RELEASE}" >&2
    exit 1
  fi
  # Atomic swap so current never dangles
  ln -sfn "${NEW_RELEASE}" "${BASE}/app/current.new"
  mv -T "${BASE}/app/current.new" "${BASE}/app/current"
  echo "current now points to ${NEW_RELEASE}"
  echo "keep ${CURRENT_TARGET} until the new release is confirmed healthy"
  exit 0
fi

"${BASE}/ops/bin/backup-db.sh"
"${BASE}/ops/bin/backup-files.sh"
"${BASE}/ops/bin/deploy-core.sh" "${VERSION}"

# Carry over only extensions/skins the new tarball does not bundle. Copying the
# old bundled ones over the new release would undo their security fixes.
for kind in extensions skins; do
  for dir in "${CURRENT_TARGET}/${kind}"/*/; do
    name="$(basename "${dir}")"
    if [[ "${name}" == *.bak ]]; then
      continue
    fi
    if [[ ! -e "${NEW_RELEASE}/${kind}/${name}" ]]; then
      cp -a "${dir%/}" "${NEW_RELEASE}/${kind}/${name}"
      echo "carried over ${kind}/${name}; update it to the branch matching ${VERSION}"
    fi
  done
done

# Custom logo/favicon/license icons referenced by LocalSettings.php
rsync -a --ignore-existing "${CURRENT_TARGET}/resources/assets/" "${NEW_RELEASE}/resources/assets/"

php "${NEW_RELEASE}/maintenance/run.php" update --quick

echo "deployed ${NEW_RELEASE}; current still points to ${CURRENT_TARGET}"
echo "test the new release, then run: $0 ${VERSION} --switch"
