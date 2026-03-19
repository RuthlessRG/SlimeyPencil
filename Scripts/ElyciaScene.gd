extends Node2D

# ============================================================
#  ElyciaScene.gd — miniSWG | Elycia
#
#  Sci-fi themed isometric scene with grey stone tile floor.
#  Uses TileMapLayer in isometric mode for the ground,
#  Y-sorted Node2D children for player and objects.
#
#  Attach to: elycia.tscn
# ============================================================

# ── ISOMETRIC GRID ──────────────────────────────────────────────
const TILE_W     : int   = 128
const TILE_H     : int   = 64
const GRID_SIZE  : int   = 128
const GRID_CENTER: int   = 64

# ── SCENE NODES ────────────────────────────────────────────────
var _tilemap       : TileMapLayer = null
var _world_layer   : Node2D       = null
var _camera        : Camera2D     = null
var _player        : Node         = null
var _cam_zoom_target : float      = 3.2

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_arena_scene")
	_setup_tilemap()
	_setup_camera()

# ── TILEMAP SETUP ─────────────────────────────────────────────
func _setup_tilemap() -> void:
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_size  = Vector2i(TILE_W, TILE_H)

	_tilemap = TileMapLayer.new()
	_tilemap.tile_set = tileset
	_tilemap.visible  = false
	add_child(_tilemap)

	# Seamless sci-fi stone floor background
	var bg_node = Node2D.new()
	bg_node.z_index = -10
	bg_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_node.set_script(_make_bg_script())
	add_child(bg_node)

	# Y-sort container for player and objects
	_world_layer = Node2D.new()
	_world_layer.name = "WorldLayer"
	_world_layer.y_sort_enabled = true
	add_child(_world_layer)

# ── CAMERA ────────────────────────────────────────────────────
func _setup_camera() -> void:
	_camera      = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = Vector2.ZERO
	_camera.zoom     = Vector2(3.2, 3.2)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()

# ── COORDINATE HELPERS ────────────────────────────────────────
func _tile_to_world(tx: int, ty: int) -> Vector2:
	if _tilemap:
		return _tilemap.map_to_local(Vector2i(tx, ty))
	return Vector2(float(tx - ty) * TILE_W * 0.5, float(tx + ty) * TILE_H * 0.5)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	if _tilemap:
		return _tilemap.local_to_map(world_pos)
	return Vector2i(0, 0)

# ── BACKGROUND SCRIPT (seamless tiled sci-fi stone texture) ───
func _make_bg_script() -> GDScript:
	var src = """extends Node2D

var _floor_tex : Texture2D = null

func _ready():
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_floor_tex = load("res://Assets/Backgrounds/elycia_floor.png") as Texture2D

func _draw():
	if _floor_tex == null:
		draw_rect(Rect2(-4000, -4000, 8000, 8000), Color(0.75, 0.77, 0.81))
		return
	var extents := 4000.0
	draw_texture_rect_region(
		_floor_tex,
		Rect2(-extents, -extents, extents * 2.0, extents * 2.0),
		Rect2(0, 0, extents * 2.0, extents * 2.0)
	)
"""
	var s = GDScript.new()
	s.source_code = src
	s.reload()
	return s
