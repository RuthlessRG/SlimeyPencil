extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  MissionTerminal.gd — Mission board terminal
#  Same interaction pattern as BossShopTerminal.
#  Player approaches + presses F to open mission window.
# ============================================================

const INTERACT_RANGE : float = 38.0

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
	_prompt_lbl.position = Vector2(-28, -62)
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
	var pulse       = 0.5 + sin(_t * 2.5) * 0.5  # 0..1 for HUD rings

	# Standing terminal — tall with legs, like SWG mission terminal
	# Origin at feet (y=0). Everything draws upward (negative y).
	var base_w : float = 30.0   # base platform width
	var base_h : float = 4.0    # base platform height
	var base_d : float = 8.0    # iso depth
	var leg_w  : float = 5.0    # each leg width
	var leg_h  : float = 22.0   # leg height
	var cab_w  : float = 24.0   # cabinet width
	var cab_h  : float = 28.0   # cabinet height
	var cab_d  : float = 7.0    # cabinet iso depth
	var shelf_h: float = 3.0    # keyboard shelf
	var total_h = base_h + leg_h + cab_h

	var foot_y : float = 0.0    # ground level

	# ── Cast shadow (SE, sun from NW) ─────────────────────────
	var sh_poly = PackedVector2Array([
		Vector2(-base_w * 0.3, foot_y),
		Vector2(base_w * 0.5, foot_y),
		Vector2(base_w * 0.5 + 6, foot_y + 2),
		Vector2(base_w * 0.3 + 8, foot_y + 5),
		Vector2(-base_w * 0.2 + 4, foot_y + 4),
	])
	draw_colored_polygon(sh_poly, Color(0, 0, 0, 0.18))

	# ── Proximity aura ────────────────────────────────────────
	if _player_near:
		var aa = 0.08 + sin(_t * 4.5) * 0.04
		var ap = PackedVector2Array()
		for i in 24:
			var a = float(i) / 24.0 * TAU
			ap.append(Vector2(cos(a) * 22, sin(a) * 8 - total_h * 0.4))
		draw_colored_polygon(ap, Color(0.9, 0.6, 0.1, aa))

	# ── BASE PLATFORM ─────────────────────────────────────────
	# Wider stepped base with two tiers
	var bt = foot_y - base_h
	# Lower tier (wider)
	var t1_w = base_w * 1.1
	draw_rect(Rect2(-t1_w * 0.5, foot_y - 2, t1_w, 2), Color(0.32, 0.30, 0.28))
	# Lower tier top face
	var t1p = PackedVector2Array([
		Vector2(-t1_w * 0.5, foot_y - 2),
		Vector2(-t1_w * 0.5 + base_d, foot_y - 2 - base_d * 0.5),
		Vector2(t1_w * 0.5 + base_d, foot_y - 2 - base_d * 0.5),
		Vector2(t1_w * 0.5, foot_y - 2),
	])
	draw_colored_polygon(t1p, Color(0.38, 0.36, 0.33))
	# Lower tier right side
	var t1sp = PackedVector2Array([
		Vector2(t1_w * 0.5, foot_y - 2),
		Vector2(t1_w * 0.5 + base_d, foot_y - 2 - base_d * 0.5),
		Vector2(t1_w * 0.5 + base_d, foot_y - base_d * 0.5),
		Vector2(t1_w * 0.5, foot_y),
	])
	draw_colored_polygon(t1sp, Color(0.20, 0.19, 0.17))

	# Upper tier (narrower)
	draw_rect(Rect2(-base_w * 0.5, bt, base_w, base_h - 2), Color(0.28, 0.27, 0.25))
	var bp = PackedVector2Array([
		Vector2(-base_w * 0.5, bt),
		Vector2(-base_w * 0.5 + base_d, bt - base_d * 0.5),
		Vector2(base_w * 0.5 + base_d, bt - base_d * 0.5),
		Vector2(base_w * 0.5, bt),
	])
	draw_colored_polygon(bp, Color(0.35, 0.33, 0.30))
	var bsp = PackedVector2Array([
		Vector2(base_w * 0.5, bt),
		Vector2(base_w * 0.5 + base_d, bt - base_d * 0.5),
		Vector2(base_w * 0.5 + base_d, bt - base_d * 0.5 + base_h - 2),
		Vector2(base_w * 0.5, foot_y - 2),
	])
	draw_colored_polygon(bsp, Color(0.18, 0.17, 0.16))

	# ── SUPPORT STRUCTURE ─────────────────────────────────────
	var leg_bot = foot_y - base_h
	var leg_top = leg_bot - leg_h
	# Back panel connecting cabinet to base (solid, not floating)
	var panel_w = cab_w * 0.7
	draw_rect(Rect2(-panel_w * 0.5, leg_top, panel_w, leg_h), Color(0.16, 0.15, 0.14))
	# Panel edge lines
	draw_line(Vector2(-panel_w * 0.5, leg_top), Vector2(-panel_w * 0.5, leg_bot), Color(0.22, 0.21, 0.19), 0.6)
	draw_line(Vector2(panel_w * 0.5, leg_top), Vector2(panel_w * 0.5, leg_bot), Color(0.22, 0.21, 0.19), 0.6)

	# Left leg column (thicker, tapered)
	var ll_x = -base_w * 0.32
	var ll_top_w = leg_w * 0.9
	var ll_bot_w = leg_w * 1.3
	var ll_poly = PackedVector2Array([
		Vector2(ll_x - ll_top_w * 0.5, leg_top),
		Vector2(ll_x + ll_top_w * 0.5, leg_top),
		Vector2(ll_x + ll_bot_w * 0.5, leg_bot),
		Vector2(ll_x - ll_bot_w * 0.5, leg_bot),
	])
	draw_colored_polygon(ll_poly, Color(0.24, 0.23, 0.21))
	# Leg highlight
	draw_line(Vector2(ll_x - ll_top_w * 0.3, leg_top + 2), Vector2(ll_x - ll_bot_w * 0.3, leg_bot - 1), Color(0.32, 0.30, 0.28), 0.8)

	# Right leg column
	var rl_x = base_w * 0.32
	var rl_poly = PackedVector2Array([
		Vector2(rl_x - ll_top_w * 0.5, leg_top),
		Vector2(rl_x + ll_top_w * 0.5, leg_top),
		Vector2(rl_x + ll_bot_w * 0.5, leg_bot),
		Vector2(rl_x - ll_bot_w * 0.5, leg_bot),
	])
	draw_colored_polygon(rl_poly, Color(0.24, 0.23, 0.21))
	draw_line(Vector2(rl_x - ll_top_w * 0.3, leg_top + 2), Vector2(rl_x - ll_bot_w * 0.3, leg_bot - 1), Color(0.32, 0.30, 0.28), 0.8)

	# Cross braces
	var brace_y1 = leg_bot - leg_h * 0.3
	var brace_y2 = leg_bot - leg_h * 0.7
	draw_line(Vector2(ll_x, brace_y1), Vector2(rl_x, brace_y1), Color(0.28, 0.26, 0.24), 1.8)
	draw_line(Vector2(ll_x, brace_y2), Vector2(rl_x, brace_y2), Color(0.28, 0.26, 0.24), 1.2)

	# Small bracket where legs meet cabinet
	draw_rect(Rect2(-cab_w * 0.5, leg_top - 1, cab_w, 3), Color(0.20, 0.19, 0.17))
	draw_line(Vector2(-cab_w * 0.5, leg_top - 1), Vector2(cab_w * 0.5, leg_top - 1), Color(0.30, 0.28, 0.26), 0.8)

	# ── CABINET BODY ──────────────────────────────────────────
	var cab_bot = leg_top
	var cab_top = cab_bot - cab_h
	var cab_lx = -cab_w * 0.5

	# Front face — dark metallic
	draw_rect(Rect2(cab_lx, cab_top, cab_w, cab_h), Color(0.14, 0.13, 0.12))
	# Inner panel bevel
	draw_rect(Rect2(cab_lx + 1.5, cab_top + 1.5, cab_w - 3, cab_h - 3), Color(0.18, 0.17, 0.15))

	# Top face (iso)
	var ct = cab_top
	var cp = PackedVector2Array([
		Vector2(cab_lx, ct),
		Vector2(cab_lx + cab_d, ct - cab_d * 0.5),
		Vector2(cab_lx + cab_w + cab_d, ct - cab_d * 0.5),
		Vector2(cab_lx + cab_w, ct),
	])
	draw_colored_polygon(cp, Color(0.22, 0.21, 0.19))

	# Right side face
	var csp = PackedVector2Array([
		Vector2(cab_lx + cab_w, ct),
		Vector2(cab_lx + cab_w + cab_d, ct - cab_d * 0.5),
		Vector2(cab_lx + cab_w + cab_d, ct - cab_d * 0.5 + cab_h),
		Vector2(cab_lx + cab_w, cab_bot),
	])
	draw_colored_polygon(csp, Color(0.08, 0.07, 0.06))
	# Side panel details — vertical lines
	for vi in 3:
		var vy = ct + 6 + vi * 9.0
		draw_line(
			Vector2(cab_lx + cab_w + 1.5, vy),
			Vector2(cab_lx + cab_w + cab_d - 1.5, vy - cab_d * 0.3),
			Color(0.12, 0.11, 0.10), 0.6)

	# ── MONITOR SCREEN ────────────────────────────────────────
	var sx = cab_lx + 3
	var sy = cab_top + 4
	var sw = cab_w - 6
	var sh2 = cab_h * 0.55
	# Screen bezel (dark frame)
	draw_rect(Rect2(sx - 1.5, sy - 1.5, sw + 3, sh2 + 3), Color(0.06, 0.05, 0.04))
	# Screen background
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.04, 0.02, 0.0))
	# Screen amber glow
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.85, 0.45, 0.03, screen_glow * 0.15))

	# HUD circles (like the screenshot's targeting rings)
	var scx = sx + sw * 0.5
	var scy = sy + sh2 * 0.5
	for ri in 3:
		var r = 2.5 + ri * 2.5
		var ring_pts = PackedVector2Array()
		for pi in 20:
			var a = float(pi) / 20.0 * TAU
			ring_pts.append(Vector2(scx + cos(a) * r, scy + sin(a) * r * 0.8))
		# Draw as line loop
		for pi in ring_pts.size():
			var p1 = ring_pts[pi]
			var p2 = ring_pts[(pi + 1) % ring_pts.size()]
			var ring_alpha = (0.3 + pulse * 0.4) * screen_glow
			draw_line(p1, p2, Color(0.95, 0.6, 0.1, ring_alpha), 0.6)

	# Center dot
	draw_circle(Vector2(scx, scy), 1.2, Color(0.95, 0.75, 0.15, screen_glow))

	# Crosshair lines
	var ch_len = 3.0
	var ch_col = Color(0.9, 0.5, 0.08, screen_glow * 0.7)
	draw_line(Vector2(scx - ch_len, scy), Vector2(scx - 1.5, scy), ch_col, 0.5)
	draw_line(Vector2(scx + 1.5, scy), Vector2(scx + ch_len, scy), ch_col, 0.5)
	draw_line(Vector2(scx, scy - ch_len * 0.8), Vector2(scx, scy - 1.2), ch_col, 0.5)
	draw_line(Vector2(scx, scy + 1.2), Vector2(scx, scy + ch_len * 0.8), ch_col, 0.5)

	# Small indicator bars at bottom of screen
	for bi in 4:
		var bx = sx + 2 + bi * (sw - 4) / 4.0
		var bw2 = (sw - 8) / 5.0
		var bfill = 0.4 + sin(_t * 1.5 + bi * 1.2) * 0.3
		draw_rect(Rect2(bx, sy + sh2 - 4, bw2, 2.5), Color(0.15, 0.08, 0.01))
		draw_rect(Rect2(bx, sy + sh2 - 4, bw2 * bfill, 2.5), Color(0.9, 0.4, 0.05, screen_glow * 0.8))

	# Screen border glow
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.85, 0.5, 0.1, 0.45 * screen_glow), false, 0.8)

	# Scanlines
	for si in int(sh2 / 2):
		if si % 2 == 0:
			draw_rect(Rect2(sx + 1, sy + si * 2.0, sw - 2, 0.5), Color(0, 0, 0, 0.12))

	# Screen text
	var font = _roboto
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz1 = maxi(1, int(round(5 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 4), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "MISSIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz1, Color(0.95, 0.72, 0.18, screen_glow * 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── KEYBOARD SHELF ────────────────────────────────────────
	var kb_y = sy + sh2 + 3
	# Shelf bracket
	draw_rect(Rect2(cab_lx + 2, kb_y, cab_w - 4, shelf_h), Color(0.22, 0.21, 0.19))
	draw_rect(Rect2(cab_lx + 2, kb_y, cab_w - 4, shelf_h), Color(0.30, 0.28, 0.26), false, 0.5)
	# Keyboard keys (tiny dots)
	for kr in 2:
		for kc in 5:
			var kx = cab_lx + 5 + kc * 3.2
			var ky2 = kb_y + 0.8 + kr * 1.3
			draw_rect(Rect2(kx, ky2, 2.2, 0.9), Color(0.35, 0.33, 0.30))

	# ── SIDE PANELS on cabinet front ──────────────────────────
	# Left panel strip
	draw_rect(Rect2(cab_lx + 1, cab_bot - 8, 3, 6), Color(0.10, 0.09, 0.08))
	draw_rect(Rect2(cab_lx + 1.5, cab_bot - 7, 2, 1.5), Color(0.3, 0.5, 0.2, glow * 0.5))
	# Right panel strip
	draw_rect(Rect2(cab_lx + cab_w - 4, cab_bot - 8, 3, 6), Color(0.10, 0.09, 0.08))
	draw_rect(Rect2(cab_lx + cab_w - 3.5, cab_bot - 7, 2, 1.5), Color(0.8, 0.3, 0.05, glow * 0.5))

	# ── Metal bolts at cabinet corners ────────────────────────
	for bpos in [Vector2(cab_lx + 2.5, cab_top + 2.5), Vector2(cab_lx + cab_w - 2.5, cab_top + 2.5),
				 Vector2(cab_lx + 2.5, cab_bot - 2.5), Vector2(cab_lx + cab_w - 2.5, cab_bot - 2.5)]:
		draw_circle(bpos, 1.2, Color(0.30, 0.28, 0.25))
		draw_circle(bpos, 0.6, Color(0.40, 0.38, 0.34))

	# ── Edge highlights ───────────────────────────────────────
	draw_rect(Rect2(cab_lx, cab_top, cab_w, cab_h), Color(0.35, 0.33, 0.30, 0.3 * glow), false, 0.8)
	draw_line(Vector2(cab_lx + cab_w, cab_top), Vector2(cab_lx + cab_w + cab_d, cab_top - cab_d * 0.5), Color(0.35, 0.33, 0.30, 0.2 * glow), 0.6)
