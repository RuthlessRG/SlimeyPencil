extends Node

## AnimBlender — Upper/lower body split using Blend2 + bone filter in AnimationTree.
##
## Proven pattern from Godot community:
##   - AnimationTree with BlendTree root
##   - Two AnimationNodeAnimation nodes: "base" (run/idle) and "upper" (attack)
##   - Blend2 with filter_enabled = true
##   - Filtered bones (upper body) blend between inputs based on blend_amount
##   - Unfiltered bones (lower body) ALWAYS play input 0 (base)
##   - blend_amount = 0: full body plays base
##   - blend_amount = 1: upper body plays "upper", lower body keeps "base"
##
## CRITICAL: AnimationPlayer.active must be false when AnimationTree is active.
##           NEVER call AnimationPlayer.play() while this blender is active.

var _anim_tree: AnimationTree
var _tree_root: AnimationNodeBlendTree
var _skeleton: Skeleton3D
var _anim_player: AnimationPlayer
var _base_path: String
var _active := false
var _blend_target := 0.0
var _upper_duration := 0.0
var _upper_timer := 0.0

func setup(character: Node3D, anim_player: AnimationPlayer, skeleton: Skeleton3D, skel_path: String) -> bool:
	if anim_player == null or skeleton == null:
		print("ANIM_BLEND: setup failed — null anim_player or skeleton")
		return false

	_anim_player = anim_player
	_skeleton = skeleton
	_base_path = skel_path
	print("ANIM_BLEND: skeleton path = '", skel_path, "'")

	# Print all bone names for debugging
	print("ANIM_BLEND: Skeleton has ", _skeleton.get_bone_count(), " bones:")
	for i in range(_skeleton.get_bone_count()):
		var parent_idx := _skeleton.get_bone_parent(i)
		var parent_name := _skeleton.get_bone_name(parent_idx) if parent_idx >= 0 else "ROOT"
		print("  [", i, "] ", _skeleton.get_bone_name(i), " (parent: ", parent_name, ")")

	# Print animation track paths for verification
	_print_anim_tracks()

	# Create AnimationTree — it takes priority over AnimationPlayer
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimBlendTree"
	character.add_child(_anim_tree)
	# Use relative path from AnimationTree to AnimationPlayer (more reliable)
	_anim_tree.anim_player = _anim_tree.get_path_to(_anim_player)
	print("ANIM_BLEND: anim_player path = '", _anim_tree.anim_player, "'")
	# Stop AnimationPlayer so it doesn't fight with AnimationTree
	# Keep active=true — AnimationTree needs it to read the animation library
	_anim_player.stop()

	# Create BlendTree root
	_tree_root = AnimationNodeBlendTree.new()
	_anim_tree.tree_root = _tree_root

	# Base animation (idle/run/walk — full body or legs-only when blending)
	var base_node := AnimationNodeAnimation.new()
	base_node.animation = &"idle"
	_tree_root.add_node("base", base_node)

	# Upper animation (attack/dizzy — upper body only when blend > 0)
	var upper_node := AnimationNodeAnimation.new()
	upper_node.animation = &"idle"
	_tree_root.add_node("upper", upper_node)

	# TimeSeek — lets us reset upper animation to frame 0 on each fire
	var seek := AnimationNodeTimeSeek.new()
	_tree_root.add_node("seek", seek)
	_tree_root.connect_node("seek", 0, "upper")

	# Blend2 node: input 0 = base, input 1 = upper (via seek)
	var blend := AnimationNodeBlend2.new()
	_tree_root.add_node("blend", blend)
	_tree_root.connect_node("blend", 0, "base")
	_tree_root.connect_node("blend", 1, "seek")
	_tree_root.connect_node("output", 0, "blend")

	# Enable bone filter on Blend2
	blend.filter_enabled = true

	# Find spine bone — the split point between upper and lower body
	var spine_bone := _find_spine_bone()
	if spine_bone == "":
		push_warning("ANIM_BLEND: No spine bone found — falling back to AnimationPlayer")
		return false

	# Build filter paths matching animation track format: "SkeletonPath:BoneName"
	var upper_paths := _get_upper_body_paths(spine_bone)
	print("ANIM_BLEND: Setting filter on ", upper_paths.size(), " upper body paths from '", spine_bone, "':")
	for path in upper_paths:
		blend.set_filter_path(path, true)
		print("  FILTER: ", path)

	# Start with blend = 0 (full body plays base)
	_anim_tree.set("parameters/blend/blend_amount", 0.0)
	_anim_tree.active = true
	_active = true
	print("ANIM_BLEND: Setup complete! Blend2 + filter ready.")
	return true

func _print_anim_tracks() -> void:
	# Print first non-RESET animation's track paths so we can verify filter paths match
	for anim_name in _anim_player.get_animation_list():
		if anim_name == "RESET":
			continue
		var anim := _anim_player.get_animation(anim_name)
		if anim == null:
			continue
		print("ANIM_BLEND: Track paths from animation '", anim_name, "':")
		for i in range(mini(anim.get_track_count(), 10)):  # first 10 tracks
			print("  TRACK[", i, "]: ", anim.track_get_path(i), " type=", anim.track_get_type(i))
		break  # only need one animation to verify paths

func is_active() -> bool:
	return _active

## Set base animation (idle/run/walk) — plays on full body or just legs when blending
func play_base(anim_name: StringName) -> void:
	if not _active or not _anim_player.has_animation(anim_name):
		return
	var node = _tree_root.get_node("base") as AnimationNodeAnimation
	if node and node.animation != anim_name:
		node.animation = anim_name

## Play upper body animation — snap blend to 1.0
func play_upper(anim_name: StringName, duration: float = 0.0) -> void:
	if not _active:
		return
	if not _anim_player.has_animation(anim_name):
		print("BLEND: play_upper SKIP — '", anim_name, "' not found")
		return
	var node = _tree_root.get_node("upper") as AnimationNodeAnimation
	if node:
		node.animation = anim_name
	# Seek upper animation to frame 0 so it replays from the start
	_anim_tree.set("parameters/seek/seek_request", 0.0)
	# Snap blend to 1.0 — upper body shows attack immediately
	_anim_tree.set("parameters/blend/blend_amount", 1.0)
	_blend_target = 1.0
	# Auto-stop after duration
	if duration > 0.0:
		_upper_duration = duration
		_upper_timer = 0.0
	else:
		_upper_duration = 0.0
	print("BLEND: play_upper -> ", anim_name, " dur=", duration)

## Stop upper body — smooth fade back to base (full body)
func stop_upper() -> void:
	_blend_target = 0.0
	_upper_duration = 0.0

## Is upper body currently blending?
func is_upper_playing() -> bool:
	if not _active:
		return false
	var amt: float = _anim_tree.get("parameters/blend/blend_amount")
	return amt > 0.05

func _process(delta: float) -> void:
	if not _active:
		return

	# Auto-stop upper after its duration expires
	if _upper_duration > 0.0:
		_upper_timer += delta
		if _upper_timer >= _upper_duration:
			_blend_target = 0.0
			_upper_duration = 0.0

	# Smooth blend transitions
	var current: float = _anim_tree.get("parameters/blend/blend_amount")
	if _blend_target < current:
		# Fading out — smooth lerp
		var new_val: float = lerpf(current, 0.0, 8.0 * delta)
		if new_val < 0.03:
			new_val = 0.0
		_anim_tree.set("parameters/blend/blend_amount", new_val)
	elif _blend_target > current:
		# Fading in — snap for responsive attacks
		_anim_tree.set("parameters/blend/blend_amount", _blend_target)

# ── BONE DISCOVERY ──────────────────────────────────────────

func _find_spine_bone() -> String:
	# Strategy: find the LOWEST spine bone (direct child of Hips) to include
	# the entire spine chain in the upper body filter.
	# Bone hierarchy is typically: Hips → Spine02 → Spine01 → Spine → shoulders/arms/head
	# We want Spine02 (not Spine) so ALL spine bones get the upper body animation.

	# First, find Hips and get its spine child
	var hips_idx := -1
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i).to_lower()
		if bname == "hips" or bname == "pelvis" or bname == "hip":
			hips_idx = i
			break

	if hips_idx >= 0:
		# Find the child of Hips that contains "spine" — that's the lowest spine bone
		for child_idx in _skeleton.get_bone_children(hips_idx):
			var child_name := _skeleton.get_bone_name(child_idx)
			if "spine" in child_name.to_lower():
				print("ANIM_BLEND: Found lowest spine bone: '", child_name, "' (child of Hips)")
				return child_name

	# Fallback: just find any spine bone
	var candidates := ["Spine02", "Spine01", "Spine2", "Spine1", "spine02", "spine01", "Spine", "spine"]
	for bname in candidates:
		if _skeleton.find_bone(bname) != -1:
			print("ANIM_BLEND: Found spine bone (fallback): '", bname, "'")
			return bname
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i)
		if "spine" in bname.to_lower():
			print("ANIM_BLEND: Found spine bone (last resort): '", bname, "'")
			return bname
	return ""

func _get_upper_body_paths(spine_bone: String) -> Array:
	var result: Array = []
	var idx := _skeleton.find_bone(spine_bone)
	if idx == -1:
		return result
	_collect_children(idx, result)
	return result

func _collect_children(index: int, result: Array) -> void:
	var bname := _skeleton.get_bone_name(index)
	# EXCLUDE Hips/Pelvis — they control root motion, filtering causes flailing
	var lower_name := bname.to_lower()
	if "hip" in lower_name or "pelvis" in lower_name:
		print("ANIM_BLEND: SKIPPING hip/pelvis bone: '", bname, "'")
		return
	result.append(NodePath(_base_path + ":" + bname))
	for child in _skeleton.get_bone_children(index):
		_collect_children(child, result)
