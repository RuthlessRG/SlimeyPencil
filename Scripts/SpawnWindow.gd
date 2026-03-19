extends CanvasLayer

# ============================================================
#  SpawnWindow.gd  —  Dev spawn menu (F1)
#  Shows a categorised list of all spawnable mobs/bosses.
#  Clicking SPAWN calls the matching _spawn_* function on the
#  scene with a position near the player.
#  Supports quantity (1 / 3 / 5) and auto-staggers positions
#  so multiple spawns don't stack on top of each other.
# ============================================================

const WIN_W  : float = 340.0
const WIN_H  : float = 480.0

var _scene   : Node  = null
var _player  : Node  = null
var _panel   : Panel = null
var _qty     : int   = 1
var _roboto  : Font  = null
var _bold    : Font  = null
var _dragging : bool = false

# ── Catalogue ────────────────────────────────────────────────
# Each entry:  label, spawn method on scene, tier tag, tier color
const ENTRIES = [
	# label                 method                  tier       tier_col (r,g,b)
	["Training Dummy",      "_spawn_dummy",          "DUMMY",   [0.60, 0.60, 0.65]],
	["Zergling",            "_spawn_zergling",       "EASY",    [0.30, 0.85, 0.40]],
	["Zerg Mob",            "_spawn_zerg_mob",       "EASY",    [0.30, 0.85, 0.40]],
	["Cyber Mob",           "_spawn_cyber_mob",      "EASY",    [0.30, 0.85, 0.40]],
	["Armored Thug",        "_spawn_armored_thug",   "MEDIUM",  [0.95, 0.75, 0.20]],
	["Robo Walker",         "_spawn_robowalker",     "MEDIUM",  [0.40, 0.80, 0.95]],
	["Zerg Boss",           "_spawn_boss",           "BOSS",    [0.95, 0.38, 0.28]],
	["Vampire Boss",        "_spawn_vampire",        "BOSS",    [0.95, 0.38, 0.28]],
	["Cyber Lord",          "_spawn_cyberlord",      "BOSS",    [0.95, 0.38, 0.28]],
]

# ── Init ─────────────────────────────────────────────────────
func init(scene: Node, player: Node) -> void:
	layer   = 20
	_scene  = scene
	_player = player
	_roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	_bold   = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf")
	_build_ui()
	visible = false

func toggle() -> void:
	visible = not visible

# ── UI build ─────────────────────────────────────────────────
func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	_panel = Panel.new()
	_panel.position = Vector2(vp.x * 0.5 - WIN_W * 0.5, vp.y * 0.5 - WIN_H * 0.5)
	_panel.size     = Vector2(WIN_W, WIN_H)

	var sty = StyleBoxFlat.new()
	sty.bg_color     = Color(0.06, 0.07, 0.13, 0.97)
	sty.border_color = Color(0.30, 0.55, 0.80, 0.80)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	sty.shadow_color = Color(0, 0, 0, 0.60)
	sty.shadow_size  = 8
	_panel.add_theme_stylebox_override("panel", sty)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)

	# Accent bar
	var accent = ColorRect.new()
	accent.color    = Color(0.20, 0.65, 1.00, 0.90)
	accent.position = Vector2(2, 2)
	accent.size     = Vector2(WIN_W - 4, 4)
	_panel.add_child(accent)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", _bold if _bold else _roboto)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.60, 0.90, 1.00))
	title.text     = "  SPAWN MENU  [F1]"
	title.position = Vector2(0, 9)
	title.size     = Vector2(WIN_W - 36, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	# Close button
	var close_btn = Button.new()
	close_btn.text     = "X"
	close_btn.position = Vector2(WIN_W - 28, 5)
	close_btn.size     = Vector2(22, 22)
	close_btn.pressed.connect(func(): visible = false)
	var csty = StyleBoxFlat.new()
	csty.bg_color     = Color(0.22, 0.06, 0.06, 0.92)
	csty.border_color = Color(0.80, 0.28, 0.28, 0.75)
	csty.set_border_width_all(1)
	csty.set_corner_radius_all(3)
	close_btn.add_theme_stylebox_override("normal", csty)
	_panel.add_child(close_btn)

	# Divider under header
	var div = ColorRect.new()
	div.color    = Color(0.20, 0.45, 0.70, 0.40)
	div.position = Vector2(8, 32)
	div.size     = Vector2(WIN_W - 16, 1)
	_panel.add_child(div)

	# Quantity label
	var qty_lbl = Label.new()
	qty_lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	qty_lbl.add_theme_font_size_override("font_size", 11)
	qty_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	qty_lbl.text     = "QUANTITY:"
	qty_lbl.position = Vector2(12, 40)
	qty_lbl.size     = Vector2(90, 20)
	qty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(qty_lbl)

	# Quantity buttons  1 / 3 / 5
	var qty_x = 108.0
	for qty_val in [1, 3, 5]:
		var btn = Button.new()
		btn.text     = "x%d" % qty_val
		btn.position = Vector2(qty_x, 37)
		btn.size     = Vector2(36, 22)
		btn.name     = "QtyBtn%d" % qty_val
		_style_qty_button(btn, qty_val == 1)
		var v = qty_val
		btn.pressed.connect(func(): _set_qty(v))
		_panel.add_child(btn)
		qty_x += 42.0

	# Divider under qty
	var div2 = ColorRect.new()
	div2.color    = Color(0.20, 0.45, 0.70, 0.40)
	div2.position = Vector2(8, 64)
	div2.size     = Vector2(WIN_W - 16, 1)
	_panel.add_child(div2)

	# Scroll container for the mob list
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(4, 68)
	scroll.size     = Vector2(WIN_W - 8, WIN_H - 72)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Build rows grouped by category
	var last_cat = ""
	for entry in ENTRIES:
		var label_text : String = entry[0]
		var method     : String = entry[1]
		var tier_text  : String = entry[2]
		var tier_rgb   : Array  = entry[3]

		# Determine category from tier
		var cat = "TRAINING" if tier_text == "DUMMY" \
			else ("BOSSES" if tier_text == "BOSS" else "MOBS")

		if cat != last_cat:
			_add_section_header(vbox, cat)
			last_cat = cat

		_add_mob_row(vbox, label_text, method, tier_text,
			Color(tier_rgb[0], tier_rgb[1], tier_rgb[2]))

func _style_qty_button(btn: Button, selected: bool) -> void:
	var s = StyleBoxFlat.new()
	if selected:
		s.bg_color     = Color(0.12, 0.35, 0.60, 0.95)
		s.border_color = Color(0.40, 0.72, 1.00, 0.90)
	else:
		s.bg_color     = Color(0.08, 0.10, 0.18, 0.88)
		s.border_color = Color(0.28, 0.38, 0.55, 0.60)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("hover",    s)
	btn.add_theme_stylebox_override("pressed",  s)
	btn.add_theme_font_override("font", _bold if _bold else _roboto)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color",
		Color(0.80, 0.95, 1.00) if selected else Color(0.55, 0.65, 0.75))

func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIN_W - 20, 26)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.40, 0.65, 0.90, 0.85))
	lbl.text = "── " + text + " ──"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	parent.add_child(row)

func _add_mob_row(parent: VBoxContainer, label: String, method: String,
		tier: String, tier_col: Color) -> void:

	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIN_W - 20, 32)

	# Tier badge
	var badge = Label.new()
	badge.add_theme_font_override("font", _bold if _bold else _roboto)
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", tier_col)
	badge.text = tier
	badge.custom_minimum_size = Vector2(54, 32)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(badge)

	# Mob name
	var name_lbl = Label.new()
	name_lbl.add_theme_font_override("font", _roboto)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	name_lbl.text = label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	# Spawn button
	var btn = Button.new()
	btn.text = "SPAWN"
	btn.custom_minimum_size = Vector2(68, 24)
	var bsty = StyleBoxFlat.new()
	bsty.bg_color     = Color(0.08, 0.22, 0.10, 0.92)
	bsty.border_color = Color(0.28, 0.75, 0.38, 0.75)
	bsty.set_border_width_all(1)
	bsty.set_corner_radius_all(3)
	var bsty_h = bsty.duplicate()
	bsty_h.bg_color = Color(0.12, 0.35, 0.16, 0.95)
	btn.add_theme_stylebox_override("normal", bsty)
	btn.add_theme_stylebox_override("hover",  bsty_h)
	btn.add_theme_font_override("font", _bold if _bold else _roboto)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.45, 1.00, 0.55))

	# Capture method and label for the closure
	var m = method
	var n = label
	btn.pressed.connect(func(): _do_spawn(m, n))
	row.add_child(btn)

	parent.add_child(row)

# ── Qty selection ────────────────────────────────────────────
func _set_qty(val: int) -> void:
	_qty = val
	for qty_val in [1, 3, 5]:
		var btn = _panel.get_node_or_null("QtyBtn%d" % qty_val)
		if btn:
			_style_qty_button(btn, qty_val == val)

# ── Spawn logic ──────────────────────────────────────────────
func _do_spawn(method: String, label: String) -> void:
	if not is_instance_valid(_scene) or not is_instance_valid(_player):
		return
	if not _scene.has_method(method):
		push_warning("SpawnWindow: method '%s' not found on scene" % method)
		return

	# Stagger spawns around the player in a ring so they don't stack
	var base_angle = randf() * TAU
	for i in _qty:
		var angle = base_angle + (TAU / max(_qty, 1)) * i
		var dist  = 200.0 + randf() * 80.0
		var pos   = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
		_scene.call(method, pos)

	print("SpawnWindow: spawned %d × %s" % [_qty, label])

# ── Input ────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_F1:
			visible = false
			get_viewport().set_input_as_handled()

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed and event.position.y < 34
	elif event is InputEventMouseMotion and _dragging:
		_panel.position += event.relative
