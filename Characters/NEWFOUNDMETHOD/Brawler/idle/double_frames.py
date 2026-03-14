"""
double_frames.py — Duplicate every frame in a horizontal sprite sheet.

Usage:
  1. Place this script in a folder with sprite sheet PNGs
  2. Run: python double_frames.py
  3. Each frame is duplicated so a 32-frame sheet becomes 64 frames
  4. Originals are backed up to a 'backups/' subfolder
  5. Output overwrites the original file (so Godot picks it up automatically)

Options:
  python double_frames.py              # 2x frames (default)
  python double_frames.py 3            # 3x frames
  python double_frames.py 2 some_dir   # process files in some_dir
"""

import os
import sys
import shutil
from PIL import Image

def double_frames(input_path, hold=2):
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size

    # Detect frame size: assume horizontal strip (height = frame height)
    # Common frame sizes to try
    frame_h = h
    candidates = [160, 144, 132, 128, 64, 48, 32, 24]

    # If image is a single horizontal row, frame_w candidates
    # Try to find frame_w where w / frame_w gives a clean integer
    frame_w = frame_h  # assume square frames first
    if w % frame_h == 0:
        frame_w = frame_h
    else:
        # Try common sizes
        for c in candidates:
            if w % c == 0 and c <= w:
                frame_w = c
                break
        else:
            # Fallback: assume square frames matching height
            frame_w = h

    num_frames = w // frame_w
    if num_frames < 2:
        print(f"  Skipping {os.path.basename(input_path)} — only {num_frames} frame(s) detected ({w}x{h}, frame_w={frame_w})")
        return False

    # Create new image with duplicated frames
    new_w = w * hold
    new_img = Image.new("RGBA", (new_w, h))

    for i in range(num_frames):
        # Crop original frame
        frame = img.crop((i * frame_w, 0, (i + 1) * frame_w, frame_h))
        # Paste it 'hold' times
        for d in range(hold):
            dest_idx = i * hold + d
            new_img.paste(frame, (dest_idx * frame_w, 0))

    new_img.save(input_path, optimize=True)
    new_frames = num_frames * hold
    print(f"  {os.path.basename(input_path)}: {num_frames} frames -> {new_frames} frames ({frame_w}x{frame_h} each)")
    return True


def main():
    hold = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 2
    target_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__))

    # Find all PNG files in the target directory
    png_files = sorted([f for f in os.listdir(target_dir) if f.lower().endswith(".png")])

    if not png_files:
        print(f"No PNG files found in {target_dir}")
        return

    print(f"Processing {len(png_files)} PNG files in {target_dir} (hold={hold}x)")
    print()

    # Create backup folder
    backup_dir = os.path.join(target_dir, "backups")
    os.makedirs(backup_dir, exist_ok=True)

    processed = 0
    for f in png_files:
        filepath = os.path.join(target_dir, f)
        # Skip directories and backup folder contents
        if not os.path.isfile(filepath):
            continue

        # Backup original
        backup_path = os.path.join(backup_dir, f)
        if not os.path.exists(backup_path):
            shutil.copy2(filepath, backup_path)

        if double_frames(filepath, hold):
            processed += 1

    print(f"\nDone. {processed} files processed. Originals backed up to backups/")


if __name__ == "__main__":
    main()
