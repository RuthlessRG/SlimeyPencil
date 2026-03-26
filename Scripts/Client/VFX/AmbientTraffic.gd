extends Node3D

## AmbientTraffic — Spawns ships flying through the city overhead.
## Creates a bustling sci-fi city feel with varied ship types, speeds, heights.

const SHIP_MODELS := [
	"res://Coronet/Mounts/spidershipgood/animated-sci_fi_ship.glb",
	"res://Coronet/Mounts/transport/Transport Shuttle_fbx.fbx",
]

# Ship scales — tuned per model
const SHIP_SCALES := [
	0.4,   # 0 spider ship
	0.04,  # 1 transport shuttle
]

# Rotation offsets — FBX forward varies per model
const SHIP_ROT_OFFSETS := [
	PI,        # 0 spider — faces backward
	PI,        # 1 transport — faces backward
]

const MAX_SHIPS := 20
const SPAWN_INTERVAL := 1.5   # seconds between new ship spawns
const CITY_RADIUS := 100.0    # how far out ships spawn/despawn
const MIN_HEIGHT := 25.0      # above building tops
const MAX_HEIGHT := 60.0
const MIN_SPEED := 8.0
const MAX_SPEED := 25.0

var _ships : Array = []
var _spawn_timer := 0.0
var _loaded_scenes := {}

func _ready() -> void:
	for path in SHIP_MODELS:
		if ResourceLoader.exists(path):
			_loaded_scenes[path] = load(path)
		else:
			print("TRAFFIC: Ship model not found: ", path)
	# Spawn initial batch spread across the sky
	for i in range(10):
		_spawn_ship(true)

func _process(delta : float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _ships.size() < MAX_SHIPS:
		_spawn_ship(false)
		_spawn_timer = SPAWN_INTERVAL + randf_range(-0.5, 0.5)

	var to_remove := []
	for i in range(_ships.size()):
		var ship_data : Dictionary = _ships[i]
		var node : Node3D = ship_data.node
		if not is_instance_valid(node):
			to_remove.append(i)
			continue
		node.position += ship_data.velocity * delta
		var dist := Vector2(node.position.x, node.position.z).length()
		if dist > CITY_RADIUS * 1.5:
			node.queue_free()
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		_ships.remove_at(idx)

func _spawn_ship(instant : bool) -> void:
	if _loaded_scenes.is_empty():
		return

	var model_idx := randi() % SHIP_MODELS.size()
	var path : String = SHIP_MODELS[model_idx]
	if path not in _loaded_scenes:
		return
	var scene : PackedScene = _loaded_scenes[path]
	if scene == null:
		return

	var ship := scene.instantiate() as Node3D
	if ship == null:
		return

	var s : float = SHIP_SCALES[model_idx] * randf_range(0.8, 1.2)
	ship.scale = Vector3(s, s, s)

	var height := randf_range(MIN_HEIGHT, MAX_HEIGHT)

	# Pick a flight lane — use defined corridors to reduce building hits
	# Corridors: fly along X axis, Z axis, or diagonals at safe heights
	var lane := randi() % 4
	var travel_angle : float
	match lane:
		0: travel_angle = 0.0 + randf_range(-0.3, 0.3)          # East-West
		1: travel_angle = PI * 0.5 + randf_range(-0.3, 0.3)     # North-South
		2: travel_angle = PI * 0.25 + randf_range(-0.2, 0.2)    # NE-SW diagonal
		_: travel_angle = PI * 0.75 + randf_range(-0.2, 0.2)    # NW-SE diagonal
	# Randomly flip direction
	if randi() % 2 == 0:
		travel_angle += PI

	var speed := randf_range(MIN_SPEED, MAX_SPEED)
	var velocity := Vector3(cos(travel_angle), 0, sin(travel_angle)) * speed
	velocity.y = randf_range(-0.2, 0.2)

	var spawn_dist := CITY_RADIUS if not instant else randf_range(15.0, CITY_RADIUS * 0.7)
	var start_angle := travel_angle + PI
	if instant:
		start_angle = randf_range(0, TAU)

	# Offset spawn laterally so ships don't all fly through center
	var lateral_offset := randf_range(-30.0, 30.0)
	var lateral_dir := Vector3(-sin(travel_angle), 0, cos(travel_angle))

	ship.position = Vector3(
		cos(start_angle) * spawn_dist,
		height,
		sin(start_angle) * spawn_dist
	) + lateral_dir * lateral_offset

	var face_angle := atan2(velocity.x, velocity.z)
	ship.rotation.y = face_angle + SHIP_ROT_OFFSETS[model_idx]

	add_child(ship)
	_ships.append({
		"node": ship,
		"velocity": velocity,
		"model_idx": model_idx,
	})
