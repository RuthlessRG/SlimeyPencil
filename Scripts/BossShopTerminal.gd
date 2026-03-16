extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  BossShopTerminal.gd — Futuristic vending machine
#  Drawn entirely in code. Player approaches + presses F
#  to open the shop window.
# ============================================================

const INTERACT_RANGE : float = 38.0

var _t           : float = 0.0
var _player_near : bool  = false
var _prompt_lbl  : Label = null

func _ready() -> void:
	add_to_group("shop_terminal")

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_lbl.text = "[F]  Open Shop"
	_prompt_lbl.add_theme_font_size_override("font_size", 9)
	_prompt_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.position = Vector2(-28, -58)
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
	var glow        = 0.60 + sin(_t * 2.1) * 0.28
	var screen_glow = 0.55 + sin(_t * 3.7) * 0.22

	# 2.5D isometric kiosk — 30% smaller
	const FW : float = 25.0    # front face width
	const FH : float = 33.0    # front face height
	const SD : float = 10.0    # side depth (right face)
	const SH : float = 6.0     # top face height offset (iso shear)

	var lx = -FW * 0.5
	var ty = -FH - SH           # top-left of front face (feet at y=0)

	# ── Cast shadow (sun from NW, shadow falls SE on ground) ──
	var sh_poly = PackedVector2Array([
		Vector2(lx + FW, ty + SH + FH),          # front-face bottom-right
		Vector2(lx + FW + SD, ty + FH),           # side-face bottom-right
		Vector2(lx + FW + SD + 8, ty + FH + 5),   # shadow tip far right
		Vector2(lx + FW + 8, ty + SH + FH + 5),   # shadow tip near right
		Vector2(lx + 4, ty + SH + FH + 3),        # shadow base near left
		Vector2(lx, ty + SH + FH),                # front-face bottom-left
	])
	draw_colored_polygon(sh_poly, Color(0, 0, 0, 0.25))

	# ── Proximity aura ────────────────────────────────────────
	if _player_near:
		var aa = 0.10 + sin(_t * 4.5) * 0.05
		var ap = PackedVector2Array()
		for i in 20:
			var a = float(i) / 20.0 * TAU
			ap.append(Vector2(cos(a) * (FW * 0.6 + 10), sin(a) * (FH * 0.35 + 10) - FH * 0.45))
		draw_colored_polygon(ap, Color(0.15, 0.75, 1.0, aa))

	# ── Top face (parallelogram) ──────────────────────────────
	var top_poly = PackedVector2Array([
		Vector2(lx, ty + SH),
		Vector2(lx + SD, ty),
		Vector2(lx + FW + SD, ty),
		Vector2(lx + FW, ty + SH),
	])
	draw_colored_polygon(top_poly, Color(0.16, 0.20, 0.28))
	# Top face highlight edge
	draw_line(Vector2(lx + SD, ty), Vector2(lx + FW + SD, ty), Color(0.30, 0.80, 1.0, 0.35 * glow), 1.0)

	# ── Right side face (parallelogram) ───────────────────────
	var side_poly = PackedVector2Array([
		Vector2(lx + FW, ty + SH),
		Vector2(lx + FW + SD, ty),
		Vector2(lx + FW + SD, ty + FH),
		Vector2(lx + FW, ty + SH + FH),
	])
	draw_colored_polygon(side_poly, Color(0.06, 0.07, 0.11))
	# Side panel lines (vents)
	for vi in 4:
		var vy = ty + SH + 8 + vi * 8.0
		var vx0 = lx + FW + 1.5
		var vx1 = lx + FW + SD - 1.5
		var vy_off = (vy - (ty + SH)) / FH * -SH
		draw_line(Vector2(vx0, vy), Vector2(vx1, vy + vy_off * 0.3), Color(0.10, 0.12, 0.18), 0.8)

	# ── Front face ────────────────────────────────────────────
	draw_rect(Rect2(lx, ty + SH, FW, FH), Color(0.08, 0.10, 0.16))
	# Inner panel bevel
	draw_rect(Rect2(lx + 1.5, ty + SH + 1.5, FW - 3, FH - 3), Color(0.11, 0.14, 0.22))
	# Subtle vertical panel seam
	draw_line(Vector2(lx + FW * 0.5, ty + SH + 2), Vector2(lx + FW * 0.5, ty + SH + FH - 2), Color(0.06, 0.08, 0.12), 0.6)

	# ── Top brand stripe (cyan, on front face) ────────────────
	draw_rect(Rect2(lx, ty + SH, FW, 5), Color(0.10, 0.50, 0.78))
	draw_rect(Rect2(lx, ty + SH, FW, 2.5), Color(0.22, 0.78, 1.00, 0.88))

	# ── Screen area ───────────────────────────────────────────
	var sx  = lx + 4
	var sy  = ty + SH + 7
	var sw  = FW - 8
	var sh2 = 17.0
	# Screen recess
	draw_rect(Rect2(sx - 1, sy - 1, sw + 2, sh2 + 2), Color(0.03, 0.04, 0.08))
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.02, 0.05, 0.12))
	# Screen glow overlay
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.10, 0.55, 1.0, screen_glow * 0.18))
	# Scanlines
	for si in 2:
		draw_rect(Rect2(sx + 1, sy + 3 + si * 6, sw - 2, 1.0), Color(0.30, 0.80, 1.0, 0.28 * screen_glow))
	# Screen border
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.20, 0.68, 1.0, 0.55), false, 1.0)
	# Screen text
	var font = _roboto
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz1 = maxi(1, int(round(6 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 7), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "SYNTH-BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz1, Color(0.35, 1.0, 1.0, screen_glow))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var _rend_sz2 = maxi(1, int(round(5 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 14), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "MARKET v2.1", HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz2, Color(0.25, 0.75, 0.85, screen_glow * 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── Indicator lights ──────────────────────────────────────
	var lt_y = ty + SH + 27.0
	var lt_colors = [Color(0.10, 1.00, 0.35), Color(0.15, 0.65, 1.0), Color(1.0, 0.85, 0.10)]
	for li in 3:
		var ltx = lx + 5 + li * 9.0
		draw_circle(Vector2(ltx, lt_y), 2.2, lt_colors[li].darkened(0.45))
		draw_circle(Vector2(ltx, lt_y), 1.5, lt_colors[li])
		draw_circle(Vector2(ltx, lt_y), 3.5, Color(lt_colors[li].r, lt_colors[li].g, lt_colors[li].b, 0.20 * glow))

	# ── Dispense slot recess ──────────────────────────────────
	draw_rect(Rect2(lx + 7, ty + SH + FH - 12, FW - 14, 7), Color(0.03, 0.03, 0.05))
	draw_rect(Rect2(lx + 8.5, ty + SH + FH - 10.5, FW - 17, 4), Color(0.01, 0.01, 0.02))

	# ── Bottom brand stripe ───────────────────────────────────
	draw_rect(Rect2(lx, ty + SH + FH - 4, FW, 4), Color(0.10, 0.50, 0.78, 0.75))

	# ── Metal bolts at corners ────────────────────────────────
	for bpos in [Vector2(lx + 3, ty + SH + 3), Vector2(lx + FW - 3, ty + SH + 3),
				 Vector2(lx + 3, ty + SH + FH - 3), Vector2(lx + FW - 3, ty + SH + FH - 3)]:
		draw_circle(bpos, 1.5, Color(0.25, 0.30, 0.40))
		draw_circle(bpos, 0.8, Color(0.35, 0.42, 0.55))

	# ── Outer glow outline ────────────────────────────────────
	draw_rect(Rect2(lx, ty + SH, FW, FH), Color(0.20, 0.62, 0.92, 0.40 * glow), false, 1.2)
	# Side edge glow
	draw_line(Vector2(lx + FW, ty + SH), Vector2(lx + FW + SD, ty), Color(0.20, 0.62, 0.92, 0.25 * glow), 1.0)
