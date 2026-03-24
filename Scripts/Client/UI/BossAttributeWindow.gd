extends CanvasLayer

# ============================================================
#  BossAttributeWindow.gd — Press C to toggle
#  Shows player stats + attribute points with [+] spend buttons
# ============================================================

var _player     : Node  = null
var _panel      : Panel = null
var _drag_active: bool  = false
var _row_labels : Array = []   # Label nodes for live value update

func init(player: Node) -> void:
	layer   = 12
	_player = player
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	const WIN_W : float = 340.0
	const WIN_H : float = 340.0
	var win_x = vp.x * 0.5 - WIN_W * 0.5
	var win_y = vp.y * 0.5 - WIN_H * 0.5

	# ── Window panel ─────────────────────────────────────────
	var panel = Panel.new()
	panel.name     = "AttrPanel"
	panel.position = Vector2(win_x, win_y)
	panel.size     = Vector2(WIN_W, WIN_H)
	var style = StyleBoxFlat.new()
	style.bg_color    = Color(0.06, 0.05, 0.10, 0.96)
	style.border_color = Color(0.35, 0.60, 0.90)
	style.set_border_width_all(2)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	_panel = panel
	add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_drag)

	# ── Title ─────────────────────────────────────────────────
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "ATTRIBUTES"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(WIN_W, 22)
	title.position = Vector2(0, 8)
	panel.add_child(title)

	# ── Points available ──────────────────────────────────────
	var pts_lbl = Label.new()
	pts_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	pts_lbl.name = "PointsLbl"
	pts_lbl.add_theme_font_size_override("font_size", 12)
	pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_lbl.size     = Vector2(WIN_W, 18)
	pts_lbl.position = Vector2(0, 32)
	panel.add_child(pts_lbl)

	# ── Divider ───────────────────────────────────────────────
	var div = ColorRect.new()
	div.color    = Color(0.3, 0.4, 0.6, 0.5)
	div.position = Vector2(12, 54)
	div.size     = Vector2(WIN_W - 24, 1)
	panel.add_child(div)

	# ── Attribute rows ────────────────────────────────────────
	var attrs = [
		{"key": "str", "label": "STR", "col": Color(1.0, 0.55, 0.2),
		 "desc": "+25 HP  |  +5 Melee Dmg  |  +5% Dmg Reduction"},
		{"key": "agi", "label": "AGI", "col": Color(0.3, 0.95, 0.5),
		 "desc": "+5% Attack Speed  |  +2% Crit Chance"},
		{"key": "int", "label": "INT", "col": Color(0.55, 0.6, 1.0),
		 "desc": "+5% Spell Dmg  |  +2% Spell Crit"},
		{"key": "spi", "label": "SPI", "col": Color(0.9, 0.5, 1.0),
		 "desc": "+25 MP  |  +5 Spell Dmg"},
	]

	var row_y : float = 64.0
	const ROW_H : float = 58.0

	for a in attrs:
		_build_attr_row(panel, a, row_y, WIN_W)
		row_y += ROW_H

	# ── Divider 2 ─────────────────────────────────────────────
	var div2 = ColorRect.new()
	div2.color    = Color(0.3, 0.4, 0.6, 0.5)
	div2.position = Vector2(12, row_y)
	div2.size     = Vector2(WIN_W - 24, 1)
	panel.add_child(div2)

	# ── Derived stats summary ─────────────────────────────────
	var summary = Label.new()
	summary.name = "SummaryLbl"
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	summary.size     = Vector2(WIN_W - 24, 50)
	summary.position = Vector2(12, row_y + 6)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD
	panel.add_child(summary)

	# ── Hint ──────────────────────────────────────────────────
	var hint = Label.new()
	hint.text = "Press C to close"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size     = Vector2(WIN_W, 16)
	hint.position = Vector2(0, WIN_H - 16)
	panel.add_child(hint)

func _on_panel_drag(event: InputEvent) -> void:
	const DRAG_BAR : float = 58.0   # title + points label + divider
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed and event.position.y <= DRAG_BAR
	elif event is InputEventMouseMotion and _drag_active:
		var vp      = get_viewport().get_visible_rect().size
		var new_pos = _panel.position + event.relative
		_panel.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - _panel.size.x),
			clampf(new_pos.y, 0.0, vp.y - _panel.size.y)
		)

func _build_attr_row(panel: Panel, a: Dictionary, y: float, win_w: float) -> void:
	# Attribute name
	var name_lbl = Label.new()
	name_lbl.text = a.label
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", a.col)
	name_lbl.position = Vector2(16, y)
	name_lbl.size     = Vector2(46, 24)
	panel.add_child(name_lbl)

	# Current value
	var val_lbl = Label.new()
	val_lbl.name = "Val_" + a.key
	val_lbl.add_theme_font_size_override("font_size", 18)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	val_lbl.position = Vector2(64, y)
	val_lbl.size     = Vector2(30, 24)
	panel.add_child(val_lbl)

	# [+] button
	var btn = Button.new()
	btn.text = "+"
	btn.position = Vector2(win_w - 46, y - 2)
	btn.size     = Vector2(30, 26)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_spend.bind(a.key))
	panel.add_child(btn)

	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = a.desc
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc_lbl.position = Vector2(16, y + 26)
	desc_lbl.size     = Vector2(win_w - 70, 18)
	panel.add_child(desc_lbl)

func _on_spend(attr_key: String) -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("spend_point"):
		_player.call("spend_point", attr_key)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var panel = get_node_or_null("AttrPanel") as Panel
	if panel == null:
		return

	var unspent = _player.get("unspent_points")
	var pts_lbl = panel.get_node_or_null("PointsLbl") as Label
	if pts_lbl:
		if unspent != null and unspent > 0:
			pts_lbl.text = "Points to spend: %d" % unspent
			pts_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		else:
			pts_lbl.text = "Level %d" % (_player.get("level") if _player.get("level") != null else 1)
			pts_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))

	# Update attribute values
	for key in ["str", "agi", "int", "spi"]:
		var lbl = panel.get_node_or_null("Val_" + key) as Label
		if lbl:
			var val = _player.get("attr_" + key)
			lbl.text = str(val) if val != null else "0"

	# Update [+] buttons visibility based on unspent points
	var has_points = (unspent != null and unspent > 0)
	for key in ["str", "agi", "int", "spi"]:
		# Buttons are the 3rd child of each row group — find by iterating
		pass
	# Simpler: show/hide all [+] buttons
	for child in panel.get_children():
		if child is Button:
			child.disabled = not has_points

	# Derived stats summary
	var summary = panel.get_node_or_null("SummaryLbl") as Label
	if summary:
		var s = _player.get("attr_str") as int
		var g = _player.get("attr_agi") as int
		var i = _player.get("attr_int") as int
		var p = _player.get("attr_spi") as int
		var max_hp = _player.get("max_hp") as float
		var max_mp = _player.get("max_mp") as float
		summary.text = "HP: %.0f   MP: %.0f   Crit: %.0f%%   Dmg Red: %.0f%%" % [
			max_hp, max_mp, g * 2.0, s * 5.0
		]
