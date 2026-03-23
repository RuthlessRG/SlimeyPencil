extends Node3D
class_name CoronetMob

## Simple 3D mob for Coronet scene. Place as child of scene root.

@export var mob_name : String = "Training Dummy"
@export var max_hp : float = 500.0
@export var max_action : float = 300.0
@export var max_mind : float = 200.0
@export var level : int = 5
@export var attack_damage : float = 20.0
@export var attack_speed : float = 2.5  # seconds between attacks
@export var aggro_range : float = 0.0   # 0 = passive, >0 = auto-aggro

# Stats for CombatEngine
var accuracy : float = 50.0
var defense : float = 30.0

# HAM pools
var ham_health : float
var ham_action : float
var ham_mind : float

# Combat state
var is_dead := false
var _current_target : Node3D = null
var _attack_timer : float = 0.0
var _anim : AnimationPlayer

# Combat states (for CombatEngine)
var state_dizzy : float = 0.0
var state_knockdown : float = 0.0
var state_stun : float = 0.0
var state_blind : float = 0.0
var state_intimidate : float = 0.0

func _ready() -> void:
	ham_health = max_hp
	ham_action = max_action
	ham_mind = max_mind
	_anim = _find_anim_player(self)
	if _anim:
		# Play idle animation
		for a in _anim.get_animation_list():
			if a != "RESET":
				var anim_res := _anim.get_animation(a)
				if anim_res:
					anim_res.loop_mode = Animation.LOOP_LINEAR
				_anim.play(a)
				break

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

func _process(delta : float) -> void:
	if is_dead:
		return
	# Tick combat states
	if state_dizzy > 0.0: state_dizzy -= delta
	if state_knockdown > 0.0: state_knockdown -= delta
	if state_stun > 0.0: state_stun -= delta
	if state_blind > 0.0: state_blind -= delta
	if state_intimidate > 0.0: state_intimidate -= delta

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
	if ham_health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	# Simple death: shrink and fade (can improve later)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 1.0)
	tw.tween_callback(queue_free)

func apply_combat_state(state_name : String, duration : float) -> void:
	match state_name:
		"dizzy":
			state_dizzy = maxf(state_dizzy, duration)
		"knockdown":
			state_knockdown = maxf(state_knockdown, duration)
		"stun":
			state_stun = maxf(state_stun, duration)
		"blind":
			state_blind = maxf(state_blind, duration)
		"intimidate":
			state_intimidate = maxf(state_intimidate, duration)

func get_display_name() -> String:
	return mob_name
