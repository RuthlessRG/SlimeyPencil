"""
Blender Sprite Sheet Renderer — Mixamo Edition
===============================================
Same pipeline as render_spritesheet.py BUT designed for Mixamo FBX rigs,
which are taller and swing limbs further outside the default frame.

Key differences from render_spritesheet.py:
  - AUTO_FIT_CAMERA: scans every animation frame's bounding box, then
    calculates exactly how far back / how wide the camera needs to be.
    Nothing will ever be clipped again.
  - Larger default frame (512 x 640) for humanoid proportions.
  - Separate _mixamo_camera_config.json — never touches Meshy settings.
  - Mixamo models are often imported with Z-up, 100x scale — import tips
    printed on startup.

Usage in Blender:
  1. Import your Mixamo FBX  (File > Import > FBX)
     Apply these import settings:
       - Scale: 0.01  (Mixamo exports at 100x scale)
       - Use Pre/Post Rotation: ON
  2. Open Scripting tab, paste this whole script.
  3. Set OUTPUT_DIR and ANIM_NAME below.
  4. Set FRAME_START / FRAME_END to match your timeline.
  5. Run Script (Alt+P).

Auto-fit:
  With AUTO_FIT_CAMERA = True the script samples ~30 frames, measures the
  combined mesh bounding box across all of them, then sets ortho_scale so
  nothing is clipped — with ORTHO_PADDING extra breathing room.
  Set AUTO_FIT_CAMERA = False and set ORTHO_SCALE manually if you want
  exact pixel-perfect framing.
"""

import bpy
import math
import os
import json
from mathutils import Vector

# ══════════════════════════════════════════════════════════════
#  CONFIGURATION — Edit these
# ══════════════════════════════════════════════════════════════

OUTPUT_DIR  = r"C:\Users\ryang\OneDrive\Desktop\Game dev\ASSET_DOWNLOADS\rendered_sprites_mixamo"
ANIM_NAME   = "run"          # prefix for output files: run_s.png, run_ne.png …

FRAME_START = 1
FRAME_END   = 60
FRAME_STEP  = 1              # 1 = every frame, 2 = every other, etc.

# Render resolution per frame — taller to fit humanoid proportions
FRAME_WIDTH  = 512
FRAME_HEIGHT = 640

USE_TRANSPARENT = True

# ── Auto-fit camera ──────────────────────────────────────────
# True  = scan all frames, auto-calculate ortho_scale (recommended)
# False = use ORTHO_SCALE below (set manually if auto-fit is wrong)
AUTO_FIT_CAMERA = True

# Extra breathing room on top of the auto-fit measurement (1.15 = 15% margin)
ORTHO_PADDING   = 1.18

# Only used when AUTO_FIT_CAMERA = False
ORTHO_SCALE = 3.8

# ── Manual camera position (used as starting point for auto-fit too) ──
CAM_DISTANCE  = 4.5   # horizontal distance from character
CAM_HEIGHT    = 2.8   # camera Z height
CHAR_CENTER_Z = 0.95  # world-Z the camera targets (Mixamo chars center ~0.9-1.0)

# Spritesheet grid
GRID_COLS = 4

# Directions: render 5, flip 3
DIRECTIONS = [
    ("s",  0),
    ("n",  180),
    ("e",  270),
    ("ne", 225),
    ("se", 315),
]
FLIP_MAP = {
    "e":  "w",
    "ne": "nw",
    "se": "sw",
}

# ══════════════════════════════════════════════════════════════
#  CAMERA CONFIG — separate file so Meshy settings are untouched
# ══════════════════════════════════════════════════════════════

CONFIG_FILE = os.path.join(OUTPUT_DIR, "_mixamo_camera_config.json")

def save_camera_config(ortho_scale_used: float) -> None:
    config = {
        "cam_distance":   CAM_DISTANCE,
        "cam_height":     CAM_HEIGHT,
        "char_center_z":  CHAR_CENTER_Z,
        "frame_width":    FRAME_WIDTH,
        "frame_height":   FRAME_HEIGHT,
        "ortho_scale":    ortho_scale_used,
        "auto_fit":       AUTO_FIT_CAMERA,
    }
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"  Camera config saved: {CONFIG_FILE}")

def load_camera_config():
    """Returns saved ortho_scale if config exists, else None."""
    if not os.path.exists(CONFIG_FILE):
        return None
    try:
        with open(CONFIG_FILE) as f:
            cfg = json.load(f)
        print(f"  Loaded mixamo config: ortho_scale={cfg.get('ortho_scale')}")
        return cfg.get("ortho_scale")
    except Exception:
        return None

# ══════════════════════════════════════════════════════════════
#  AUTO-FIT: bounding box scan
# ══════════════════════════════════════════════════════════════

def get_mesh_objects():
    """Return all mesh objects in the scene (skip cameras, lights, empties)."""
    return [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.visible_get()]

def world_bbox_all_frames():
    """
    Sample ~30 frames, measure each mesh corner RELATIVE to the character's
    own center that frame.  This gives the true limb-swing extent regardless
    of root motion — exactly what we need for ortho_scale.
    Returns (min_x, min_y, min_z, max_x, max_y, max_z) in character-local space.
    """
    scene  = bpy.context.scene
    meshes = get_mesh_objects()
    if not meshes:
        print("  WARNING: No visible mesh objects found for auto-fit scan.")
        return None

    INF = float('inf')
    mn = [INF, INF, INF]
    mx = [-INF, -INF, -INF]

    total_frames = FRAME_END - FRAME_START + 1
    sample_step  = max(1, total_frames // 30)

    for frame in range(FRAME_START, FRAME_END + 1, sample_step):
        scene.frame_set(frame)
        # Character center at this frame — subtract it so root motion doesn't
        # inflate the bounding box.
        center = get_char_center_this_frame()
        for obj in meshes:
            for corner in obj.bound_box:
                wp = obj.matrix_world @ Vector(corner)
                # Make relative to character center
                rel = [wp.x - center.x, wp.y - center.y, wp.z - center.z]
                for i in range(3):
                    if rel[i] < mn[i]: mn[i] = rel[i]
                    if rel[i] > mx[i]: mx[i] = rel[i]

    print(f"  BBox scan (relative to char center):")
    print(f"    X[{mn[0]:.2f}, {mx[0]:.2f}]  "
          f"Y[{mn[1]:.2f}, {mx[1]:.2f}]  Z[{mn[2]:.2f}, {mx[2]:.2f}]")
    return tuple(mn + mx)

def calc_auto_ortho_scale(bbox) -> float:
    """
    Given the world-space AABB, calculate the ortho_scale needed so the
    character fits in frame from any of the 5 camera angles.

    For an orthographic camera:
      - ortho_scale = world units visible vertically in frame
      - world units visible horizontally = ortho_scale * (W / H)

    Vertical extent  = bbox Z height (tallest pose across all frames)
    Horizontal worst = diagonal of XY footprint (covers any rotation angle)
    """
    min_x, min_y, min_z, max_x, max_y, max_z = bbox

    aspect = FRAME_WIDTH / FRAME_HEIGHT

    # Vertical: Z range (head to feet including raised arms/jumps)
    vertical = max_z - min_z

    # Horizontal: worst-case is the diagonal of the XY bounding box,
    # which handles any of the 8 camera angles without clipping.
    xy_diag = math.sqrt((max_x - min_x) ** 2 + (max_y - min_y) ** 2)
    horizontal_as_vertical = xy_diag / aspect   # convert to ortho_scale units

    needed = max(vertical, horizontal_as_vertical)
    ortho_scale = needed * ORTHO_PADDING

    print(f"  Auto-fit: vertical={vertical:.2f}  xy_diag={xy_diag:.2f}  "
          f"needed={needed:.2f}  ortho_scale={ortho_scale:.3f}  (padding {ORTHO_PADDING}x)")
    return ortho_scale

# ══════════════════════════════════════════════════════════════
#  RENDER SETUP
# ══════════════════════════════════════════════════════════════

def setup_render_settings():
    scene = bpy.context.scene
    for engine in ['BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH']:
        try:
            scene.render.engine = engine
            break
        except Exception:
            continue
    scene.render.resolution_x           = FRAME_WIDTH
    scene.render.resolution_y           = FRAME_HEIGHT
    scene.render.resolution_percentage  = 100
    scene.render.image_settings.file_format  = 'PNG'
    scene.render.image_settings.color_mode  = 'RGBA'
    scene.render.image_settings.compression = 15
    if USE_TRANSPARENT:
        scene.render.film_transparent = True
    try:
        scene.eevee.use_bloom       = False
        scene.eevee.use_motion_blur = False
    except Exception:
        pass

def setup_camera(ortho_scale: float):
    """Create (or recreate) the SpriteCamera with the given ortho_scale."""
    cam_name = "SpriteCameraMixamo"
    if cam_name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[cam_name], do_unlink=True)

    cam_data = bpy.data.cameras.new(name=cam_name)
    cam_data.type        = 'ORTHO'
    cam_data.ortho_scale = ortho_scale

    cam_obj = bpy.data.objects.new(cam_name, cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj
    return cam_obj

def get_char_center_this_frame() -> Vector:
    """
    Return the world-space XYZ center of the character at the current frame.
    Handles root-motion animations where the armature/mesh actually moves.

    Priority:
      1. Armature object location (most reliable for Mixamo)
      2. Average bounding box center of all visible meshes
      3. Fallback: (0, 0, CHAR_CENTER_Z)
    """
    # 1. Find armature — Mixamo rigs always have one
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE' and obj.visible_get():
            loc = obj.matrix_world.translation
            return Vector((loc.x, loc.y, loc.z + CHAR_CENTER_Z))

    # 2. Bounding box center of all meshes
    meshes = get_mesh_objects()
    if meshes:
        all_pts = []
        for obj in meshes:
            for corner in obj.bound_box:
                all_pts.append(obj.matrix_world @ Vector(corner))
        xs = [p.x for p in all_pts]
        ys = [p.y for p in all_pts]
        zs = [p.z for p in all_pts]
        return Vector((
            (min(xs) + max(xs)) * 0.5,
            (min(ys) + max(ys)) * 0.5,
            (min(zs) + max(zs)) * 0.5,
        ))

    # 3. Fallback
    return Vector((0.0, 0.0, CHAR_CENTER_Z))


def position_camera(cam_obj, angle_deg: float, center: Vector = None):
    """
    Orbit the camera around `center` at the given horizontal angle.
    If center is None it falls back to (0, 0, CHAR_CENTER_Z) — same as
    render_spritesheet.py behaviour.
    """
    if center is None:
        center = Vector((0.0, 0.0, CHAR_CENTER_Z))
    angle_rad = math.radians(angle_deg)
    cam_obj.location = Vector((
        center.x + math.sin(angle_rad) * CAM_DISTANCE,
        center.y - math.cos(angle_rad) * CAM_DISTANCE,
        center.z + CAM_HEIGHT,
    ))
    direction = center - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

def setup_lighting():
    for obj in bpy.data.objects:
        if obj.type == 'LIGHT':
            bpy.data.objects.remove(obj, do_unlink=True)

    for name, energy, rot in [
        ("KeyLight",  3.0, (math.radians(45), 0, math.radians(-30))),
        ("FillLight", 1.5, (math.radians(60), 0, math.radians(150))),
        ("RimLight",  0.8, (math.radians(-30), 0, math.radians(60))),
    ]:
        d = bpy.data.lights.new(name=name, type='SUN')
        d.energy = energy
        o = bpy.data.objects.new(name, d)
        bpy.context.scene.collection.objects.link(o)
        o.rotation_euler = rot

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.15, 0.15, 0.15, 1.0)
        bg.inputs[1].default_value = 0.5

def make_materials_matte():
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    if 'Roughness' in node.inputs:
                        node.inputs['Roughness'].default_value = 0.25
                    for spec_key in ('Specular IOR Level', 'Specular'):
                        if spec_key in node.inputs:
                            node.inputs[spec_key].default_value = 0.1
                            break

# ══════════════════════════════════════════════════════════════
#  RENDERING
# ══════════════════════════════════════════════════════════════

def render_direction(cam_obj, dir_name: str, angle_deg: float, output_dir: str) -> int:
    dir_folder = os.path.join(output_dir, dir_name)
    os.makedirs(dir_folder, exist_ok=True)

    scene = bpy.context.scene
    frames_rendered = 0
    for frame in range(FRAME_START, FRAME_END + 1, FRAME_STEP):
        scene.frame_set(frame)

        # Re-center camera on the character's actual position this frame.
        # This handles root-motion animations where the rig walks/moves in world space.
        center = get_char_center_this_frame()
        position_camera(cam_obj, angle_deg, center)

        filepath = os.path.join(dir_folder, f"frame_{frame:04d}.png")
        scene.render.filepath = filepath
        bpy.ops.render.render(write_still=True)
        frames_rendered += 1
        print(f"  Rendered {dir_name} frame {frame}/{FRAME_END}  "
              f"(center X={center.x:.2f} Y={center.y:.2f})")
    return frames_rendered

def combine_to_strip(dir_name: str, output_dir: str, num_frames: int) -> None:
    dir_folder  = os.path.join(output_dir, dir_name)
    first_path  = os.path.join(dir_folder, f"frame_{FRAME_START:04d}.png")
    first_img   = bpy.data.images.load(first_path)
    fw, fh      = first_img.size[0], first_img.size[1]
    bpy.data.images.remove(first_img)

    strip_name = f"{ANIM_NAME}_{dir_name}_strip"
    strip = bpy.data.images.new(strip_name, width=fw * num_frames, height=fh, alpha=True)
    strip_pixels = [0.0] * (fw * num_frames * fh * 4)

    frame_idx = 0
    for frame in range(FRAME_START, FRAME_END + 1, FRAME_STEP):
        frame_path = os.path.join(dir_folder, f"frame_{frame:04d}.png")
        frame_img  = bpy.data.images.load(frame_path)
        src_px     = list(frame_img.pixels)
        for y in range(fh):
            for x in range(fw):
                si = (y * fw + x) * 4
                di = (y * (fw * num_frames) + (frame_idx * fw + x)) * 4
                strip_pixels[di:di+4] = src_px[si:si+4]
        bpy.data.images.remove(frame_img)
        frame_idx += 1

    strip.pixels = strip_pixels
    strip_path = os.path.join(output_dir, f"{ANIM_NAME}_{dir_name}.png")
    strip.filepath_raw  = strip_path
    strip.file_format   = 'PNG'
    strip.save()
    bpy.data.images.remove(strip)
    print(f"  Saved strip: {strip_path}")

def combine_to_grid(output_dir: str, num_frames: int) -> None:
    first_dir   = DIRECTIONS[0][0]
    first_path  = os.path.join(output_dir, first_dir, f"frame_{FRAME_START:04d}.png")
    first_img   = bpy.data.images.load(first_path)
    fw, fh      = first_img.size[0], first_img.size[1]
    bpy.data.images.remove(first_img)

    total = num_frames * len(DIRECTIONS)
    rows  = math.ceil(total / GRID_COLS)
    grid  = bpy.data.images.new("spritesheet", width=fw * GRID_COLS, height=fh * rows, alpha=True)
    gpx   = [0.0] * (fw * GRID_COLS * fh * rows * 4)

    gf = 0
    for dir_name, _ in DIRECTIONS:
        dir_folder = os.path.join(output_dir, dir_name)
        for frame in range(FRAME_START, FRAME_END + 1, FRAME_STEP):
            col = gf % GRID_COLS
            row = rows - 1 - (gf // GRID_COLS)
            fp  = os.path.join(dir_folder, f"frame_{frame:04d}.png")
            fi  = bpy.data.images.load(fp)
            fpx = list(fi.pixels)
            for y in range(fh):
                for x in range(fw):
                    si = (y * fw + x) * 4
                    dx, dy = col * fw + x, row * fh + y
                    di = (dy * (fw * GRID_COLS) + dx) * 4
                    if di + 3 < len(gpx):
                        gpx[di:di+4] = fpx[si:si+4]
            bpy.data.images.remove(fi)
            gf += 1

    grid.pixels = gpx
    grid_path = os.path.join(output_dir, f"{ANIM_NAME}_spritesheet.png")
    grid.filepath_raw = grid_path
    grid.file_format  = 'PNG'
    grid.save()
    bpy.data.images.remove(grid)
    print(f"\n  Saved grid: {grid_path}  ({GRID_COLS} cols x {rows} rows)")

# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=" * 60)
    print("  SPRITE RENDERER — MIXAMO EDITION")
    print("=" * 60)
    print()
    print("  Mixamo import tips (if you haven't imported yet):")
    print("    File > Import > FBX")
    print("    Scale = 0.01  (Mixamo rigs export at 100x)")
    print("    Use Pre/Post Rotation: ON")
    print()

    # ── Determine ortho_scale ──────────────────────────────────
    if AUTO_FIT_CAMERA:
        print("[1/7] Scanning bounding box across all animation frames...")
        bbox = world_bbox_all_frames()
        if bbox:
            ortho_scale_final = calc_auto_ortho_scale(bbox)
        else:
            print("  Bounding box scan failed — falling back to manual ORTHO_SCALE")
            ortho_scale_final = ORTHO_SCALE
    else:
        saved = load_camera_config()
        ortho_scale_final = saved if saved is not None else ORTHO_SCALE
        print(f"[1/7] Manual ortho_scale = {ortho_scale_final} (AUTO_FIT_CAMERA is off)")

    print(f"\n  Final ortho_scale: {ortho_scale_final:.3f}")

    # ── Setup ──────────────────────────────────────────────────
    print("\n[2/7] Setting up render settings...")
    setup_render_settings()

    print("[3/7] Setting up camera...")
    cam = setup_camera(ortho_scale_final)

    print("[4/7] Setting up lighting...")
    setup_lighting()

    print("[4.5] Making materials matte...")
    make_materials_matte()

    # ── Render ─────────────────────────────────────────────────
    num_frames = len(range(FRAME_START, FRAME_END + 1, FRAME_STEP))
    print(f"\n[5/7] Rendering {len(DIRECTIONS)} directions x {num_frames} frames...")

    for dir_name, angle in DIRECTIONS:
        print(f"\n  --- {dir_name.upper()} ({angle}°) ---")
        render_direction(cam, dir_name, angle, OUTPUT_DIR)
        combine_to_strip(dir_name, OUTPUT_DIR, num_frames)

    # ── Cleanup individual frame folders ──────────────────────
    print("\n[6/7] Cleaning up frame folders...")
    import shutil
    for dir_name, _ in DIRECTIONS:
        folder = os.path.join(OUTPUT_DIR, dir_name)
        if os.path.isdir(folder):
            shutil.rmtree(folder)
            print(f"  Deleted: {folder}")

    # ── Save config + flip ─────────────────────────────────────
    save_camera_config(ortho_scale_final)

    print("\n[7/7] Generating flipped directions (E->W, NE->NW, SE->SW)...")
    try:
        from PIL import Image as PILImage
        for src_dir, dst_dir in FLIP_MAP.items():
            src = os.path.join(OUTPUT_DIR, f"{ANIM_NAME}_{src_dir}.png")
            dst = os.path.join(OUTPUT_DIR, f"{ANIM_NAME}_{dst_dir}.png")
            if os.path.exists(src):
                PILImage.open(src).transpose(PILImage.FLIP_LEFT_RIGHT).save(dst)
                print(f"  Flipped: {ANIM_NAME}_{src_dir}.png -> {ANIM_NAME}_{dst_dir}.png")
            else:
                print(f"  WARNING: {src} not found")
    except ImportError:
        print("  PIL not available — flip manually (E->W, NE->NW, SE->SW) in GIMP")

    print("\n" + "=" * 60)
    print("  DONE!")
    print(f"  Output: {OUTPUT_DIR}")
    print(f"  ortho_scale used: {ortho_scale_final:.3f}")
    print(f"  Frame size: {FRAME_WIDTH} x {FRAME_HEIGHT}")
    print("=" * 60)

main()
