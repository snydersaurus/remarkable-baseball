#!/usr/bin/env bash
# Copy the built bundle to the tablet and restart xochitl so AppLoad reads it.
set -euo pipefail

RM_HOST="${RM_HOST:-10.11.99.1}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/appload-native/out"
DEST="/home/root/xovi/exthome/appload/baseball"

[ -f "$OUT/resources.rcc" ] || { echo "nothing built — run ./build.sh first" >&2; exit 1; }

echo "==> checking AppLoad on $RM_HOST"
ssh "root@$RM_HOST" '[ -d /home/root/xovi/exthome/appload ]'

echo "==> copying bundle"
ssh "root@$RM_HOST" "mkdir -p $DEST"
for file in manifest.json resources.rcc icon.png; do
    scp -q "$OUT/$file" "root@$RM_HOST:$DEST/$file.new"
    ssh "root@$RM_HOST" "mv -f $DEST/$file.new $DEST/$file"
done

if [ "${NO_RESTART:-}" = 1 ]; then
    echo "Copied. Restart xochitl yourself for AppLoad to pick it up."
    exit 0
fi
echo "==> restarting xochitl so AppLoad rescans its apps"
ssh "root@$RM_HOST" 'systemctl restart xochitl'
echo "Installed at $DEST. Unlock the tablet, open AppLoad, tap Pocket Diamond."
