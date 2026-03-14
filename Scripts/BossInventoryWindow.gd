extends CanvasLayer

# ============================================================
#  BossInventoryWindow.gd — Press I to toggle
#  5×5 grid of item slots.  Double-click an item to equip/unequip.
#  Equipped items glow.  Credit counter at bottom.
# ============================================================

const COLS      : int   = 5
const ROWS      : int   = 5
const SLOT_SIZE : float = 52.0
const SLOT_GAP  : float = 6.0
const PAD       : float = 14.0

var _player     : Node    = null
var _panel      : Panel   = null
var _grid_root  : Control = null
var _drag_active : bool   = false

func init(player: Node) -> void:
	layer   = 26
	_player = player
	_build_ui()

func _build_ui() -> void:
	var vp      = get_viewport().get_visible_rect().size
	var grid_w  = COLS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var grid_h  = ROWS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var win_w   = grid_w + PAD * 2
	var win_h   = grid_h + PAD * 2 + 52.0

	var win_x   = vp.x * 0.5 - win_w * 0.5
	var win_y   = vp.y * 0.5 - win_h * 0.5 + 60.0

	# ── Window panel (dark glass) ──────────────────────────────
	_panel          = Panel.new()
	_panel.position = Vector2(win_x, win_y)
	_panel.size     = Vector2(win_w, win_h)
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.03, 0.04, 0.10, 0.94)
	sty.border_color = Color(0.35, 0.55, 0.85, 0.70)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_drag)

	# ── Glowing top / bottom bar ───────────────────────────────
	var top_bar          = ColorRect.new()
	top_bar.size         = Vector2(win_w, 4)
	top_bar.color        = Color(0.22, 0.78, 1.00, 0.85)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(top_bar)

	var bot_bar          = ColorRect.new()
	bot_bar.size         = Vector2(win_w, 3)
	bot_bar.position     = Vector2(0, win_h - 3)
	bot_bar.color        = Color(0.22, 0.78, 1.00, 0.50)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bot_bar)

	# ── Title ─────────────────────────────────────────────────
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "I N V E N T O R Y"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size         = Vector2(win_w, 18)
	title.position     = Vector2(0, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	var hint_eq = Label.new()
	hint_eq.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hint_eq.name = "HintLabel"
	hint_eq.text = "double-click to equip / unequip"
	hint_eq.add_theme_font_size_override("font_size", 8)
	hint_eq.add_theme_color_override("font_color", Color(0.40, 0.50, 0.60, 0.70))
	hint_eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_eq.size         = Vector2(win_w, 12)
	hint_eq.position     = Vector2(0, 22)
	hint_eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hint_eq)

	# ── Grid container ────────────────────────────────────────
	_grid_root          = Control.new()
	_grid_root.position = Vector2(PAD, 36)
	_grid_root.size     = Vector2(grid_w, grid_h)
	_panel.add_child(_grid_root)

	_build_item_slots()

	# ── Credit counter ────────────────────────────────────────
	var credit_lbl = Label.new()
	credit_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	credit_lbl.name = "CreditLabel"
	credit_lbl.add_theme_font_size_override("font_size", 12)
	credit_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	credit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_lbl.size     = Vector2(win_w, 20)
	credit_lbl.position = Vector2(0, win_h - 32)
	_panel.add_child(credit_lbl)

	# ── Hint ──────────────────────────────────────────────────
	var hint = Label.new()
	hint.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hint.text = "Press I to close"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size         = Vector2(win_w, 14)
	hint.position     = Vector2(0, win_h - 13)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hint)

# ── Build / refresh item slots ────────────────────────────────
func _build_item_slots() -> void:
	if _grid_root == null:
		return
	for ch in _grid_root.get_children():
		ch.queue_free()

	var inv : Array = []
	if is_instance_valid(_player):
		var v = _player.get("inventory")
		if v != null:
			inv = v

	var icon_script = load("res://Scripts/BossItemIcon.gd")

	var _offered_idxs : Array = []
	var ts = _get_trade_system()
	if ts != null and bool(ts.get("_open")):
		_offered_idxs = ts.get("_my_items")

	for row in ROWS:
		for col in COLS:
			var idx  = row * COLS + col
			var slot = Panel.new()
			slot.position = Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))
			slot.size     = Vector2(SLOT_SIZE, SLOT_SIZE)

			var has_item = idx < inv.size()
			var equipped = has_item and inv[idx].get("equipped", false)
			var offered  = _offered_idxs.has(idx)

			var ssty = StyleBoxFlat.new()
			if offered:
				ssty.bg_color    = Color(0.06, 0.28, 0.20, 0.96)
				ssty.border_color = Color(0.20, 0.90, 0.55, 1.0)
				ssty.set_border_width_all(2)
			elif equipped:
				ssty.bg_color    = Color(0.07, 0.22, 0.38, 0.96)
				ssty.border_color = Color(0.28, 0.85, 1.0, 1.0)
				ssty.set_border_width_all(2)
			else:
				ssty.bg_color    = Color(0.10, 0.08, 0.16, 0.90)
				ssty.border_color = Color(0.28, 0.24, 0.46, 0.80)
				ssty.set_border_width_all(1)
			ssty.set_corner_radius_all(3)
			slot.add_theme_stylebox_override("panel", ssty)

			if has_item:
				var icon = Control.new()
				icon.set_script(icon_script)
				icon.size         = Vector2(SLOT_SIZE, SLOT_SIZE)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				# item_data points to the SAME dict in player.inventory —
				# equip flag updates automatically without rebuilding
				icon.set("item_data", inv[idx])
				slot.add_child(icon)

				if offered:
					var tr_lbl = Label.new()
					tr_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
					tr_lbl.text = "OFFER"
					tr_lbl.add_theme_font_size_override("font_size", 7)
					tr_lbl.add_theme_color_override("font_color", Color(0.20, 1.0, 0.60))
					tr_lbl.position     = Vector2(2, 2)
					tr_lbl.size         = Vector2(36, 12)
					tr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					slot.add_child(tr_lbl)
				elif equipped:
					var eq_lbl = Label.new()
					eq_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
					eq_lbl.text = "EQ"
					eq_lbl.add_theme_font_size_override("font_size", 7)
					eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
					eq_lbl.position     = Vector2(2, 2)
					eq_lbl.size         = Vector2(20, 12)
					eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					slot.add_child(eq_lbl)

				slot.mouse_filter = Control.MOUSE_FILTER_STOP
				slot.gui_input.connect(_on_slot_input.bind(idx))
				# Tooltip
				var tip = _player.get_node_or_null("TooltipManager") if is_instance_valid(_player) else null
				if tip and tip.has_method("watch"):
					var captured = inv[idx].duplicate()
					tip.call("watch", slot, func():
						# Re-read live data so equipped state stays current
						var live_inv = _player.get("inventory") if is_instance_valid(_player) else []
						var live_item = live_inv[idx] if live_inv and idx < live_inv.size() else captured
						return tip.get_script().data_for_item(live_item))
			else:
				slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

			_grid_root.add_child(slot)

func _on_panel_drag(event: InputEvent) -> void:
	const DRAG_BAR : float = 36.0   # title + hint strip
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_active = event.pressed and event.position.y <= DRAG_BAR
	elif event is InputEventMouseMotion and _drag_active:
		var vp      = get_viewport().get_visible_rect().size
		var new_pos = _panel.position + event.relative
		_panel.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - _panel.size.x),
			clampf(new_pos.y, 0.0, vp.y - _panel.size.y)
		)

func _get_trade_system() -> Node:
	var scene = get_tree().get_first_node_in_group("boss_arena_scene")
	if scene == null: return null
	var ts = scene.get("_trade_system")
	if not is_instance_valid(ts): return null
	return ts

func _on_slot_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed): return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var ts = _get_trade_system()
		if ts != null and bool(ts.get("_open")):
			# Trade is open — single click adds/removes item from offer
			var offered : Array = ts.get("_my_items")
			if offered.has(idx):
				ts.call("_remove_my_item", offered.find(idx))
			else:
				ts.call("add_item_to_trade", idx)
			call_deferred("_build_item_slots")
		elif event.double_click and is_instance_valid(_player):
			_player.call("toggle_equip", idx)
			call_deferred("_build_item_slots")

func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or _panel == null:
		return
	var lbl = _panel.get_node_or_null("CreditLabel") as Label
	if lbl:
		var c = _player.get("credits")
		lbl.text = "Credits:  %d ¢" % (c if c != null else 0)
	var hint = _panel.get_node_or_null("HintLabel") as Label
	if hint:
		var ts = _get_trade_system()
		if ts != null and bool(ts.get("_open")):
			hint.text = "click to offer / click again to remove"
			hint.add_theme_color_override("font_color", Color(0.30, 0.88, 1.00, 0.90))
		else:
			hint.text = "double-click to equip / unequip"
			hint.add_theme_color_override("font_color", Color(0.40, 0.50, 0.60, 0.70))
