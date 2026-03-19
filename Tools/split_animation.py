"""
split_animation.py — Split a folder of directional sprite strips into numbered subfolders.
=============================================================================
Takes a folder of strips like:
    idle/
        idle_e.png   (e.g. 120 frames wide at 512px each)
        idle_n.png
        idle_ne.png
        ...

Splits each strip into chunks of CHUNK_SIZE frames and writes:
    idle/
        idle1/
            idle1_e.png   (frames 1–30)
            idle1_n.png
            ...
        idle2/
            idle2_e.png   (frames 31–60)
            ...
        idle3/ ...

Usage:
    python split_animation.py "C:\\path\\to\\idle"
    python split_animation.py "C:\\path\\to\\idle" 30
    python split_animation.py "C:\\path\\to\\idle" 40 512

Args:
    folder     — folder containing the source strip PNGs
    chunk_size — frames per part (default: 30)
    frame_size — pixel width/height of each square frame (default: 512)
"""

import os
import sys
from PIL import Image


def split_strip(img_path: str, chunk_size: int, frame_size: int, base_name: str, out_dir: str):
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size

    if h != frame_size:
        print(f"  SKIP {os.path.basename(img_path)} — height {h} != frame_size {frame_size}")
        return 0

    total_frames = w // frame_size
    if total_frames == 0:
        print(f"  SKIP {os.path.basename(img_path)} — no frames detected")
        return 0

    # Derive the direction suffix from filename, e.g. "idle_ne.png" → "_ne"
    stem = os.path.splitext(os.path.basename(img_path))[0]  # "idle_ne"
    # Strip the base_name prefix to get the direction part
    if stem.startswith(base_name + "_"):
        direction = stem[len(base_name):]  # "_ne"
    else:
        direction = "_" + stem  # fallback

    num_parts = (total_frames + chunk_size - 1) // chunk_size
    print(f"  {stem}.png  →  {total_frames} frames  →  {num_parts} parts of ≤{chunk_size}")

    for part_idx in range(num_parts):
        part_num  = part_idx + 1
        f_start   = part_idx * chunk_size
        f_end     = min(f_start + chunk_size, total_frames)
        part_name = f"{base_name}{part_num}"  # "idle1", "idle2", ...

        part_dir  = os.path.join(out_dir, part_name)
        os.makedirs(part_dir, exist_ok=True)

        part_frames = f_end - f_start
        out_img = Image.new("RGBA", (part_frames * frame_size, frame_size))

        for i, fi in enumerate(range(f_start, f_end)):
            frame = img.crop((fi * frame_size, 0, (fi + 1) * frame_size, frame_size))
            out_img.paste(frame, (i * frame_size, 0))

        out_path = os.path.join(part_dir, f"{part_name}{direction}.png")
        out_img.save(out_path)

    return num_parts


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    folder     = sys.argv[1]
    chunk_size = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    frame_size = int(sys.argv[3]) if len(sys.argv) > 3 else 512

    if not os.path.isdir(folder):
        print(f"ERROR: folder not found: {folder}")
        sys.exit(1)

    # Find all PNG strips directly in the folder (not in subdirs)
    pngs = sorted([
        f for f in os.listdir(folder)
        if f.lower().endswith(".png") and os.path.isfile(os.path.join(folder, f))
    ])

    if not pngs:
        print(f"No PNG files found in {folder}")
        sys.exit(1)

    # Derive base name from the first PNG, e.g. "idle_e.png" → "idle"
    # Assumes format: <base>_<dir>.png
    first_stem = os.path.splitext(pngs[0])[0]
    if "_" in first_stem:
        base_name = first_stem.rsplit("_", 1)[0]
    else:
        base_name = first_stem

    print(f"Folder    : {folder}")
    print(f"Base name : {base_name}")
    print(f"Chunk size: {chunk_size} frames")
    print(f"Frame size: {frame_size}px")
    print(f"Files     : {len(pngs)}")
    print()

    total_parts = 0
    for f in pngs:
        path = os.path.join(folder, f)
        total_parts += split_strip(path, chunk_size, frame_size, base_name, folder)

    print(f"\nDone. Created {total_parts} part files total.")
    print("Subdirs are ready to drop into your Godot project.")


if __name__ == "__main__":
    main()
