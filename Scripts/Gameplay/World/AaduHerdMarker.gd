@tool
extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  AaduHerdMarker.gd — miniSWG  (@tool — visible in editor)
#
#  Add this as a child of spaceport.tscn in the Godot editor
#  to place an Aadu herd anywhere on the map.
#  SpaceportScene reads all nodes in "aadu_herd_marker" group
#  at game start and spawns herds at each marker's position.
# ============================================================

@export var herd_min      : int   = 2
@export var herd_max      : int   = 6
@export var wander_radius : float = 200.0
@export var baby_chance   : float = 0.25   # 0–1: fraction of herd that are calves

func _ready() -> void:
	add_to_group("aadu_herd_marker")

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	# Wander area ring
	draw_arc(Vector2.ZERO, wander_radius, 0.0, TAU, 64,
		Color(0.55, 0.90, 0.35, 0.55), 1.8)
	draw_circle(Vector2.ZERO, wander_radius, Color(0.55, 0.90, 0.35, 0.08))
	# Centre dot
	draw_circle(Vector2.ZERO, 6.0, Color(0.55, 0.90, 0.35, 0.90))
	# Label
	var font = _roboto
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz = maxi(1, int(round(12 * _ct_sc.x)))
		draw_set_transform(Vector2(-36, -wander_radius - 10), 0.0, _inv)
		draw_string(font, Vector2.ZERO,
			"Aadu  x%d–%d%s" % [herd_min, herd_max, "  (babies)" if baby_chance > 0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz,
			Color(0.65, 1.0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
