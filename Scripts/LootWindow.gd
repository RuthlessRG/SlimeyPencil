extends CanvasLayer

# ============================================================
#  LootWindow.gd — miniSWG
#  Small loot window opened when player presses F near a LootBag.
#  Contains a tier-1 item (50/50 knife or rifle) + 25 credits.
#  Right-click item slot to loot.
#  All party members receive the same reward via relay.
# ============================================================

const W : float = 260.0
const H : float = 180.0

const CREDITS_REWARD : int = 25

const LOOT_KNIFE = {
	"id": "knife_grey", "name": "Iron Knife", "rarity": "grey", "type": "knife",
	"cost": 10, "attr_str": 2, "attr_agi": 1, "attr_int": 0, "attr_spi": 0,
	"desc": "A worn iron knife, but still sharp."
}
const LOOT_RIFLE = {
	"id": "rifle_silver", "name": "Synth Rifle", "rarity": "silver", "type": "rifle",
	"cost": 20, "attr_str": 0, "attr_agi": 2, "attr_int": 0, "attr_spi": 1,
	"desc": "A synthetic pulse rifle."
}

var _player    : Node  = null
var _bag       : Node  = null
var _item      : Dictionary = {}
var _looted    : bool  = false
var _win_panel : Panel = null
var _drag      : bool  = false

# Rarity colors (matching BossShopWindow style)
const RARITY_COL = {
	"grey":   Color(0.72, 0.72, 0.72),
	"white":  Color(1.00, 1.00, 1.00),
	"silver": Color(0.70, 0.80, 0.95),
	"gold":   Color(0.95, 0.82, 0.20),
}

func init(player: Node, bag: Node) -> void:
	layer   = 20
	_player = player
	_bag    = bag
	_item   = LOOT_KNIFE.duplicate() if randf() < 0.5 else LOOT_RIFLE.duplicate()
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size
	var wx = vp.x * 0.5 - W * 0.5
	var wy = vp.y * 0.5 - H * 0.5

	_win_panel = Panel.new()
	_win_panel.position     = Vector2(wx, wy)
	_win_panel.size         = Vector2(W, H)
	_win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sty = StyleBoxFlat.new()
	sty.bg_color     = Color(0.04, 0.04, 0.06, 0.96)
	sty.border_color = Color(0.82, 0.55, 0.08, 0.90)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(4)
	_win_panel.add_theme_stylebox_override("panel", sty)
	add_child(_win_panel)

	# ── Title bar ──────────────────────────────────────────────
	var title_bar = Panel.new()
	title_bar.position     = Vector2(0, 0)
	title_bar.size         = Vector2(W, 30)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var tsty = StyleBoxFlat.new()
	tsty.bg_color          = Color(0.10, 0.06, 0.02, 1.0)
	tsty.border_color      = Color(0.82, 0.55, 0.08, 0.70)
	tsty.border_width_bottom = 1
	title_bar.add_theme_stylebox_override("panel", tsty)
	_win_panel.add_child(title_bar)
	title_bar.gui_input.connect(_on_title_drag)

	var title_lbl = Label.new()
	title_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title_lbl.text = "≡  LOOT"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	title_lbl.position     = Vector2(10, 7)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text     = "×"
	close_btn.position = Vector2(W - 28, 4)
	close_btn.size     = Vector2(22, 22)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.90, 0.40, 0.20))
	var bsty = StyleBoxFlat.new()
	bsty.bg_color     = Color(0.12, 0.06, 0.02, 0.85)
	bsty.border_color = Color(0.70, 0.30, 0.10, 0.60)
	bsty.set_border_width_all(1)
	bsty.set_corner_radius_all(2)
	close_btn.add_theme_stylebox_override("normal",  bsty)
	close_btn.add_theme_stylebox_override("hover",   bsty)
	close_btn.add_theme_stylebox_override("pressed", bsty)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(queue_free)
	title_bar.add_child(close_btn)

	# ── Header hint ────────────────────────────────────────────
	var hint = Label.new()
	hint.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hint.text = "Right-click item to loot"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	hint.position             = Vector2(0, 33)
	hint.size                 = Vector2(W, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(hint)

	# ── Item slot ──────────────────────────────────────────────
	var PAD  = 14.0
	var y    = 52.0
	var slot = Panel.new()
	slot.position     = Vector2(PAD, y)
	slot.size         = Vector2(W - PAD * 2, 64)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var ssty = StyleBoxFlat.new()
	ssty.bg_color     = Color(0.07, 0.05, 0.03, 0.92)
	ssty.border_color = Color(0.50, 0.36, 0.08, 0.60)
	ssty.set_border_width_all(1)
	ssty.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", ssty)
	_win_panel.add_child(slot)
	slot.gui_input.connect(_on_slot_input)

	# Icon box
	var icon_box = Panel.new()
	icon_box.position     = Vector2(6, 6)
	icon_box.size         = Vector2(52, 52)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isty = StyleBoxFlat.new()
	var rar_col = RARITY_COL.get(_item.get("rarity", "grey"), Color(0.7, 0.7, 0.7))
	isty.bg_color     = Color(0.10, 0.08, 0.05, 0.95)
	isty.border_color = rar_col
	isty.set_border_width_all(2)
	isty.set_corner_radius_all(3)
	icon_box.add_theme_stylebox_override("panel", isty)
	slot.add_child(icon_box)

	# Icon letter
	var icon_lbl = Label.new()
	icon_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	var itype = _item.get("type", "knife")
	icon_lbl.text = "K" if itype == "knife" else "R"
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.add_theme_color_override("font_color", rar_col)
	icon_lbl.position             = Vector2(0, 8)
	icon_lbl.size                 = Vector2(52, 36)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_lbl)

	# Item name
	var name_lbl = Label.new()
	name_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	name_lbl.text = _item.get("name", "Item")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", rar_col)
	name_lbl.position     = Vector2(64, 6)
	name_lbl.size         = Vector2(W - PAD * 2 - 70, 18)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_lbl)

	# Item rarity
	var rar_lbl = Label.new()
	rar_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	rar_lbl.text = _item.get("rarity", "grey").capitalize()
	rar_lbl.add_theme_font_size_override("font_size", 9)
	rar_lbl.add_theme_color_override("font_color", rar_col.darkened(0.2))
	rar_lbl.position     = Vector2(64, 23)
	rar_lbl.size         = Vector2(100, 14)
	rar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(rar_lbl)

	# Item desc
	var desc_lbl = Label.new()
	desc_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	desc_lbl.text = _item.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
	desc_lbl.position     = Vector2(64, 37)
	desc_lbl.size         = Vector2(W - PAD * 2 - 70, 18)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(desc_lbl)

	y += 70.0

	# ── Credits row ────────────────────────────────────────────
	var div = Control.new()
	div.set_script(_hline_script(W - PAD * 2))
	div.position     = Vector2(PAD, y)
	div.size         = Vector2(W - PAD * 2, 2)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(div)
	y += 10.0

	var cr_lbl = Label.new()
	cr_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	cr_lbl.text = "Credits:"
	cr_lbl.add_theme_font_size_override("font_size", 11)
	cr_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	cr_lbl.position     = Vector2(PAD, y)
	cr_lbl.size         = Vector2(110, 18)
	cr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(cr_lbl)

	var cr_val = Label.new()
	cr_val.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	cr_val.text = "%d CR" % CREDITS_REWARD
	cr_val.add_theme_font_size_override("font_size", 11)
	cr_val.add_theme_color_override("font_color", Color(0.95, 0.85, 0.20))
	cr_val.position     = Vector2(PAD + 110, y)
	cr_val.size         = Vector2(W - PAD * 2 - 110, 18)
	cr_val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(cr_val)

	y += 26.0

	# ── Loot All button ────────────────────────────────────────
	var loot_btn = Button.new()
	loot_btn.text     = "LOOT ALL"
	loot_btn.position = Vector2(W * 0.5 - 50, y)
	loot_btn.size     = Vector2(100, 22)
	loot_btn.add_theme_font_size_override("font_size", 10)
	var lsty = StyleBoxFlat.new()
	lsty.bg_color     = Color(0.08, 0.20, 0.04, 0.90)
	lsty.border_color = Color(0.50, 0.80, 0.12, 0.75)
	lsty.set_border_width_all(1)
	lsty.set_corner_radius_all(2)
	loot_btn.add_theme_stylebox_override("normal",  lsty)
	loot_btn.add_theme_stylebox_override("hover",   lsty)
	loot_btn.add_theme_stylebox_override("pressed", lsty)
	loot_btn.add_theme_color_override("font_color", Color(0.55, 1.0, 0.20))
	loot_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	loot_btn.pressed.connect(_do_loot)
	_win_panel.add_child(loot_btn)

func _on_slot_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed): return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_do_loot()

func _do_loot() -> void:
	if _looted: return
	_looted = true

	# Award to local player
	if is_instance_valid(_player):
		_player.call("add_item_to_inventory", _item.duplicate())
		var cur_credits = int(_player.get("credits")) if _player.get("credits") != null else 0
		_player.set("credits", cur_credits + CREDITS_REWARD)

	# Share with party
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("share_loot_with_party"):
		arena.call("share_loot_with_party", _item.duplicate(), CREDITS_REWARD)

	# Remove the bag from the world
	if is_instance_valid(_bag):
		_bag.queue_free()

	queue_free()

func _on_title_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		_win_panel.position += event.relative

func _hline_script(w: float) -> GDScript:
	var src = """extends Control
func _draw():
\tdraw_line(Vector2(0,1), Vector2(%f, 1), Color(0.60, 0.42, 0.08, 0.55), 1.0)
""" % w
	var s = GDScript.new(); s.source_code = src; s.reload(); return s
