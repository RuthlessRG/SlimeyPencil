extends Node2D

# ============================================================
#  BankTerminal.gd — miniSWG
#  Drawn entirely in code. Player approaches + presses F
#  to open the bank terminal (stub — deposit/withdraw coming soon).
# ============================================================

const INTERACT_RANGE : float = 58.0

var _t           : float = 0.0
var _player_near : bool  = false
var _prompt_lbl  : Label = null
var _panel       : Control = null

func _ready() -> void:
	add_to_group("bank_terminal")

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_lbl.text = "[F]  Bank Terminal"
	_prompt_lbl.add_theme_font_size_override("font_size", 9)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.position = Vector2(-40, -78)
	_prompt_lbl.size     = Vector2(82, 14)
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
		if near and _panel == null:
			pass  # panel shown on F-press via _input
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if _player_near:
			_toggle_panel()

func _toggle_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		return

	_panel = _build_panel()
	# Attach to the scene root canvas layer or direct child of scene
	get_tree().current_scene.add_child(_panel)

func _build_panel() -> Control:
	var p = Panel.new()
	p.size     = Vector2(280, 160)
	p.position = Vector2(
		get_viewport().size.x * 0.5 - 140,
		get_viewport().size.y * 0.5 - 80)
	p.z_index = 50

	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "BANK TERMINAL"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size     = Vector2(280, 24)
	p.add_child(title)

	var sub = Label.new()
	sub.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	sub.text = "Deposit & withdraw credits\nand items for safekeeping."
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 56)
	sub.size     = Vector2(280, 44)
	p.add_child(sub)

	var coming = Label.new()
	coming.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	coming.text = "— Coming Soon —"
	coming.add_theme_font_size_override("font_size", 10)
	coming.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	coming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming.position = Vector2(0, 108)
	coming.size     = Vector2(280, 16)
	p.add_child(coming)

	var close = Label.new()
	close.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	close.text = "[F] Close"
	close.add_theme_font_size_override("font_size", 9)
	close.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.position = Vector2(0, 134)
	close.size     = Vector2(280, 14)
	p.add_child(close)

	return p

func _draw() -> void:
	var glow        = 0.55 + sin(_t * 2.3) * 0.30
	var screen_glow = 0.50 + sin(_t * 3.9) * 0.22

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

	# Proximity aura (gold)
	if _player_near:
		var aa = 0.10 + sin(_t * 4.5) * 0.05
		var ap = PackedVector2Array()
		for i in 20:
			var a = float(i) / 20.0 * TAU
			ap.append(Vector2(cos(a) * W * 0.70, sin(a) * H * 0.25))
		draw_colored_polygon(ap, Color(1.0, 0.85, 0.20, aa))

	# Cabinet body
	var body = PackedVector2Array([
		Vector2(lx,           ty),
		Vector2(lx + W,       ty),
		Vector2(lx + W,       0.0),
		Vector2(lx,           0.0),
	])
	draw_colored_polygon(body, Color(0.14, 0.10, 0.06))

	# Gold trim stripe
	draw_rect(Rect2(lx, ty + 4, W, 6), Color(0.80, 0.65, 0.10))

	# Screen (amber/gold)
	var sx = lx + 6;  var sy = ty + 14;  var sw = W - 12;  var sh2 = H * 0.38
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.24, 0.18, 0.04))
	var glow_c = Color(0.90 * screen_glow, 0.70 * screen_glow, 0.10 * screen_glow)
	draw_rect(Rect2(sx + 2, sy + 2, sw - 4, sh2 - 4), glow_c)

	# Coin slot
	draw_rect(Rect2(lx + W * 0.5 - 10, ty + H * 0.66, 20, 4), Color(0.55, 0.44, 0.10))

	# Keypad dots
	for row in 3:
		for col in 3:
			draw_circle(
				Vector2(lx + 10 + col * 8, ty + H * 0.78 + row * 6),
				1.5,
				Color(0.70 * glow, 0.55 * glow, 0.12 * glow))

	# Glow beacon on top
	draw_circle(Vector2(0, ty - 4), 4.5, Color(1.0, 0.85, 0.20, 0.18 * glow))
	draw_circle(Vector2(0, ty - 4), 2.5, Color(1.0, 0.90, 0.40, glow))
