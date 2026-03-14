extends CanvasLayer

# ============================================================
#  SettingsWindow.gd — Dark-fantasy style cogwheel settings
#  Audio sliders, navigation buttons, FPS display
# ============================================================

@warning_ignore("unused_signal")
signal request_character_select

const CFG_PATH   : String = "user://player_prefs.cfg"
const CFG_SECTION: String = "settings"

var _open      : bool  = false
var _panel     : Panel = null
var _btn       : Button = null
var _fps_lbl      : Label  = null
var _fps_panel    : Panel   = null
var _fps_dragging : bool    = false
var _fps_drag_off : Vector2 = Vector2.ZERO

var music_vol   : float = 0.80
var sfx_vol     : float = 0.90
var zoom_unlock : bool  = false   # false = zoom locked at max
var _scene_ref  : Node  = null    # reference to the scene for zoom lock control

func init(scene: Node) -> void:
	layer = 20
	_scene_ref = scene
	_load_settings()
	_apply_audio()
	_apply_zoom_lock()
	_build_button()

# ── Persist ───────────────────────────────────────────────────
func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		music_vol   = cfg.get_value(CFG_SECTION, "music_vol",   0.80)
		sfx_vol     = cfg.get_value(CFG_SECTION, "sfx_vol",     0.90)
		zoom_unlock = cfg.get_value(CFG_SECTION, "zoom_unlock", false)

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(CFG_SECTION, "music_vol",   music_vol)
	cfg.set_value(CFG_SECTION, "sfx_vol",     sfx_vol)
	cfg.set_value(CFG_SECTION, "zoom_unlock", zoom_unlock)
	cfg.save(CFG_PATH)

func _apply_zoom_lock() -> void:
	if _scene_ref and is_instance_valid(_scene_ref):
		_scene_ref.set("_zoom_locked", not zoom_unlock)
		# When locking, snap back to max zoom
		if not zoom_unlock:
			_scene_ref.set("_cam_zoom_base", 2.5)
			var cam = _scene_ref.get("_camera")
			if cam and is_instance_valid(cam):
				cam.zoom = Vector2(2.5, 2.5)

func _apply_audio() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(music_vol))
	var m_idx = AudioServer.get_bus_index("Music")
	if m_idx >= 0:
		AudioServer.set_bus_volume_db(m_idx, linear_to_db(music_vol))
	var s_idx = AudioServer.get_bus_index("SFX")
	if s_idx >= 0:
		AudioServer.set_bus_volume_db(s_idx, linear_to_db(sfx_vol))

func set_btn_pos(p: Vector2) -> void:
	if _btn: _btn.position = p

func set_fps_pos(p: Vector2) -> void:
	if _fps_panel: _fps_panel.position = p
	if _fps_lbl:   _fps_lbl.position   = Vector2(2, 3)

# ── Button ────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _fps_lbl and is_instance_valid(_fps_lbl):
		_fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()

func _build_button() -> void:
	var vp   = get_viewport().get_visible_rect().size
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

	_btn               = Button.new()
	_btn.text          = "⚙"
	_btn.size          = Vector2(28, 24)
	_btn.position      = Vector2(vp.x - 44, 12)
	_btn.add_theme_font_size_override("font_size", 14)
	_btn.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))
	_btn.add_theme_stylebox_override("normal",  _btn_sty(false))
	_btn.add_theme_stylebox_override("hover",   _btn_sty(true))
	_btn.add_theme_stylebox_override("pressed", _btn_sty(true))
	_btn.pressed.connect(_toggle)
	add_child(_btn)

	# FPS draggable widget
	_fps_panel          = Panel.new()
	_fps_panel.size     = Vector2(68, 20)
	_fps_panel.position = Vector2(vp.x - 116, 16)
	var fps_sty         = StyleBoxFlat.new()
	fps_sty.bg_color    = Color(0.04, 0.04, 0.03, 0.85)
	fps_sty.border_color = Color(0.25, 0.22, 0.14, 0.60)
	fps_sty.set_border_width_all(1); fps_sty.set_corner_radius_all(2)
	_fps_panel.add_theme_stylebox_override("panel", fps_sty)
	_fps_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_fps_panel.gui_input.connect(_on_fps_drag)
	add_child(_fps_panel)

	_fps_lbl               = Label.new()
	_fps_lbl.add_theme_font_override("font", font)
	_fps_lbl.size          = Vector2(64, 16)
	_fps_lbl.position      = Vector2(2, 3)
	_fps_lbl.add_theme_font_size_override("font_size", 9)
	_fps_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.55, 0.85))
	_fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_fps_panel.add_child(_fps_lbl)

func _btn_sty(hovered: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color     = Color(0.10, 0.09, 0.06, 0.92) if hovered else Color(0.06, 0.05, 0.04, 0.90)
	s.border_color = Color(0.40, 0.32, 0.18, 0.80)
	s.set_border_width_all(1); s.set_corner_radius_all(2)
	return s

func _toggle() -> void:
	if _open: _close()
	else:     _open_window()

func _open_window() -> void:
	_open = true
	var vp   = get_viewport().get_visible_rect().size
	var W  = 340.0
	var H  = 380.0

	_panel          = Panel.new()
	_panel.size     = Vector2(W, H)
	_panel.position = Vector2(vp.x * 0.5 - W * 0.5, vp.y * 0.5 - H * 0.5)
	_panel.add_theme_stylebox_override("panel", _panel_sty())
	add_child(_panel)

	# Title
	_lbl(_panel, "⚙  SETTINGS", 0, 14, W, 30, 16,
		Color(0.90, 0.85, 0.60), HORIZONTAL_ALIGNMENT_CENTER)
	_div(_panel, 15, 48, W - 30)

	# ── Audio section ──────────────────────────────────────────
	_lbl(_panel, "AUDIO", 16, 58, 300, 18, 11, Color(0.80, 0.75, 0.50))

	_slider_row("Music Volume", music_vol, 76, func(v: float):
		music_vol = v
		_apply_audio()
		_save_settings())

	_slider_row("SFX Volume", sfx_vol, 122, func(v: float):
		sfx_vol = v
		_apply_audio()
		_save_settings())

	_div(_panel, 15, 172, W - 30)

	# ── Camera section ────────────────────────────────────────
	_lbl(_panel, "CAMERA", 16, 182, 300, 18, 11, Color(0.80, 0.75, 0.50))

	var zoom_cb = CheckBox.new()
	zoom_cb.text = "  Unlock Camera Zoom (scroll wheel)"
	zoom_cb.button_pressed = zoom_unlock
	zoom_cb.size     = Vector2(W - 32, 24)
	zoom_cb.position = Vector2(16, 204)
	zoom_cb.add_theme_font_size_override("font_size", 12)
	zoom_cb.add_theme_color_override("font_color", Color(0.85, 0.82, 0.70))
	zoom_cb.toggled.connect(func(on: bool):
		zoom_unlock = on
		_apply_zoom_lock()
		_save_settings())
	_panel.add_child(zoom_cb)

	_div(_panel, 15, 236, W - 30)

	# ── Navigation section ────────────────────────────────────
	_lbl(_panel, "NAVIGATION", 16, 246, 300, 18, 11, Color(0.80, 0.75, 0.50))

	var char_btn = _action_btn("⬅  Back to Character Select", Color(0.50, 0.42, 0.22, 0.90), 266)
	char_btn.pressed.connect(_on_char_select)
	_panel.add_child(char_btn)

	var quit_btn = _action_btn("✕  Quit Game", Color(0.65, 0.22, 0.18, 0.90), 312)
	quit_btn.pressed.connect(func(): get_tree().quit())
	_panel.add_child(quit_btn)

	var close_btn = _action_btn("Close", Color(0.30, 0.25, 0.18, 0.90), H - 46)
	close_btn.pressed.connect(_close)
	_panel.add_child(close_btn)

func _on_char_select() -> void:
	_close()
	var tree = get_tree()
	if tree:
		tree.reload_current_scene()

# ── UI helpers ────────────────────────────────────────────────
func _panel_sty() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color     = Color(0.05, 0.05, 0.04, 0.97)
	s.border_color = Color(0.45, 0.38, 0.22, 0.85)
	s.set_border_width_all(2); s.set_corner_radius_all(4)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	s.shadow_size  = 6
	return s

func _lbl(parent: Control, text: String, x: float, y: float, w: float, h: float,
		sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l = Label.new()
	l.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	l.text = text; l.position = Vector2(x, y); l.size = Vector2(w, h)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _div(parent: Control, x: float, y: float, w: float) -> void:
	var d = ColorRect.new()
	d.size = Vector2(w, 1); d.position = Vector2(x, y)
	d.color = Color(0.45, 0.38, 0.22, 0.30)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)

func _slider_row(label: String, init_val: float, y: float, cb: Callable) -> void:
	var W = _panel.size.x
	_lbl(_panel, label, 16, y, 160, 20, 13, Color(0.85, 0.82, 0.70))
	var pct = _lbl(_panel, "%d%%" % int(init_val * 100),
		W - 52, y, 44, 20, 13, Color(0.95, 0.88, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)
	var sl       = HSlider.new()
	sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.01; sl.value = init_val
	sl.size      = Vector2(W - 32, 22); sl.position = Vector2(16, y + 20)
	sl.value_changed.connect(func(v: float):
		pct.text = "%d%%" % int(v * 100)
		cb.call(v))
	_panel.add_child(sl)

func _action_btn(text: String, border_col: Color, y: float) -> Button:
	var W   = _panel.size.x
	var btn = Button.new()
	btn.text = text; btn.size = Vector2(W - 30, 36); btn.position = Vector2(15, y)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.88, 0.85, 0.72))
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.06, 0.06, 0.05, 0.92); bs.border_color = border_col
	bs.set_border_width_all(1); bs.set_corner_radius_all(3)
	var bsh = bs.duplicate() as StyleBoxFlat; bsh.bg_color = Color(0.12, 0.10, 0.07, 0.98)
	btn.add_theme_stylebox_override("normal", bs); btn.add_theme_stylebox_override("hover", bsh)
	return btn

func _on_fps_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_fps_dragging = event.pressed
		_fps_drag_off = event.position
	elif event is InputEventMouseMotion and _fps_dragging:
		var np = _fps_panel.position + event.relative
		var vp2 = get_viewport().get_visible_rect().size
		np.x = clampf(np.x, 0, vp2.x - _fps_panel.size.x)
		np.y = clampf(np.y, 0, vp2.y - _fps_panel.size.y)
		_fps_panel.position = np

func _close() -> void:
	_open = false
	if _panel and is_instance_valid(_panel):
		_panel.queue_free(); _panel = null

func _input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
