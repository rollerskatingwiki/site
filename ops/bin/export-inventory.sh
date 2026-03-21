#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-/home/wiki/dev/wiki}"
OUT_DIR="${BASE}/backups/inventory"
CURRENT_LINK="${BASE}/app/current"
CURRENT_RELEASE="$(readlink -f "${CURRENT_LINK}" || true)"

mkdir -p "${OUT_DIR}"

{
  echo "DATE=$(date --iso-8601=seconds)"
  echo "HOSTNAME=$(hostname)"
  echo "CURRENT_RELEASE=${CURRENT_RELEASE}"
  echo "PHP_VERSION=$(php -r 'echo PHP_VERSION;')"
  echo "DOCKER_VERSION=$(docker --version 2>/dev/null || true)"
  echo "COMPOSE_VERSION=$(docker compose version 2>/dev/null || true)"
  echo
  echo "[uname]"
  uname -a
  echo
  echo "[docker ps]"
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || true
  echo
  echo "[nginx version]"
  nginx -v 2>&1 || true
  echo
  echo "[php modules]"
  php -m | sort
} > "${OUT_DIR}/system.txt"

if [[ -n "${CURRENT_RELEASE}" && -d "${CURRENT_RELEASE}/extensions" ]]; then
  find "${CURRENT_RELEASE}/extensions" -maxdepth 1 -mindepth 1 -type d | sort > "${OUT_DIR}/extensions.txt"
else
  : > "${OUT_DIR}/extensions.txt"
fi

if [[ -n "${CURRENT_RELEASE}" && -d "${CURRENT_RELEASE}/skins" ]]; then
  find "${CURRENT_RELEASE}/skins" -maxdepth 1 -mindepth 1 -type d | sort > "${OUT_DIR}/skins.txt"
else
  : > "${OUT_DIR}/skins.txt"
fi

: > "${OUT_DIR}/extensions-git.txt"
while read -r dir; do
  [[ -z "${dir}" ]] && continue
  if [[ -d "${dir}/.git" ]]; then
    {
      echo "[${dir}]"
      git -C "${dir}" branch --show-current || true
      git -C "${dir}" rev-parse HEAD || true
      echo
    } >> "${OUT_DIR}/extensions-git.txt"
  fi
done < "${OUT_DIR}/extensions.txt"

echo "wrote ${OUT_DIR}"
