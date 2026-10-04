#!/usr/bin/env bash
# Render screenshots of the game offscreen, portrait and landscape, into shots/.
# Uses Ubuntu's Qt in docker/preview.Dockerfile; nothing touches the tablet.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=chess-preview
docker image inspect "$IMAGE" >/dev/null 2>&1 \
    || docker build --platform linux/amd64 -t "$IMAGE" -f "$HERE/docker/preview.Dockerfile" "$HERE/docker"
mkdir -p "$HERE/shots"
for size in 954x1696:portrait 1696x954:landscape; do
    dims=${size%%:*}; name=${size##*:}
    docker run --rm --platform linux/amd64 -v "$HERE":/src -w /src "$IMAGE" \
        timeout 60 /usr/lib/qt6/bin/qml tools/Shot.qml -- "${dims%x*}" "${dims#*x}" "shots/$name"
done
echo "Screenshots in $HERE/shots"
