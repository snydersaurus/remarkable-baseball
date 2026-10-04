#!/usr/bin/env bash
# Lint the QML and pack it into the AppLoad bundle. There is no backend, so the
# SDK is only needed for rcc and qmllint; an existing SDK image can be reused.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${IMAGE:-rmpp-sdk-5.7}"

SDK_SH="${1:-}"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    [ -n "$SDK_SH" ] && [ -f "$SDK_SH" ] || {
        echo "No '$IMAGE' image. Pass a compatible reMarkable SDK installer:" >&2
        echo "  ./build.sh /path/to/remarkable-toolchain.sh" >&2
        exit 1
    }
    SDK_PATH="$(cd "$(dirname "$SDK_SH")" && pwd)/$(basename "$SDK_SH")"
    if [ "$SDK_PATH" != "$HERE/docker/rmpp-sdk.sh" ]; then
        cp "$SDK_PATH" "$HERE/docker/rmpp-sdk.sh"
    fi
    docker build --platform linux/amd64 -t "$IMAGE" "$HERE/docker"
fi

# rcc does not complain about missing files in every case; check them here.
for f in $(sed -n 's|.*<file>\(.*\)</file>.*|\1|p' "$HERE/application.qrc"); do
    [ -f "$HERE/$f" ] || { echo "missing $f listed in application.qrc" >&2; exit 1; }
done

docker run --rm --platform linux/amd64 -v "$HERE":/src "$IMAGE" bash -lc '
  set -euo pipefail
  source /opt/rmpp-sdk/environment-setup-*-remarkable-linux
  cd /src
  "${OECORE_NATIVE_SYSROOT}/usr/bin/qmllint" ui/*.qml || true
  rm -rf appload-native/out && mkdir -p appload-native/out
  "${OECORE_NATIVE_SYSROOT}/usr/libexec/rcc" --binary --no-compress \
      -o appload-native/out/resources.rcc application.qrc
  cp appload-native/manifest.json appload-native/icon.png appload-native/out/
'

# --no-compress keeps the QML greppable: confirm the bundle holds this revision.
grep -q "pitcherHint" "$HERE/appload-native/out/resources.rcc" || {
    echo "resources.rcc does not contain Baseball.mjs — refusing" >&2; exit 1; }
echo "Built: $HERE/appload-native/out"
