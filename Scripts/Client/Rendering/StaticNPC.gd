extends Node2D

# ============================================================
#  StaticNPC.gd — miniSWG
#  Placeable ambient NPC from sprite sheets.
#  Place in editor, pick sheet + index, drag to position.
# ============================================================

## Which sprite sheet: 0 = npcsalpha.png, 1 = npcs1alpha.png
@export_range(0, 1) var sheet : int = 0 :
	set(v):
		sheet = v
		queue_redraw()

## Which NPC in the sheet (0-9: row0 col0..4, row1 col0..4)
@export_range(0, 9) var npc_index : int = 0 :
	set(v):
		npc_index = v
		queue_redraw()

## Visual scale
@export var npc_scale : float = 0.087 :
	set(v):
		npc_scale = v
		queue_redraw()

const CELL_W : int = 288
const CELL_H : int = 360
const COLS   : int = 5

var _t : float = 0.0
var _tex0 : Texture2D = null
var _tex1 : Texture2D = null

func _ready() -> void:
	_tex0 = load("res://Characters/NEWFOUNDMETHOD/NPC/npcsalpha.png") as Texture2D
	_tex1 = load("res://Characters/NEWFOUNDMETHOD/NPC/npcs1alpha.png") as Texture2D
	add_to_group("npc")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var tex = _tex0 if sheet == 0 else _tex1
	if tex == null:
		# Fallback placeholder
		draw_circle(Vector2.ZERO, 8, Color(0.5, 0.8, 0.3))
		return

	var col = npc_index % COLS
	var row = npc_index / COLS
	# Trim 40px margins left/right to clip neighbor bleed
	var margin : int = 40
	var trimmed_w = CELL_W - margin * 2
	var src_rect = Rect2(col * CELL_W + margin, row * CELL_H, trimmed_w, CELL_H)

	var draw_w = trimmed_w * npc_scale
	var draw_h = CELL_H * npc_scale

	var bob = 0.0

	# Shadow
	var shadow_w = draw_w * 0.5
	var shadow_h = draw_h * 0.08
	var shadow_pts = PackedVector2Array()
	for i in 12:
		var a = float(i) / 12.0 * TAU
		shadow_pts.append(Vector2(cos(a) * shadow_w * 0.5, sin(a) * shadow_h))
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.18))

	# Draw NPC — origin at feet (bottom center of cell)
	var dest_rect = Rect2(-draw_w * 0.5, -draw_h + bob, draw_w, draw_h)
	draw_texture_rect_region(tex, dest_rect, src_rect)
