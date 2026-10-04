# Development

## Optional checks

The repository includes deterministic rules and animation checks:

```bash
node tools/test-baseball.mjs
node tools/test-motion.mjs
```

The rules suite simulates 4,000 games. These checks predate the latest smooth
motion revision and were not rerun as part of publishing this repository.
`tools/LiveCheck.qml` exercises the automatic pitch clock and pause behavior.

## Screenshots

Build the desktop preview image; it does not require a tablet SDK:

```bash
docker build --platform linux/amd64 -t chess-preview -f docker/preview.Dockerfile docker
mkdir -p docs/screenshots
for size in 1696x954:landscape 954x1696:portrait; do
    dims=${size%%:*}; name=${size##*:}
    docker run --rm --platform linux/amd64 -v "$PWD":/src -w /src chess-preview \
        /usr/lib/qt6/bin/qml tools/RefinePreview.qml -- \
        "${dims%x*}" "${dims#*x}" "/src/docs/screenshots/$name.png"
done
```

`tools/preview.sh` additionally renders scripted gameplay scenarios and runs
assertions through `tools/Shot.qml`. `tools/make-icon.sh` renders the launcher
icon from the batter artwork. These use the same production components.

Screenshots cannot establish physical display latency or ghosting. Assess
those on the tablet. The current smooth mode uses 150 ms ball-movement steps
at Relaxed pace, with a longer arrival hold preserving the contact window.

## Build and resources

The app requires no native backend. `build.sh` packages QML, JavaScript, and
artwork into `appload-native/out/resources.rcc` with the SDK's `rcc` tool.
It also runs `qmllint`; unresolved device-specific types may generate warnings.
Packaging success alone does not prove the game will run on a given firmware.

`ui/Main.qml` loads AppLoad's display helper dynamically. If it is unavailable,
play continues with standard refresh. The helper is destroyed on pause, hide,
end of play, and unload. The API follows the upstream
[DisplayMethodArea](https://github.com/asivery/rm-appload/blob/95d2de5948f5fcae8ff07d046408483f5a35e888/resources/ApploadUtils/DisplayMethodArea.qml).

`tools/make-sprites.mjs` preserves an earlier procedural art experiment. It
writes `tools/legacy-sprites.mjs`, not the live sprite-atlas definitions.
