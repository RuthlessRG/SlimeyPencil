"""
gif_batch_convert.py
--------------------
Converts every GIF in the folder into its own single-row spritesheet PNG.
Output is named to match the original GIF.

EXAMPLES:
    jump_n.gif   →  jump_n.png
    jump_sw.gif  →  jump_sw.png
    slam_e.gif   →  slam_e.png

USAGE:
    1. Drop this script in the folder with your GIFs
    2. Run: python gif_batch_convert.py

REQUIREMENTS:
    pip install Pillow
"""

import sys
from pathlib import Path
from PIL import Image, ImageSequence


def convert_gif(gif_path: Path):
    with Image.open(gif_path) as gif:
        frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]

    if not frames:
        print(f"  ⚠️  Skipping {gif_path.name} — no frames found.")
        return

    fw, fh = frames[0].size
    sheet = Image.new("RGBA", (fw * len(frames), fh), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        if frame.size != (fw, fh):
            frame = frame.resize((fw, fh), Image.NEAREST)
        sheet.paste(frame, (i * fw, 0))

    output = gif_path.parent / (gif_path.stem + ".png")
    sheet.save(output, "PNG")
    print(f"  ✅ {gif_path.name}  →  {output.name}  ({len(frames)} frames, {fw}x{fh}px each)")


def main():
    folder = Path(__file__).parent
    gifs = sorted(folder.glob("*.gif"))

    if not gifs:
        print("❌ No GIF files found in this folder.")
        sys.exit(1)

    print(f"\n📂 Found {len(gifs)} GIF(s) in: {folder}\n")

    for gif_path in gifs:
        convert_gif(gif_path)

    print(f"\n✅ Done! {len(gifs)} spritesheet(s) saved.\n")


if __name__ == "__main__":
    main()
