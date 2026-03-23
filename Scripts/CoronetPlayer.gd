extends Node3D

## 3D player controller for Coronet scene with combat + HUD.
## Attach to the root "Coronet" node.

# ── MOVEMENT ────────────────────────────────────────────────
const MOVE_SPEED := 5.0
const SPRINT_SPEED := 8.25  # 1.65x move speed
const ROTATION_SPEED := 25.0
const CAM_MOUSE_SENSITIVITY := 0.003
const CAM_DISTANCE := 12.0
const CAM_LOOK_OFFSET := Vector3(0.0, 1.0, 0.0)

# ── SPRINT ─────────────────────────────────────────────────
const SPRINT_DURATION := 15.0
const SPRINT_COOLDOWN := 30.0

# ── VEHICLE ────────────────────────────────────────────────
const VEHICLE_SPEED := 28.0
const VEHICLE_BOOST_SPEED := 70.0
const VEHICLE_FLY_SPEED := 8.0
const VEHICLE_MOUNT_RANGE := 5.0
const VEHICLE_CAM_DISTANCE := 20.0
const VEHICLE_TURN_SPEED := 4.0        # slower than character (25.0)
const VEHICLE_ACCEL := 8.0             # units/s² for normal speed ramp
const VEHICLE_BOOST_ACCEL := 12.0      # units/s² for boost ramp

# ── COMBAT ──────────────────────────────────────────────────
const ATTACK_RANGE_MELEE := 3.0
const ATTACK_RANGE_RANGED := 15.0
const ATTACK_COOLDOWN := 5.0      # seconds between auto-attacks
const ATTACK_ANIM_DURATION := 1.0 # how long attack anim plays before resuming move
const BASE_DAMAGE := 40.0
const TARGET_CYCLE_RANGE := 30.0

# ── ANIMATION FBX PATHS ────────────────────────────────────
const SILVER_ANIMS := {
	"run":     "res://Characters/Coronet/silverarmor/run/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Running_withSkin.fbx",
	"walk":    "res://Characters/Coronet/silverarmor/walk/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Walking_withSkin.fbx",
	"attack":  "res://Characters/Coronet/silverarmor/attack/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Right_Hand_Sword_Slash_withSkin.fbx",
	"attack2": "res://Characters/Coronet/silverarmor/attack2/Meshy_AI_Iron_Sentinel_biped/Meshy_AI_Iron_Sentinel_biped_Animation_Weapon_Combo_1_withSkin.fbx",
	"dodge":   "res://Characters/Coronet/silverarmor/dodge/Meshy_AI_Iron_Sentinel_biped_Animation_Counterstrike_withSkin.fbx",
	"kd":      "res://Characters/Coronet/silverarmor/kd/Meshy_AI_Iron_Sentinel_biped_Animation_Knock_Down_1_withSkin.fbx",
}
const RED_ANIMS := {
	"run":     "res://Characters/Coronet/Redarmor/run/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Running_withSkin.fbx",
	"walk":    "res://Characters/Coronet/Redarmor/walk/Meshy_AI_Ember_Guard_biped/Meshy_AI_Ember_Guard_biped_Animation_Walking_withSkin.fbx",
	"attack":  "res://Characters/Coronet/Redarmor/attack/shootfromhip.fbx",
	"attack2": "res://Characters/Coronet/Redarmor/attack/shootfromhip.fbx",
	"dodge":   "res://Characters/Coronet/Redarmor/dodge/Meshy_AI_Ember_Guard_biped_Animation_Roll_Dodge_3_withSkin.fbx",
	"kd":      "res://Characters/Coronet/Redarmor/kd/Meshy_AI_Ember_Guard_biped_Animation_Knock_Down_1_withSkin.fbx",
}

# ── NODES ───────────────────────────────────────────────────
var _silver : Node3D
var _red    : Node3D
var _camera : Camera3D
var _active : Node3D

var _silver_anim : AnimationPlayer
var _red_anim    : AnimationPlayer
var _silver_armature : Node3D
var _red_armature    : Node3D

# ── CAMERA ──────────────────────────────────────────────────
var _cam_zoom := 1.0
var _cam_yaw := 0.0
var _cam_pitch := 0.6
var _rmb_held := false

# ── PLAYER STATS ────────────────────────────────────────────
var ham_health : float = 1000.0
var max_health : float = 1000.0
var ham_action : float = 800.0
var max_action_stat : float = 800.0
var ham_mind   : float = 600.0
var max_mind   : float = 600.0
var accuracy   : float = 60.0
var defense    : float = 40.0
var character_class : String = "melee"

# Combat states
var state_dizzy : float = 0.0
var state_knockdown : float = 0.0
var state_stun : float = 0.0
var state_blind : float = 0.0
var state_intimidate : float = 0.0

# ── COMBAT ──────────────────────────────────────────────────
var _current_target : Node3D = null
var _auto_attacking := false
var _attack_timer := 0.0
var _attack_anim_timer := 0.0  # countdown for attack anim, then resume move anim
var _attack_cycle := 0         # alternates between 0 and 1 for melee attack swap
var _anim_state := "idle"  # idle, run, attack

# ── VEHICLE ─────────────────────────────────────────────────
var _vehicle_mount : Node3D = null
var _vehicle_base_y := 0.0
var _vehicle_hover_time := 0.0
var _mounted := false
var _mount_tween : Tween = null
var _vehicle_boosting := false
var _vehicle_cur_speed := 0.0  # current speed (ramps up/down)
var _vehicle_last_dir := Vector3.ZERO  # last horizontal movement direction
var _vehicle_prompt : Label3D = null
var _speed_lines : Array = []  # speed effect meshes

# ── SPRINT ────────────────────────────────────────────────
var _sprint_active := false
var _sprint_timer := 0.0
var _sprint_cooldown_timer := 0.0

# ── RAIN ───────────────────────────────────────────────────
var _rain_particles : GPUParticles3D = null
var _rain_audio : AudioStreamPlayer = null
var _rain_enabled := false
var _lightning_timer := 0.0
var _lightning_flash_timer := 0.0
var _lightning_bolt : MeshInstance3D = null

# ── HUD ─────────────────────────────────────────────────────
var _hud : CanvasLayer
var _hp_bar : ProgressBar
var _action_bar : ProgressBar
var _mind_bar : ProgressBar
var _player_name_lbl : Label
var _tgt_panel : Panel
var _tgt_name_lbl : Label
var _tgt_hp_bar : ProgressBar
var _tgt_action_bar : ProgressBar
var _tgt_mind_bar : ProgressBar
var _combat_log : RichTextLabel
var _target_indicator : Node3D  # visual ring under target
var _player_buff_row : HBoxContainer
var _tgt_debuff_row : HBoxContainer

# ── MINIMAP ────────────────────────────────────────────────
const MMAP_SIZE := 180
var _minimap_panel : Panel
var _minimap_draw : Control
var _minimap_zoom := 0.5  # world units per pixel

# ── CHAT ──────────────────────────────────────────────────
var _chat_panel : Panel
var _chat_log : RichTextLabel
var _chat_input : LineEdit
var _chat_visible := true

# ── MULTIPLAYER ───────────────────────────────────────────
var _remote_players : Dictionary = {}  # peer_id -> Node3D

# ── HOTBAR ─────────────────────────────────────────────────
const HOTBAR_SLOTS := 8
const SLOT_SIZE := 44
const SLOT_PAD := 4
var _hotbar_panel : Panel
var _hotbar_slots : Array = []      # Array of Panel (visual slots)
var _hotbar_skills : Array = []     # Array of Dictionary (skill data per slot)
var _hotbar_cooldowns : Array = []  # Array of float (cooldown timers)
var _hotbar_labels : Array = []     # Array of Label (key number labels)
var _hotbar_icons : Array = []      # Array of ColorRect (icon color)
var _hotbar_cd_labels : Array = []  # Array of Label (cooldown text)
# ── SKILLS WINDOW ──────────────────────────────────────────
var _skills_window : Panel = null
var _skills_visible := false

# ── SKILL DEFINITIONS ──────────────────────────────────────
const SKILL_DATA := {
	"dizzy": {
		"id": "dizzy",
		"name": "Dizzy",
		"desc": "Disorients the target for 15 seconds, reducing accuracy.",
		"dmg_mult": 1.0,
		"action_cost": 40.0,
		"state": "dizzy",
		"state_dur": 15.0,
		"cooldown": 0.0,
		"color": Color(0.9, 0.8, 0.2),
	},
	"knockdown": {
		"id": "knockdown",
		"name": "Knockdown",
		"desc": "Knocks the target down. They must press SPACE to stand.",
		"dmg_mult": 1.5,
		"action_cost": 60.0,
		"state": "knockdown",
		"state_dur": 999.0,
		"cooldown": 0.0,
		"color": Color(0.9, 0.3, 0.2),
	},
	"sprint": {
		"id": "sprint",
		"name": "Sprint",
		"desc": "Run 65% faster for 15 seconds.",
		"dmg_mult": 0.0,
		"action_cost": 50.0,
		"state": "",
		"state_dur": 0.0,
		"cooldown": 30.0,
		"color": Color(0.3, 0.8, 1.0),
		"self_cast": true,
	},
	"sensu_bean": {
		"id": "sensu_bean",
		"name": "Sensu Bean",
		"desc": "Heals all HAM pools to full over 10 seconds.",
		"dmg_mult": 0.0,
		"action_cost": 0.0,
		"state": "",
		"state_dur": 0.0,
		"cooldown": 30.0,
		"color": Color(0.2, 0.9, 0.3),
		"self_cast": true,
	},
}

# ── SENSU BEAN (heal over time) ────────────────────────────
var _sensu_active := false
var _sensu_timer := 0.0
const SENSU_DURATION := 10.0

# ── KD IMMUNITY ────────────────────────────────────────────
var _kd_immunity_timer := 0.0
const KD_IMMUNITY_DURATION := 30.0

# ════════════════════════════════════════════════════════════
#  READY
# ════════════════════════════════════════════════════════════
func _ready() -> void:
	for child in get_children():
		var n : String = child.name
		if "Iron_Sentinel" in n:
			_silver = child
		elif "Ember_Guard" in n:
			_red = child

	_camera = $Camera3D

	if _silver:
		_silver_anim = _find_anim_player(_silver)
		_silver_armature = _silver.get_node_or_null("Armature")
		if _silver_armature:
			_silver_armature_rot = _silver_armature.rotation
	if _red:
		_red_anim = _find_anim_player(_red)
		_red_armature = _red.get_node_or_null("Armature")
		if _red_armature:
			_red_armature_rot = _red_armature.rotation

	# Print skeleton bone names for debugging
	if _silver:
		var skel := _find_skeleton(_silver)
		if skel:
			print("SILVER bones: ", _get_bone_names(skel))
	if _red:
		var skel := _find_skeleton(_red)
		if skel:
			print("RED bones: ", _get_bone_names(skel))

	var silver_skel : Skeleton3D = _find_skeleton(_silver) if _silver else null
	var red_skel : Skeleton3D = _find_skeleton(_red) if _red else null
	# Get skeleton path relative to AnimationPlayer for track remapping
	var silver_skel_path := _get_skel_path(_silver_anim, silver_skel)
	var red_skel_path := _get_skel_path(_red_anim, red_skel)
	print("SILVER skel path: ", silver_skel_path)
	print("RED skel path: ", red_skel_path)
	_load_anims(_silver_anim, SILVER_ANIMS, silver_skel, silver_skel_path)
	_load_anims(_red_anim, RED_ANIMS, red_skel, red_skel_path)
	_strip_all_anims(_silver_anim)
	_strip_all_anims(_red_anim)
	_set_loop_modes(_silver_anim)
	_set_loop_modes(_red_anim)

	# Set up NPC-like stats on both characters so they can be targeted
	if _silver:
		_silver.set_meta("ham_health", 1000.0)
		_silver.set_meta("max_hp", 1000.0)
		_silver.set_meta("ham_action", 800.0)
		_silver.set_meta("max_action", 800.0)
		_silver.set_meta("ham_mind", 600.0)
		_silver.set_meta("max_mind", 600.0)
		_silver.set_meta("is_dead", false)
		_silver.set_meta("display_name", "Silver Sentinel")
		_silver.set_meta("accuracy", 60.0)
		_silver.set_meta("defense", 40.0)
	if _red:
		_red.set_meta("ham_health", 1000.0)
		_red.set_meta("max_hp", 1000.0)
		_red.set_meta("ham_action", 800.0)
		_red.set_meta("max_action", 800.0)
		_red.set_meta("ham_mind", 600.0)
		_red.set_meta("max_mind", 600.0)
		_red.set_meta("is_dead", false)
		_red.set_meta("display_name", "Ember Guard")
		_red.set_meta("accuracy", 55.0)
		_red.set_meta("defense", 35.0)

	_active = _silver
	character_class = "melee"
	_play_anim("idle")
	_update_camera(0.0)
	_build_hud()
	_build_hotbar()
	_build_skills_window()
	_build_minimap()
	_build_chat()
	_connect_relay()
	_spawn_test_mobs()
	_setup_vehicle()
	_paint_buildings()
	_setup_rain()

# ════════════════════════════════════════════════════════════
#  ANIMATION HELPERS
# ════════════════════════════════════════════════════════════
func _find_skeleton(root : Node) -> Skeleton3D:
	for child in root.get_children():
		if child is Skeleton3D:
			return child
		for gc in child.get_children():
			if gc is Skeleton3D:
				return gc
			for ggc in gc.get_children():
				if ggc is Skeleton3D:
					return ggc
	return null

func _get_bone_names(skel : Skeleton3D) -> Array:
	var names := []
	for i in range(skel.get_bone_count()):
		names.append(skel.get_bone_name(i))
	return names

func _get_skel_path(ap : AnimationPlayer, skel : Skeleton3D) -> String:
	if ap == null or skel == null:
		return ""
	var root_node : Node = ap.get_node(ap.root_node)
	if root_node == null:
		return ""
	var path : String = str(root_node.get_path_to(skel))
	return path

func _find_anim_player(root : Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer:
			return child
		for gc in child.get_children():
			if gc is AnimationPlayer:
				return gc
			for ggc in gc.get_children():
				if ggc is AnimationPlayer:
					return ggc
	return null

func _load_anims(ap : AnimationPlayer, anim_dict : Dictionary, target_skel : Skeleton3D = null, skel_path : String = "") -> void:
	if ap == null:
		print("LOAD_ANIMS: AnimationPlayer is null!")
		return
	# Build bone name lookup for remapping
	var target_bones := {}  # lowercase stripped name -> actual bone name
	if target_skel:
		for i in range(target_skel.get_bone_count()):
			var bname : String = target_skel.get_bone_name(i)
			# Store with and without common prefixes stripped
			target_bones[bname.to_lower()] = bname
			var stripped : String = bname.replace("mixamorig_", "").replace("mixamorig:", "")
			target_bones[stripped.to_lower()] = bname

	for anim_name in anim_dict:
		var path : String = anim_dict[anim_name]
		if not ResourceLoader.exists(path):
			print("LOAD_ANIMS: file not found: ", path)
			continue
		var scene : PackedScene = load(path)
		if scene == null:
			print("LOAD_ANIMS: could not load: ", path)
			continue
		var temp : Node = scene.instantiate()
		var temp_ap := _find_anim_player(temp)
		if temp_ap == null:
			print("LOAD_ANIMS: no AnimationPlayer in: ", path)
			if temp is AnimationPlayer:
				temp_ap = temp
			else:
				temp.queue_free()
				continue
		var loaded := false
		for src_name in temp_ap.get_animation_list():
			if src_name == "RESET":
				continue
			var anim : Animation = temp_ap.get_animation(src_name)
			if anim:
				var dupe : Animation = anim.duplicate(true)
				# Only remap bone tracks if they don't already match target skeleton
				if target_skel and target_bones.size() > 0:
					if _needs_remap(dupe, target_skel, skel_path):
						_remap_anim_tracks(dupe, target_bones, skel_path)
						print("  -> remapped tracks for '", anim_name, "'")
					else:
						print("  -> tracks already match, no remap for '", anim_name, "'")
				var lib := ap.get_animation_library("")
				if lib == null:
					lib = AnimationLibrary.new()
					ap.add_animation_library("", lib)
				if lib.has_animation(anim_name):
					lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)
				print("LOAD_ANIMS: loaded '", anim_name, "' from '", src_name, "' (", dupe.length, "s, ", dupe.get_track_count(), " tracks)")
				loaded = true
				break
		if not loaded:
			print("LOAD_ANIMS: no valid animation found in: ", path, " anims: ", temp_ap.get_animation_list())
		temp.queue_free()

func _needs_remap(anim : Animation, target_skel : Skeleton3D, _skel_path : String) -> bool:
	# Check if the first bone track already matches the target skeleton
	for i in range(anim.get_track_count()):
		var t := anim.track_get_type(i)
		if t != Animation.TYPE_ROTATION_3D and t != Animation.TYPE_POSITION_3D and t != Animation.TYPE_SCALE_3D:
			continue
		var track_path : String = str(anim.track_get_path(i))
		var colon_idx : int = track_path.rfind(":")
		if colon_idx < 0:
			continue
		var bone_name : String = track_path.substr(colon_idx + 1)
		# Check if this bone exists in the target skeleton
		if target_skel.find_bone(bone_name) >= 0:
			return false  # bones match, no remap needed
		else:
			return true   # first bone doesn't match, needs remap
	return false

func _remap_anim_tracks(anim : Animation, target_bones : Dictionary, skel_path : String = "") -> void:
	for i in range(anim.get_track_count()):
		var track_path : String = str(anim.track_get_path(i))
		var colon_idx : int = track_path.rfind(":")
		if colon_idx < 0:
			continue
		var prefix : String = track_path.substr(0, colon_idx + 1)  # e.g. "Armature/Skeleton3D:"
		var bone_part : String = track_path.substr(colon_idx + 1)
		# Strip mixamorig_ prefix for matching
		var stripped : String = bone_part.replace("mixamorig_", "").replace("mixamorig:", "")
		var lookup : String = stripped.to_lower()
		if lookup in target_bones:
			var new_bone : String = target_bones[lookup]
			# Use target skeleton path if provided, otherwise keep original prefix
			var new_prefix : String = skel_path + ":" if skel_path != "" else prefix
			anim.track_set_path(i, NodePath(new_prefix + new_bone))


func _strip_root_motion(anim : Animation) -> void:
	for i in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			anim.remove_track(i)


func _strip_all_anims(ap : AnimationPlayer) -> void:
	if ap == null:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET":
				continue
			var anim := lib.get_animation(anim_name)
			if anim:
				var dupe : Animation = anim.duplicate(true)
				_strip_root_motion(dupe)
				lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)

func _set_loop_modes(ap : AnimationPlayer) -> void:
	if ap == null:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null or anim_name == "RESET":
				continue
			var lower := anim_name.to_lower()
			if "idle" in lower or "run" in lower or "walk" in lower:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE

func _get_active_anim() -> AnimationPlayer:
	if _active == _silver:
		return _silver_anim
	return _red_anim

func _play_anim(anim_name : String) -> void:
	var ap := _get_active_anim()
	if ap == null:
		return
	if anim_name == "idle":
		for a in ap.get_animation_list():
			if a != "RESET" and a not in ["run","walk","attack","attack2","dodge","kd"]:
				if ap.current_animation != a:
					ap.play(a)
				return
	if ap.has_animation(anim_name):
		ap.stop()
		ap.play(anim_name)
	else:
		print("ANIM NOT FOUND: ", anim_name, " available: ", ap.get_animation_list())

func _play_anim_on_node(node : Node3D, anim_name : String) -> void:
	# Play an animation on a specific character node (not necessarily the active one)
	var ap : AnimationPlayer = null
	if node == _silver:
		ap = _silver_anim
	elif node == _red:
		ap = _red_anim
	else:
		return  # mobs don't have loaded anims yet
	if ap == null:
		return
	if ap.has_animation(anim_name):
		ap.stop()
		ap.play(anim_name)

# ════════════════════════════════════════════════════════════
#  BUILDINGS
# ════════════════════════════════════════════════════════════
func _paint_buildings() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.27, 1.0)
	mat.roughness = 0.95
	mat.metallic = 0.0
	for child in get_children():
		if "starport" in child.name.to_lower() or "building" in child.name.to_lower():
			_apply_mat_recursive(child, mat)

func _apply_mat_recursive(node : Node, mat : StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_mat_recursive(child, mat)

# ════════════════════════════════════════════════════════════
#  RAIN
# ════════════════════════════════════════════════════════════
func _setup_rain() -> void:
	_rain_particles = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, -30, 0)
	# Emit from a wide box above the player
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(25, 0.5, 25)
	mat.scale_min = 1.0
	mat.scale_max = 1.0
	mat.color = Color(0.75, 0.8, 0.9, 0.5)
	_rain_particles.process_material = mat
	_rain_particles.amount = 6000
	_rain_particles.lifetime = 1.2
	_rain_particles.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	# Raindrop mesh — thin stretched box
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.03, 0.5, 0.03)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.7, 0.75, 0.85, 0.4)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mesh.material = drop_mat
	_rain_particles.draw_pass_1 = drop_mesh
	_rain_particles.emitting = false
	add_child(_rain_particles)

	# Audio — looping rain sound
	_rain_audio = AudioStreamPlayer.new()
	var stream = load("res://Sounds/rain.mp3")
	if stream:
		_rain_audio.stream = stream
		_rain_audio.volume_db = -6.0
	add_child(_rain_audio)

func _toggle_rain() -> void:
	_rain_enabled = !_rain_enabled
	if _rain_particles:
		_rain_particles.emitting = _rain_enabled
	if _rain_audio and _rain_audio.stream:
		if _rain_enabled:
			_rain_audio.play()
		else:
			_rain_audio.stop()
	# Darken scene for storm effect
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node is WorldEnvironment and env_node.environment:
		var env : Environment = env_node.environment
		if _rain_enabled:
			env.ambient_light_energy = 0.45
			env.tonemap_white = 1.5
			env.fog_enabled = true
			env.fog_light_color = Color(0.4, 0.42, 0.48)
			env.fog_density = 0.015
			env.volumetric_fog_enabled = false
		else:
			env.ambient_light_energy = 0.5
			env.tonemap_white = 1.0
			env.fog_enabled = false
	# Darken sun for storm
	var sun = get_node_or_null("Sun")
	if sun and sun is DirectionalLight3D:
		if _rain_enabled:
			sun.light_energy = 0.6
			sun.light_color = Color(0.6, 0.62, 0.7)
		else:
			sun.light_energy = 1.0
			sun.light_color = Color(1, 1, 1)
	# Darken sky
	var sky_mat = null
	if env_node and env_node is WorldEnvironment and env_node.environment and env_node.environment.sky:
		sky_mat = env_node.environment.sky.sky_material
	if sky_mat and sky_mat is ProceduralSkyMaterial:
		if _rain_enabled:
			sky_mat.sky_top_color = Color(0.25, 0.28, 0.35)
			sky_mat.sky_horizon_color = Color(0.35, 0.38, 0.42)
			sky_mat.ground_horizon_color = Color(0.3, 0.32, 0.36)
		else:
			sky_mat.sky_top_color = Color(0.25, 0.47, 0.85)
			sky_mat.sky_horizon_color = Color(0.55, 0.7, 0.9)
			sky_mat.ground_horizon_color = Color(0.45, 0.55, 0.7)
	print("Rain: ", "ON" if _rain_enabled else "OFF")

# ════════════════════════════════════════════════════════════
#  VEHICLE
# ════════════════════════════════════════════════════════════
func _setup_vehicle() -> void:
	for child in get_children():
		if "vehiclemount" in child.name.to_lower() or "vehicle" in child.name.to_lower():
			_vehicle_mount = child
			_vehicle_base_y = child.position.y
			break
	# Also check under Ground node
	if _vehicle_mount == null:
		var ground := get_node_or_null("Ground")
		if ground:
			for child in ground.get_children():
				if "vehicle" in child.name.to_lower():
					_vehicle_mount = child
					_vehicle_base_y = child.position.y
					break
	if _vehicle_mount:
		print("Vehicle mount found: ", _vehicle_mount.name, " base_y=", _vehicle_base_y)

func _tick_vehicle_hover(delta : float) -> void:
	if _vehicle_mount == null or not is_instance_valid(_vehicle_mount):
		return
	_vehicle_hover_time += delta
	var hover_offset := sin(_vehicle_hover_time * 1.5) * 0.3
	if not _mounted:
		_vehicle_mount.position.y = _vehicle_base_y + hover_offset
	# When mounted, hover bob is applied on top of current Y in the movement code

func _toggle_mount() -> void:
	if _vehicle_mount == null or not is_instance_valid(_vehicle_mount):
		_log_combat("[color=gray]No vehicle nearby[/color]")
		return

	if _mounted:
		# ── DISMOUNT ──
		_mounted = false
		# Fade character back in
		_set_character_visible(_active, true)
		# Place character next to vehicle
		var dismount_side := _vehicle_mount.global_transform.basis.z.normalized()
		_active.position = _vehicle_mount.position + dismount_side * 3.0
		_active.position.y = 0.0
		# Raise idle vehicle slightly
		_vehicle_base_y = 5.0
		_vehicle_mount.position.y = _vehicle_base_y
		# Clean ion glow
		if _ion_glow and is_instance_valid(_ion_glow):
			_ion_glow.queue_free()
			_ion_glow = null
		_play_anim("idle")
		_anim_state = "idle"
		_log_combat("[color=yellow]Dismounted vehicle.[/color]")
	else:
		# ── MOUNT ──
		var dist := _active.global_position.distance_to(_vehicle_mount.global_position)
		if dist > VEHICLE_MOUNT_RANGE:
			_log_combat("[color=gray]Too far from vehicle (get closer)[/color]")
			return
		_mounted = true
		# Remove prompt
		if _vehicle_prompt and is_instance_valid(_vehicle_prompt):
			_vehicle_prompt.queue_free()
			_vehicle_prompt = null
		# Stop combat
		_auto_attacking = false
		_current_target = null
		_update_target_indicator()
		# Fade character out
		_set_character_visible(_active, false)
		# Move vehicle to player's position
		_vehicle_mount.position.x = _active.position.x
		_vehicle_mount.position.z = _active.position.z
		_vehicle_base_y = 5.0  # match dismount height
		_vehicle_cur_speed = 0.0
		# Create ion engine glow
		_create_ion_glow()
		_vehicle_mount.position.y = _vehicle_base_y
		_log_combat("[color=yellow]Mounted vehicle! WASD to move, SPACE/CTRL to fly up/down, F to dismount.[/color]")

func _set_character_visible(character : Node3D, vis : bool) -> void:
	if character == null:
		return
	# Find MeshInstance3D children and toggle visibility
	for child in character.get_children():
		_set_node_visible_recursive(child, vis)

func _set_node_visible_recursive(node : Node, vis : bool) -> void:
	if node is MeshInstance3D:
		node.visible = vis
	for child in node.get_children():
		_set_node_visible_recursive(child, vis)

var _ion_glow : Node3D = null
var _ion_glow_mat : StandardMaterial3D = null

func _create_ion_glow() -> void:
	if _ion_glow and is_instance_valid(_ion_glow):
		return  # already exists
	if _vehicle_mount == null:
		return
	_ion_glow = Node3D.new()
	_ion_glow.name = "IonGlow"
	_vehicle_mount.add_child(_ion_glow)
	_ion_glow.position = Vector3(0.73, -0.05, 0.0)

	# Layer 1: Inner white-hot core
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.95)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.8, 0.9, 1.0)
	core_mat.emission_energy_multiplier = 25.0
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	core_mesh.material = core_mat
	core.mesh = core_mesh
	core.name = "Core"
	_ion_glow.add_child(core)

	# Layer 2: Mid glow (blue-white)
	var mid := MeshInstance3D.new()
	var mid_mesh := SphereMesh.new()
	mid_mesh.radius = 0.35
	mid_mesh.height = 0.7
	_ion_glow_mat = StandardMaterial3D.new()
	_ion_glow_mat.albedo_color = Color(0.3, 0.6, 1.0, 0.6)
	_ion_glow_mat.emission_enabled = true
	_ion_glow_mat.emission = Color(0.2, 0.5, 1.0)
	_ion_glow_mat.emission_energy_multiplier = 12.0
	_ion_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ion_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ion_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mid_mesh.material = _ion_glow_mat
	mid.mesh = mid_mesh
	mid.name = "MidGlow"
	_ion_glow.add_child(mid)

	# Layer 3: Outer halo
	var outer := MeshInstance3D.new()
	var outer_mesh := SphereMesh.new()
	outer_mesh.radius = 0.7
	outer_mesh.height = 1.4
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.15, 0.35, 0.9, 0.2)
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.1, 0.3, 0.8)
	outer_mat.emission_energy_multiplier = 6.0
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	outer_mesh.material = outer_mat
	outer.mesh = outer_mesh
	outer.name = "OuterHalo"
	_ion_glow.add_child(outer)

	# Layer 4: Exhaust particles
	var particles := GPUParticles3D.new()
	particles.name = "ExhaustParticles"
	particles.amount = 30
	particles.lifetime = 0.4
	particles.explosiveness = 0.1
	particles.fixed_fps = 60
	var p_mat := ParticleProcessMaterial.new()
	p_mat.direction = Vector3(1, 0, 0)
	p_mat.spread = 15.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3.ZERO
	p_mat.scale_min = 0.03
	p_mat.scale_max = 0.08
	p_mat.color = Color(0.4, 0.7, 1.0, 0.8)
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.8, 0.9, 1.0, 1.0))
	color_ramp.set_color(1, Color(0.2, 0.4, 1.0, 0.0))
	var color_tex := GradientTexture1D.new()
	color_tex.gradient = color_ramp
	p_mat.color_ramp = color_tex
	particles.process_material = p_mat
	var p_draw := SphereMesh.new()
	p_draw.radius = 0.04
	p_draw.height = 0.08
	var p_draw_mat := StandardMaterial3D.new()
	p_draw_mat.albedo_color = Color(0.5, 0.7, 1.0, 0.9)
	p_draw_mat.emission_enabled = true
	p_draw_mat.emission = Color(0.3, 0.6, 1.0)
	p_draw_mat.emission_energy_multiplier = 8.0
	p_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_draw.material = p_draw_mat
	particles.draw_pass_1 = p_draw
	_ion_glow.add_child(particles)

func _tick_ion_glow() -> void:
	if _ion_glow == null or not is_instance_valid(_ion_glow) or _ion_glow_mat == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var speed_frac := clampf(_vehicle_cur_speed / VEHICLE_BOOST_SPEED, 0.0, 1.0)
	var glow_scale := lerpf(0.4, 1.0, speed_frac)
	var glow_energy := lerpf(4.0, 18.0, speed_frac)

	var pulse := glow_energy + sin(t * 6.0) * (2.0 + speed_frac * 3.0)
	_ion_glow_mat.emission_energy_multiplier = pulse
	_ion_glow_mat.emission = Color(0.2, 0.45 + sin(t * 3.0) * 0.1, 1.0)

	var core_node = _ion_glow.get_node_or_null("Core")
	var mid_node = _ion_glow.get_node_or_null("MidGlow")
	var outer_node = _ion_glow.get_node_or_null("OuterHalo")
	if core_node:
		var cs := glow_scale * (0.9 + sin(t * 20.0) * 0.1)
		core_node.scale = Vector3(cs, cs, cs)
		# Also dim/brighten core material
		var core_mat = core_node.mesh.material as StandardMaterial3D
		if core_mat:
			core_mat.emission_energy_multiplier = lerpf(5.0, 25.0, speed_frac)
			core_mat.albedo_color.a = lerpf(0.3, 0.95, speed_frac)
	if mid_node:
		mid_node.scale = Vector3(glow_scale, glow_scale, glow_scale)
		_ion_glow_mat.albedo_color.a = lerpf(0.15, 0.6, speed_frac)
	if outer_node:
		outer_node.scale = Vector3(glow_scale, glow_scale, glow_scale)
		var outer_mat = outer_node.mesh.material as StandardMaterial3D
		if outer_mat:
			outer_mat.emission_energy_multiplier = lerpf(1.0, 6.0, speed_frac)
			outer_mat.albedo_color.a = lerpf(0.05, 0.2, speed_frac)

func _tick_speed_lines(_delta : float, active : bool) -> void:
	# Clean old speed lines
	for line in _speed_lines:
		if is_instance_valid(line):
			line.queue_free()
	_speed_lines.clear()

	if not active or _vehicle_mount == null:
		return

	var vpos := _vehicle_mount.global_position
	var forward := -_vehicle_mount.global_transform.basis.x.normalized()

	# ── SPEED LINES ──
	for i in range(12):
		var line := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = randf_range(2.0, 5.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.9, 1.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.85, 1.0)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cyl.material = mat
		line.mesh = cyl
		add_child(line)
		var behind := -forward * randf_range(2.0, 5.0)
		var scatter := Vector3(randf_range(-1.5, 1.5), randf_range(-0.8, 1.0), randf_range(-1.5, 1.5))
		line.global_position = vpos + behind + scatter
		line.look_at(line.global_position + forward)
		line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_speed_lines.append(line)
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
		tw.tween_callback(func():
			if is_instance_valid(line):
				line.queue_free()
		)

func _tick_rain() -> void:
	if not _rain_enabled:
		return
	if _rain_particles and _active:
		_rain_particles.global_position = _active.global_position + Vector3(0, 15, 0)

	# Lightning system
	var delta := get_process_delta_time()
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(4.0, 12.0)
		_trigger_lightning()

	# Flash fade out
	if _lightning_flash_timer > 0.0:
		_lightning_flash_timer -= delta
		if _lightning_flash_timer <= 0.0:
			# Restore storm lighting
			var sun = get_node_or_null("Sun")
			if sun and sun is DirectionalLight3D:
				sun.light_energy = 0.4
			# Remove bolt
			if _lightning_bolt and is_instance_valid(_lightning_bolt):
				_lightning_bolt.queue_free()
				_lightning_bolt = null

func _trigger_lightning() -> void:
	if not _active:
		return
	# Flash — briefly max out the sun
	var sun = get_node_or_null("Sun")
	if sun and sun is DirectionalLight3D:
		sun.light_energy = 4.0
	_lightning_flash_timer = 0.15

	# Create a lightning bolt mesh
	if _lightning_bolt and is_instance_valid(_lightning_bolt):
		_lightning_bolt.queue_free()
	_lightning_bolt = MeshInstance3D.new()
	var bolt_mesh := BoxMesh.new()
	bolt_mesh.size = Vector3(0.15, 20.0, 0.15)
	_lightning_bolt.mesh = bolt_mesh
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.9, 0.92, 1.0, 0.9)
	bolt_mat.emission_enabled = true
	bolt_mat.emission = Color(0.8, 0.85, 1.0)
	bolt_mat.emission_energy_multiplier = 8.0
	bolt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt_mesh.material = bolt_mat
	var offset := Vector3(randf_range(-20, 20), 10, randf_range(-20, 20))
	_lightning_bolt.global_position = _active.global_position + offset
	# Slight random tilt
	_lightning_bolt.rotation.x = randf_range(-0.1, 0.1)
	_lightning_bolt.rotation.z = randf_range(-0.15, 0.15)
	add_child(_lightning_bolt)

# ════════════════════════════════════════════════════════════
#  TEST MOBS
# ════════════════════════════════════════════════════════════
func _spawn_machine_walker() -> void:
	var mw := Node3D.new()
	mw.set_script(load("res://Scripts/MachineWalker.gd"))
	mw.name = "MachineWalker_" + str(randi() % 9999)
	add_child(mw)
	# Spawn 8 units in front of player (based on camera facing direction)
	var cam_forward := -_camera.global_transform.basis.z.normalized()
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	mw.global_position = _active.global_position + cam_forward * 8.0
	mw.position.y = 0.0
	_log_combat("[color=green]Machine Walker spawned![/color]")

func _spawn_test_mobs() -> void:
	var mob_positions := [
		Vector3(8.0, 0.0, 0.0),
		Vector3(-6.0, 0.0, -5.0),
		Vector3(3.0, 0.0, -10.0),
	]
	var mob_names := ["Rogue Sentry", "Patrol Droid", "Outlaw Scout"]
	for i in range(mob_positions.size()):
		var mob := Node3D.new()
		mob.set_script(load("res://Scripts/CoronetMob.gd"))
		mob.name = mob_names[i]
		mob.set("mob_name", mob_names[i])
		mob.set("max_hp", 300.0 + i * 100.0)
		mob.set("max_action", 200.0)
		mob.set("max_mind", 150.0)
		mob.set("level", 3 + i * 2)
		add_child(mob)
		mob.global_position = mob_positions[i]

		# Create a simple visual — colored cube
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 1.8, 0.8)
		mesh_inst.mesh = box
		mesh_inst.position.y = 0.9
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.2, 0.2, 1.0) if i == 0 else (Color(0.2, 0.6, 0.8, 1.0) if i == 1 else Color(0.7, 0.5, 0.2, 1.0))
		mesh_inst.material_override = mat
		mob.add_child(mesh_inst)

		# Name label above mob
		var lbl3d := Label3D.new()
		lbl3d.text = mob_names[i] + " [Lv" + str(3 + i * 2) + "]"
		lbl3d.position.y = 2.2
		lbl3d.font_size = 32
		lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl3d.modulate = Color(1.0, 0.8, 0.3, 1.0)
		mob.add_child(lbl3d)

# ════════════════════════════════════════════════════════════
#  HUD
# ════════════════════════════════════════════════════════════
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	# ── Player Frame ──
	var pf := Panel.new()
	pf.position = Vector2(10, 10)
	pf.size = Vector2(220, 72)
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.04, 0.04, 0.04, 0.88)
	pf_style.border_color = Color(0.25, 0.25, 0.3)
	pf_style.set_border_width_all(1)
	pf_style.set_corner_radius_all(4)
	pf.add_theme_stylebox_override("panel", pf_style)
	_hud.add_child(pf)

	_player_name_lbl = Label.new()
	_player_name_lbl.text = "Silver Sentinel"
	_player_name_lbl.position = Vector2(8, 2)
	_player_name_lbl.add_theme_font_size_override("font_size", 11)
	pf.add_child(_player_name_lbl)

	_hp_bar = _make_bar(pf, Vector2(8, 20), Vector2(204, 14), Color(0.8, 0.15, 0.15))
	_action_bar = _make_bar(pf, Vector2(8, 36), Vector2(204, 14), Color(0.85, 0.75, 0.1))
	_mind_bar = _make_bar(pf, Vector2(8, 52), Vector2(204, 14), Color(0.15, 0.4, 0.85))

	# ── Player Buff/Debuff Row ──
	_player_buff_row = HBoxContainer.new()
	_player_buff_row.position = Vector2(10, 84)
	_hud.add_child(_player_buff_row)

	# ── Target Frame ──
	_tgt_panel = Panel.new()
	_tgt_panel.position = Vector2(300, 10)
	_tgt_panel.size = Vector2(250, 82)
	var tgt_style := StyleBoxFlat.new()
	tgt_style.bg_color = Color(0.04, 0.04, 0.04, 0.88)
	tgt_style.border_color = Color(0.25, 0.25, 0.3)
	tgt_style.set_border_width_all(1)
	tgt_style.set_corner_radius_all(4)
	_tgt_panel.add_theme_stylebox_override("panel", tgt_style)
	_tgt_panel.visible = false
	_hud.add_child(_tgt_panel)

	_tgt_name_lbl = Label.new()
	_tgt_name_lbl.text = ""
	_tgt_name_lbl.position = Vector2(8, 2)
	_tgt_name_lbl.add_theme_font_size_override("font_size", 11)
	_tgt_panel.add_child(_tgt_name_lbl)

	_tgt_hp_bar = _make_bar(_tgt_panel, Vector2(8, 22), Vector2(234, 14), Color(0.8, 0.15, 0.15))
	_tgt_action_bar = _make_bar(_tgt_panel, Vector2(8, 40), Vector2(234, 14), Color(0.85, 0.75, 0.1))
	_tgt_mind_bar = _make_bar(_tgt_panel, Vector2(8, 58), Vector2(234, 14), Color(0.15, 0.4, 0.85))

	# ── Target Debuff Row ──
	_tgt_debuff_row = HBoxContainer.new()
	_tgt_debuff_row.position = Vector2(300, 94)
	_hud.add_child(_tgt_debuff_row)

	# ── Combat Log ──
	_combat_log = RichTextLabel.new()
	_combat_log.position = Vector2(10, 500)
	_combat_log.size = Vector2(400, 150)
	_combat_log.bbcode_enabled = true
	_combat_log.scroll_following = true
	_combat_log.modulate = Color(1, 1, 1, 0.7)
	_combat_log.add_theme_font_size_override("normal_font_size", 11)
	_hud.add_child(_combat_log)

func _make_bar(parent : Control, pos : Vector2, sz : Vector2, color : Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.custom_minimum_size = sz
	bar.size = sz
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	bar.add_theme_stylebox_override("fill", sb)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar.add_theme_stylebox_override("background", sb_bg)
	parent.add_child(bar)
	return bar

func _log_combat(text : String) -> void:
	if _combat_log:
		_combat_log.append_text(text + "\n")

# ════════════════════════════════════════════════════════════
#  HOTBAR
# ════════════════════════════════════════════════════════════
func _build_hotbar() -> void:
	var vp := get_viewport().get_visible_rect().size
	var total_w : float = HOTBAR_SLOTS * (SLOT_SIZE + SLOT_PAD) - SLOT_PAD
	_hotbar_panel = Panel.new()
	_hotbar_panel.position = Vector2((vp.x - total_w) * 0.5, vp.y - SLOT_SIZE - 20)
	_hotbar_panel.size = Vector2(total_w + 16, SLOT_SIZE + 16)
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	hb_style.border_color = Color(0.3, 0.3, 0.35)
	hb_style.set_border_width_all(1)
	hb_style.set_corner_radius_all(4)
	_hotbar_panel.add_theme_stylebox_override("panel", hb_style)
	_hud.add_child(_hotbar_panel)

	_hotbar_slots.clear()
	_hotbar_skills.clear()
	_hotbar_cooldowns.clear()
	_hotbar_labels.clear()
	_hotbar_icons.clear()
	_hotbar_cd_labels.clear()

	for i in range(HOTBAR_SLOTS):
		var slot := Panel.new()
		slot.position = Vector2(8 + i * (SLOT_SIZE + SLOT_PAD), 8)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		slot_style.border_color = Color(0.35, 0.35, 0.4)
		slot_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", slot_style)
		_hotbar_panel.add_child(slot)
		_hotbar_slots.append(slot)

		# Key number label
		var key_lbl := Label.new()
		key_lbl.text = str(i + 1)
		key_lbl.position = Vector2(2, 1)
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot.add_child(key_lbl)
		_hotbar_labels.append(key_lbl)

		# Skill icon (colored rect)
		var icon := ColorRect.new()
		icon.position = Vector2(6, 12)
		icon.size = Vector2(32, 28)
		icon.color = Color(0, 0, 0, 0)
		slot.add_child(icon)
		_hotbar_icons.append(icon)

		# Cooldown label
		var cd_lbl := Label.new()
		cd_lbl.text = ""
		cd_lbl.position = Vector2(8, 14)
		cd_lbl.add_theme_font_size_override("font_size", 14)
		cd_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		cd_lbl.visible = false
		slot.add_child(cd_lbl)
		_hotbar_cd_labels.append(cd_lbl)

		_hotbar_skills.append({})
		_hotbar_cooldowns.append(0.0)

	# Pre-load dizzy on slot 1, knockdown on slot 2
	_set_hotbar_slot(0, SKILL_DATA["dizzy"])
	_set_hotbar_slot(1, SKILL_DATA["knockdown"])

func _set_hotbar_slot(idx : int, skill : Dictionary) -> void:
	if idx < 0 or idx >= HOTBAR_SLOTS:
		return
	_hotbar_skills[idx] = skill
	if skill.is_empty():
		_hotbar_icons[idx].color = Color(0, 0, 0, 0)
	else:
		_hotbar_icons[idx].color = skill.get("color", Color(0.5, 0.5, 0.5))

func _activate_hotbar_slot(idx : int) -> void:
	if idx < 0 or idx >= HOTBAR_SLOTS:
		return
	var skill : Dictionary = _hotbar_skills[idx]
	if skill.is_empty():
		return
	# Check cooldown
	if _hotbar_cooldowns[idx] > 0.0:
		_log_combat("[color=gray]" + skill.get("name", "") + " is on cooldown (" + str(int(_hotbar_cooldowns[idx])) + "s)[/color]")
		return
	# Self-cast skills (like Sensu Bean)
	var is_self_cast : bool = skill.get("self_cast", false)
	if not is_self_cast:
		# Check target
		if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
			_log_combat("[color=gray]No valid target[/color]")
			return
		# Check range
		var dist : float = _active.global_position.distance_to(_current_target.global_position)
		var atk_range : float = ATTACK_RANGE_MELEE if character_class == "melee" else ATTACK_RANGE_RANGED
		if dist > atk_range:
			_log_combat("[color=gray]Target out of range[/color]")
			return
	# Check action cost
	var cost : float = skill.get("action_cost", 0.0)
	if ham_action < cost:
		_log_combat("[color=gray]Not enough action[/color]")
		return
	# Spend action
	ham_action -= cost
	# Start cooldown
	_hotbar_cooldowns[idx] = skill.get("cooldown", 10.0)

	# Handle self-cast skills
	if is_self_cast:
		if skill.get("id", "") == "sensu_bean":
			_sensu_active = true
			_sensu_timer = SENSU_DURATION
			_log_combat("[color=green]Sensu Bean activated! Healing over " + str(int(SENSU_DURATION)) + "s[/color]")
			_spawn_damage_text(_active, "SENSU BEAN", Color(0.2, 1.0, 0.3))
			_spawn_heal_effect(_active)
		elif skill.get("id", "") == "sprint":
			_sprint_active = true
			_sprint_timer = SPRINT_DURATION
			_log_combat("[color=aqua]Sprint activated! Moving 65% faster for " + str(int(SPRINT_DURATION)) + "s[/color]")
			_spawn_damage_text(_active, "SPRINT", Color(0.3, 0.8, 1.0))
		return

	# Apply damage
	var dmg : float = BASE_DAMAGE * skill.get("dmg_mult", 1.0) + randf_range(-5, 10)
	_tgt_take_damage(_current_target, dmg, "health")
	# Apply state
	var state_name : String = skill.get("state", "")
	var state_dur : float = skill.get("state_dur", 0.0)
	if state_name != "":
		_tgt_apply_state(_current_target, state_name, state_dur)
	# Play attack anim
	_play_anim("attack2" if _active == _silver else "attack")
	_attack_anim_timer = 1.0
	# Log
	var sn := _tgt_display_name(_current_target)
	_log_combat("[color=yellow]" + skill.get("name", "") + " → " + sn + " for " + str(int(dmg)) + " dmg[/color]")
	if state_name == "dizzy":
		_log_combat("[color=orange]" + sn + " is dizzied for " + str(int(state_dur)) + "s![/color]")
		_spawn_damage_text(_current_target, "DIZZY", Color(0.9, 0.8, 0.2))
		_spawn_dizzy_effect(_current_target)
	elif state_name == "knockdown":
		_log_combat("[color=red]" + sn + " is knocked down![/color]")
		_spawn_damage_text(_current_target, "KNOCKDOWN", Color(1, 0.3, 0.2))
		_play_anim_on_node(_current_target, "kd")

func _tick_hotbar(delta : float) -> void:
	for i in range(HOTBAR_SLOTS):
		if _hotbar_cooldowns[i] > 0.0:
			_hotbar_cooldowns[i] -= delta
			_hotbar_cd_labels[i].text = str(int(ceilf(_hotbar_cooldowns[i])))
			_hotbar_cd_labels[i].visible = true
		else:
			_hotbar_cooldowns[i] = 0.0
			_hotbar_cd_labels[i].visible = false

# ════════════════════════════════════════════════════════════
#  SKILLS WINDOW (P)
# ════════════════════════════════════════════════════════════
func _build_skills_window() -> void:
	_skills_window = Panel.new()
	var vp := get_viewport().get_visible_rect().size
	_skills_window.position = Vector2(vp.x * 0.5 - 200, vp.y * 0.5 - 180)
	_skills_window.size = Vector2(400, 360)
	var sw_style := StyleBoxFlat.new()
	sw_style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sw_style.border_color = Color(0.4, 0.35, 0.25)
	sw_style.set_border_width_all(2)
	sw_style.set_corner_radius_all(6)
	_skills_window.add_theme_stylebox_override("panel", sw_style)
	_skills_window.visible = false
	_hud.add_child(_skills_window)

	# Title
	var title := Label.new()
	title.text = "Skills"
	title.position = Vector2(160, 8)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_skills_window.add_child(title)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(370, 5)
	close_btn.size = Vector2(24, 24)
	close_btn.pressed.connect(_toggle_skills_window)
	_skills_window.add_child(close_btn)

	# Skill entries
	var y_off := 45
	for skill_id in SKILL_DATA:
		var skill : Dictionary = SKILL_DATA[skill_id]
		_build_skill_entry(_skills_window, skill, y_off)
		y_off += 100

	# Instructions
	var instr := Label.new()
	instr.text = "Click a skill to place it on your hotbar (slots 1-8)"
	instr.position = Vector2(20, y_off + 20)
	instr.add_theme_font_size_override("font_size", 10)
	instr.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_skills_window.add_child(instr)

func _build_skill_entry(parent : Panel, skill : Dictionary, y : int) -> void:
	var entry := Panel.new()
	entry.position = Vector2(15, y)
	entry.size = Vector2(370, 85)
	var e_style := StyleBoxFlat.new()
	e_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	e_style.border_color = skill.get("color", Color(0.4, 0.4, 0.4))
	e_style.set_border_width_all(1)
	e_style.set_corner_radius_all(3)
	entry.add_theme_stylebox_override("panel", e_style)
	parent.add_child(entry)

	# Icon
	var icon := ColorRect.new()
	icon.position = Vector2(8, 8)
	icon.size = Vector2(40, 40)
	icon.color = skill.get("color", Color(0.5, 0.5, 0.5))
	entry.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = skill.get("name", "")
	name_lbl.position = Vector2(58, 5)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	entry.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = skill.get("desc", "")
	desc_lbl.position = Vector2(58, 25)
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	entry.add_child(desc_lbl)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Action: " + str(int(skill.get("action_cost", 0))) + "  |  CD: " + str(int(skill.get("cooldown", 0))) + "s  |  DMG: " + str(skill.get("dmg_mult", 1.0)) + "x"
	stats_lbl.position = Vector2(58, 45)
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	entry.add_child(stats_lbl)

	# Click to add to hotbar
	var btn := Button.new()
	btn.text = "Add to Hotbar"
	btn.position = Vector2(260, 55)
	btn.size = Vector2(100, 24)
	var sk_copy := skill.duplicate()
	btn.pressed.connect(func(): _add_skill_to_next_slot(sk_copy))
	entry.add_child(btn)

func _add_skill_to_next_slot(skill : Dictionary) -> void:
	# Find first empty slot, or first slot with same skill to replace
	for i in range(HOTBAR_SLOTS):
		if _hotbar_skills[i].is_empty():
			_set_hotbar_slot(i, skill)
			_log_combat("[color=green]" + skill.get("name", "") + " placed on slot " + str(i + 1) + "[/color]")
			return
		if _hotbar_skills[i].get("id", "") == skill.get("id", ""):
			return  # already on hotbar
	_log_combat("[color=gray]Hotbar full[/color]")

func _toggle_skills_window() -> void:
	_skills_visible = !_skills_visible
	if _skills_window:
		_skills_window.visible = _skills_visible

# ════════════════════════════════════════════════════════════
#  MINIMAP
# ════════════════════════════════════════════════════════════
func _build_minimap() -> void:
	var vp := get_viewport().get_visible_rect().size
	_minimap_panel = Panel.new()
	_minimap_panel.position = Vector2(vp.x - MMAP_SIZE - 15, 10)
	_minimap_panel.size = Vector2(MMAP_SIZE, MMAP_SIZE)
	var mm_style := StyleBoxFlat.new()
	mm_style.bg_color = Color(0.05, 0.08, 0.05, 0.85)
	mm_style.border_color = Color(0.3, 0.35, 0.3)
	mm_style.set_border_width_all(2)
	mm_style.set_corner_radius_all(4)
	_minimap_panel.add_theme_stylebox_override("panel", mm_style)
	_hud.add_child(_minimap_panel)

	# Location label
	var loc_lbl := Label.new()
	loc_lbl.text = "CORONET"
	loc_lbl.position = Vector2(8, 2)
	loc_lbl.add_theme_font_size_override("font_size", 10)
	loc_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	_minimap_panel.add_child(loc_lbl)

	# Draw area — create with script pre-loaded
	var mm_script = load("res://Scripts/CoronetMinimap.gd") if ResourceLoader.exists("res://Scripts/CoronetMinimap.gd") else null
	_minimap_draw = Control.new()
	if mm_script:
		_minimap_draw.set_script(mm_script)
	_minimap_draw.position = Vector2(4, 18)
	_minimap_draw.size = Vector2(MMAP_SIZE - 8, MMAP_SIZE - 22)
	_minimap_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_panel.add_child(_minimap_draw)
	if _minimap_draw.get_script() != null:
		_minimap_draw.scene_ref = self

func _update_minimap() -> void:
	if _minimap_draw == null or _active == null:
		return
	_minimap_draw.queue_redraw()

# ════════════════════════════════════════════════════════════
#  CHAT
# ════════════════════════════════════════════════════════════
func _build_chat() -> void:
	var vp := get_viewport().get_visible_rect().size
	_chat_panel = Panel.new()
	_chat_panel.position = Vector2(10, vp.y - 220)
	_chat_panel.size = Vector2(420, 200)
	var ch_style := StyleBoxFlat.new()
	ch_style.bg_color = Color(0.04, 0.04, 0.04, 0.75)
	ch_style.border_color = Color(0.25, 0.25, 0.3)
	ch_style.set_border_width_all(1)
	ch_style.set_corner_radius_all(4)
	_chat_panel.add_theme_stylebox_override("panel", ch_style)
	_hud.add_child(_chat_panel)

	# Chat log
	_chat_log = RichTextLabel.new()
	_chat_log.position = Vector2(8, 8)
	_chat_log.size = Vector2(404, 160)
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.add_theme_font_size_override("normal_font_size", 12)
	_chat_log.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_chat_panel.add_child(_chat_log)

	# Chat input
	_chat_input = LineEdit.new()
	_chat_input.position = Vector2(8, 172)
	_chat_input.size = Vector2(404, 22)
	_chat_input.placeholder_text = "Press Enter to chat..."
	_chat_input.add_theme_font_size_override("font_size", 11)
	var ci_style := StyleBoxFlat.new()
	ci_style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	ci_style.border_color = Color(0.3, 0.3, 0.35)
	ci_style.set_border_width_all(1)
	_chat_input.add_theme_stylebox_override("normal", ci_style)
	_chat_input.text_submitted.connect(_on_chat_submit)
	_chat_panel.add_child(_chat_input)

	_chat_log.append_text("[color=gray]Welcome to Coronet. Press Enter to chat.[/color]\n")

func _on_chat_submit(text : String) -> void:
	if text.strip_edges().is_empty():
		_chat_input.clear()
		_chat_input.release_focus()
		return
	# Display locally
	var nick := "Silver Sentinel" if _active == _silver else "Ember Guard"
	_chat_log.append_text("[color=cyan]" + nick + ":[/color] " + text + "\n")
	# Send via Relay
	if Relay and Relay.has_method("send_game_data"):
		Relay.send_game_data({"cmd": "chat", "nick": nick, "msg": text})
	# Show bubble above player in 3D
	_show_chat_bubble(_active, nick, text)
	_chat_input.clear()
	_chat_input.release_focus()

func _show_chat_bubble(target : Node3D, nick : String, msg : String) -> void:
	if not is_instance_valid(target):
		return
	# Remove old bubble
	var old := target.get_node_or_null("ChatBubble3D")
	if old:
		old.queue_free()
	# 3D billboard label
	var bubble := Label3D.new()
	bubble.name = "ChatBubble3D"
	bubble.text = nick + ": " + msg
	bubble.font_size = 24
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate = Color(1, 1, 1, 1)
	bubble.outline_modulate = Color(0, 0, 0, 1)
	bubble.outline_size = 4
	bubble.position = Vector3(0, 3.0, 0)
	target.add_child(bubble)
	# Fade after 5s
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(bubble, "modulate:a", 0.0, 1.0)
	tw.tween_callback(bubble.queue_free)

# ════════════════════════════════════════════════════════════
#  MULTIPLAYER RELAY
# ════════════════════════════════════════════════════════════
func _connect_relay() -> void:
	if Relay and Relay.has_signal("game_data_received"):
		if not Relay.game_data_received.is_connected(_on_relay_data):
			Relay.game_data_received.connect(_on_relay_data)

func _on_relay_data(from_peer : int, data : Dictionary) -> void:
	var cmd : String = str(data.get("cmd", ""))
	match cmd:
		"chat":
			var nick := str(data.get("nick", "Player_%d" % from_peer))
			var msg := str(data.get("msg", ""))
			if msg.length() > 0:
				_chat_log.append_text("[color=cyan]" + nick + ":[/color] " + msg + "\n")
				var rp = _remote_players.get(from_peer)
				if is_instance_valid(rp):
					_show_chat_bubble(rp, nick, msg)
		"pos":
			# Remote player position update
			var px : float = data.get("x", 0.0)
			var py : float = data.get("y", 0.0)
			var pz : float = data.get("z", 0.0)
			var rp = _remote_players.get(from_peer)
			if is_instance_valid(rp):
				rp.global_position = Vector3(px, py, pz)

# ════════════════════════════════════════════════════════════
#  DIZZY EFFECT
# ════════════════════════════════════════════════════════════
func _spawn_dizzy_effect(target : Node3D) -> void:
	# Spinning cartoon stars above the target's head
	var stars_parent := Node3D.new()
	stars_parent.name = "DizzyEffect"
	target.add_child(stars_parent)
	stars_parent.position = Vector3(0, 2.5, 0)
	# Create 5 star-shaped meshes using PrismMesh (closest to star shape)
	for i in range(5):
		var star := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.15, 0.15, 0.04)
		var star_mat := StandardMaterial3D.new()
		# Alternate gold and white stars
		var col := Color(1, 0.9, 0.15) if i % 2 == 0 else Color(1, 1, 0.7)
		star_mat.albedo_color = col
		star_mat.emission_enabled = true
		star_mat.emission = col
		star_mat.emission_energy_multiplier = 4.0
		star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		prism.material = star_mat
		star.mesh = prism
		stars_parent.add_child(star)
	# Animate — smooth continuous spin like cartoon dizzy
	var tw := create_tween()
	tw.set_loops(750)  # 15s at 0.02s per loop
	tw.tween_callback(func():
		if is_instance_valid(stars_parent):
			stars_parent.rotation.y += 0.12
			for j in range(stars_parent.get_child_count()):
				var angle := stars_parent.rotation.y + j * (TAU / 5.0)
				var bob := sin(stars_parent.rotation.y * 3.0 + j * 1.5) * 0.08
				stars_parent.get_child(j).position = Vector3(cos(angle) * 0.5, bob, sin(angle) * 0.5)
				# Each star spins on its own axis too
				stars_parent.get_child(j).rotation.z += 0.2
	).set_delay(0.02)
	# Remove after 15s
	get_tree().create_timer(15.0).timeout.connect(func():
		if is_instance_valid(stars_parent):
			stars_parent.queue_free()
	)

func _tgt_stat(node : Node3D, stat : String, fallback = null):
	# Check property first (CoronetMob), then metadata (player character nodes)
	var val = node.get(stat)
	if val != null:
		return val
	if node.has_meta(stat):
		return node.get_meta(stat)
	return fallback

func _tgt_display_name(node : Node3D) -> String:
	if node.has_method("get_display_name"):
		return node.get_display_name()
	if node.has_meta("display_name"):
		return node.get_meta("display_name")
	return str(node.name)

func _tgt_take_damage(node : Node3D, amount : float, pool : String = "health") -> void:
	if node.has_method("take_damage"):
		node.take_damage(amount, pool)
	elif node.has_meta("ham_health"):
		# Player character node — update metadata
		var key := "ham_" + pool if pool != "health" else "ham_health"
		var cur : float = node.get_meta(key, 0.0)
		node.set_meta(key, maxf(0.0, cur - amount))
		# Check death
		if node.get_meta("ham_health", 0.0) <= 0.0:
			node.set_meta("is_dead", true)

func _tgt_apply_state(node : Node3D, state_name : String, duration : float) -> void:
	if node.has_method("apply_combat_state"):
		node.apply_combat_state(state_name, duration)
	elif node.has_meta("ham_health"):
		node.set_meta("state_" + state_name, duration)

func _update_hud() -> void:
	# Player bars
	if _hp_bar:
		_hp_bar.max_value = max_health
		_hp_bar.value = ham_health
	if _action_bar:
		_action_bar.max_value = max_action_stat
		_action_bar.value = ham_action
	if _mind_bar:
		_mind_bar.max_value = max_mind
		_mind_bar.value = ham_mind

	# Target frame
	var tgt_dead = _tgt_stat(_current_target, "is_dead", false) if _current_target and is_instance_valid(_current_target) else true
	if _current_target and is_instance_valid(_current_target) and not tgt_dead:
		_tgt_panel.visible = true
		_tgt_name_lbl.text = _tgt_display_name(_current_target)
		_tgt_hp_bar.max_value = _tgt_stat(_current_target, "max_hp", 100.0)
		_tgt_hp_bar.value = _tgt_stat(_current_target, "ham_health", 0.0)
		_tgt_action_bar.max_value = _tgt_stat(_current_target, "max_action", 100.0)
		_tgt_action_bar.value = _tgt_stat(_current_target, "ham_action", 0.0)
		_tgt_mind_bar.max_value = _tgt_stat(_current_target, "max_mind", 100.0)
		_tgt_mind_bar.value = _tgt_stat(_current_target, "ham_mind", 0.0)
		# Target debuff icons
		_update_status_row(_tgt_debuff_row, _current_target, false)
	else:
		_tgt_panel.visible = false
		_clear_status_row(_tgt_debuff_row)
		if _current_target and (not is_instance_valid(_current_target) or tgt_dead):
			_current_target = null
			_auto_attacking = false

	# Player buff icons
	_update_status_row(_player_buff_row, null, true)

func _update_status_row(row : HBoxContainer, target : Node3D, is_player : bool) -> void:
	if row == null:
		return
	# Clear existing icons
	for child in row.get_children():
		child.queue_free()

	var icons_to_show : Array = []

	if is_player:
		# Buffs on player
		if _sprint_active:
			icons_to_show.append({"label": "SPR", "color": Color(0.3, 0.8, 1.0), "time": _sprint_timer})
		if _sensu_active:
			icons_to_show.append({"label": "HEAL", "color": Color(0.2, 0.9, 0.3), "time": _sensu_timer})
		# Debuffs on player
		if state_dizzy > 0.0:
			icons_to_show.append({"label": "DIZ", "color": Color(0.9, 0.8, 0.2), "time": state_dizzy})
		if state_knockdown > 0.0:
			icons_to_show.append({"label": "KD", "color": Color(0.9, 0.3, 0.2), "time": state_knockdown})
		if state_stun > 0.0:
			icons_to_show.append({"label": "STN", "color": Color(0.8, 0.5, 0.9), "time": state_stun})
		if state_blind > 0.0:
			icons_to_show.append({"label": "BLN", "color": Color(0.5, 0.5, 0.5), "time": state_blind})
	else:
		# Debuffs on target
		if target and is_instance_valid(target):
			var diz : float = _tgt_stat(target, "state_dizzy", 0.0)
			var kd : float = _tgt_stat(target, "state_knockdown", 0.0)
			if diz > 0.0:
				icons_to_show.append({"label": "DIZ", "color": Color(0.9, 0.8, 0.2), "time": diz})
			if kd > 0.0:
				icons_to_show.append({"label": "KD", "color": Color(0.9, 0.3, 0.2), "time": kd})

	for icon_data in icons_to_show:
		var icon_panel := Panel.new()
		icon_panel.custom_minimum_size = Vector2(36, 36)
		var ic_style := StyleBoxFlat.new()
		ic_style.bg_color = Color(0.06, 0.06, 0.06, 0.9)
		ic_style.border_color = icon_data["color"]
		ic_style.set_border_width_all(2)
		ic_style.set_corner_radius_all(3)
		icon_panel.add_theme_stylebox_override("panel", ic_style)
		row.add_child(icon_panel)

		var lbl := Label.new()
		lbl.text = icon_data["label"]
		lbl.position = Vector2(2, 1)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", icon_data["color"])
		icon_panel.add_child(lbl)

		var time_lbl := Label.new()
		time_lbl.text = str(int(ceilf(icon_data["time"])))
		time_lbl.position = Vector2(2, 18)
		time_lbl.add_theme_font_size_override("font_size", 10)
		time_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		icon_panel.add_child(time_lbl)

func _clear_status_row(row : HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()

# ════════════════════════════════════════════════════════════
#  TARGETING
# ════════════════════════════════════════════════════════════
func _get_all_targetables() -> Array:
	var targets := []
	for child in get_children():
		if child is CoronetMob and not child.is_dead:
			targets.append(child)
		elif child is MachineWalker and not child.is_dead:
			targets.append(child)
	# Include the inactive player character as targetable
	var inactive : Node3D = _red if _active == _silver else _silver
	if inactive and is_instance_valid(inactive):
		targets.append(inactive)
	return targets

func _cycle_target() -> void:
	var mobs := _get_all_targetables()
	if mobs.is_empty():
		_current_target = null
		_auto_attacking = false
		return
	# Sort by distance
	mobs.sort_custom(func(a, b): return _active.global_position.distance_to(a.global_position) < _active.global_position.distance_to(b.global_position))
	# Filter by range
	var in_range := mobs.filter(func(m): return _active.global_position.distance_to(m.global_position) < TARGET_CYCLE_RANGE)
	if in_range.is_empty():
		_current_target = null
		_auto_attacking = false
		return
	# Cycle to next
	if _current_target == null or _current_target not in in_range:
		_current_target = in_range[0]
	else:
		var idx := in_range.find(_current_target)
		_current_target = in_range[(idx + 1) % in_range.size()]
	_auto_attacking = true
	_attack_timer = 0.3  # small delay before first hit
	_log_combat("[color=yellow]Target: " + _tgt_display_name(_current_target) + "[/color]")

func _update_target_indicator() -> void:
	# Remove old indicator
	if _target_indicator and is_instance_valid(_target_indicator):
		_target_indicator.queue_free()
		_target_indicator = null
	if _current_target == null or not is_instance_valid(_current_target):
		return
	# Create a ring under the target
	var torus := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.6
	mesh.outer_radius = 0.8
	mesh.rings = 16
	mesh.ring_segments = 16
	torus.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.3, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.2, 1.0)
	mat.emission_energy_multiplier = 2.0
	torus.material_override = mat
	torus.position = Vector3(0, 0.05, 0)
	_current_target.add_child(torus)
	_target_indicator = torus

# ════════════════════════════════════════════════════════════
#  COMBAT
# ════════════════════════════════════════════════════════════
func _tick_combat(delta : float) -> void:
	if not _auto_attacking:
		return
	if _current_target == null or not is_instance_valid(_current_target) or _tgt_stat(_current_target, "is_dead", false):
		_auto_attacking = false
		_current_target = null
		return

	var dist : float = _active.global_position.distance_to(_current_target.global_position)
	var atk_range : float = ATTACK_RANGE_MELEE if character_class == "melee" else ATTACK_RANGE_RANGED

	# Out of range — don't attack but keep target
	if dist > atk_range:
		return

	# Face the target
	var dir : Vector3 = (_current_target.global_position - _active.global_position).normalized()
	var target_angle := atan2(dir.x, dir.z)
	# Red armor attack anim shoots left — rotate 90 degrees clockwise
	if _active == _red and _attack_anim_timer > 0.0:
		target_angle -= PI * 0.5
	_active.rotation.y = lerp_angle(_active.rotation.y, target_angle, ROTATION_SPEED * delta)

	# Attack timer
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_do_attack()
		_attack_timer = ATTACK_COOLDOWN

func _do_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	# Pick attack anim: melee alternates attack/attack2, ranged always uses attack
	var atk_name : String
	if character_class == "melee":
		atk_name = "attack" if _attack_cycle == 0 else "attack2"
		_attack_cycle = 1 - _attack_cycle
	else:
		atk_name = "attack"

	_play_anim(atk_name)
	_anim_state = "attack"
	var ap := _get_active_anim()
	if ap and ap.has_animation(atk_name):
		_attack_anim_timer = ap.get_animation(atk_name).length
	else:
		_attack_anim_timer = 2.0

	# Roll to hit using CombatEngine
	var attack_data := {"is_ranged": character_class != "melee"}
	var result := CombatEngine.roll_to_hit(self, _current_target, attack_data)

	# Spawn attack effect based on class
	if character_class == "ranged":
		_spawn_laser_effect(_active, _current_target)
	else:
		# Delay melee hit to match swing
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(_current_target):
				_spawn_melee_hit_effect(_current_target)
		)

	var tgt_name := _tgt_display_name(_current_target)
	match result.get("result", "miss"):
		"miss", "dodge":
			_log_combat("[color=cyan]" + tgt_name + " dodges![/color]")
			_spawn_damage_text(_current_target, "DODGE", Color(0.3, 0.8, 1.0))
			# Play dodge anim on target
			_play_anim_on_node(_current_target, "dodge")
		"block":
			var reduction : float = result.get("reduction", 0.75)
			var dmg := BASE_DAMAGE * (1.0 - reduction)
			_tgt_take_damage(_current_target, dmg, "health")
			_log_combat("[color=orange]" + tgt_name + " blocks! (" + str(int(dmg)) + " dmg)[/color]")
			_spawn_damage_text(_current_target, str(int(dmg)), Color(1.0, 0.6, 0.2))
		_:  # hit
			var dmg := BASE_DAMAGE + randf_range(-5.0, 10.0)
			# 2x damage if target is knocked down
			var tgt_kd : float = _tgt_stat(_current_target, "state_knockdown", 0.0)
			if tgt_kd > 0.0:
				dmg *= 2.0
			_tgt_take_damage(_current_target, dmg, "health")
			var dmg_text := str(int(dmg)) + (" (KD 2x!)" if tgt_kd > 0.0 else "")
			_log_combat("[color=red]You hit " + tgt_name + " for " + dmg_text + " damage[/color]")
			_spawn_damage_text(_current_target, str(int(dmg)), Color(1.0, 1.0, 0.2))

func _spawn_damage_text(target : Node3D, text : String, color : Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.position = target.global_position + Vector3(randf_range(-0.5, 0.5), 2.5, 0)
	add_child(lbl)
	# Float up and fade
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 2.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(lbl.queue_free)

# ════════════════════════════════════════════════════════════
#  ATTACK EFFECTS
# ════════════════════════════════════════════════════════════
func _spawn_laser_effect(from_node : Node3D, target : Node3D) -> void:
	# Delay to match shoot anim
	get_tree().create_timer(0.6).timeout.connect(func():
		if not is_instance_valid(from_node) or not is_instance_valid(target):
			return
		# Spawn a traveling bullet from shooter to target
		var start_pos : Vector3 = from_node.global_position + Vector3(0, 1.2, 0)
		var end_pos : Vector3 = target.global_position + Vector3(0, 1.0, 0)
		var bullet := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.3, 0.1, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.2, 0.05)
		mat.emission_energy_multiplier = 15.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material = mat
		bullet.mesh = sphere
		bullet.global_position = start_pos
		add_child(bullet)
		# Travel to target
		var travel_time := clampf(start_pos.distance_to(end_pos) / 30.0, 0.1, 0.5)
		var tw := create_tween()
		tw.tween_property(bullet, "global_position", end_pos, travel_time)
		tw.tween_callback(func():
			if is_instance_valid(bullet):
				# Impact flash
				_spawn_impact_effect(end_pos)
				bullet.queue_free()
		)
	)

func _spawn_heal_effect(target : Node3D) -> void:
	if not is_instance_valid(target):
		return
	for i in range(8):
		var particle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.4, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.9, 0.3)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere.material = mat
		particle.mesh = sphere
		add_child(particle)
		var start_pos := target.global_position + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5))
		particle.global_position = start_pos
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(particle, "position:y", start_pos.y + 2.5, 1.0 + randf_range(0, 0.5))
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
		tw.chain().tween_callback(particle.queue_free)

func _spawn_melee_hit_effect(target : Node3D) -> void:
	if not is_instance_valid(target):
		return
	var hit_pos : Vector3 = target.global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
	_spawn_impact_effect(hit_pos)

func _spawn_impact_effect(pos : Vector3) -> void:
	# White semi-transparent star burst
	var flash := MeshInstance3D.new()
	var star := PrismMesh.new()
	star.size = Vector3(0.5, 0.5, 0.1)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 1, 1, 0.5)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1, 1, 1)
	flash_mat.emission_energy_multiplier = 4.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star.material = flash_mat
	flash.mesh = star
	add_child(flash)
	flash.global_position = pos
	# Expand then remove
	var tw := create_tween()
	tw.tween_property(flash, "scale", Vector3(3.0, 3.0, 3.0), 0.2)
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.15)
	tw.tween_callback(flash.queue_free)

# ════════════════════════════════════════════════════════════
#  INPUT
# ════════════════════════════════════════════════════════════
func _input(event : InputEvent) -> void:
	# Enter — focus/unfocus chat
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if _chat_input and not _chat_input.has_focus():
			_chat_input.grab_focus()
			get_viewport().set_input_as_handled()
			return
	# Block game input when chat is focused
	if _chat_input and _chat_input.has_focus():
		return

	# TAB — cycle targets
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_target()
		_update_target_indicator()

	# F1/F2 — switch active character
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and _silver:
			_active = _silver
			character_class = "melee"
			_player_name_lbl.text = "Silver Sentinel"
			_play_anim("idle")
		elif event.keycode == KEY_F2 and _red:
			_active = _red
			character_class = "ranged"
			_player_name_lbl.text = "Ember Guard"
			_play_anim("idle")
		elif event.keycode == KEY_ESCAPE:
			_current_target = null
			_auto_attacking = false
			_update_target_indicator()
		elif event.keycode == KEY_R:
			_toggle_rain()
		elif event.keycode == KEY_P:
			_toggle_skills_window()
		# Hotbar keys 1-8
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			_activate_hotbar_slot(event.keycode - KEY_1)
		# Spacebar — stand up from knockdown (only when not mounted)
		elif event.keycode == KEY_F5:
			_spawn_machine_walker()
		elif event.keycode == KEY_SPACE and state_knockdown > 0.0 and not _mounted:
			state_knockdown = 0.0
			_play_anim("idle")
			_log_combat("[color=green]You stand up![/color]")
		# F — mount/dismount vehicle
		elif event.keycode == KEY_F:
			_toggle_mount()

	# RMB — hold to orbit camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_held = event.pressed
			if _rmb_held:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Block camera zoom if hovering minimap
			if _minimap_panel:
				var mp := get_viewport().get_mouse_position()
				if Rect2(_minimap_panel.global_position, _minimap_panel.size).has_point(mp):
					return
			_cam_zoom = clampf(_cam_zoom - 0.05, 0.3, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _minimap_panel:
				var mp := get_viewport().get_mouse_position()
				if Rect2(_minimap_panel.global_position, _minimap_panel.size).has_point(mp):
					return
			_cam_zoom = clampf(_cam_zoom + 0.05, 0.3, 3.0)

	# RMB drag — orbit camera
	if event is InputEventMouseMotion and _rmb_held:
		_cam_yaw -= event.relative.x * CAM_MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch + event.relative.y * CAM_MOUSE_SENSITIVITY, 0.1, 1.4)

	# LMB — click to target mob (raycast)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_click_target(event.position)

# ════════════════════════════════════════════════════════════
#  CLICK TARGETING (raycast from mouse)
# ════════════════════════════════════════════════════════════
func _try_click_target(screen_pos : Vector2) -> void:
	if _camera == null:
		return
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	# Check if hit a mob
	var hit_node : Node = result.get("collider")
	while hit_node and not (hit_node is CoronetMob):
		hit_node = hit_node.get_parent()
	if hit_node is CoronetMob and not hit_node.is_dead:
		_current_target = hit_node
		_auto_attacking = true
		_attack_timer = 0.3
		_update_target_indicator()
		_log_combat("[color=yellow]Target: " + _tgt_display_name(_current_target) + "[/color]")

# ════════════════════════════════════════════════════════════
#  PROCESS
# ════════════════════════════════════════════════════════════
# Store original armature rotations (FBX import applies axis conversion)
var _silver_armature_rot := Vector3.ZERO
var _red_armature_rot := Vector3.ZERO

func _lock_armatures() -> void:
	if _silver_armature:
		_silver_armature.position = Vector3.ZERO
	if _red_armature:
		_red_armature.position = Vector3.ZERO
		_red_armature.rotation = _red_armature_rot

func _process(delta : float) -> void:
	if _active == null:
		return

	# Lock armatures to prevent root motion (both now and after anim applies)
	_lock_armatures()
	_lock_armatures.call_deferred()

	# Tick combat states
	if state_knockdown > 0.0:
		state_knockdown -= delta
		_update_camera(delta)
		_update_hud()
		return  # KD blocks all

	if state_dizzy > 0.0: state_dizzy -= delta
	if state_stun > 0.0: state_stun -= delta
	if state_blind > 0.0: state_blind -= delta
	if state_intimidate > 0.0: state_intimidate -= delta

	# Sensu Bean heal over time
	if _sensu_active:
		_sensu_timer -= delta
		var heal_rate_h := max_health / SENSU_DURATION * delta
		var heal_rate_a := max_action_stat / SENSU_DURATION * delta
		var heal_rate_m := max_mind / SENSU_DURATION * delta
		ham_health = minf(ham_health + heal_rate_h, max_health)
		ham_action = minf(ham_action + heal_rate_a, max_action_stat)
		ham_mind = minf(ham_mind + heal_rate_m, max_mind)
		if _sensu_timer <= 0.0:
			_sensu_active = false
			_log_combat("[color=green]Sensu Bean effect ended.[/color]")

	# Sprint tick
	if _sprint_active:
		_sprint_timer -= delta
		if _sprint_timer <= 0.0:
			_sprint_active = false
			_log_combat("[color=aqua]Sprint ended.[/color]")
	if _sprint_cooldown_timer > 0.0:
		_sprint_cooldown_timer -= delta

	# Tick attack anim timer
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta

	# ── VEHICLE PROMPT (when near vehicle and not mounted) ──
	if not _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount) and _active:
		var vdist := _active.global_position.distance_to(_vehicle_mount.global_position)
		if vdist <= VEHICLE_MOUNT_RANGE:
			if _vehicle_prompt == null:
				_vehicle_prompt = Label3D.new()
				_vehicle_prompt.text = "[F] Enter Vehicle"
				_vehicle_prompt.font_size = 28
				_vehicle_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				_vehicle_prompt.modulate = Color(1, 0.9, 0.3, 1)
				_vehicle_prompt.outline_modulate = Color(0, 0, 0, 1)
				_vehicle_prompt.outline_size = 4
				_vehicle_mount.add_child(_vehicle_prompt)
				_vehicle_prompt.position = Vector3(0, 2.5, 0)
		else:
			if _vehicle_prompt and is_instance_valid(_vehicle_prompt):
				_vehicle_prompt.queue_free()
				_vehicle_prompt = null

	# ── VEHICLE CONTROLS (when mounted) ──
	if _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount):
		var v_input := Vector3.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			v_input.z -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			v_input.z += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			v_input.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			v_input.x += 1.0
		# Fly up/down
		if Input.is_key_pressed(KEY_SPACE):
			v_input.y += 1.0
		if Input.is_key_pressed(KEY_CTRL):
			v_input.y -= 1.0
		# Shift boost
		_vehicle_boosting = Input.is_key_pressed(KEY_SHIFT)
		var target_speed := VEHICLE_BOOST_SPEED if _vehicle_boosting else VEHICLE_SPEED
		var accel := VEHICLE_BOOST_ACCEL if _vehicle_boosting else VEHICLE_ACCEL

		var has_horizontal := (v_input.x != 0 or v_input.z != 0)
		var is_moving := v_input.length_squared() > 0.01

		# Accelerate / decelerate
		if has_horizontal:
			_vehicle_cur_speed = move_toward(_vehicle_cur_speed, target_speed, accel * delta)
			var flat_input := Vector3(v_input.x, 0, v_input.z).normalized()
			_vehicle_last_dir = flat_input.rotated(Vector3.UP, _cam_yaw)
		else:
			# Slow deceleration — coast to a stop
			_vehicle_cur_speed = move_toward(_vehicle_cur_speed, 0.0, accel * 1.0 * delta)

		# Move in current direction (coasting when no input)
		if _vehicle_cur_speed > 0.1 and _vehicle_last_dir.length() > 0.01:
			_vehicle_mount.position += _vehicle_last_dir * _vehicle_cur_speed * delta

		# Vertical movement (always immediate)
		if v_input.y != 0:
			_vehicle_mount.position.y += v_input.y * VEHICLE_FLY_SPEED * delta
		_vehicle_mount.position.y = maxf(0.5, _vehicle_mount.position.y)

		# Turning — only when actively steering
		if has_horizontal:
			var target_angle := atan2(_vehicle_last_dir.x, _vehicle_last_dir.z)
			var speed_ratio := clampf(_vehicle_cur_speed / VEHICLE_BOOST_SPEED, 0.0, 1.0)
			var turn_rate := lerpf(VEHICLE_TURN_SPEED, VEHICLE_TURN_SPEED * 0.2, speed_ratio)
			_vehicle_mount.rotation.y = lerp_angle(_vehicle_mount.rotation.y, target_angle + PI * 0.5, turn_rate * delta)

		# Speed lines effect when boosting and moving fast
		_tick_speed_lines(delta, _vehicle_boosting and _vehicle_cur_speed > VEHICLE_SPEED * 0.8)

		# Ion glow — always animate while mounted (scales with speed)
		_tick_ion_glow()

		# Hover bob continues always (even when idle)
		_vehicle_hover_time += delta
		var hover_bob := sin(_vehicle_hover_time * 1.5) * 0.2
		if not is_moving and v_input.y == 0:
			_vehicle_mount.position.y += hover_bob * delta * 2.0  # gentle drift

		# Camera follows vehicle
		_active.position = _vehicle_mount.position
		_active.position.y = 0.0
		_tick_rain()
		_tick_hotbar(delta)
		if _kd_immunity_timer > 0.0:
			_kd_immunity_timer -= delta
		_update_camera(delta)
		_update_hud()
		_update_minimap()
		return  # Skip normal character movement

	# ── NORMAL CHARACTER MOVEMENT ──
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0

	var speed := SPRINT_SPEED if _sprint_active else MOVE_SPEED
	var moving := input.length_squared() > 0.01
	if moving:
		input = input.normalized()
		var rotated := input.rotated(Vector3.UP, _cam_yaw)
		_active.position += rotated * speed * delta
		var target_angle := atan2(rotated.x, rotated.z)
		_active.rotation.y = lerp_angle(_active.rotation.y, target_angle, ROTATION_SPEED * delta)
		# Movement always overrides attack anim
		if _anim_state != "run":
			_play_anim("run")
			_anim_state = "run"
			_attack_anim_timer = 0.0
	else:
		# Not moving: respect attack/dodge timer before returning to idle
		if _attack_anim_timer > 0.0:
			pass  # let attack or dodge anim finish
		elif _anim_state != "idle":
			_play_anim("idle")
			_anim_state = "idle"

	_active.position.y = 0.0

	# Combat
	_tick_combat(delta)
	_tick_vehicle_hover(delta)
	_tick_rain()
	_tick_hotbar(delta)
	if _kd_immunity_timer > 0.0:
		_kd_immunity_timer -= delta
	_update_camera(delta)
	_update_hud()
	_update_minimap()

# ════════════════════════════════════════════════════════════
#  CAMERA
# ════════════════════════════════════════════════════════════
func _update_camera(delta : float) -> void:
	if _active == null or _camera == null:
		return
	var base_dist := VEHICLE_CAM_DISTANCE if _mounted else CAM_DISTANCE
	var dist : float = base_dist * _cam_zoom
	var look_target : Vector3
	if _mounted and _vehicle_mount and is_instance_valid(_vehicle_mount):
		look_target = _vehicle_mount.position
	else:
		look_target = _active.position
	var offset := Vector3(
		dist * sin(_cam_yaw) * cos(_cam_pitch),
		dist * sin(_cam_pitch),
		dist * cos(_cam_yaw) * cos(_cam_pitch)
	)
	var target_pos : Vector3 = look_target + offset
	if delta > 0.0:
		_camera.position = _camera.position.lerp(target_pos, 8.0 * delta)
	else:
		_camera.position = target_pos
	_camera.look_at(look_target + CAM_LOOK_OFFSET)
