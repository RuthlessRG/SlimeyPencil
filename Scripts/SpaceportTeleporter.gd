extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  SpaceportTeleporter.gd
#  A fully procedural teleporter pad + floating portal oval.
#
#  Place in scene by calling:
#    _spawn_teleporter(world_pos, teleporter_id, destinations)
#
#  destinations is an Array of Dicts:
#    { "label": "Coronet Spaceport", "pos": Vector2(x, y) }
#
#  When player walks within INTERACT_RADIUS and presses F,
#  a menu appears listing all destinations. Choosing one
#  teleports the player instantly.
# ============================================================

const INTERACT_RADIUS : float = 120.0
const PAD_R           : float = 52.0     # outer pad radius
const OVAL_W          : float = 42.0     # portal oval half-width  (was 60, -30%)
const OVAL_H          : float = 56.0     # portal oval half-height (was 80, -30%)
const OVAL_Y_OFF      : float = -105.0   # height above pad center (was -160, closer)
const ENERGY_BEAM_W   : float = 6.0

var _t           : float = 0.0
var _player      : Node  = null
var _near_player : bool  = false
var _menu_open   : bool  = false
var _destinations : Array = []
var _teleporter_id : String = ""

# UI nodes
var _prompt_label  : Label  = null
var _menu_layer    : CanvasLayer = null

func init(player: Node, tid: String, destinations: Array) -> void:
	_player        = player
	_teleporter_id = tid
	_destinations  = destinations
	_build_prompt()

func _build_prompt() -> void:
	# "Press F" prompt floats above the portal — built as a CanvasLayer so it's
	# always readable regardless of camera zoom
	var cl = CanvasLayer.new()
	cl.layer = 15
	add_child(cl)

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_label.text = "[F] Teleport"
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(0.60, 0.92, 1.00))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.visible      = false
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_prompt_label)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

	if not is_instance_valid(_player):
		return

	# Distance check
	var dist = global_position.distance_to(_player.global_position)
	_near_player = dist < INTERACT_RADIUS

	# Update prompt position — convert world pos to screen pos
	if _prompt_label:
		var vp         = get_viewport()
		var cam        = vp.get_camera_2d() if vp else null
		var screen_pos = Vector2.ZERO
		if cam:
			screen_pos = (global_position + Vector2(0, OVAL_Y_OFF - OVAL_H - 22)) - cam.global_position
			screen_pos *= cam.zoom
			screen_pos += vp.get_visible_rect().size * 0.5
		_prompt_label.position = screen_pos - Vector2(54, 10)
		_prompt_label.visible  = _near_player and not _menu_open

	# F key to open / close menu
	if _near_player and Input.is_action_just_pressed("ui_focus_next"):
		# "ui_focus_next" is Tab — we need F key directly
		pass

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			if _near_player and not _menu_open:
				_open_menu()
			elif _menu_open:
				_close_menu()

# ── TELEPORT MENU ─────────────────────────────────────────────
func _open_menu() -> void:
	_menu_open  = true
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 30
	add_child(_menu_layer)

	var vp  = get_viewport().get_visible_rect().size
	var mw  = 340.0
	var mh  = 80.0 + _destinations.size() * 52.0
	var mx  = vp.x * 0.5 - mw * 0.5
	var my  = vp.y * 0.5 - mh * 0.5

	# Dark overlay
	var overlay        = ColorRect.new()
	overlay.size       = vp
	overlay.color      = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(overlay)

	# Panel
	var panel      = Panel.new()
	panel.size     = Vector2(mw, mh)
	panel.position = Vector2(mx, my)
	var sty        = StyleBoxFlat.new()
	sty.bg_color   = Color(0.04, 0.06, 0.14, 0.97)
	sty.border_color = Color(0.35, 0.70, 1.00, 0.90)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sty)
	_menu_layer.add_child(panel)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "✦  TELEPORT NETWORK  ✦"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.55, 0.88, 1.00))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(mw, 30)
	title.position = Vector2(0, 14)
	panel.add_child(title)

	var divider       = ColorRect.new()
	divider.size      = Vector2(mw - 30, 1)
	divider.position  = Vector2(15, 48)
	divider.color     = Color(0.35, 0.70, 1.00, 0.40)
	panel.add_child(divider)

	# Destination buttons
	for i in _destinations.size():
		var dest   = _destinations[i]
		var btn    = Button.new()
		btn.text   = "⬡  " + dest.get("label", "Unknown")
		btn.size   = Vector2(mw - 30, 42)
		btn.position = Vector2(15, 58 + i * 52)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.00))

		var bs       = StyleBoxFlat.new()
		bs.bg_color  = Color(0.08, 0.14, 0.28, 0.90)
		bs.border_color = Color(0.30, 0.60, 0.90, 0.60)
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(4)
		var bs_hov   = bs.duplicate() as StyleBoxFlat
		bs_hov.bg_color = Color(0.14, 0.24, 0.48, 0.95)
		bs_hov.border_color = Color(0.55, 0.85, 1.00)
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_stylebox_override("hover",  bs_hov)
		btn.add_theme_stylebox_override("pressed", bs_hov)

		btn.pressed.connect(_on_dest_selected.bind(dest))
		panel.add_child(btn)

	# Close hint
	var close_lbl = Label.new()
	close_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	close_lbl.text = "Press F or click outside to close"
	close_lbl.add_theme_font_size_override("font_size", 10)
	close_lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_lbl.size     = Vector2(mw, 16)
	close_lbl.position = Vector2(0, mh - 20)
	panel.add_child(close_lbl)

	# Click outside to close
	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_menu()
	)

func _close_menu() -> void:
	_menu_open = false
	if _menu_layer and is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
		_menu_layer = null

func _on_dest_selected(dest: Dictionary) -> void:
	_close_menu()
	if is_instance_valid(_player):
		_player.global_position = dest.get("pos", global_position)

# ============================================================
#  DRAW — pad + energy beam + floating portal oval
# ============================================================
func _draw() -> void:
	_draw_ground_aura()
	_draw_pad()
	_draw_energy_beam()
	_draw_portal_oval()
	_draw_interaction_ring()
	_draw_label_below()

# ── PAD ───────────────────────────────────────────────────────
func _draw_pad() -> void:
	# Ground shadow
	draw_colored_polygon(
		_ellipse(Vector2(6, 8), PAD_R + 10, PAD_R * 0.38, 0.0, 32),
		Color(0, 0, 0, 0.28))

	# Outer ring — dark metal
	draw_colored_polygon(
		_ellipse(Vector2.ZERO, PAD_R, PAD_R * 0.36, 0.0, 48),
		Color(0.18, 0.22, 0.32))

	# Mid ring — glowing edge
	var glow_pulse = 0.6 + sin(_t * 3.0) * 0.25
	draw_colored_polygon(
		_ellipse(Vector2.ZERO, PAD_R - 5, (PAD_R - 5) * 0.36, 0.0, 48),
		Color(0.20, 0.55, 1.00, glow_pulse * 0.55))

	# Inner pad surface
	draw_colored_polygon(
		_ellipse(Vector2.ZERO, PAD_R - 9, (PAD_R - 9) * 0.36, 0.0, 40),
		Color(0.10, 0.14, 0.22))

	# Rune ring — 8 glowing dots rotating
	for i in 8:
		var a   = float(i) / 8.0 * TAU + _t * 0.8
		var rp  = Vector2(cos(a), sin(a) * 0.36) * (PAD_R - 14)
		var dp  = 0.5 + 0.5 * sin(_t * 4.0 + float(i) * 0.78)
		draw_circle(rp, 3.5, Color(0.40, 0.80, 1.00, dp))
		draw_circle(rp, 1.8, Color(1.0, 1.0, 1.0, dp * 0.8))

	# Inner hex pattern
	for i in 6:
		var a0 = float(i) / 6.0 * TAU
		var a1 = float(i + 1) / 6.0 * TAU
		var p0 = Vector2(cos(a0), sin(a0) * 0.36) * (PAD_R - 22)
		var p1 = Vector2(cos(a1), sin(a1) * 0.36) * (PAD_R - 22)
		draw_line(p0, p1, Color(0.30, 0.65, 1.00, 0.50), 1.5)

	# (label drawn below pad in _draw_teleporter_label)

# ── ENERGY BEAM ───────────────────────────────────────────────
func _draw_energy_beam() -> void:
	var beam_top = Vector2(0, OVAL_Y_OFF)
	var beam_bot = Vector2(0, 0)

	# Core beam — animated sine wobble
	var segs = 16
	for i in segs:
		var t0 = float(i) / segs
		var t1 = float(i + 1) / segs
		var w0 = sin(_t * 5.0 + t0 * TAU) * 3.0
		var w1 = sin(_t * 5.0 + t1 * TAU) * 3.0
		var p0 = beam_bot.lerp(beam_top, t0) + Vector2(w0, 0)
		var p1 = beam_bot.lerp(beam_top, t1) + Vector2(w1, 0)
		var alpha = 0.55 + 0.35 * sin(_t * 6.0 + t0 * 3.0)
		draw_line(p0, p1, Color(0.30, 0.70, 1.00, alpha), ENERGY_BEAM_W)

	# Glow fringe beams
	for side in [-1.0, 1.0]:
		for i in segs:
			var t0 = float(i) / segs
			var t1 = float(i + 1) / segs
			var w0 = side * (4.0 + sin(_t * 4.5 + t0 * TAU + side) * 2.5)
			var w1 = side * (4.0 + sin(_t * 4.5 + t1 * TAU + side) * 2.5)
			var p0 = beam_bot.lerp(beam_top, t0) + Vector2(w0, 0)
			var p1 = beam_bot.lerp(beam_top, t1) + Vector2(w1, 0)
			var alpha = 0.18 + 0.12 * sin(_t * 5.0 + t0 * 2.0)
			draw_line(p0, p1, Color(0.55, 0.85, 1.00, alpha), 3.0)

# ── PORTAL OVAL ───────────────────────────────────────────────
func _draw_portal_oval() -> void:
	var oc = Vector2(0, OVAL_Y_OFF)    # oval center

	# ── Outer glow rings ──────────────────────────────────────
	for ri in 3:
		var extra = float(ri) * 6.0 + sin(_t * 2.5 + ri) * 3.0
		var alpha = 0.15 - ri * 0.04
		draw_colored_polygon(
			_ellipse(oc, OVAL_W + extra, OVAL_H + extra, 0.0, 40),
			Color(0.25, 0.55, 1.00, alpha))

	# ── Oval frame — energy ring ───────────────────────────────
	var frame_alpha = 0.75 + sin(_t * 3.0) * 0.18
	draw_colored_polygon(
		_ellipse(oc, OVAL_W, OVAL_H, 0.0, 48),
		Color(0.10, 0.18, 0.40))
	draw_arc(oc, OVAL_W, 0.0, TAU, 48, Color(0.40, 0.75, 1.00, frame_alpha), 3.5)

	# Rotating bright sparks on the oval edge
	for i in 6:
		var a = float(i) / 6.0 * TAU + _t * 1.2
		var sp = Vector2(cos(a) * OVAL_W, sin(a) * OVAL_H) + oc
		var bp = 0.5 + 0.5 * sin(_t * 8.0 + float(i) * 1.05)
		draw_circle(sp, 4.0, Color(0.60, 0.90, 1.00, bp))
		draw_circle(sp, 2.0, Color(1.0, 1.0, 1.0, bp))

	# ── Cosmic black hole interior ────────────────────────────
	# Dark void base
	draw_colored_polygon(
		_ellipse(oc, OVAL_W - 4, OVAL_H - 4, 0.0, 40),
		Color(0.01, 0.01, 0.04))

	# Swirling accretion disk layers — each a partial arc rotated over time
	var disk_colors = [
		Color(0.55, 0.05, 0.80, 0.60),   # purple inner
		Color(0.15, 0.10, 0.65, 0.55),   # deep blue
		Color(0.00, 0.35, 0.90, 0.50),   # blue-cyan
		Color(0.40, 0.80, 1.00, 0.40),   # cyan outer
	]
	for di in disk_colors.size():
		var r_ratio = 0.30 + float(di) * 0.16
		var rx = (OVAL_W - 4) * r_ratio
		var ry = (OVAL_H - 4) * r_ratio
		var rot_speed = (2.0 - float(di) * 0.35) * (1.0 if di % 2 == 0 else -1.0)
		var rot_off   = _t * rot_speed + float(di) * 0.8

		# Draw as a series of short arc strokes with varying alpha
		var arc_segs = 28
		for si in arc_segs:
			var a0 = float(si) / arc_segs * TAU + rot_off
			var a1 = float(si + 1) / arc_segs * TAU + rot_off
			var p0 = oc + Vector2(cos(a0) * rx, sin(a0) * ry)
			var p1 = oc + Vector2(cos(a1) * rx, sin(a1) * ry)
			# Fade: bright on one side, dim on the opposite
			var fade = 0.3 + 0.7 * (0.5 + 0.5 * sin(a0 + _t * 0.5))
			var col  = disk_colors[di]
			draw_line(p0, p1, Color(col.r, col.g, col.b, col.a * fade),
				2.5 - float(di) * 0.4)

	# Gravitational lensing streaks — thin radial lines curving inward
	for i in 14:
		var base_ang = float(i) / 14.0 * TAU + _t * 0.3
		var outer_r_x = (OVAL_W - 4) * 0.88
		var outer_r_y = (OVAL_H - 4) * 0.88
		var inner_r_x = (OVAL_W - 4) * 0.22
		var inner_r_y = (OVAL_H - 4) * 0.22
		# Curve the streak by sampling 4 points
		var pts = PackedVector2Array()
		for s in 5:
			var t_s = float(s) / 4.0
			var ang = base_ang + t_s * 0.45   # slight angular curl
			var rx  = lerpf(outer_r_x, inner_r_x, t_s)
			var ry  = lerpf(outer_r_y, inner_r_y, t_s)
			pts.append(oc + Vector2(cos(ang) * rx, sin(ang) * ry))
		var streak_alpha = 0.12 + 0.10 * sin(_t * 3.0 + float(i))
		draw_polyline(pts, Color(0.60, 0.80, 1.00, streak_alpha), 1.2)

	# Central singularity — absolute black dot + tiny hot white core
	draw_circle(oc, 12.0, Color(0.0, 0.0, 0.0))
	draw_circle(oc, 5.0,  Color(0.0, 0.0, 0.0))
	# Event horizon glow
	var eh_pulse = 0.4 + 0.3 * sin(_t * 7.0)
	draw_arc(oc, 12.0, 0.0, TAU, 24, Color(0.50, 0.10, 0.85, eh_pulse), 2.5)
	draw_circle(oc, 3.0, Color(0.85, 0.70, 1.00, eh_pulse * 0.6))

# ── INTERACTION RING ──────────────────────────────────────────
func _draw_interaction_ring() -> void:
	if not _near_player: return
	var alpha = 0.18 + 0.12 * sin(_t * 4.0)
	draw_arc(Vector2.ZERO, INTERACT_RADIUS, 0.0, TAU, 64,
		Color(0.40, 0.80, 1.00, alpha), 2.0)
	# Dashed markers at cardinal points
	for i in 8:
		var a  = float(i) / 8.0 * TAU
		var p0 = Vector2(cos(a), sin(a)) * (INTERACT_RADIUS - 8)
		var p1 = Vector2(cos(a), sin(a)) * (INTERACT_RADIUS + 8)
		draw_line(p0, p1, Color(0.55, 0.90, 1.00, 0.50), 2.0)

# ── Ground aura — blue/black halo around the pad base ─────────
func _draw_ground_aura() -> void:
	# Layered soft ellipses expanding outward — pulsing blue-black
	for i in 5:
		var fi    = float(i)
		var phase = _t * 1.8 - fi * 0.5
		var pulse = 0.5 + 0.5 * sin(phase)
		var rx    = PAD_R + 18.0 + fi * 14.0
		var ry    = (PAD_R + 18.0 + fi * 14.0) * 0.36
		var alpha = (0.22 - fi * 0.04) * pulse
		draw_colored_polygon(
			_ellipse(Vector2.ZERO, rx, ry, 0.0, 36),
			Color(0.05, 0.20, 0.70, alpha))
	# Rotating blue arc sweeping around the base
	for ring in 2:
		var rot_off = _t * (1.2 if ring == 0 else -0.8) + ring * PI
		var arc_a   = rot_off
		var arc_b   = rot_off + TAU * 0.55
		var rx      = PAD_R + 10.0 + ring * 8.0
		var ry      = rx * 0.36
		var alpha   = 0.35 + 0.20 * sin(_t * 3.0 + ring)
		# Draw arc as short line segments around the ellipse perimeter
		var segs = 24
		for si in segs:
			var t0  = float(si) / segs
			var t1  = float(si + 1) / segs
			var a0  = arc_a + t0 * (arc_b - arc_a)
			var a1  = arc_a + t1 * (arc_b - arc_a)
			var p0  = Vector2(cos(a0) * rx, sin(a0) * ry)
			var p1  = Vector2(cos(a1) * rx, sin(a1) * ry)
			draw_line(p0, p1, Color(0.20, 0.55, 1.00, alpha), 2.5)
	# Tiny rising blue sparks
	for i in 6:
		var sp_phase = fmod(_t * 1.4 + float(i) * 1.047, 1.0)
		var ang      = float(i) / 6.0 * TAU + _t * 0.4
		var base_r   = PAD_R * 0.7
		var sp_x     = cos(ang) * base_r
		var sp_y     = sin(ang) * base_r * 0.36 - sp_phase * 28.0
		var sp_alpha = (1.0 - sp_phase) * 0.65
		draw_circle(Vector2(sp_x, sp_y), 2.2, Color(0.35, 0.70, 1.00, sp_alpha))

# ── Label below the pad ────────────────────────────────────────
func _draw_label_below() -> void:
	var font      = _roboto
	var label_y   = PAD_R * 0.36 + 18.0   # just below the pad ellipse bottom
	var pulse_a   = 0.65 + 0.25 * sin(_t * 2.5)
	var _ct_sc = get_canvas_transform().get_scale()
	var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
	var _rend_sz = maxi(1, int(round(11 * _ct_sc.x)))
	draw_set_transform(Vector2(-18, label_y), 0.0, _inv)
	draw_string(font, Vector2.ZERO, "TP 01",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz,
		Color(0.45, 0.80, 1.00, pulse_a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Ellipse helper ────────────────────────────────────────────
func _ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts   = PackedVector2Array()
	var cos_r = cos(rot); var sin_r = sin(rot)
	for i in n:
		var a  = float(i) / float(n) * TAU
		var lx = cos(a) * rx; var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cos_r - ly * sin_r, lx * sin_r + ly * cos_r))
	return pts
