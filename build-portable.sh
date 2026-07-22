#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${CONTAINER_ENGINE:-}"
if [[ -z "$ENGINE" ]]; then
  if command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
  elif command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
  else
    echo "ERROR: Podman or Docker is required for the portable build." >&2
    exit 1
  fi
fi

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

"$ENGINE" run --rm \
  --volume "$ROOT_DIR:/src" \
  --workdir /src \
  --env HOST_UID="$HOST_UID" \
  --env HOST_GID="$HOST_GID" \
  ubuntu:22.04 \
  bash -lc '
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends python3 python3-venv python3-pip python3-tk curl ca-certificates file binutils
    ./packaging/build-appimage.sh
    chown -R "$HOST_UID:$HOST_GID" /src/dist /src/.build-appimage
  '

echo "Portable AppImage build finished in $ROOT_DIR/dist."

