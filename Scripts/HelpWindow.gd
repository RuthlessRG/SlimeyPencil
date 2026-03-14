extends CanvasLayer

# ============================================================
#  HelpWindow.gd — Dark-fantasy style controls reference
# ============================================================

var _open      : bool  = false
var _panel     : Panel = null
var _btn       : Button = null

func init() -> void:
	layer = 20
	_build_button()

func set_btn_pos(p: Vector2) -> void:
	if _btn: _btn.position = p

func _build_button() -> void:
	var vp = get_viewport().get_visible_rect().size

	_btn               = Button.new()
	_btn.text          = "?"
	_btn.size          = Vector2(28, 24)
	_btn.position      = Vector2(vp.x - 80, 12)
	_btn.add_theme_font_size_override("font_size", 14)
	_btn.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))

	var sty = StyleBoxFlat.new()
	sty.bg_color    = Color(0.06, 0.05, 0.04, 0.90)
	sty.border_color = Color(0.40, 0.32, 0.18, 0.80)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(2)
	var sty_hov = sty.duplicate() as StyleBoxFlat
	sty_hov.bg_color = Color(0.10, 0.09, 0.06, 0.95)
	_btn.add_theme_stylebox_override("normal",  sty)
	_btn.add_theme_stylebox_override("hover",   sty_hov)
	_btn.add_theme_stylebox_override("pressed", sty_hov)
	_btn.pressed.connect(_toggle)
	add_child(_btn)

func _toggle() -> void:
	if _open: _close()
	else:     _open_window()

func _open_window() -> void:
	_open = true
	var vp  = get_viewport().get_visible_rect().size
	var W   = 480.0
	var H   = 560.0
	var px  = vp.x * 0.5 - W * 0.5
	var py  = vp.y * 0.5 - H * 0.5

	_panel          = Panel.new()
	_panel.size     = Vector2(W, H)
	_panel.position = Vector2(px, py)
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.05, 0.05, 0.04, 0.97)
	sty.border_color = Color(0.45, 0.38, 0.22, 0.85)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(4)
	sty.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	sty.shadow_size  = 6
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "CONTROLS & HOTKEYS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.90, 0.85, 0.60))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(W, 30); title.position = Vector2(0, 14)
	_panel.add_child(title)

	var div      = ColorRect.new()
	div.size     = Vector2(W - 30, 1); div.position = Vector2(15, 48)
	div.color    = Color(0.45, 0.38, 0.22, 0.35)
	_panel.add_child(div)

	# Scrollable content
	var scroll          = ScrollContainer.new()
	scroll.size         = Vector2(W - 20, H - 80)
	scroll.position     = Vector2(10, 54)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# ── Content sections ──────────────────────────────────────
	_section(vbox, "MOVEMENT")
	_row(vbox,   "W / A / S / D",      "Move character")
	_row(vbox,   "Mouse",              "Aim / face direction")

	_section(vbox, "COMBAT")
	_row(vbox,   "Left Click",         "Attack / interact")
	_row(vbox,   "1 – 8",              "Use skill in action bar slot")
	_row(vbox,   "Drag skill → bar",   "Assign skill to slot (from P menu)")
	_row(vbox,   "Drag skill off bar", "Remove skill from slot")

	_section(vbox, "WINDOWS")
	_row(vbox,   "I",    "Open / close Inventory")
	_row(vbox,   "P",    "Open / close Skill Browser")
	_row(vbox,   "F",    "Interact (shop terminal, teleporter)")

	_section(vbox, "MOUNT")
	_row(vbox,   "Double-click speeder", "Equip / unequip mount")
	_row(vbox,   "W  (mounted)",         "Throttle forward")
	_row(vbox,   "S  (mounted)",         "Brake / reverse — no auto-decel!")
	_row(vbox,   "Mouse  (mounted)",     "Nose follows cursor")

	_section(vbox, "TARGETING")
	_row(vbox,   "Left Click",         "Target player / enemy")
	_row(vbox,   "ESC",                "Clear target / close window")
	_row(vbox,   "TAB",                "Cycle targets")

	_section(vbox, "DEBUG HOTKEYS")
	_row(vbox,   "G",    "Instantly kill current target")
	_row(vbox,   "H",    "+5000 Credits")
	_row(vbox,   "J",    "Level up")
	_row(vbox,   "L",    "Spawn Teleporter at player")

	_section(vbox, "SPAWN (DEBUG)")
	_row(vbox,   "F1",   "Spawn Training Dummy")
	_row(vbox,   "F2",   "Spawn Zerg Boss")
	_row(vbox,   "F3",   "Spawn Cyber Lord")
	_row(vbox,   "F4",   "Spawn Zerg Mob")
	_row(vbox,   "F5",   "Spawn Cyber Mob")

	_section(vbox, "HUD")
	_row(vbox,   "Drag player frame",   "Move the HP/MP/XP widget anywhere")

	# Close button
	var close_btn   = Button.new()
	close_btn.text  = "Close"
	close_btn.size  = Vector2(100, 32)
	close_btn.position = Vector2(W * 0.5 - 50, H - 44)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.68))
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.08, 0.07, 0.05)
	cs.border_color = Color(0.45, 0.38, 0.22, 0.70)
	cs.set_border_width_all(1); cs.set_corner_radius_all(3)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.pressed.connect(_close)
	_panel.add_child(close_btn)

# ── Helpers ───────────────────────────────────────────────────
func _section(parent: VBoxContainer, text: String) -> void:
	var spacer       = Control.new(); spacer.custom_minimum_size = Vector2(0, 6)
	parent.add_child(spacer)
	var lbl          = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text         = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.75, 0.50))
	parent.add_child(lbl)
	var line         = ColorRect.new()
	line.custom_minimum_size = Vector2(440, 1)
	line.color       = Color(0.40, 0.32, 0.18, 0.30)
	parent.add_child(line)

func _row(parent: VBoxContainer, key: String, desc: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var key_lbl  = Label.new()
	key_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	key_lbl.text = key
	key_lbl.custom_minimum_size = Vector2(160, 0)
	key_lbl.add_theme_font_size_override("font_size", 12)
	key_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	hbox.add_child(key_lbl)

	var desc_lbl  = Label.new()
	desc_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.76, 0.65))
	hbox.add_child(desc_lbl)

func _close() -> void:
	_open = false
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null

func _input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
