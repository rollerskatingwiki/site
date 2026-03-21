#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <ExtensionName> <REL_branch> [release_dir]" >&2
  exit 1
fi

EXTENSION_NAME="$1"
REL_BRANCH="$2"
BASE="/home/wiki/dev/wiki"
TARGET_RELEASE="${3:-${BASE}/app/current}"
TARGET_DIR="${TARGET_RELEASE}/extensions/${EXTENSION_NAME}"
REPO_URL="https://gerrit.wikimedia.org/r/mediawiki/extensions/${EXTENSION_NAME}"

if [[ -e "${TARGET_DIR}" ]]; then
  echo "extension already exists: ${TARGET_DIR}" >&2
  exit 1
fi

git clone -b "${REL_BRANCH}" "${REPO_URL}" "${TARGET_DIR}"
echo "installed ${EXTENSION_NAME} into ${TARGET_DIR}"
echo "enable it in LocalSettings.php and then run:"
echo "php ${TARGET_RELEASE}/maintenance/run.php update"
