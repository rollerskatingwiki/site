#!/usr/bin/env bash
set -euo pipefail

WIKI_ROOT="/home/wiki/dev/wiki"
SITEMAP_DIR="${WIKI_ROOT}/app/shared/sitemap"
MW_ROOT="${WIKI_ROOT}/app/current"
SERVER="https://rollerskating.wiki"

mkdir -p "${SITEMAP_DIR}"

php "${MW_ROOT}/maintenance/run.php" generateSitemap \
  --fspath "${SITEMAP_DIR}" \
  --urlpath /sitemap/ \
  --server "${SERVER}" \
  --compress no \
  --quiet
