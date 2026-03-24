extends Node

## AnimBlender — Sets up AnimationTree with upper/lower body split.
## Upper body plays attack/dodge/kd, lower body keeps run/walk.
## Attach to the CoronetPlayer and call setup() after anims are loaded.

var _anim_tree : AnimationTree
var _tree_root : AnimationNodeBlendTree
var _skeleton : Skeleton3D
var _anim_player : AnimationPlayer
var _base_path : String  # e.g. "Armature/Skeleton3D"
var _active := false

func setup(character : Node3D, anim_player : AnimationPlayer, skeleton : Skeleton3D, skel_path : String) -> bool:
	if anim_player == null or skeleton == null:
		return false

	_anim_player = anim_player
	_skeleton = skeleton
	_base_path = skel_path

	# Disable the raw AnimationPlayer — AnimationTree takes over
	_anim_player.active = false

	# Create AnimationTree
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimBlendTree"
	character.add_child(_anim_tree)
	_anim_tree.anim_player = _anim_player.get_path()

	# Create BlendTree root
	_tree_root = AnimationNodeBlendTree.new()
	_anim_tree.tree_root = _tree_root

	# Base animation node (run/idle/walk — plays on full body)
	var base_anim := AnimationNodeAnimation.new()
	base_anim.animation = &"idle"  # default
	_tree_root.add_node("base", base_anim)

	# Upper body overlay animation (attack/dodge/kd)
	var upper_anim := AnimationNodeAnimation.new()
	upper_anim.animation = &"attack"
	_tree_root.add_node("upper", upper_anim)

	# OneShot node — base on input 0, one-shot overlay on input 1
	var one_shot := AnimationNodeOneShot.new()
	_tree_root.add_node("OneShot", one_shot)
	_tree_root.connect_node("OneShot", 0, "base")
	_tree_root.connect_node("OneShot", 1, "upper")
	_tree_root.connect_node("output", 0, "OneShot")

	# Filter upper body bones (from Spine upward)
	one_shot.filter_enabled = true
	var spine_bone := _find_spine_bone()
	if spine_bone != "":
		var upper_paths := _get_bone_and_children_paths(spine_bone)
		for path in upper_paths:
			one_shot.set_filter_path(path, true)
		print("ANIM_BLEND: Filtered ", upper_paths.size(), " upper body bones from '", spine_bone, "'")
	else:
		push_warning("ANIM_BLEND: Could not find spine bone — blending disabled")
		return false

	_anim_tree.active = true
	_active = true
	print("ANIM_BLEND: Setup complete")
	return true

func is_active() -> bool:
	return _active

## Play a base animation (run, walk, idle) — affects full body
func play_base(anim_name : StringName) -> void:
	if not _active:
		return
	var base_node = _tree_root.get_node("base") as AnimationNodeAnimation
	if base_node and _anim_player.has_animation(anim_name):
		base_node.animation = anim_name

## Fire a one-shot upper body animation (attack, dodge)
func fire_upper(anim_name : StringName) -> void:
	if not _active:
		return
	var upper_node = _tree_root.get_node("upper") as AnimationNodeAnimation
	if upper_node and _anim_player.has_animation(anim_name):
		upper_node.animation = anim_name
	_anim_tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

## Check if the one-shot is currently playing
func is_upper_playing() -> bool:
	if not _active:
		return false
	return _anim_tree.get("parameters/OneShot/active") as bool

## Find the best spine bone to split upper/lower body
func _find_spine_bone() -> String:
	# Try common bone names in order of preference
	var candidates := ["Spine1", "Spine2", "spine1", "spine2", "Spine", "spine"]
	for name in candidates:
		if _skeleton.find_bone(name) != -1:
			return name
	# Fallback: find any bone with "spine" in the name
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i)
		if "spine" in bname.to_lower() and "1" in bname:
			return bname
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i)
		if "spine" in bname.to_lower():
			return bname
	return ""

## Get all bone paths from a root bone downward (recursive)
func _get_bone_and_children_paths(bone_name : String) -> Array:
	var result : Array = []
	var idx := _skeleton.find_bone(bone_name)
	if idx == -1:
		return result
	_collect_children(idx, result)
	return result

func _collect_children(index : int, result : Array) -> void:
	var bname := _skeleton.get_bone_name(index)
	result.append(NodePath(_base_path + ":" + bname))
	for child in _skeleton.get_bone_children(index):
		_collect_children(child, result)
