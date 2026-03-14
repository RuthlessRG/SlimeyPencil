extends Node2D

# ============================================================
#  LunarBuilding.gd — miniSWG | Lunar Station
#
#  Sprite-based building node for isometric scene.
#  A Sprite2D child displays the building image (set by spawner).
#  This script only handles the zoom-compensated name label.
#
#  Metadata:
#    "label"   : String — building name shown above sprite
#    "label_y" : float  — Y offset for label (negative = above)
# ============================================================

const C_LABEL = Color(0.72, 0.82, 0.95)
var _roboto : Font = null

func _ready() -> void:
	_roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

func _draw() -> void:
	var lbl : String = get_meta("label", "")
	if lbl.length() > 0 and _roboto != null:
		_draw_building_label(lbl)

func _draw_building_label(text: String) -> void:
	var ct_sc = get_canvas_transform().get_scale()
	var inv   = Vector2(1.0 / ct_sc.x, 1.0 / ct_sc.y)
	var sz    = 11
	var rend  = maxi(1, int(round(sz * ct_sc.x)))
	var tw    = _roboto.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, rend).x / ct_sc.x
	var ly    : float = get_meta("label_y", -80.0)
	draw_set_transform(Vector2(-tw * 0.5, ly), 0.0, inv)
	draw_string(_roboto, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, rend, C_LABEL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
