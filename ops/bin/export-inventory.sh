#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
OUT_DIR="${BASE}/backups/inventory"
# MediaWiki runs in the "wiki" container (built from ~/dev/docker/wiki)
APP_CONTAINER="${APP_CONTAINER:-wiki}"

mkdir -p "${OUT_DIR}"

in_app() {
  docker exec "${APP_CONTAINER}" "$@"
}

{
  echo "DATE=$(date --iso-8601=seconds)"
  echo "HOSTNAME=$(hostname)"
  echo "MEDIAWIKI_VERSION=$(echo 'echo MW_VERSION;' | docker exec -i "${APP_CONTAINER}" php maintenance/run.php eval)"
  echo "PHP_VERSION=$(in_app php -r 'echo PHP_VERSION;')"
  echo "APP_IMAGE=$(docker inspect "${APP_CONTAINER}" --format '{{.Config.Image}} {{.Image}}')"
  echo "DOCKER_VERSION=$(docker --version 2>/dev/null || true)"
  echo "COMPOSE_VERSION=$(docker compose version 2>/dev/null || true)"
  echo
  echo "[uname]"
  uname -a
  echo
  echo "[docker ps]"
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || true
  echo
  echo "[php modules]"
  in_app php -m | sort
} > "${OUT_DIR}/system.txt"

# name and declared version of every extension/skin baked into the image
list_components() {
  in_app php -r '
    foreach (glob($argv[1] . "/*/" . $argv[2]) as $f) {
      $j = json_decode(file_get_contents($f), true);
      echo basename(dirname($f)), " ", $j["version"] ?? "-", "\n";
    }' "$1" "$2"
}

list_components extensions extension.json > "${OUT_DIR}/extensions.txt"
list_components skins skin.json > "${OUT_DIR}/skins.txt"

# Exact refs come from the Dockerfile's ADD lines
grep -E '^ADD ' /home/assisr/dev/docker/wiki/Dockerfile > "${OUT_DIR}/extensions-git.txt" || true

echo "wrote ${OUT_DIR}"
