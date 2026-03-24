extends Node2D

var character_name : String = "Player"
var hp             : float  = 100.0
var max_hp         : float  = 100.0

func _ready() -> void:
	add_to_group("remote_player")
	# "targetable" added only during an active duel via DuelSystem._enable_duel_combat

func get_target_position() -> Vector2:
	return global_position

func take_damage(amount: float) -> void:
	hp = maxf(0.0, hp - amount)
