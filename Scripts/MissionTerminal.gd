extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  MissionTerminal.gd — Mission board terminal
#  Same interaction pattern as BossShopTerminal.
#  Player approaches + presses F to open mission window.
# ============================================================

const INTERACT_RANGE : float = 58.0

var _t           : float = 0.0
var _player_near : bool  = false
var _prompt_lbl  : Label = null

func _ready() -> void:
	add_to_group("mission_terminal")

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_lbl.text = "[F]  Missions"
	_prompt_lbl.add_theme_font_size_override("font_size", 9)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.position = Vector2(-28, -78)
	_prompt_lbl.size     = Vector2(60, 14)
	_prompt_lbl.visible  = false
	_prompt_lbl.z_index  = 10
	add_child(_prompt_lbl)

func _process(delta: float) -> void:
	_t += delta
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
	var glow        = 0.55 + sin(_t * 1.9) * 0.30
	var screen_glow = 0.50 + sin(_t * 3.3) * 0.25

	const W : float = 44.0
	const H : float = 58.0
	var lx  = -W * 0.5
	var ty  = -H

	# Ground shadow
	var sh = PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		sh.append(Vector2(cos(a) * W * 0.52, sin(a) * H * 0.15) + Vector2(0, 3))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.30))

	# Proximity aura (amber glow)
	if _player_near:
		var aa = 0.10 + sin(_t * 4.5) * 0.05
		var ap = PackedVector2Array()
		for i in 20:
			var a = float(i) / 20.0 * TAU
			ap.append(Vector2(cos(a) * (W * 0.55 + 12), sin(a) * (H * 0.5 + 12) - H * 0.5))
		draw_colored_polygon(ap, Color(0.85, 0.55, 0.05, aa))

	# Machine body
	draw_rect(Rect2(lx,     ty,     W,     H    ), Color(0.09, 0.07, 0.04, 1.0))
	draw_rect(Rect2(lx + 1, ty + 1, W - 2, H - 2), Color(0.14, 0.10, 0.05, 1.0))

	# Top brand stripe (amber)
	draw_rect(Rect2(lx, ty,     W, 7), Color(0.65, 0.38, 0.05, 1.0))
	draw_rect(Rect2(lx, ty,     W, 3), Color(0.90, 0.58, 0.08, 0.88))

	# Screen area
	var sx  = lx + 5
	var sy  = ty + 10
	var sw  = W - 10
	var sh2 = 24.0
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.06, 0.04, 0.01, 1.0))
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.80, 0.50, 0.05, screen_glow * 0.14))
	# Scanlines
	for si in 3:
		draw_rect(Rect2(sx + 2, sy + 4 + si * 7, sw - 4, 1.2),
			Color(0.90, 0.60, 0.10, 0.24 * screen_glow))
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.75, 0.45, 0.08, 0.55), false, 1.2)
	# Screen text
	var font = _roboto
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz1 = maxi(1, int(round(7 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 10), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "MISSIONS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz1, Color(0.95, 0.72, 0.18, screen_glow))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var _rend_sz2 = maxi(1, int(round(6 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 19), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "BOARD  v3.2",
			HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz2, Color(0.75, 0.55, 0.14, screen_glow * 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Indicator lights
	var lt_y     = ty + 38.0
	var lt_colors = [Color(0.95, 0.65, 0.05), Color(0.80, 0.40, 0.05), Color(0.40, 0.80, 0.10)]
	for li in 3:
		var ltx = lx + 7 + li * 12.0
		draw_circle(Vector2(ltx, lt_y), 3.0, lt_colors[li].darkened(0.45))
		draw_circle(Vector2(ltx, lt_y), 2.0, lt_colors[li])
		draw_circle(Vector2(ltx, lt_y), 5.0,
			Color(lt_colors[li].r, lt_colors[li].g, lt_colors[li].b, 0.18 * glow))

	# Dispense slot
	draw_rect(Rect2(lx + 11, ty + H - 16, W - 22, 9), Color(0.04, 0.03, 0.01, 1.0))
	draw_rect(Rect2(lx + 13, ty + H - 14, W - 26, 5), Color(0.02, 0.01, 0.00, 1.0))

	# Bottom brand stripe
	draw_rect(Rect2(lx, ty + H - 6, W, 6), Color(0.65, 0.38, 0.05, 0.75))

	# Outer glow
	draw_rect(Rect2(lx, ty, W, H), Color(0.80, 0.50, 0.08, 0.45 * glow), false, 1.5)
