"""
render_launcher.py  —  Headless Blender FBX / GLB Sprite Renderer
==================================================================
Drives render_spritesheet.py from the command line without opening the
Blender UI.  Automatically cleans the default scene, imports the model,
and renders all 8 directions as sprite strips.

Run via batch file or terminal:
  blender --background --python render_launcher.py -- [args]

Required args:
  --fbx    PATH    Path to .fbx/.glb file OR folder containing one
  --output PATH    Output folder for sprite strips
  --anim   NAME    Animation name prefix  (run, idle, attack, …)

Optional args:
  --mode   MODE    meshy | mixamo          (default: mixamo)
  --start  N       First frame             (default: auto from timeline)
  --end    N       Last frame              (default: auto from timeline)
  --step   N       Frame step              (default: 1)
  --width  N       Frame width in px       (default: 512)
  --height N       Frame height in px      (default: auto from mode)
  --scale  F       Force ortho_scale       (default: auto-fit in mixamo)
  --padding F      Auto-fit padding mult   (default: 1.18)
  --chunk  N       Frames per strip chunk  (default: 0 = no limit w/ PIL)
  --no-skip        Re-render existing frames (default: skip existing)

Example:
  blender --background --python render_launcher.py -- ^
      --fbx "C:\\chars\\Bear\\fbx\\fbxrun\\bear_run.fbx" ^
      --output "C:\\chars\\Bear\\run" ^
      --anim run --mode mixamo --start 1 --end 60
"""

import bpy, sys, os, math, json, shutil
from mathutils import Vector

# ══════════════════════════════════════════════════════════════
#  ARG PARSING
# ══════════════════════════════════════════════════════════════

def parse_args() -> dict:
    """Parse arguments that come after '--' in the Blender command line."""
    argv = sys.argv
    args = {}
    if "--" not in argv:
        print("  render_launcher: No '--' separator found in sys.argv.")
        print("  Usage: blender --background --python render_launcher.py -- --fbx ... --output ... --anim ...")
        return args
    argv = argv[argv.index("--") + 1:]
    i = 0
    while i < len(argv):
        key = argv[i].lstrip("-")
        if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
            args[key] = argv[i + 1]
            i += 2
        else:
            args[key] = True
            i += 1
    return args

# ══════════════════════════════════════════════════════════════
#  SCENE SETUP
# ══════════════════════════════════════════════════════════════

def clean_scene() -> None:
    """Delete everything in the default scene (cube, camera, light)."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):   bpy.data.meshes.remove(block)
    for block in list(bpy.data.cameras):  bpy.data.cameras.remove(block)
    for block in list(bpy.data.lights):   bpy.data.lights.remove(block)
    print("  Scene cleared.")

def ensure_addons() -> None:
    """Enable import addons that may not be loaded in background mode."""
    for addon in ("io_scene_fbx", "io_scene_gltf2"):
        try:
            bpy.ops.preferences.addon_enable(module=addon)
        except Exception:
            pass  # Already enabled or not available — either is fine

def force_workbench() -> None:
    """Switch to Workbench renderer which always works headless.
    EEVEE requires a GPU context that may not be available in --background.
    """
    try:
        bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
        print("  Renderer: WORKBENCH (headless-safe)")
    except Exception as e:
        print(f"  WARNING: Could not set renderer: {e}")

def find_model_file(path: str) -> str:
    """Return the .fbx or .glb file path.
    Accepts either a direct file path or a folder (finds first match).
    """
    extensions = (".fbx", ".glb", ".gltf")
    if os.path.isfile(path):
        return path
    if os.path.isdir(path):
        for fname in sorted(os.listdir(path)):
            if fname.lower().endswith(extensions):
                return os.path.join(path, fname)
    return None

def import_model(model_path: str, mode: str) -> None:
    """Import FBX or GLB with settings appropriate for the source."""
    ext = os.path.splitext(model_path)[1].lower()
    if ext == ".fbx":
        scale = 0.01 if mode == "mixamo" else 1.0
        bpy.ops.import_scene.fbx(
            filepath        = model_path,
            global_scale    = scale,
            use_prepost_rot = True,
        )
        print(f"  Imported FBX (scale={scale}): {os.path.basename(model_path)}")
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=model_path)
        print(f"  Imported GLB: {os.path.basename(model_path)}")
    else:
        raise ValueError(f"Unsupported model format: {ext}")

def _iter_action_fcurves(action):
    """Yield fcurves from an action — handles Blender 4.x and 5.0 APIs.

    Blender 4.x: action.fcurves (direct attribute, non-empty)
    Blender 5.0: action.layers[].strips[].channelbags[].fcurves (slotted system)
    If action.fcurves exists but is empty (5.0 compat shim), fall through to
    the layered system so keyframes are not missed.
    """
    # Blender 4.x — only use if it actually contains curves
    if hasattr(action, 'fcurves'):
        curves = list(action.fcurves)
        if curves:
            yield from curves
            return
    # Blender 5.0 layered/slotted actions
    for layer in getattr(action, 'layers', []):
        for strip in getattr(layer, 'strips', []):
            if hasattr(strip, 'fcurves'):
                yield from strip.fcurves
                continue
            for cb in getattr(strip, 'channelbags', []):
                yield from getattr(cb, 'fcurves', [])


def detect_anim_frame_range() -> tuple:
    """Read the actual keyframe extent by scanning f-curve keyframe points.

    Scans bpy.data.actions directly — more reliable than going through
    obj.animation_data.action, which may be None after some FBX imports
    even though the action is in bpy.data.actions.

    Falls back to scene.frame_start/end if no keyframes are found.
    """
    scene = bpy.context.scene
    start = float('inf')
    end   = float('-inf')

    for action in bpy.data.actions:
        for fcurve in _iter_action_fcurves(action):
            for kp in fcurve.keyframe_points:
                if kp.co.x < start: start = kp.co.x
                if kp.co.x > end:   end   = kp.co.x

    if start == float('inf'):
        print("  Frame range: no keyframes found, using scene range")
        return int(scene.frame_start), int(scene.frame_end)

    s, e = int(round(start)), int(round(end))
    print(f"  Detected keyframe range from fcurves: {s}–{e}  "
          f"({e - s + 1} frames)")
    return s, e

# ══════════════════════════════════════════════════════════════
#  RENDER PIPELINE  (mirrors render_spritesheet.py)
# ══════════════════════════════════════════════════════════════

# --- globals set by launcher_main() before calling render_main() ---
MODE          = "meshy"
OUTPUT_DIR    = ""
ANIM_NAME     = "anim"
FRAME_START   = None
FRAME_END     = None
FRAME_STEP    = 1
FRAME_WIDTH   = None
FRAME_HEIGHT  = None
CAM_DISTANCE  = None
CAM_HEIGHT    = None
CHAR_CENTER_Z = None
ORTHO_SCALE   = 2.5
AUTO_FIT_CAMERA = True
ORTHO_PADDING = 1.18
USE_TRANSPARENT = True
SKIP_EXISTING = True
CHUNK_SIZE    = 50      # split strips into N-frame chunks (attack1, attack2…)
DIRECTIONS    = [("s",0),("n",180),("e",270),("ne",225),("se",315)]

def _resolve_defaults():
    global FRAME_WIDTH, FRAME_HEIGHT, CAM_DISTANCE, CAM_HEIGHT, CHAR_CENTER_Z
    mx = (MODE == "mixamo")
    if FRAME_WIDTH   is None: FRAME_WIDTH   = 512
    if FRAME_HEIGHT  is None: FRAME_HEIGHT  = 640  if mx else 512
    if CAM_DISTANCE  is None: CAM_DISTANCE  = 4.5  if mx else 3.0
    if CAM_HEIGHT    is None: CAM_HEIGHT    = 2.8  if mx else 2.0
    if CHAR_CENTER_Z is None: CHAR_CENTER_Z = 0.95 if mx else 0.8

def _config_path():
    return os.path.join(OUTPUT_DIR, f"_{MODE}_camera_config.json")

def save_camera_config(ortho_scale_used):
    cfg = {"mode":MODE,"cam_distance":CAM_DISTANCE,"cam_height":CAM_HEIGHT,
           "char_center_z":CHAR_CENTER_Z,"frame_width":FRAME_WIDTH,
           "frame_height":FRAME_HEIGHT,"ortho_scale":ortho_scale_used}
    with open(_config_path(),"w") as f: json.dump(cfg,f,indent=2)
    print(f"  Config saved: {_config_path()}")

def load_camera_config():
    p = _config_path()
    if not os.path.exists(p): return None
    try:
        with open(p) as f: val = json.load(f).get("ortho_scale")
        print(f"  Loaded {MODE} config: ortho_scale={val}")
        return val
    except Exception: return None

def setup_render_settings():
    scene = bpy.context.scene
    for engine in ['BLENDER_EEVEE_NEXT','BLENDER_EEVEE','BLENDER_WORKBENCH']:
        try: scene.render.engine = engine; break
        except Exception: continue
    scene.render.resolution_x = FRAME_WIDTH
    scene.render.resolution_y = FRAME_HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode  = 'RGBA'
    scene.render.image_settings.compression = 15
    if USE_TRANSPARENT: scene.render.film_transparent = True
    try: scene.eevee.use_bloom = False; scene.eevee.use_motion_blur = False
    except Exception: pass

def setup_camera(ortho_scale):
    cam_name = "SpriteCamera"
    if cam_name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[cam_name], do_unlink=True)
    cam_data = bpy.data.cameras.new(name=cam_name)
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale
    cam_obj = bpy.data.objects.new(cam_name, cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj
    return cam_obj

def setup_lighting():
    for obj in bpy.data.objects:
        if obj.type == 'LIGHT':
            bpy.data.objects.remove(obj, do_unlink=True)
    for name, energy, rot in [
        ("KeyLight",  3.0, (math.radians(45),  0, math.radians(-30))),
        ("FillLight", 1.5, (math.radians(60),  0, math.radians(150))),
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
                    for key in ('Specular IOR Level','Specular'):
                        if key in node.inputs:
                            node.inputs[key].default_value = 0.1; break

def _get_mesh_objects():
    return [o for o in bpy.context.scene.objects
            if o.type == 'MESH' and o.visible_get()]

def get_char_center_this_frame():
    if MODE == "mixamo":
        for obj in bpy.context.scene.objects:
            if obj.type == 'ARMATURE' and obj.visible_get():
                loc = obj.matrix_world.translation
                return Vector((loc.x, loc.y, loc.z + CHAR_CENTER_Z))
        meshes = _get_mesh_objects()
        if meshes:
            pts = [obj.matrix_world @ Vector(c)
                   for obj in meshes for c in obj.bound_box]
            xs = [p.x for p in pts]; ys = [p.y for p in pts]
            return Vector(((min(xs)+max(xs))*0.5,
                           (min(ys)+max(ys))*0.5, CHAR_CENTER_Z))
    return Vector((0.0, 0.0, CHAR_CENTER_Z))

def position_camera(cam_obj, angle_deg, target=None):
    if target is None: target = Vector((0.0, 0.0, CHAR_CENTER_Z))
    a = math.radians(angle_deg)
    cam_obj.location = Vector((
        target.x + math.sin(a) * CAM_DISTANCE,
        target.y - math.cos(a) * CAM_DISTANCE,
        target.z + CAM_HEIGHT,
    ))
    direction = target - cam_obj.location
    cam_obj.rotation_euler = direction.to_track_quat('-Z','Y').to_euler()

def _scan_bbox_relative_to_center():
    scene  = bpy.context.scene
    meshes = _get_mesh_objects()
    if not meshes:
        print("  WARNING: No visible meshes — auto-fit skipped.")
        return None
    INF = float('inf')
    mn = [INF,INF,INF]; mx = [-INF,-INF,-INF]
    step = max(1, (FRAME_END - FRAME_START + 1) // 30)
    for frame in range(FRAME_START, FRAME_END + 1, step):
        scene.frame_set(frame)
        center = get_char_center_this_frame()
        for obj in meshes:
            for corner in obj.bound_box:
                wp  = obj.matrix_world @ Vector(corner)
                rel = [wp.x-center.x, wp.y-center.y, wp.z-center.z]
                for i in range(3):
                    if rel[i] < mn[i]: mn[i] = rel[i]
                    if rel[i] > mx[i]: mx[i] = rel[i]
    print(f"  BBox: X[{mn[0]:.2f},{mx[0]:.2f}] "
          f"Y[{mn[1]:.2f},{mx[1]:.2f}] Z[{mn[2]:.2f},{mx[2]:.2f}]")
    return tuple(mn + mx)

def _calc_auto_ortho_scale(bbox):
    min_x,min_y,min_z,max_x,max_y,max_z = bbox
    aspect   = FRAME_WIDTH / FRAME_HEIGHT
    vertical = max_z - min_z
    xy_diag  = math.sqrt((max_x-min_x)**2 + (max_y-min_y)**2)
    needed   = max(vertical, xy_diag / aspect)
    result   = needed * ORTHO_PADDING
    print(f"  Auto-fit: Z={vertical:.2f} XY_diag={xy_diag:.2f} "
          f"→ ortho_scale={result:.3f} (×{ORTHO_PADDING})")
    return result

def render_direction(cam_obj, dir_name, angle_deg, output_dir):
    dir_folder = os.path.join(output_dir, dir_name)
    os.makedirs(dir_folder, exist_ok=True)
    scene = bpy.context.scene
    rendered = skipped = 0
    for frame in range(FRAME_START, FRAME_END + 1, FRAME_STEP):
        filepath = os.path.join(dir_folder, f"frame_{frame:04d}.png")
        if SKIP_EXISTING and os.path.exists(filepath):
            skipped += 1; continue
        scene.frame_set(frame)
        target = get_char_center_this_frame()
        position_camera(cam_obj, angle_deg, target)
        scene.render.filepath = filepath
        bpy.ops.render.render(write_still=True)
        rendered += 1
        extra = f" center=({target.x:.2f},{target.y:.2f})" if MODE=="mixamo" else ""
        print(f"  {dir_name} {frame}/{FRAME_END}{extra}")
    if skipped: print(f"  Skipped {skipped} existing frames")
    return rendered

def _write_strip_pil(frame_paths, out_path):
    from PIL import Image as PILImage
    first  = PILImage.open(frame_paths[0]).convert("RGBA")
    fw, fh = first.size
    strip  = PILImage.new("RGBA", (fw * len(frame_paths), fh))
    strip.paste(first, (0, 0))
    for i, fp in enumerate(frame_paths[1:], start=1):
        strip.paste(PILImage.open(fp).convert("RGBA"), (i * fw, 0))
    strip.save(out_path)
    print(f"  Saved: {out_path}  ({len(frame_paths)} frames, PIL)")

def _write_strip_blender(frame_paths, out_path):
    first_img = bpy.data.images.load(frame_paths[0])
    fw, fh = first_img.size[0], first_img.size[1]
    n  = len(frame_paths)
    img = bpy.data.images.new(os.path.basename(out_path),
                               width=fw*n, height=fh, alpha=True)
    px = [0.0] * (fw * n * fh * 4)
    for fi, fp in enumerate(frame_paths):
        src    = first_img if fi == 0 else bpy.data.images.load(fp)
        src_px = list(src.pixels)
        for y in range(fh):
            for x in range(fw):
                si = (y*fw+x)*4
                di = (y*fw*n + fi*fw+x)*4
                px[di:di+4] = src_px[si:si+4]
        bpy.data.images.remove(src)
    img.pixels = px
    img.filepath_raw = out_path; img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)
    print(f"  Saved: {out_path}  ({n} frames, Blender fallback)")

def _write_strip(frame_paths, out_path):
    try:    _write_strip_pil(frame_paths, out_path)
    except ImportError: _write_strip_blender(frame_paths, out_path)

def combine_to_strip(dir_name, output_dir, num_frames):
    dir_folder = os.path.join(output_dir, dir_name)
    all_paths  = [os.path.join(dir_folder, f"frame_{f:04d}.png")
                  for f in range(FRAME_START, FRAME_END+1, FRAME_STEP)]
    # CHUNK_SIZE always respected — PIL just removes the memory crash risk,
    # not the intentional splitting into numbered parts.
    chunk = CHUNK_SIZE if CHUNK_SIZE > 0 else num_frames
    try:
        import PIL  # noqa — just confirming it's available for _write_strip
    except ImportError:
        # Without PIL, cap chunk lower to avoid OOM
        if CHUNK_SIZE == 0 or chunk > 40:
            chunk = 40

    results = []
    if num_frames <= chunk:
        out = os.path.join(output_dir, f"{ANIM_NAME}_{dir_name}.png")
        _write_strip(all_paths, out)
        results.append((ANIM_NAME, out))
    else:
        n_parts = math.ceil(num_frames / chunk)
        for pi in range(n_parts):
            sep   = "_" if ANIM_NAME and ANIM_NAME[-1].isdigit() else ""
            label = f"{ANIM_NAME}{sep}{pi+1}"
            paths = all_paths[pi*chunk:(pi+1)*chunk]
            part_dir = os.path.join(output_dir, label)
            os.makedirs(part_dir, exist_ok=True)
            out = os.path.join(part_dir, f"{label}_{dir_name}.png")
            _write_strip(paths, out)
            results.append((label, out))
    return results

def render_main():
    """Full render pipeline — called after scene is set up."""
    global FRAME_START, FRAME_END
    _resolve_defaults()
    scene = bpy.context.scene
    if FRAME_START is None: FRAME_START = scene.frame_start
    if FRAME_END   is None: FRAME_END   = scene.frame_end

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    num_frames    = len(range(FRAME_START, FRAME_END+1, FRAME_STEP))
    total_renders = num_frames * len(DIRECTIONS)

    print("=" * 60)
    print(f"  HEADLESS RENDER  —  {MODE.upper()} MODE")
    print("=" * 60)
    print(f"  Anim:    {ANIM_NAME}")
    print(f"  Frames:  {FRAME_START}–{FRAME_END}  ({num_frames} frames)")
    print(f"  Renders: {total_renders}  ({len(DIRECTIONS)} dirs × {num_frames} frames)")
    print(f"  Output:  {OUTPUT_DIR}")
    print()

    # Ortho scale
    if MODE == "mixamo" and AUTO_FIT_CAMERA:
        print("[1/6] Auto-fitting camera...")
        bbox = _scan_bbox_relative_to_center()
        ortho_scale = _calc_auto_ortho_scale(bbox) if bbox else ORTHO_SCALE
    else:
        saved = load_camera_config()
        ortho_scale = saved if saved is not None else ORTHO_SCALE
        print(f"[1/6] ortho_scale = {ortho_scale}")
    print(f"  → ortho_scale = {ortho_scale:.3f}\n")

    print("[2/6] Render settings...")
    setup_render_settings()
    print("[3/6] Camera...")
    cam = setup_camera(ortho_scale)
    print("[4/6] Lighting + materials...")
    setup_lighting()
    make_materials_matte()

    print(f"\n[5/6] Rendering...")
    dir_results = {}
    for dir_name, angle in DIRECTIONS:
        print(f"\n  --- {dir_name.upper()} ({angle}°) ---")
        render_direction(cam, dir_name, angle, OUTPUT_DIR)
        dir_results[dir_name] = combine_to_strip(dir_name, OUTPUT_DIR, num_frames)

    print("\n[6/6] Cleanup...")
    for dir_name, _ in DIRECTIONS:
        folder = os.path.join(OUTPUT_DIR, dir_name)
        if os.path.isdir(folder):
            shutil.rmtree(folder)
            print(f"  Deleted: {dir_name}/")

    save_camera_config(ortho_scale)

    print("\n" + "=" * 60)
    print("  DONE!")
    print(f"  Output: {OUTPUT_DIR}")
    print("=" * 60)

# ══════════════════════════════════════════════════════════════
#  LAUNCHER ENTRY POINT
# ══════════════════════════════════════════════════════════════

def launcher_main():
    global MODE, OUTPUT_DIR, ANIM_NAME
    global FRAME_START, FRAME_END, FRAME_STEP
    global FRAME_WIDTH, FRAME_HEIGHT
    global ORTHO_SCALE, AUTO_FIT_CAMERA, ORTHO_PADDING
    global SKIP_EXISTING, CHUNK_SIZE

    args = parse_args()

    if not args:
        print("  No args found. Exiting.")
        return

    # ── Required ──────────────────────────────────────────────
    fbx_arg    = args.get("fbx")
    OUTPUT_DIR = args.get("output", "")
    ANIM_NAME  = args.get("anim",   "anim")

    if not fbx_arg:
        print("  ERROR: --fbx is required.")
        return
    if not OUTPUT_DIR:
        print("  ERROR: --output is required.")
        return

    # ── Optional ──────────────────────────────────────────────
    MODE          = args.get("mode",    "meshy")
    FRAME_START   = int(args["start"])  if "start"   in args else None
    FRAME_END     = int(args["end"])    if "end"     in args else None
    FRAME_STEP    = int(args.get("step", 1))
    FRAME_WIDTH   = int(args["width"])  if "width"   in args else None
    FRAME_HEIGHT  = int(args["height"]) if "height"  in args else None
    ORTHO_SCALE   = float(args["scale"]) if "scale"  in args else 2.5
    AUTO_FIT_CAMERA = ("scale" not in args)   # manual scale disables auto-fit
    ORTHO_PADDING = float(args.get("padding", 1.18))
    CHUNK_SIZE    = int(args.get("chunk", 0))
    SKIP_EXISTING = ("no_skip" not in args and "no-skip" not in args)

    # ── Find model file ───────────────────────────────────────
    model_path = find_model_file(fbx_arg)
    if not model_path:
        print(f"  ERROR: No .fbx/.glb file found at: {fbx_arg}")
        return

    print("=" * 60)
    print("  render_launcher.py")
    print("=" * 60)
    print(f"  Model:  {model_path}")
    print(f"  Output: {OUTPUT_DIR}")
    print(f"  Anim:   {ANIM_NAME}  Mode: {MODE}")
    print()

    # ── Scene setup ───────────────────────────────────────────
    print("[0/6] Enabling addons...")
    ensure_addons()

    print("[0/6] Cleaning scene...")
    clean_scene()

    print("[0/6] Setting renderer to Workbench (headless-safe)...")
    force_workbench()

    print("[0/6] Importing model...")
    import_model(model_path, MODE)

    # After import, detect exact frame range from animation keyframes.
    # Reading action.frame_range is more precise than scene.frame_start/end
    # which sometimes includes extra padding frames from the FBX exporter.
    if FRAME_START is None or FRAME_END is None:
        detected_start, detected_end = detect_anim_frame_range()
        if FRAME_START is None: FRAME_START = detected_start
        if FRAME_END   is None: FRAME_END   = detected_end
    print(f"  Frame range: {FRAME_START}–{FRAME_END}  ({FRAME_END - FRAME_START + 1} frames)")

    # ── Render ────────────────────────────────────────────────
    render_main()

launcher_main()
