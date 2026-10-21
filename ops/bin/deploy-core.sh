#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <mediawiki-version>" >&2
  exit 1
fi

VERSION="$1"
BASE="${BASE:-/home/wiki/dev/wiki}"
RELEASES_DIR="${BASE}/app/releases"
RELEASE_DIR="${RELEASES_DIR}/mediawiki-${VERSION}"
ARCHIVE="mediawiki-${VERSION}.tar.gz"
SERIES="${VERSION%.*}"
URL="https://releases.wikimedia.org/mediawiki/${SERIES}/${ARCHIVE}"

mkdir -p "${RELEASES_DIR}" "${BASE}/app/shared/images" "${BASE}/app/config/secrets"

if [[ -e "${RELEASE_DIR}" ]]; then
  echo "release already exists: ${RELEASE_DIR}" >&2
  exit 1
fi

cd "${RELEASES_DIR}"
curl -fLO "${URL}"
tar -xzf "${ARCHIVE}"
rm -f "${ARCHIVE}"

# The tarball ships its own images/ (README, .htaccess); ln -sfn onto it would
# create images/images, so replace it with the shared uploads dir
rm -rf "${RELEASE_DIR}/images"
ln -s "${BASE}/app/shared/images" "${RELEASE_DIR}/images"

if [[ -e "${BASE}/app/config/LocalSettings.php" ]]; then
  ln -sfn "${BASE}/app/config/LocalSettings.php" "${RELEASE_DIR}/LocalSettings.php"
fi

if [[ ! -L "${BASE}/app/current" ]]; then
  ln -sfn "${RELEASE_DIR}" "${BASE}/app/current"
fi

echo "deployed ${RELEASE_DIR}"
echo "current points to $(readlink "${BASE}/app/current" || true)"
