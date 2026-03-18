extends Node2D

# ============================================================
#  MobSpawner.gd — Place in viewport, spawns mobs at runtime
#  Add as child of WorldLayer in theed.tscn
#  Set mob_type via Inspector or node name convention:
#    VampireSpawner, ThugSpawner, ZergSpawner, CyberSpawner
# ============================================================

@export_enum("vampire", "armored_thug", "zerg", "cyber") var mob_type : String = "vampire"
@export var mob_count : int = 2
@export var spawn_radius : float = 80.0
@export var respawn_time : float = 30.0

var _spawned : Array = []
var _respawn_timers : Array = []

func _ready() -> void:
	# Auto-detect type from node name if not set
	var n = name.to_lower()
	if "vampire" in n: mob_type = "vampire"
	elif "thug" in n or "armor" in n: mob_type = "armored_thug"
	elif "zerg" in n: mob_type = "zerg"
	elif "cyber" in n: mob_type = "cyber"

	# Wait one frame for scene to be fully loaded
	await get_tree().process_frame
	_do_initial_spawn()

func _process(delta: float) -> void:
	# Check for dead mobs and start respawn timers
	for i in range(_spawned.size() - 1, -1, -1):
		if _spawned[i] == null or not is_instance_valid(_spawned[i]):
			_spawned.remove_at(i)
			_respawn_timers.append(respawn_time)

	# Tick respawn timers
	for i in range(_respawn_timers.size() - 1, -1, -1):
		_respawn_timers[i] -= delta
		if _respawn_timers[i] <= 0.0:
			_respawn_timers.remove_at(i)
			_spawn_one()

func _do_initial_spawn() -> void:
	for i in mob_count:
		_spawn_one()

func _spawn_one() -> void:
	var scene_root = get_tree().current_scene
	if scene_root == null: return

	# Random position within spawn_radius of this node
	var angle = randf() * TAU
	var dist = randf() * spawn_radius
	var pos = global_position + Vector2(cos(angle), sin(angle)) * dist

	# Call the scene's spawn function
	match mob_type:
		"vampire":
			if scene_root.has_method("_spawn_vampire"):
				scene_root.call("_spawn_vampire", pos, false)
		"armored_thug":
			if scene_root.has_method("_spawn_armored_thug"):
				scene_root.call("_spawn_armored_thug", pos, false)
		"zerg":
			if scene_root.has_method("_spawn_zerg_mob"):
				scene_root.call("_spawn_zerg_mob", pos, false)
		"cyber":
			if scene_root.has_method("_spawn_cyber_mob"):
				scene_root.call("_spawn_cyber_mob", pos, false)
