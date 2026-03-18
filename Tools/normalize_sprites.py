"""
Normalize Sprite Sizes
======================
Run this AFTER rendering all animations for a character.
It finds the largest content bounds across ALL strips in a folder
and re-centers every frame to match, so idle/run/attack are all
the same size and position.

Usage:
  python normalize_sprites.py "C:\path\to\Brawler3"

Or just edit CHAR_DIR below and run it.
"""

import os
import sys
import numpy as np
from PIL import Image

# Edit this to your character's folder
CHAR_DIR = r"C:\Users\ryang\OneDrive\Documents\miniSWG\Characters\NEWFOUNDMETHOD\Brawler3"
CELL = 512  # Frame size

def get_content_bounds(img_array):
    """Get bounding box of non-transparent content."""
    alpha = img_array[:, :, 3]
    rows = np.any(alpha > 30, axis=1)
    cols = np.any(alpha > 30, axis=0)
    if not rows.any() or not cols.any():
        return None
    y0 = int(np.argmax(rows))
    y1 = int(len(rows) - np.argmax(rows[::-1]))
    x0 = int(np.argmax(cols))
    x1 = int(len(cols) - np.argmax(cols[::-1]))
    return (x0, y0, x1, y1)

def main():
    char_dir = CHAR_DIR
    if len(sys.argv) > 1:
        char_dir = sys.argv[1]

    print(f"Scanning: {char_dir}")

    # Find ALL strip PNGs recursively
    strips = []
    for root, dirs, files in os.walk(char_dir):
        for f in files:
            if f.endswith('.png') and not f.endswith('.import') and not f.startswith('_'):
                path = os.path.join(root, f)
                img = Image.open(path)
                if img.size[1] == CELL:  # It's a strip
                    strips.append(path)

    print(f"Found {len(strips)} strips")

    # Pass 1: Find global max content bounds across ALL frames of ALL strips
    global_max_w = 0
    global_max_h = 0
    all_centers = []

    for path in strips:
        img = Image.open(path).convert('RGBA')
        arr = np.array(img)
        num_frames = img.size[0] // CELL

        for fi in range(num_frames):
            cell = arr[:, fi*CELL:(fi+1)*CELL]
            bounds = get_content_bounds(cell)
            if bounds is None:
                continue
            x0, y0, x1, y1 = bounds
            w = x1 - x0
            h = y1 - y0
            cx = (x0 + x1) / 2.0
            cy = (y0 + y1) / 2.0
            global_max_w = max(global_max_w, w)
            global_max_h = max(global_max_h, h)
            all_centers.append((cx, cy))

    if not all_centers:
        print("No content found!")
        return

    # Average center across all frames
    avg_cx = np.mean([c[0] for c in all_centers])
    avg_cy = np.mean([c[1] for c in all_centers])

    print(f"Global max content: {global_max_w}x{global_max_h}")
    print(f"Average center: ({avg_cx:.1f}, {avg_cy:.1f})")
    print(f"Target center: ({CELL//2}, {CELL//2})")

    # Pass 2: Re-center all frames so content is at the same position
    shift_x = int(CELL / 2 - avg_cx)
    shift_y = int(CELL / 2 - avg_cy)

    print(f"Shifting all frames by ({shift_x}, {shift_y}) pixels")

    modified = 0
    for path in strips:
        img = Image.open(path).convert('RGBA')
        arr = np.array(img)
        num_frames = img.size[0] // CELL
        new_arr = np.zeros_like(arr)

        for fi in range(num_frames):
            cell = arr[:, fi*CELL:(fi+1)*CELL]
            # Create new cell with content shifted
            new_cell = np.zeros((CELL, CELL, 4), dtype=np.uint8)

            # Calculate source and destination regions with clamping
            src_x0 = max(0, -shift_x)
            src_y0 = max(0, -shift_y)
            src_x1 = min(CELL, CELL - shift_x)
            src_y1 = min(CELL, CELL - shift_y)
            dst_x0 = max(0, shift_x)
            dst_y0 = max(0, shift_y)
            dst_x1 = dst_x0 + (src_x1 - src_x0)
            dst_y1 = dst_y0 + (src_y1 - src_y0)

            # Clamp to cell bounds
            w = min(dst_x1, CELL) - dst_x0
            h = min(dst_y1, CELL) - dst_y0
            if w > 0 and h > 0:
                new_cell[dst_y0:dst_y0+h, dst_x0:dst_x0+w] = cell[src_y0:src_y0+h, src_x0:src_x0+w]

            new_arr[:, fi*CELL:(fi+1)*CELL] = new_cell

        new_img = Image.fromarray(new_arr)
        new_img.save(path)
        modified += 1

    print(f"\nDone! Modified {modified} strips.")
    print("All animations now have consistent character positioning.")

if __name__ == "__main__":
    main()
