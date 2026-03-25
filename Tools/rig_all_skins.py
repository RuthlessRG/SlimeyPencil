"""
Blender Script: Auto-rig all character skins using RedWedding's armature.

HOW TO USE:
1. Open Blender
2. Go to the Scripting tab
3. Click "Open" and select this file
4. Click "Run Script"
5. Wait for it to finish — rigged FBX files will be saved in each skin's folder

The script will:
- Import RedWedding's BASESKELETONFORALL.fbx to get the armature
- For each unrigged skin, import its FBX, parent to armature with automatic weights
- Export as <SkinName>_rigged.fbx in the skin's folder
"""

import bpy
import os

# ── PATHS ──────────────────────────────────────────────────────────
BASE_DIR = r"C:\Users\ryang\OneDrive\Documents\miniSWG\Coronet\charactercolors"
ARMATURE_FBX = os.path.join(BASE_DIR, "RedWedding", "BASESKELETONFORALL.fbx")

# Skins that need rigging (skin_name: fbx_path relative to BASE_DIR)
SKINS_TO_RIG = {
    "CyberBH": os.path.join(BASE_DIR, "CyberBH", "Meshy_AI_Azure_Sentinel_0324195504_texture_fbx", "Meshy_AI_Azure_Sentinel_0324195504_texture.fbx"),
    "DarkForest": os.path.join(BASE_DIR, "DarkForest", "Meshy_AI_Azure_Sentinel_0324195217_texture_fbx", "Meshy_AI_Azure_Sentinel_0324195217_texture.fbx"),
    "DesertStorm": os.path.join(BASE_DIR, "DesertStorm", "Meshy_AI_Azure_Sentinel_0324195344_texture_fbx", "Meshy_AI_Azure_Sentinel_0324195344_texture.fbx"),
    "GilleCamo": os.path.join(BASE_DIR, "GilleCamo", "Meshy_AI_Azure_Sentinel_0325071735_texture_fbx", "Meshy_AI_Azure_Sentinel_0325071735_texture.fbx"),
    "MoltenCore": os.path.join(BASE_DIR, "MoltenCore", "Meshy_AI_Azure_Sentinel_0324195410_texture_fbx", "Meshy_AI_Azure_Sentinel_0324195410_texture.fbx"),
    "Silverium": os.path.join(BASE_DIR, "Silverium", "Meshy_AI_Azure_Sentinel_0324195433_texture_fbx", "Meshy_AI_Azure_Sentinel_0324195433_texture.fbx"),
    "Tron": os.path.join(BASE_DIR, "Tron", "Meshy_AI_Azure_Sentinel_0325070913_texture_fbx", "Meshy_AI_Azure_Sentinel_0325070913_texture.fbx"),
    "TindremicSteel": os.path.join(BASE_DIR, "TindremicSteel", "Meshy_AI_Azure_Sentinel_0325070948_texture_fbx", "Meshy_AI_Azure_Sentinel_0325070948_texture.fbx"),
}


def clear_scene():
    """Remove all objects from the scene."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=True)
    # Clear orphan data
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.armatures:
        if block.users == 0:
            bpy.data.armatures.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in bpy.data.images:
        if block.users == 0:
            bpy.data.images.remove(block)


def import_fbx(filepath):
    """Import an FBX file and return the imported objects."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=filepath)
    after = set(bpy.data.objects)
    return list(after - before)


def find_armature(objects):
    """Find the armature object in a list of objects."""
    for obj in objects:
        if obj.type == 'ARMATURE':
            return obj
    return None


def find_meshes(objects):
    """Find all mesh objects in a list of objects."""
    return [obj for obj in objects if obj.type == 'MESH']


def rig_skin(skin_name, skin_fbx_path):
    """Rig a single skin using the armature from BASESKELETONFORALL.fbx."""
    print(f"\n{'='*60}")
    print(f"  Rigging: {skin_name}")
    print(f"{'='*60}")

    if not os.path.exists(skin_fbx_path):
        print(f"  SKIP: FBX not found: {skin_fbx_path}")
        return False

    # Start fresh
    clear_scene()

    # Step 1: Import the armature
    print(f"  Importing armature from: {os.path.basename(ARMATURE_FBX)}")
    arm_objects = import_fbx(ARMATURE_FBX)
    armature = find_armature(arm_objects)
    if armature is None:
        print("  ERROR: No armature found in base skeleton FBX!")
        return False
    print(f"  Armature found: {armature.name} ({len(armature.data.bones)} bones)")

    # Remove any meshes that came with the armature (we only want the bones)
    arm_meshes = find_meshes(arm_objects)
    for m in arm_meshes:
        bpy.data.objects.remove(m, do_unlink=True)
    print(f"  Removed {len(arm_meshes)} mesh(es) from armature import")

    # Step 2: Import the skin mesh
    print(f"  Importing skin mesh from: {os.path.basename(skin_fbx_path)}")
    skin_objects = import_fbx(skin_fbx_path)
    skin_meshes = find_meshes(skin_objects)

    # Remove any armature that came with the skin (we use our own)
    skin_arm = find_armature(skin_objects)
    if skin_arm:
        bpy.data.objects.remove(skin_arm, do_unlink=True)
        print("  Removed armature from skin import (using base skeleton)")

    if not skin_meshes:
        print("  ERROR: No meshes found in skin FBX!")
        return False
    print(f"  Found {len(skin_meshes)} mesh(es) in skin")

    # Step 2.5: Apply all transforms and align armature to mesh
    # Apply transforms on armature
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Apply transforms on each mesh
    for mesh_obj in skin_meshes:
        bpy.ops.object.select_all(action='DESELECT')
        mesh_obj.select_set(True)
        bpy.context.view_layer.objects.active = mesh_obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Match armature position/scale to mesh bounds
    import mathutils
    # Find mesh bounding box center and height
    all_verts_z = []
    all_verts_x = []
    all_verts_y = []
    for mesh_obj in skin_meshes:
        for v in mesh_obj.data.vertices:
            co = mesh_obj.matrix_world @ v.co
            all_verts_x.append(co.x)
            all_verts_y.append(co.y)
            all_verts_z.append(co.z)

    if all_verts_z:
        mesh_min_z = min(all_verts_z)
        mesh_max_z = max(all_verts_z)
        mesh_height = mesh_max_z - mesh_min_z
        mesh_center_x = (min(all_verts_x) + max(all_verts_x)) / 2
        mesh_center_y = (min(all_verts_y) + max(all_verts_y)) / 2

        # Find armature bone bounds
        bone_positions_z = []
        for bone in armature.data.bones:
            head_world = armature.matrix_world @ bone.head_local
            tail_world = armature.matrix_world @ bone.tail_local
            bone_positions_z.extend([head_world.z, tail_world.z])

        if bone_positions_z:
            arm_min_z = min(bone_positions_z)
            arm_max_z = max(bone_positions_z)
            arm_height = arm_max_z - arm_min_z

            if arm_height > 0:
                # Scale armature to match mesh height
                scale_factor = mesh_height / arm_height
                armature.scale = (scale_factor, scale_factor, scale_factor)
                print(f"  Scaled armature by {scale_factor:.3f} to match mesh height")

                # Apply the scale
                bpy.ops.object.select_all(action='DESELECT')
                armature.select_set(True)
                bpy.context.view_layer.objects.active = armature
                bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

            # Recalculate bone positions after scale
            bone_positions_z = []
            bone_positions_x = []
            bone_positions_y = []
            for bone in armature.data.bones:
                head_world = armature.matrix_world @ bone.head_local
                bone_positions_z.append(head_world.z)
                bone_positions_x.append(head_world.x)
                bone_positions_y.append(head_world.y)

            # Align armature center to mesh center
            arm_center_x = (min(bone_positions_x) + max(bone_positions_x)) / 2
            arm_center_y = (min(bone_positions_y) + max(bone_positions_y)) / 2
            arm_min_z = min(bone_positions_z)

            armature.location.x += mesh_center_x - arm_center_x
            armature.location.y += mesh_center_y - arm_center_y
            armature.location.z += mesh_min_z - arm_min_z
            print(f"  Aligned armature to mesh (offset: x={armature.location.x:.3f} y={armature.location.y:.3f} z={armature.location.z:.3f})")

            # Apply location
            bpy.ops.object.select_all(action='DESELECT')
            armature.select_set(True)
            bpy.context.view_layer.objects.active = armature
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Step 3: Parent each mesh to the armature with automatic weights
    for mesh_obj in skin_meshes:
        print(f"  Parenting '{mesh_obj.name}' to armature with automatic weights...")

        # Clear any existing parent
        mesh_obj.parent = None
        mesh_obj.matrix_world = mesh_obj.matrix_world

        # Remove existing armature modifiers
        for mod in mesh_obj.modifiers:
            if mod.type == 'ARMATURE':
                mesh_obj.modifiers.remove(mod)

        # Clear existing vertex groups
        mesh_obj.vertex_groups.clear()

        # Select mesh, then armature (armature must be active)
        bpy.ops.object.select_all(action='DESELECT')
        mesh_obj.select_set(True)
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature

        # Parent with automatic weights
        try:
            bpy.ops.object.parent_set(type='ARMATURE_AUTO')
            print(f"    OK — {len(mesh_obj.vertex_groups)} vertex groups created")
        except Exception as e:
            print(f"    WARNING: Auto weights failed ({e}), trying envelope weights...")
            try:
                bpy.ops.object.parent_set(type='ARMATURE_ENVELOPE')
                print(f"    OK (envelope) — {len(mesh_obj.vertex_groups)} vertex groups created")
            except Exception as e2:
                print(f"    ERROR: Could not parent mesh: {e2}")
                return False

    # Step 4: Export as rigged FBX
    output_dir = os.path.join(BASE_DIR, skin_name)
    output_path = os.path.join(output_dir, f"{skin_name}_rigged.fbx")

    # Select armature and all skin meshes for export
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    for mesh_obj in skin_meshes:
        mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    # Copy textures next to the output FBX so they embed properly
    skin_dir = os.path.dirname(skin_fbx_path)
    import shutil
    for f in os.listdir(skin_dir):
        if f.endswith(".png"):
            src = os.path.join(skin_dir, f)
            dst = os.path.join(output_dir, f)
            if not os.path.exists(dst):
                shutil.copy2(src, dst)
                print(f"  Copied texture: {f}")

    print(f"  Exporting to: {output_path}")
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=True,
        apply_scale_options='FBX_SCALE_ALL',
        bake_anim=False,
        add_leaf_bones=False,
        mesh_smooth_type='FACE',
        path_mode='COPY',
        embed_textures=True,
    )
    print(f"  SUCCESS: {skin_name}_rigged.fbx exported!")
    return True


# ── MAIN ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("\n" + "="*60)
    print("  AUTO-RIG ALL SKINS")
    print("="*60)

    if not os.path.exists(ARMATURE_FBX):
        print(f"ERROR: Base skeleton not found: {ARMATURE_FBX}")
    else:
        success = []
        failed = []
        for skin_name, skin_path in SKINS_TO_RIG.items():
            if rig_skin(skin_name, skin_path):
                success.append(skin_name)
            else:
                failed.append(skin_name)

        print("\n" + "="*60)
        print("  RESULTS")
        print("="*60)
        print(f"  Success ({len(success)}): {', '.join(success)}")
        if failed:
            print(f"  Failed  ({len(failed)}): {', '.join(failed)}")
        print("\nDone! Rigged FBX files are in each skin's folder.")
        print("Next: tell Claude to update SKIN_RIGGED_FBX paths in CoronetPlayer.gd")
