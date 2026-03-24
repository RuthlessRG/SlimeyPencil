extends Node3D
class_name TestDummy

## Test Dummy — can be attacked, attacks back with small damage.
## Tries dizzy + knockdown every 5 seconds.
## Goes idle if not attacked for 10 seconds.

const MODEL_PATH := "res://Coronet/NPC/MachineWalker/idle/Meshy_AI_android_war_machine_f_biped_Animation_Idle_5_frame_rate_60.fbx"
const ANIM_PATHS := {
	"walk":    "res://Coronet/NPC/MachineWalker/walk/Meshy_AI_android_war_machine_f_biped_Animation_Walking_frame_rate_60.fbx",
	"attack":  "res://Coronet/NPC/MachineWalker/attack/attack1/Meshy_AI_android_war_machine_f_biped_Animation_Left_Hook_from_Guard_frame_rate_60.fbx",
	"kd":      "res://Coronet/NPC/MachineWalker/kd/Meshy_AI_android_war_machine_f_biped_Animation_Knock_Down_1_frame_rate_60.fbx",
}

@export var mob_name : String = "Test Dummy"
@export var max_hp : float = 99999.0
@export var max_action : float = 99999.0
@export var max_mind : float = 99999.0
@export var level : int = 1
@export var attack_damage : float = 5.0
@export var attack_range : float = 3.5
@export var chase_speed : float = 2.5

var accuracy : float = 999.0  # never miss
var defense : float = 20.0

var ham_health : float
var ham_action : float
var ham_mind : float

var is_dead := false
var _current_target : Node3D = null
var _attack_timer : float = 0.0
var _attack_anim_timer : float = 0.0
var _special_timer : float = 5.0  # dizzy+kd every 5 seconds
var _idle_timer : float = 0.0     # time since last hit, go idle at 10s
var _in_combat := false
var _anim : AnimationPlayer = null
var _armature : Node3D = null
var _model : Node3D = null

var state_dizzy : float = 0.0
var state_knockdown : float = 0.0
var state_stun : float = 0.0
var state_blind : float = 0.0
var state_intimidate : float = 0.0

func _ready() -> void:
	ham_health = max_hp
	ham_action = max_action
	ham_mind = max_mind
	_spawn_model()
	# Add collision body for raycast targeting
	var body := StaticBody3D.new()
	var coll := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.0
	shape.height = 3.0
	coll.shape = shape
	coll.position = Vector3(0, 1.5, 0)
	body.add_child(coll)
	add_child(body)
	# Name label
	var lbl := Label3D.new()
	lbl.text = mob_name + " [Test]"
	lbl.position.y = 3.5
	lbl.font_size = 32
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.5, 1.0, 0.5)
	add_child(lbl)

func _spawn_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		return
	var scene : PackedScene = load(MODEL_PATH)
	if scene == null:
		return
	_model = scene.instantiate()
	_model.scale = Vector3(1.75, 1.75, 1.75)
	add_child(_model)
	_anim = _find_anim_player(_model)
	_armature = _model.get_node_or_null("Armature")
	if _anim:
		for anim_name in ANIM_PATHS:
			_load_anim(anim_name, ANIM_PATHS[anim_name])
		_strip_position_tracks()
		_set_loop_modes()
		_play_idle()

func _process(delta : float) -> void:
	if is_dead:
		return
	# Lock armature position
	if _armature:
		_armature.position = Vector3.ZERO

	# Tick states
	if state_knockdown > 0.0:
		state_knockdown -= delta
		if state_knockdown <= 0.0:
			state_knockdown = 0.0
			_play_idle()
		return
	if state_dizzy > 0.0:
		state_dizzy -= delta

	# Idle timeout — stop combat after 10s without being attacked
	if _in_combat:
		_idle_timer += delta
		if _idle_timer >= 10.0:
			_in_combat = false
			_current_target = null
			_play_idle()
			return

	if not _in_combat or _current_target == null:
		return

	var player := _current_target
	if not is_instance_valid(player):
		_in_combat = false
		_current_target = null
		_play_idle()
		return

	# Face target
	var dir := (player.global_position - global_position).normalized()
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)

	var dist := global_position.distance_to(player.global_position)

	# Chase if too far
	if dist > attack_range:
		global_position += dir * chase_speed * delta
		global_position.y = 0.0
		if _attack_anim_timer <= 0.0:
			_play_mob_anim("walk")
		return
	else:
		# In range — stop moving
		if _attack_anim_timer > 0.0:
			_attack_anim_timer -= delta

		# Auto attack
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_do_attack()
			_attack_timer = 3.0

		# Special: dizzy + knockdown every 5 seconds
		_special_timer -= delta
		if _special_timer <= 0.0:
			_do_special()
			_special_timer = 5.0

func take_damage(amount : float, pool : String = "health") -> void:
	if is_dead:
		return
	# Dummy takes damage but regens instantly (effectively invincible)
	match pool:
		"health": ham_health = maxf(1.0, ham_health - amount)
		"action": ham_action = maxf(1.0, ham_action - amount)
		"mind":   ham_mind = maxf(1.0, ham_mind - amount)
	# Regen back
	ham_health = minf(ham_health + amount * 0.5, max_hp)
	# Aggro — target whoever hit us
	_idle_timer = 0.0
	if not _in_combat:
		_in_combat = true
		_special_timer = 5.0
	var player := _find_player()
	if player:
		_current_target = player._active

func _do_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	_play_mob_anim("attack")
	_attack_anim_timer = 1.5
	var player := _find_player()
	if player == null:
		return
	# Small damage auto-attack
	var result := CombatEngine.roll_to_hit(self, player, {"is_ranged": false})
	match result.get("result", "miss"):
		"miss":
			player._spawn_damage_text(player._active, "MISS", Color(0.7, 0.7, 0.7))
			player._log_combat("[color=gray]" + mob_name + " misses[/color]")
			player._play_anim("dodge")
			var dodge_ap = player._get_active_anim()
			if dodge_ap and dodge_ap.has_animation("dodge"):
				player._attack_anim_timer = dodge_ap.get_animation("dodge").length
			else:
				player._attack_anim_timer = 2.0
			player._anim_state = "attack"
		"dodge":
			player._spawn_damage_text(player._active, "DODGE", Color(0.3, 0.8, 1.0))
			player._log_combat("[color=cyan]You dodge " + mob_name + "[/color]")
			player._play_anim("dodge")
			var dodge_ap = player._get_active_anim()
			if dodge_ap and dodge_ap.has_animation("dodge"):
				player._attack_anim_timer = dodge_ap.get_animation("dodge").length
			else:
				player._attack_anim_timer = 2.0
			player._anim_state = "attack"
		_:
			var dmg := attack_damage + randf_range(-2.0, 3.0)
			player.ham_health -= dmg
			player.ham_health = maxf(0.0, player.ham_health)
			player._spawn_damage_text(player._active, str(int(dmg)), Color(1, 0.3, 0.3))
			player._log_combat("[color=red]" + mob_name + " hits you for " + str(int(dmg)) + "[/color]")

func _do_special() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	var player := _find_player()
	if player == null:
		return
	# Try dizzy
	if player.state_dizzy <= 0.0:
		player.state_dizzy = 8.0
		player._spawn_damage_text(player._active, "DIZZY", Color(0.9, 0.8, 0.2))
		player._log_combat("[color=orange]" + mob_name + " dizzies you for 8s![/color]")
		player._spawn_dizzy_effect(player._active)
	# Try knockdown
	if player.state_knockdown <= 0.0:
		player.state_knockdown = 999.0  # player must press space to stand
		player._spawn_damage_text(player._active, "KNOCKDOWN", Color(1, 0.3, 0.2))
		player._log_combat("[color=red]" + mob_name + " knocks you down![/color]")
		player._play_anim("kd")
		player._anim_state = "attack"
		var kd_ap = player._get_active_anim()
		if kd_ap and kd_ap.has_animation("kd"):
			player._attack_anim_timer = kd_ap.get_animation("kd").length
		else:
			player._attack_anim_timer = 3.0

func _play_idle() -> void:
	if _anim == null:
		return
	for a in _anim.get_animation_list():
		if a != "RESET" and a not in ANIM_PATHS.keys():
			_anim.play(a)
			return

func _play_mob_anim(anim_name : String) -> void:
	if _anim and _anim.has_animation(anim_name):
		_anim.play(anim_name)

func _find_player() -> Node:
	var parent := get_parent()
	if parent and parent.has_method("_log_combat"):
		return parent
	return null

func get_display_name() -> String:
	return mob_name

func apply_combat_state(state_name : String, duration : float) -> void:
	match state_name:
		"dizzy": state_dizzy = maxf(state_dizzy, duration)
		"knockdown":
			state_knockdown = maxf(state_knockdown, minf(duration, 10.0))
			if _anim and _anim.has_animation("kd"):
				_anim.stop()
				_anim.play("kd")

# ── Animation helpers (same as MachineWalker) ──
func _find_anim_player(root : Node) -> AnimationPlayer:
	for child in root.get_children():
		if child is AnimationPlayer: return child
		for gc in child.get_children():
			if gc is AnimationPlayer: return gc
			for ggc in gc.get_children():
				if ggc is AnimationPlayer: return ggc
	return null

func _load_anim(anim_name : String, path : String) -> void:
	if not ResourceLoader.exists(path): return
	var scene : PackedScene = load(path)
	if scene == null: return
	var temp : Node = scene.instantiate()
	var temp_ap := _find_anim_player(temp)
	if temp_ap == null:
		temp.queue_free()
		return
	for src_name in temp_ap.get_animation_list():
		if src_name == "RESET": continue
		var anim : Animation = temp_ap.get_animation(src_name)
		if anim:
			var dupe := anim.duplicate(true)
			var lib := _anim.get_animation_library("")
			if lib == null:
				lib = AnimationLibrary.new()
				_anim.add_animation_library("", lib)
			lib.add_animation(anim_name, dupe)
			break
	temp.queue_free()

func _strip_position_tracks() -> void:
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		if lib == null: continue
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET": continue
			var anim := lib.get_animation(anim_name)
			if anim:
				var dupe := anim.duplicate(true)
				for i in range(dupe.get_track_count() - 1, -1, -1):
					if dupe.track_get_type(i) == Animation.TYPE_POSITION_3D:
						dupe.remove_track(i)
				lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)

func _set_loop_modes() -> void:
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		if lib == null: continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null or anim_name == "RESET": continue
			var lower := anim_name.to_lower()
			if "idle" in lower or "walk" in lower:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE
