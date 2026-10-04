#!/usr/bin/env bash
# Render appload-native/icon.png from the game's batter, in the preview image.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=chess-preview
docker image inspect "$IMAGE" >/dev/null 2>&1 \
    || docker build --platform linux/amd64 -t "$IMAGE" -f "$HERE/docker/preview.Dockerfile" "$HERE/docker"
docker run --rm --platform linux/amd64 -v "$HERE":/src -w /src "$IMAGE" \
    timeout 60 /usr/lib/qt6/bin/qml tools/Icon.qml
