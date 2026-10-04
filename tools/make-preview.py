"""Assemble rendered production-QML frames into a desktop animation preview.
Run tools/Animation.qml first; requires Pillow. Does not simulate e-paper.
"""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
paths = sorted((root / "shots/frames").glob("frame-*.png"))
if not paths:
    raise SystemExit("Render tools/Animation.qml into shots/frames first")
frames = []
for path in paths:
    with Image.open(path) as source:
        frame = source.convert("RGB")
        frame.thumbnail((1018, 573), Image.Resampling.LANCZOS)
        frames.append(frame.quantize(colors=16, dither=Image.Dither.NONE))
durations = [250] + [180] * (len(frames) - 1)
for i in range(max(1, len(frames) - 6), len(frames)):
    durations[i] = 280
out = root / "shots/gameplay.gif"
frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, disposal=2, optimize=False)
print(out)
