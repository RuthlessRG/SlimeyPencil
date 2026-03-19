extends CanvasLayer

# ============================================================
#  BossShopWindow.gd — Futuristic terminal shop UI
#  Glass aesthetic (dark + scanlines + cyan bars).
#  Press F or close button to dismiss.
# ============================================================

# ── Item catalogue (add more items here in the future) ────────
const SHOP_ITEMS : Array = [
	# ── ARMOR ──────────────────────────────────────────────────
	{
		"id": "armor_tattered_vest", "name": "Tattered Vest", "rarity": "white",
		"type": "armor", "cost": 80,
		"attr_str": 1, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 3, "resist_kinetic": 8, "resist_energy": 0,
		"desc": "Worn chest armour.\n+3 Defense  +8 Kinetic resist",
	},
	{
		"id": "armor_composite", "name": "Composite Armor", "rarity": "blue",
		"type": "armor", "cost": 500,
		"attr_str": 3, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 12, "resist_kinetic": 22, "resist_energy": 15,
		"desc": "Solid composite plating.\n+12 Defense  +22 Kinetic  +15 Energy",
	},
	{
		"id": "armor_battle_plate", "name": "Battle Plate", "rarity": "gold",
		"type": "armor", "cost": 1600,
		"attr_str": 6, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 22, "resist_kinetic": 38, "resist_energy": 28,
		"desc": "Heavy battle-forged plate.\n+22 Defense  +38 Kinetic  +28 Energy",
	},
	# ── MELEE WEAPONS ──────────────────────────────────────────
	{
		"id": "weapon_vibroknife", "name": "Vibroknife", "rarity": "white",
		"type": "weapon", "cost": 180,
		"attr_str": 1, "attr_agi": 1, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 6, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "High-frequency blade.\n+6 Damage  +1 STR  +1 AGI",
	},
	{
		"id": "weapon_vibrolance", "name": "Vibrolance", "rarity": "blue",
		"type": "weapon", "cost": 750,
		"attr_str": 4, "attr_agi": 1, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 16, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "Powered shock lance.\n+16 Damage  +4 STR  +1 AGI",
	},
	# ── RANGED WEAPONS ─────────────────────────────────────────
	{
		"id": "weapon_scatter_pistol", "name": "Scatter Pistol", "rarity": "white",
		"type": "weapon", "cost": 220,
		"attr_str": 0, "attr_agi": 2, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 5, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "Wide-spread pistol.\n+5 Damage  +2 AGI",
	},
	{
		"id": "weapon_precision_rifle", "name": "Precision Rifle", "rarity": "blue",
		"type": "weapon", "cost": 820,
		"attr_str": 0, "attr_agi": 4, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 18, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "High-accuracy rifle.\n+18 Damage  +4 AGI",
	},
	# ── MOUNTS ─────────────────────────────────────────────────
	{
		"id": "mount_speeder_mk1", "name": "LandSpeeder MK1", "rarity": "blue",
		"type": "mount", "cost": 10000, "speed_mult": 5.0,
		"mount_variant": "fighter",
		"attr_str": 0, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "Mount: 5× speed\nSleek fighter speeder",
	},
	{
		"id": "mount_speeder_mk2", "name": "LandSpeeder MK2", "rarity": "gold",
		"type": "mount", "cost": 20000, "speed_mult": 7.0,
		"mount_variant": "transport",
		"attr_str": 0, "attr_agi": 0, "attr_int": 0, "attr_spi": 0,
		"damage_bonus": 0, "defense": 0, "resist_kinetic": 0, "resist_energy": 0,
		"desc": "Mount: 7× speed\nBroad transport speeder",
	},
]

const RARITY_COLOR : Dictionary = {
	"grey":  Color(0.75, 0.76, 0.80),
	"white": Color(0.95, 0.96, 1.00),
	"gold":  Color(1.00, 0.85, 0.20),
	"blue":  Color(0.35, 0.72, 1.00),
}

var _player          : Node    = null
var _panel           : Panel   = null
var _credit_lbl      : Label   = null
var _sell_panel      : Panel   = null
var _sell_slots_root : Control = null
var _sell_btn        : Button  = null
var _drag_active     : bool    = false
var _drag_offset     : Vector2 = Vector2.ZERO

func init(player: Node) -> void:
	layer   = 14
	_player = player
	_build_ui()

func _build_ui() -> void:
	var vp    = get_viewport().get_visible_rect().size
	const WIN_W : float = 520.0
	const ICON  : float = 52.0
	const ROW_H : float = 72.0
	const HDR_H : float = 54.0
	const FTR_H : float = 52.0

	var win_h = HDR_H + SHOP_ITEMS.size() * ROW_H + FTR_H
	var win_x = vp.x * 0.5 - WIN_W * 0.5
	var win_y = vp.y * 0.5 - win_h * 0.5

	# ── Outer panel (dark glass) ───────────────────────────────
	_panel          = Panel.new()
	_panel.position = Vector2(win_x, win_y)
	_panel.size     = Vector2(WIN_W, win_h)
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.03, 0.04, 0.10, 0.94)
	sty.set_border_width_all(0)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_gui_input)

	# ── Scanline overlay ──────────────────────────────────────
	var scan = Control.new()
	scan.size          = Vector2(WIN_W, win_h)
	scan.position      = Vector2.ZERO
	scan.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	scan.set_script(_scanline_script(WIN_W, win_h))
	_panel.add_child(scan)

	# ── Glowing top bar ───────────────────────────────────────
	var top_bar       = ColorRect.new()
	top_bar.size      = Vector2(WIN_W, 5)
	top_bar.position  = Vector2.ZERO
	top_bar.color     = Color(0.22, 0.78, 1.00, 0.92)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(top_bar)

	var bot_bar       = ColorRect.new()
	bot_bar.size      = Vector2(WIN_W, 4)
	bot_bar.position  = Vector2(0, win_h - 4)
	bot_bar.color     = Color(0.22, 0.78, 1.00, 0.55)
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bot_bar)

	# ── Header ────────────────────────────────────────────────
	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "T E R M I N A L   S H O P"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(WIN_W, 22)
	title.position = Vector2(0, 10)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	var sub = Label.new()
	sub.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	sub.text = "SYNTH-BOT MARKET  ·  SPEND YOUR CREDITS"
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", Color(0.35, 0.65, 0.80, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size     = Vector2(WIN_W, 14)
	sub.position = Vector2(0, 32)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sub)

	# Header separator
	var hsep       = ColorRect.new()
	hsep.size      = Vector2(WIN_W - 20, 1)
	hsep.position  = Vector2(10, HDR_H - 1)
	hsep.color     = Color(0.25, 0.55, 1.0, 0.35)
	hsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hsep)

	# ── Item rows ─────────────────────────────────────────────
	for idx in SHOP_ITEMS.size():
		_build_item_row(idx, HDR_H + idx * ROW_H, WIN_W, ICON, ROW_H)
		# Row divider
		if idx < SHOP_ITEMS.size() - 1:
			var div       = ColorRect.new()
			div.size      = Vector2(WIN_W - 20, 1)
			div.position  = Vector2(10, HDR_H + (idx + 1) * ROW_H - 1)
			div.color     = Color(0.25, 0.55, 1.0, 0.18)
			div.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_panel.add_child(div)

	# Footer separator
	var fsep       = ColorRect.new()
	fsep.size      = Vector2(WIN_W - 20, 1)
	fsep.position  = Vector2(10, HDR_H + SHOP_ITEMS.size() * ROW_H)
	fsep.color     = Color(0.25, 0.55, 1.0, 0.35)
	fsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(fsep)

	# ── Credits display ───────────────────────────────────────
	_credit_lbl = Label.new()
	_credit_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_credit_lbl.name = "CreditLbl"
	_credit_lbl.add_theme_font_size_override("font_size", 13)
	_credit_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_credit_lbl.position = Vector2(14, HDR_H + SHOP_ITEMS.size() * ROW_H + 10)
	_credit_lbl.size     = Vector2(WIN_W * 0.45, 22)
	_panel.add_child(_credit_lbl)

	# ── Sell button ───────────────────────────────────────────
	_sell_btn          = Button.new()
	_sell_btn.text     = "SELL ITEMS"
	_sell_btn.size     = Vector2(110, 26)
	_sell_btn.position = Vector2(WIN_W - 242, HDR_H + SHOP_ITEMS.size() * ROW_H + 8)
	_sell_btn.add_theme_font_size_override("font_size", 11)
	_sell_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	var sell_sty          = StyleBoxFlat.new()
	sell_sty.bg_color     = Color(0.12, 0.08, 0.02, 0.90)
	sell_sty.border_color = Color(1.0, 0.65, 0.20, 0.80)
	sell_sty.set_border_width_all(1)
	sell_sty.set_corner_radius_all(4)
	_sell_btn.add_theme_stylebox_override("normal", sell_sty)
	_sell_btn.pressed.connect(_on_sell_toggle)
	_panel.add_child(_sell_btn)

	# ── Close button ──────────────────────────────────────────
	var btn_close = Button.new()
	btn_close.text     = "CLOSE  [F]"
	btn_close.size     = Vector2(110, 26)
	btn_close.position = Vector2(WIN_W - 124, HDR_H + SHOP_ITEMS.size() * ROW_H + 8)
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	var btn_sty       = StyleBoxFlat.new()
	btn_sty.bg_color  = Color(0.04, 0.10, 0.18, 0.90)
	btn_sty.border_color = Color(0.28, 0.75, 1.0, 0.80)
	btn_sty.set_border_width_all(1)
	btn_sty.set_corner_radius_all(4)
	btn_close.add_theme_stylebox_override("normal", btn_sty)
	btn_close.pressed.connect(queue_free)
	_panel.add_child(btn_close)

	# ── Sell overlay panel (hidden by default) ─────────────────
	_build_sell_panel(HDR_H, SHOP_ITEMS.size() * ROW_H, WIN_W)

# ── Sell overlay ───────────────────────────────────────────────
func _build_sell_panel(panel_y: float, panel_h: float, win_w: float) -> void:
	_sell_panel          = Panel.new()
	_sell_panel.position = Vector2(0, panel_y)
	_sell_panel.size     = Vector2(win_w, panel_h)
	_sell_panel.visible  = false
	var bg               = StyleBoxFlat.new()
	bg.bg_color          = Color(0.04, 0.03, 0.08, 0.97)
	_sell_panel.add_theme_stylebox_override("panel", bg)
	_panel.add_child(_sell_panel)

	# Amber top accent bar
	var accent       = ColorRect.new()
	accent.size      = Vector2(win_w, 3)
	accent.color     = Color(1.0, 0.65, 0.15, 0.80)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_panel.add_child(accent)

	# Title
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = "SELECT ITEM TO SELL"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25, 0.90))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(win_w, 18)
	lbl.position = Vector2(0, 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_panel.add_child(lbl)

	# Scrollable slot container
	_sell_slots_root          = Control.new()
	_sell_slots_root.position = Vector2(0, 26)
	_sell_slots_root.size     = Vector2(win_w, panel_h - 26)
	_sell_panel.add_child(_sell_slots_root)

func _on_sell_toggle() -> void:
	if _sell_panel == null:
		return
	_sell_panel.visible = not _sell_panel.visible
	if _sell_panel.visible:
		_sell_btn.text = "← BACK"
		_sell_btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		_rebuild_sell_slots()
	else:
		_sell_btn.text = "SELL ITEMS"
		_sell_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))

func _rebuild_sell_slots() -> void:
	if _sell_slots_root == null:
		return
	for ch in _sell_slots_root.get_children():
		ch.queue_free()

	if not is_instance_valid(_player):
		return

	var inv : Array = _player.get("inventory") if _player.get("inventory") != null else []

	if inv.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		empty_lbl.text = "— inventory is empty —"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size     = Vector2(_sell_slots_root.size.x, 30)
		empty_lbl.position = Vector2(0, 20)
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_slots_root.add_child(empty_lbl)
		return

	const ROW_H   : float = 52.0
	const ICON_SZ : float = 36.0
	var icon_script = load("res://Scripts/BossItemIcon.gd")
	var win_w = _sell_slots_root.size.x

	for i in inv.size():
		var item       = inv[i]
		var row_y      = i * ROW_H
		var sell_price = int(item.get("cost", 0) * 0.5)

		# Row background (subtle stripe on odd rows)
		if i % 2 == 1:
			var stripe       = ColorRect.new()
			stripe.position  = Vector2(0, row_y)
			stripe.size      = Vector2(win_w, ROW_H)
			stripe.color     = Color(1, 1, 1, 0.025)
			stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sell_slots_root.add_child(stripe)

		# Icon bg
		var icon_bg      = Panel.new()
		icon_bg.position = Vector2(10, row_y + (ROW_H - ICON_SZ) * 0.5)
		icon_bg.size     = Vector2(ICON_SZ, ICON_SZ)
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ibs          = StyleBoxFlat.new()
		ibs.bg_color     = Color(0.08, 0.10, 0.18, 0.90)
		ibs.border_color = RARITY_COLOR.get(item.get("rarity", "grey"), Color(0.4, 0.4, 0.4)) * 0.6
		ibs.set_border_width_all(1)
		ibs.set_corner_radius_all(3)
		icon_bg.add_theme_stylebox_override("panel", ibs)
		_sell_slots_root.add_child(icon_bg)

		# Item icon
		var icon = Control.new()
		icon.set_script(icon_script)
		icon.size         = Vector2(ICON_SZ, ICON_SZ)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set("item_data", item)
		icon_bg.add_child(icon)

		# Name
		var name_lbl = Label.new()
		name_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		name_lbl.text = item.get("name", "Unknown")
		if item.get("equipped", false):
			name_lbl.text += "  [EQ]"
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", RARITY_COLOR.get(item.get("rarity", "grey"), Color.WHITE))
		name_lbl.position    = Vector2(54, row_y + 8)
		name_lbl.size        = Vector2(220, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_slots_root.add_child(name_lbl)

		# Sell price
		var price_lbl = Label.new()
		price_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		price_lbl.text = "sell: %d ¢" % sell_price
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22))
		price_lbl.position    = Vector2(54, row_y + 28)
		price_lbl.size        = Vector2(180, 16)
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_slots_root.add_child(price_lbl)

		# SELL button
		var btn       = Button.new()
		btn.text      = "SELL"
		btn.size      = Vector2(56, 26)
		btn.position  = Vector2(win_w - 70, row_y + (ROW_H - 26) * 0.5)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(1.0, 0.70, 0.20))
		var bsty          = StyleBoxFlat.new()
		bsty.bg_color     = Color(0.14, 0.08, 0.02, 0.90)
		bsty.border_color = Color(1.0, 0.60, 0.15, 0.80)
		bsty.set_border_width_all(1)
		bsty.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", bsty)
		btn.pressed.connect(_on_sell_item.bind(i))
		_sell_slots_root.add_child(btn)

		# Row divider
		if i < inv.size() - 1:
			var div       = ColorRect.new()
			div.size      = Vector2(win_w - 20, 1)
			div.position  = Vector2(10, row_y + ROW_H - 1)
			div.color     = Color(0.80, 0.55, 0.10, 0.18)
			div.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sell_slots_root.add_child(div)

func _on_sell_item(idx: int) -> void:
	if not is_instance_valid(_player):
		return
	var inv = _player.get("inventory") as Array
	if inv == null or idx >= inv.size():
		return
	var item       = inv[idx]
	var sell_price = int(item.get("cost", 0) * 0.5)
	# Unequip first so stats are removed
	if item.get("equipped", false):
		_player.call("toggle_equip", idx)
	# Remove from inventory
	inv.remove_at(idx)
	# Add credits (via add_credits so floating text fires)
	if _player.has_method("add_credits"):
		_player.call("add_credits", sell_price)
	else:
		var creds = _player.get("credits") as int
		_player.set("credits", (creds if creds != null else 0) + sell_price)
	_rebuild_sell_slots()

func _build_item_row(idx: int, row_y: float, win_w: float, icon_sz: float, row_h: float) -> void:
	var item    = SHOP_ITEMS[idx]
	var pad     = 10.0
	var icon_x  = pad
	var icon_y  = row_y + (row_h - icon_sz) * 0.5

	# Icon background slot
	var icon_bg       = Panel.new()
	icon_bg.position  = Vector2(icon_x, icon_y)
	icon_bg.size      = Vector2(icon_sz, icon_sz)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ibs           = StyleBoxFlat.new()
	ibs.bg_color      = Color(0.08, 0.10, 0.18, 0.92)
	ibs.border_color  = RARITY_COLOR.get(item.rarity, Color(0.4, 0.4, 0.4)) * 0.6
	ibs.set_border_width_all(1)
	ibs.set_corner_radius_all(3)
	icon_bg.add_theme_stylebox_override("panel", ibs)
	_panel.add_child(icon_bg)

	# Item icon (BossItemIcon Control)
	var icon_script = load("res://Scripts/BossItemIcon.gd")
	var icon        = Control.new()
	icon.set_script(icon_script)
	icon.size         = Vector2(icon_sz, icon_sz)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set("item_data", item)
	icon_bg.add_child(icon)

	# Item name
	var name_lbl = Label.new()
	name_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	name_lbl.text = item.name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", RARITY_COLOR.get(item.rarity, Color.WHITE))
	name_lbl.position    = Vector2(icon_x + icon_sz + 10, row_y + 8)
	name_lbl.size        = Vector2(200, 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(name_lbl)

	# Rarity badge
	var rarity_lbl = Label.new()
	rarity_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	rarity_lbl.text = "[%s]" % item.rarity.to_upper()
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.add_theme_color_override("font_color", RARITY_COLOR.get(item.rarity, Color.WHITE) * 0.7)
	rarity_lbl.position     = Vector2(icon_x + icon_sz + 12, row_y + 26)
	rarity_lbl.size         = Vector2(100, 14)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rarity_lbl)

	# Stats
	var stat_lbl = Label.new()
	stat_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	stat_lbl.text = item.desc
	stat_lbl.add_theme_font_size_override("font_size", 11)
	stat_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
	stat_lbl.position    = Vector2(icon_x + icon_sz + 10, row_y + 40)
	stat_lbl.size        = Vector2(200, 18)
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stat_lbl)

	# Cost label
	var cost_lbl = Label.new()
	cost_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	cost_lbl.name = "Cost_%d" % idx
	cost_lbl.text = "%d ¢" % item.cost
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.position    = Vector2(win_w - 160, row_y + (row_h - 20) * 0.5)
	cost_lbl.size        = Vector2(90, 20)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(cost_lbl)

	# BUY button
	var btn        = Button.new()
	btn.name       = "Buy_%d" % idx
	btn.text       = "BUY"
	btn.size       = Vector2(56, 28)
	btn.position   = Vector2(win_w - 70, row_y + (row_h - 28) * 0.5)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.30, 0.90, 1.0))
	var bsty       = StyleBoxFlat.new()
	bsty.bg_color  = Color(0.04, 0.12, 0.18, 0.90)
	bsty.border_color = Color(0.28, 0.75, 1.0, 0.80)
	bsty.set_border_width_all(1)
	bsty.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bsty)
	btn.pressed.connect(_on_buy.bind(idx))
	_panel.add_child(btn)

func _on_buy(idx: int) -> void:
	if not is_instance_valid(_player):
		return
	var item   = SHOP_ITEMS[idx]
	var creds  = _player.get("credits") as int
	if creds == null or creds < item.cost:
		_flash_btn(idx, false)
		return
	# Class restriction check
	var allowed = item.get("allowed_class", "")
	if allowed != "":
		var pclass = _player.get("character_class") as String
		if pclass == null or pclass != allowed:
			_flash_btn(idx, false)
			_show_class_error(idx, allowed)
			return
	# Deduct credits
	_player.set("credits", creds - item.cost)
	# Add to inventory
	if _player.has_method("add_item_to_inventory"):
		_player.call("add_item_to_inventory", item)
	_flash_btn(idx, true)

func _flash_btn(idx: int, success: bool) -> void:
	var btn = _panel.get_node_or_null("Buy_%d" % idx) as Button
	if btn == null:
		return
	var orig_col = Color(0.30, 0.90, 1.0) if success else Color(1.0, 0.30, 0.30)
	btn.add_theme_color_override("font_color", orig_col)
	# Reset after 0.6s using a timer
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(btn):
			btn.add_theme_color_override("font_color", Color(0.30, 0.90, 1.0))
	)

func _show_class_error(idx: int, required_class: String) -> void:
	# Show a small "wrong class" label above the buy button that fades out
	var btn = _panel.get_node_or_null("Buy_%d" % idx) as Button
	if btn == null:
		return
	var err_key = "ClassErr_%d" % idx
	if _panel.get_node_or_null(err_key) != null:
		return  # already showing
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.name = err_key
	lbl.text = "%s only!" % required_class.capitalize()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	lbl.position = btn.position + Vector2(-28, -18)
	lbl.size     = Vector2(110, 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lbl)
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player) or _credit_lbl == null:
		return
	var c = _player.get("credits")
	_credit_lbl.text = "Credits:  %d ¢" % (c if c != null else 0)

# Helper: returns a GDScript object that draws scanlines
# (Inline script object trick — avoids a separate file for a tiny visual)
func _on_panel_gui_input(event: InputEvent) -> void:
	const HDR_DRAG : float = 54.0   # matches HDR_H — drag from header area only
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y <= HDR_DRAG:
			_drag_active = true
			_drag_offset = event.position
		else:
			_drag_active = false
	elif event is InputEventMouseMotion and _drag_active:
		var new_pos = _panel.position + event.relative
		var vp      = get_viewport().get_visible_rect().size
		new_pos.x   = clampf(new_pos.x, 0.0, vp.x - _panel.size.x)
		new_pos.y   = clampf(new_pos.y, 0.0, vp.y - _panel.size.y)
		_panel.position = new_pos

func _scanline_script(w: float, h: float) -> GDScript:
	var src = """
extends Control
var _w : float = %f
var _h : float = %f
func _draw() -> void:
\tvar steps = int(_h / 6.0)
\tfor i in steps:
\t\tdraw_rect(Rect2(0, i * 6, _w, 1.5), Color(1, 1, 1, 0.016))
""" % [w, h]
	var scr = GDScript.new()
	scr.source_code = src
	scr.reload()
	return scr
