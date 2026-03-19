extends CanvasLayer

# ============================================================
#  SWGStatsWindow.gd — Character stats overview
#  Press L to toggle. Shows all combat stats from learned boxes.
# ============================================================

var _player : Node = null
var _panel  : Panel = null
var _roboto : Font = null
var _bold   : Font = null

const WIN_W : float = 360.0
const WIN_H : float = 520.0

var _dragging : bool = false
var _scroll : ScrollContainer = null
var _content : VBoxContainer = null

func init(player: Node) -> void:
	layer = 14
	_player = player
	_roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	_bold = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf")
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size
	_panel = Panel.new()
	_panel.position = Vector2(vp.x * 0.5 - WIN_W * 0.5, vp.y * 0.5 - WIN_H * 0.5)
	_panel.size = Vector2(WIN_W, WIN_H)
	var sty = StyleBoxFlat.new()
	sty.bg_color = Color(0.07, 0.08, 0.14, 0.96)
	sty.border_color = Color(0.40, 0.60, 0.90, 0.75)
	sty.set_border_width_all(2); sty.set_corner_radius_all(5)
	sty.shadow_color = Color(0, 0, 0, 0.5); sty.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sty)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)

	# Accent
	var accent = ColorRect.new()
	accent.color = Color(0.22, 0.78, 1.00, 0.92)
	accent.position = Vector2(2, 2); accent.size = Vector2(WIN_W - 4, 4)
	_panel.add_child(accent)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", _bold if _bold else _roboto)
	title.text = "CHARACTER STATS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0))
	title.position = Vector2(12, 10); title.size = Vector2(WIN_W - 60, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	# Close
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(WIN_W - 28, 5); close_btn.size = Vector2(22, 22)
	close_btn.pressed.connect(queue_free)
	var cbsty = StyleBoxFlat.new()
	cbsty.bg_color = Color(0.20, 0.08, 0.08, 0.9)
	cbsty.border_color = Color(0.85, 0.35, 0.35, 0.7)
	cbsty.set_border_width_all(1); cbsty.set_corner_radius_all(3)
	close_btn.add_theme_stylebox_override("normal", cbsty)
	_panel.add_child(close_btn)

	# Scroll container for stats
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(4, 32)
	_scroll.size = Vector2(WIN_W - 8, WIN_H - 36)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Dark scrollbar
	var sb_sty = StyleBoxFlat.new()
	sb_sty.bg_color = Color(0.12, 0.15, 0.25, 0.6)
	sb_sty.set_corner_radius_all(2)
	_scroll.add_theme_stylebox_override("panel", sb_sty)
	_panel.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_player): return

	# Clear content
	for c in _content.get_children():
		c.queue_free()

	var y = 4.0

	# ── HAM POOLS ────────────────────────────────────────────
	_section("HAM POOLS", y); y += 22
	_stat_row("Health", "%d / %d" % [int(_player.ham_health), int(_player.call("get_effective_max_health"))], Color(0.9, 0.3, 0.2), y); y += 18
	_stat_row("Action", "%d / %d" % [int(_player.ham_action), int(_player.call("get_effective_max_action"))], Color(0.9, 0.75, 0.2), y); y += 18
	_stat_row("Mind", "%d / %d" % [int(_player.ham_mind), int(_player.call("get_effective_max_mind"))], Color(0.3, 0.5, 0.9), y); y += 18

	if _player.wound_health > 0 or _player.wound_action > 0 or _player.wound_mind > 0:
		_stat_row("Wounds (H/A/M)", "%d / %d / %d" % [int(_player.wound_health), int(_player.wound_action), int(_player.wound_mind)], Color(0.8, 0.4, 0.4), y); y += 18

	y += 4
	_divider(y); y += 8

	# ── OFFENSE ──────────────────────────────────────────────
	_section("OFFENSE", y); y += 22
	var cs = _player._combat_stats as Dictionary
	_stat_row("Accuracy",       str(int(_player.get_stat("accuracy"))),           Color(0.7, 0.9, 0.5), y); y += 17
	_stat_row("Unarmed Damage", "+%d" % cs.get("unarmed_damage", 0),              Color(0.9, 0.7, 0.4), y); y += 17
	_stat_row("One Hand Damage", "+%d" % cs.get("onehand_damage", 0),  Color(0.9, 0.7, 0.4), y); y += 17
	_stat_row("Two Hand Damage", "+%d" % cs.get("twohand_damage", 0), Color(0.9, 0.7, 0.4), y); y += 17
	_stat_row("Polearm Damage", "+%d" % cs.get("polearm_damage", 0),              Color(0.9, 0.7, 0.4), y); y += 17

	y += 4; _divider(y); y += 8

	# ── DEFENSE ──────────────────────────────────────────────
	_section("DEFENSE", y); y += 22
	_stat_row("Defense",       str(int(_player.get_stat("defense"))),       Color(0.5, 0.8, 1.0), y); y += 17
	_stat_row("Dodge",         str(int(_player.get_stat("dodge"))),         Color(0.5, 0.8, 1.0), y); y += 17
	_stat_row("Block",         str(int(_player.get_stat("block"))),         Color(0.5, 0.8, 1.0), y); y += 17
	_stat_row("Counterattack", str(int(_player.get_stat("counterattack"))), Color(0.5, 0.8, 1.0), y); y += 17

	y += 4; _divider(y); y += 8

	# ── STATE DEFENSE ────────────────────────────────────────
	_section("STATE DEFENSE", y); y += 22
	_stat_row("Def vs Dizzy",      str(int(_player.get_stat("defense_vs_dizzy"))),      Color(0.8, 0.7, 0.5), y); y += 17
	_stat_row("Def vs Knockdown",  str(int(_player.get_stat("defense_vs_knockdown"))),  Color(0.8, 0.7, 0.5), y); y += 17
	_stat_row("Def vs Stun",       str(int(_player.get_stat("defense_vs_stun"))),       Color(0.8, 0.7, 0.5), y); y += 17
	_stat_row("Def vs Blind",      str(int(_player.get_stat("defense_vs_blind"))),      Color(0.8, 0.7, 0.5), y); y += 17
	_stat_row("Def vs Intimidate", str(int(_player.get_stat("defense_vs_intimidate"))), Color(0.8, 0.7, 0.5), y); y += 17

	y += 4; _divider(y); y += 8

	# ── ARMOR RESISTANCE ─────────────────────────────────────
	_section("ARMOR RESISTANCE", y); y += 22
	for dtype in ["kinetic", "energy", "heat", "cold", "acid", "electricity", "blast", "stun"]:
		var val = int(_player.get_stat("resist_" + dtype))
		var col = Color(0.6, 0.7, 0.8) if val == 0 else Color(0.4, 0.9, 0.6)
		_stat_row(dtype.capitalize(), "%d%%" % val, col, y); y += 17

	# ── GEAR BONUSES ─────────────────────────────────────────
	var dmg_bonus = _player.get("_item_dmg_bonus")
	var gear_defense = _player.get("_item_combat_stats")
	var has_gear = (dmg_bonus != null and dmg_bonus > 0.0) or (gear_defense != null and not gear_defense.is_empty())
	if has_gear:
		y += 4; _divider(y); y += 8
		_section("GEAR BONUSES", y); y += 22
		if dmg_bonus != null and dmg_bonus > 0.0:
			_stat_row("Damage Bonus", "+%d" % int(dmg_bonus), Color(1.0, 0.75, 0.30), y); y += 17
		if gear_defense != null:
			for gkey in ["defense", "resist_kinetic", "resist_energy"]:
				var gv = int(gear_defense.get(gkey, 0))
				if gv > 0:
					_stat_row(gkey.replace("resist_", "").capitalize() + " (gear)",
						"+%d" % gv, Color(0.45, 0.95, 0.65), y); y += 17
		# Show equipped item names
		var inv = _player.get("inventory")
		if inv != null:
			for itm in inv:
				if itm.get("equipped", false) and itm.get("type","") in ["weapon","armor"]:
					var rc : Color
					match itm.get("rarity","white"):
						"blue": rc = Color(0.40, 0.72, 1.00)
						"gold": rc = Color(1.00, 0.82, 0.15)
						_:      rc = Color(0.88, 0.88, 0.88)
					_stat_row("[" + itm.get("type","").capitalize() + "]",
						itm.get("name",""), rc, y); y += 17

func _section(text: String, _y: float) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIN_W - 16, 20)
	var lbl = Label.new()
	lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0, 0.9))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	_content.add_child(row)

func _stat_row(label: String, value: String, col: Color, _y: float) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(WIN_W - 16, 17)
	var name_lbl = Label.new()
	name_lbl.add_theme_font_override("font", _roboto)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.text = "   " + label
	name_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.text = value
	val_lbl.add_theme_color_override("font_color", col)
	val_lbl.custom_minimum_size = Vector2(100, 17)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	_content.add_child(row)

func _divider(_y: float) -> void:
	var sep = HSeparator.new()
	sep.custom_minimum_size = Vector2(WIN_W - 28, 6)
	sep.add_theme_constant_override("separation", 2)
	_content.add_child(sep)

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and event.position.y < 30
	elif event is InputEventMouseMotion and _dragging:
		_panel.position += event.relative

func _process(_delta: float) -> void:
	if is_instance_valid(_player):
		_refresh()
