extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  LootBag.gd — miniSWG
#  Spawned when a mob dies with a 10% loot roll.
#  Arcs out from the death position and lands nearby.
#  Player presses F when close to open LootWindow.
# ============================================================

const INTERACT_RANGE : float = 60.0
const ARC_DURATION   : float = 0.55

var _arc_t       : float   = 0.0
var _arc_done    : bool    = false
var _start_pos   : Vector2 = Vector2.ZERO
var _end_pos     : Vector2 = Vector2.ZERO
var _draw_off_y  : float   = 0.0       # visual height offset during arc
var _arc_height  : float   = -55.0     # peak of arc (negative = up)

var _player_near : bool    = false
var _prompt_lbl  : Label   = null

var _pulse_t     : float   = 0.0

func _ready() -> void:
	add_to_group("loot_bag")
	_start_pos = global_position
	# Pick a random landing spot 45–90 px away
	var angle  = randf() * TAU
	var dist   = randf_range(45.0, 90.0)
	_end_pos   = _start_pos + Vector2(cos(angle), sin(angle)) * dist

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_lbl.text = "[F]  Loot"
	_prompt_lbl.add_theme_font_size_override("font_size", 9)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.40))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.position    = Vector2(-25, -48)
	_prompt_lbl.size        = Vector2(50, 14)
	_prompt_lbl.visible     = false
	_prompt_lbl.z_index     = 10
	_prompt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_lbl)

func _process(delta: float) -> void:
	_pulse_t += delta

	if not _arc_done:
		_arc_t += delta
		var t = minf(_arc_t / ARC_DURATION, 1.0)
		# Ease-out for ground movement
		var et = 1.0 - pow(1.0 - t, 2.0)
		global_position = _start_pos.lerp(_end_pos, et)
		# Parabolic visual height: peaks at t=0.5
		_draw_off_y = _arc_height * 4.0 * t * (1.0 - t)
		if t >= 1.0:
			_arc_done   = true
			_draw_off_y = 0.0
	else:
		# Proximity check for prompt
		var near = false
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and global_position.distance_to(p.global_position) <= INTERACT_RANGE:
				near = true
				break
		if near != _player_near:
			_player_near = near
			_prompt_lbl.visible = near

	queue_redraw()

func _draw() -> void:
	var oy = _draw_off_y   # visual height offset (0 when landed)

	# Shadow under the bag (always at ground level)
	if not _arc_done:
		var shadow_scale = 1.0 - clampf(-oy / 80.0, 0.0, 0.6)
		draw_circle(Vector2(0, 0), 9.0 * shadow_scale, Color(0, 0, 0, 0.25 * shadow_scale))

	# ── Bag body ──────────────────────────────────────────────
	var base = Vector2(0, oy)

	# Bag sack (circle)
	draw_circle(base, 11.0, Color(0.48, 0.30, 0.10))
	draw_circle(base, 11.0, Color(0.65, 0.45, 0.18), false, 1.8)

	# Highlight sheen on bag
	draw_circle(base + Vector2(-3, -3), 4.0, Color(0.80, 0.62, 0.32, 0.45))

	# Neck / tie
	var neck_rect = Rect2(base.x - 3, base.y - 18, 6, 8)
	draw_rect(neck_rect, Color(0.38, 0.22, 0.06))
	draw_rect(neck_rect, Color(0.55, 0.36, 0.12), false, 1.2)

	# Knot bow (two small arcs)
	draw_line(base + Vector2(-5, -18), base + Vector2(0, -22), Color(0.55, 0.36, 0.12), 2.0, true)
	draw_line(base + Vector2( 5, -18), base + Vector2(0, -22), Color(0.55, 0.36, 0.12), 2.0, true)

	# Credit symbol on bag
	var font = _roboto
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz = maxi(1, int(round(9 * _ct_sc.x)))
		draw_set_transform(base + Vector2(-4, 5), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "$",
			HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz,
			Color(0.95, 0.82, 0.20, 0.90))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Sparkle when landed and player nearby
	if _arc_done and _player_near:
		var sp = 0.55 + sin(_pulse_t * 5.0) * 0.45
		var sc = Color(1.0, 0.90, 0.30, sp)
		var r  = 4.0 + sin(_pulse_t * 5.0) * 1.5
		draw_circle(base + Vector2(8, -14), r * 0.5, sc)
		draw_circle(base + Vector2(-9, -5), r * 0.4, sc)
