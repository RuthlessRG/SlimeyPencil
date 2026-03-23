extends Node3D
class_name MachineWalker

## MachineWalker mob — attacks back when hit, plays KD anim on knockdown.

const MODEL_PATH := "res://Characters/Coronet/NPC/MachineWalker/idle/Meshy_AI_android_war_machine_f_biped_Animation_Idle_5_frame_rate_60.fbx"
const ANIM_PATHS := {
	"walk":    "res://Characters/Coronet/NPC/MachineWalker/walk/Meshy_AI_android_war_machine_f_biped_Animation_Walking_frame_rate_60.fbx",
	"attack":  "res://Characters/Coronet/NPC/MachineWalker/attack/attack1/Meshy_AI_android_war_machine_f_biped_Animation_Left_Hook_from_Guard_frame_rate_60.fbx",
	"attack2": "res://Characters/Coronet/NPC/MachineWalker/attack/attack2/Meshy_AI_android_war_machine_f_biped_Animation_Punch_Combo_frame_rate_60.fbx",
	"attack3": "res://Characters/Coronet/NPC/MachineWalker/attack/attack3/Meshy_AI_android_war_machine_f_biped_Animation_Triple_Combo_Attack_frame_rate_60.fbx",
	"kd":      "res://Characters/Coronet/NPC/MachineWalker/kd/Meshy_AI_android_war_machine_f_biped_Animation_Knock_Down_1_frame_rate_60.fbx",
}

@export var mob_name : String = "Machine Walker"
@export var max_hp : float = 400.0
@export var max_action : float = 250.0
@export var max_mind : float = 150.0
@export var level : int = 5
@export var attack_damage : float = 15.0
@export var attack_speed : float = 3.0
@export var aggro_range : float = 10.0
@export var chase_speed : float = 3.0

var accuracy : float = 48.0  # ~70% hit chance vs player defense 40
var defense : float = 25.0

var ham_health : float
var ham_action : float
var ham_mind : float

var is_dead := false
var _current_target : Node3D = null
var _attack_timer : float = 0.0
var _attack_anim_timer : float = 0.0
var _anim : AnimationPlayer = null
var _armature : Node3D = null
var _model : Node3D = null

# Combat states
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

func _spawn_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		print("MachineWalker: model not found: ", MODEL_PATH)
		return
	var scene : PackedScene = load(MODEL_PATH)
	if scene == null:
		return
	_model = scene.instantiate()
	_model.scale = Vector3(1.75, 1.75, 1.75)
	add_child(_model)

	_anim = _find_anim_player(_model)
	_armature = _model.get_node_or_null("Armature")

	# Load additional animations
	if _anim:
		for anim_name in ANIM_PATHS:
			_load_anim(anim_name, ANIM_PATHS[anim_name])
		_strip_position_tracks()
		_set_loop_modes()
		# Play idle
		for a in _anim.get_animation_list():
			if a != "RESET" and a not in ANIM_PATHS.keys():
				_anim.play(a)
				break

	# Add name label
	var lbl := Label3D.new()
	lbl.text = mob_name + " [Lv" + str(level) + "]"
	lbl.position = Vector3(0, 2.5, 0)
	lbl.font_size = 28
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.8, 0.3, 1.0)
	add_child(lbl)

func _load_anim(anim_name : String, path : String) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene : PackedScene = load(path)
	if scene == null:
		return
	var temp : Node = scene.instantiate()
	var temp_ap := _find_anim_player(temp)
	if temp_ap == null:
		temp.queue_free()
		return
	for src_name in temp_ap.get_animation_list():
		if src_name == "RESET":
			continue
		var anim : Animation = temp_ap.get_animation(src_name)
		if anim:
			var dupe : Animation = anim.duplicate(true)
			var lib := _anim.get_animation_library("")
			if lib == null:
				lib = AnimationLibrary.new()
				_anim.add_animation_library("", lib)
			if lib.has_animation(anim_name):
				lib.remove_animation(anim_name)
			lib.add_animation(anim_name, dupe)
			break
	temp.queue_free()

func _strip_position_tracks() -> void:
	if _anim == null:
		return
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			if anim_name == "RESET":
				continue
			var anim := lib.get_animation(anim_name)
			if anim:
				var dupe : Animation = anim.duplicate(true)
				for i in range(dupe.get_track_count() - 1, -1, -1):
					if dupe.track_get_type(i) == Animation.TYPE_POSITION_3D:
						dupe.remove_track(i)
				lib.remove_animation(anim_name)
				lib.add_animation(anim_name, dupe)

func _set_loop_modes() -> void:
	if _anim == null:
		return
	for lib_name in _anim.get_animation_library_list():
		var lib := _anim.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			if anim == null or anim_name == "RESET":
				continue
			var lower := anim_name.to_lower()
			if "idle" in lower or "walk" in lower:
				anim.loop_mode = Animation.LOOP_LINEAR
			elif lower not in ["attack", "attack2", "attack3", "kd"]:
				anim.loop_mode = Animation.LOOP_LINEAR
			else:
				anim.loop_mode = Animation.LOOP_NONE

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

func _play_mob_anim(anim_name : String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim_name):
		_anim.stop()
		_anim.play(anim_name)

func _process(delta : float) -> void:
	if is_dead:
		return

	# Lock armature position to prevent sliding
	if _armature:
		_armature.position = Vector3.ZERO

	# Tick states
	if state_dizzy > 0.0:
		state_dizzy -= delta
	if state_stun > 0.0:
		state_stun -= delta
	if state_blind > 0.0:
		state_blind -= delta
	if state_intimidate > 0.0:
		state_intimidate -= delta

	# Knockdown — can't act
	if state_knockdown > 0.0:
		# Only lower model in second half of KD anim (after the fall)
		if _model and _anim:
			var kd_len := 0.0
			if _anim.has_animation("kd"):
				kd_len = _anim.get_animation("kd").length
			var playback_pos := _anim.current_animation_position if _anim.current_animation == "kd" else kd_len
			if kd_len > 0.0 and playback_pos > kd_len * 0.5:
				_model.position.y = lerp(_model.position.y, -1.2, 8.0 * delta)
		return
	else:
		if _model and _model.position.y < -0.01:
			_model.position.y = lerp(_model.position.y, 0.0, 8.0 * delta)

	# Attack anim timer
	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta
		if _attack_anim_timer <= 0.0:
			_play_mob_anim("idle" if _current_target == null else "walk")

	# Chase and attack target
	if _current_target and is_instance_valid(_current_target):
		var dist := global_position.distance_to(_current_target.global_position)
		# Face target
		var dir := (_current_target.global_position - global_position).normalized()
		var target_angle := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 15.0 * delta)

		if dist > 2.5:
			# Chase
			position += dir * chase_speed * delta
			position.y = 0.0
			if _attack_anim_timer <= 0.0 and _anim and _anim.current_animation != "walk":
				_play_mob_anim("walk")
		else:
			# In range — stop moving, play idle between attacks
			if _attack_anim_timer <= 0.0 and _anim and _anim.current_animation == "walk":
				_play_mob_anim("idle")
			_attack_timer -= delta
			if _attack_timer <= 0.0 and _attack_anim_timer <= 0.0:
				_do_mob_attack()
				_attack_timer = attack_speed
	else:
		_current_target = null

func _do_mob_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	# Pick random attack anim
	var atk_anims := ["attack", "attack2", "attack3"]
	var pick : String = atk_anims[randi() % atk_anims.size()]
	if _anim and _anim.has_animation(pick):
		_play_mob_anim(pick)
		_attack_anim_timer = _anim.get_animation(pick).length
	else:
		_play_mob_anim("attack")
		_attack_anim_timer = 1.5

	# Roll to hit using CombatEngine
	var player := _find_player()
	if player:
		var attack_data := {"is_ranged": false}
		var result := CombatEngine.roll_to_hit(self, player, attack_data)
		match result.get("result", "miss"):
			"miss":
				player._spawn_damage_text(player._active, "MISS", Color(0.7, 0.7, 0.7))
				player._log_combat("[color=gray]" + mob_name + " misses you[/color]")
				player._play_anim("dodge")
				player._attack_anim_timer = 0.8
				player._anim_state = "attack"
			"dodge":
				player._spawn_damage_text(player._active, "DODGE", Color(0.3, 0.8, 1.0))
				player._log_combat("[color=cyan]You dodge " + mob_name + "'s attack![/color]")
				player._play_anim("dodge")
				player._attack_anim_timer = 0.8
				player._anim_state = "attack"
			"block":
				var reduction : float = result.get("reduction", 0.75)
				var dmg := (attack_damage + randf_range(-3.0, 5.0)) * (1.0 - reduction)
				player.ham_health -= dmg
				player.ham_health = maxf(0.0, player.ham_health)
				player._spawn_damage_text(player._active, str(int(dmg)), Color(1.0, 0.6, 0.2))
				player._log_combat("[color=orange]You block " + mob_name + "! (" + str(int(dmg)) + " dmg)[/color]")
			_:  # hit
				var dmg := attack_damage + randf_range(-3.0, 5.0)
				player.ham_health -= dmg
				player.ham_health = maxf(0.0, player.ham_health)
				player._spawn_damage_text(player._active, str(int(dmg)), Color(1, 0.3, 0.3))
				player._log_combat("[color=red]" + mob_name + " hits you for " + str(int(dmg)) + " damage[/color]")

func _find_player() -> Node:
	var parent := get_parent()
	if parent and parent.has_method("_log_combat"):
		return parent
	return null

func take_damage(amount : float, pool : String = "health") -> void:
	if is_dead:
		return
	match pool:
		"health":
			ham_health = maxf(0.0, ham_health - amount)
		"action":
			ham_action = maxf(0.0, ham_action - amount)
		"mind":
			ham_mind = maxf(0.0, ham_mind - amount)
	# Aggro — fight back when hit
	if _current_target == null:
		var player := _find_player()
		if player and player._active:
			_current_target = player._active
			_attack_timer = 0.5  # short delay before first counter-attack
	if ham_health <= 0.0:
		_die()

func apply_combat_state(state_name : String, duration : float) -> void:
	match state_name:
		"dizzy":
			state_dizzy = maxf(state_dizzy, duration)
		"knockdown":
			state_knockdown = maxf(state_knockdown, duration)
			if _anim and _anim.has_animation("kd"):
				_anim.stop()
				_anim.play("kd", -1, 1.3)  # 30% faster
		"stun":
			state_stun = maxf(state_stun, duration)
		"blind":
			state_blind = maxf(state_blind, duration)
		"intimidate":
			state_intimidate = maxf(state_intimidate, duration)

func _die() -> void:
	is_dead = true
	_current_target = null
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 1.0)
	tw.tween_callback(queue_free)

func get_display_name() -> String:
	return mob_name
