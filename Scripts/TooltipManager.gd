extends CanvasLayer

# ============================================================
#  TooltipManager.gd
#  Single global tooltip that follows the mouse.
#  Other systems register controls to track:
#
#    TooltipManager.watch(control, callable_that_returns_dict)
#
#  The callable returns a dict:
#    { "title": "...", "rows": [["Key","Value"], ...],
#      "color": Color(...),  "footer": "optional small text" }
#  or {} to hide.
#
#  Call init() after add_child.
# ============================================================

const TIP_W        : float = 220.0
const TIP_PAD      : float = 10.0
const SHOW_DELAY   : float = 0.25   # seconds before tooltip appears
const EDGE_MARGIN  : float = 12.0   # keep away from screen edge

var _tip_panel  : Panel  = null
var _visible    : bool   = false
var _hover_t    : float  = 0.0      # time hovering current control
var _watches    : Array  = []       # [{ctrl, cb}]
var _cur_data   : Dictionary = {}
var _cur_ctrl   : Control = null

func init() -> void:
	layer = 50   # above everything
	_build_panel()

func watch(ctrl: Control, cb: Callable) -> void:
	_watches.append({"ctrl": ctrl, "cb": cb})
	ctrl.mouse_entered.connect(_on_enter.bind(ctrl, cb))
	ctrl.mouse_exited.connect(_on_exit.bind(ctrl))

func _build_panel() -> void:
	_tip_panel          = Panel.new()
	_tip_panel.visible  = false
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty             = StyleBoxFlat.new()
	sty.bg_color        = Color(0.04, 0.05, 0.14, 0.97)
	sty.border_color    = Color(0.35, 0.65, 1.00, 0.80)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	_tip_panel.add_theme_stylebox_override("panel", sty)
	add_child(_tip_panel)

func _on_enter(ctrl: Control, cb: Callable) -> void:
	_cur_ctrl  = ctrl
	_hover_t   = 0.0
	_visible   = false
	_tip_panel.visible = false
	# Pre-fetch data so we know the size immediately on show
	_cur_data  = cb.call()

func _on_exit(ctrl: Control) -> void:
	if _cur_ctrl == ctrl:
		_cur_ctrl  = null
		_cur_data  = {}
		_hover_t   = 0.0
		_visible   = false
		_tip_panel.visible = false

func _process(delta: float) -> void:
	if _cur_ctrl == null or _cur_data.is_empty():
		return

	# Make sure watched control is still alive
	if not is_instance_valid(_cur_ctrl):
		_cur_ctrl = null
		_tip_panel.visible = false
		return

	_hover_t += delta
	if _hover_t < SHOW_DELAY:
		return

	if not _visible:
		_visible = true
		_rebuild_tip(_cur_data)

	# Follow mouse
	var mp  = get_viewport().get_mouse_position()
	var vp  = get_viewport().get_visible_rect().size
	var tx  = mp.x + 16.0
	var ty  = mp.y + 8.0
	# Flip left if too close to right edge
	if tx + TIP_W + EDGE_MARGIN > vp.x:
		tx = mp.x - TIP_W - 12.0
	# Flip up if too close to bottom
	if ty + _tip_panel.size.y + EDGE_MARGIN > vp.y:
		ty = mp.y - _tip_panel.size.y - 8.0
	_tip_panel.position = Vector2(tx, ty)

func _rebuild_tip(data: Dictionary) -> void:
	# Clear old children
	for ch in _tip_panel.get_children():
		ch.queue_free()

	if data.is_empty():
		_tip_panel.visible = false
		return

	var title    = data.get("title",  "")
	var rows     = data.get("rows",   [])   # Array of [key_str, val_str]
	var accent   = data.get("color",  Color(0.55, 0.85, 1.00))
	var footer   = data.get("footer", "")

	# Update border color to match item rarity accent
	var sty              = StyleBoxFlat.new()
	sty.bg_color         = Color(0.04, 0.05, 0.14, 0.97)
	sty.border_color     = accent
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(5)
	_tip_panel.add_theme_stylebox_override("panel", sty)

	var cur_y = TIP_PAD

	# Title
	if title != "":
		var lbl = Label.new()
		lbl.text = title
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", accent)
		lbl.position = Vector2(TIP_PAD, cur_y)
		lbl.size     = Vector2(TIP_W - TIP_PAD * 2, 20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(lbl)
		cur_y += 22

		# Title underline
		var line      = ColorRect.new()
		line.size     = Vector2(TIP_W - TIP_PAD * 2, 1)
		line.position = Vector2(TIP_PAD, cur_y)
		line.color    = Color(accent.r, accent.g, accent.b, 0.35)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(line)
		cur_y += 6

	# Rows
	for row in rows:
		var key_s = row[0] if row.size() > 0 else ""
		var val_s = row[1] if row.size() > 1 else ""

		var key_lbl = Label.new()
		key_lbl.text = key_s
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
		key_lbl.position  = Vector2(TIP_PAD, cur_y)
		key_lbl.size      = Vector2(86, 16)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(key_lbl)

		var val_lbl = Label.new()
		val_lbl.text = val_s
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.00))
		val_lbl.position  = Vector2(TIP_PAD + 88, cur_y)
		val_lbl.size      = Vector2(TIP_W - TIP_PAD * 2 - 88, 16)
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(val_lbl)
		cur_y += 18

	# Footer
	if footer != "":
		cur_y += 4
		var div      = ColorRect.new()
		div.size     = Vector2(TIP_W - TIP_PAD * 2, 1)
		div.position = Vector2(TIP_PAD, cur_y)
		div.color    = Color(1, 1, 1, 0.12)
		div.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(div)
		cur_y += 6

		var ft = Label.new()
		ft.text = footer
		ft.add_theme_font_size_override("font_size", 10)
		ft.add_theme_color_override("font_color", Color(0.50, 0.58, 0.68))
		ft.position  = Vector2(TIP_PAD, cur_y)
		ft.size      = Vector2(TIP_W - TIP_PAD * 2, 16)
		ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.add_child(ft)
		cur_y += 18

	_tip_panel.size    = Vector2(TIP_W, cur_y + TIP_PAD)
	_tip_panel.visible = true

# ── Static helpers — build tooltip data dicts ─────────────────

static func data_for_item(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var itype   = item.get("type", "")
	var rarity  = item.get("rarity", "")
	var name_s  = item.get("name",  "Unknown")
	var cost    = item.get("cost",  0)
	var sell    = int(cost * 0.5)
	var _desc   = item.get("desc",  "")

	var accent : Color
	match rarity:
		"grey":  accent = Color(0.75, 0.76, 0.80)
		"white": accent = Color(0.92, 0.94, 1.00)
		"gold":  accent = Color(1.00, 0.85, 0.20)
		"blue":  accent = Color(0.35, 0.72, 1.00)
		_:       accent = Color(0.55, 0.85, 1.00)

	var rows : Array = []
	rows.append(["Type",   itype.capitalize()])
	rows.append(["Rarity", rarity.capitalize()])

	match itype:
		"mount":
			var spd = item.get("speed_mult", 1.0)
			rows.append(["Speed",  "%.0f× walk" % spd])
		"knife":
			var s = item.get("attr_str", 0); var a = item.get("attr_agi", 0)
			if s > 0: rows.append(["STR", "+%d" % s])
			if a > 0: rows.append(["AGI", "+%d" % a])
		"rifle":
			var a = item.get("attr_agi", 0)
			if a > 0: rows.append(["AGI", "+%d" % a])
			var cls = item.get("allowed_class", "")
			if cls != "": rows.append(["Class", cls.capitalize() + " only"])

	rows.append(["Buy",  "%d ¢" % cost])
	rows.append(["Sell", "%d ¢" % sell])

	var footer = "Double-click to equip" if not item.get("equipped", false) else "Double-click to unequip"

	return {"title": name_s, "rows": rows, "color": accent, "footer": footer}

static func data_for_skill(skill: Dictionary) -> Dictionary:
	if skill.is_empty():
		return {}

	var sid    = skill.get("id",    "")
	var sname  = skill.get("name",  sid)
	var lvl    = skill.get("req_level", 1)
	var cd     = skill.get("cooldown",  0)
	var _desc  = skill.get("description", "")

	var rows : Array = []
	rows.append(["Required Lv", str(lvl)])
	if cd > 0:
		rows.append(["Cooldown", "%ds" % cd])
	else:
		rows.append(["Cooldown", "None"])

	match sid:
		"sprint":
			rows.append(["Effect", "+65% speed"])
			rows.append(["Duration", "15 sec"])
		"sensu_bean":
			rows.append(["Effect", "Restore HP + MP"])
			rows.append(["Duration", "10 sec"])
		"triple_strike":
			rows.append(["Effect", "3 instant hits"])

	var footer = "Press 1–5 to activate"
	return {"title": sname, "rows": rows, "color": Color(0.55, 0.88, 1.00), "footer": footer}
