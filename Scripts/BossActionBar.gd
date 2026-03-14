extends CanvasLayer

# ============================================================
#  BossActionBar.gd — Dreadmyst-style 3-row action bar
#  Row 1 (top):    Ctrl+1..8  — reserved for future use
#  Row 2 (middle): Shift+1..8 — reserved for future use
#  Row 3 (bottom): 1..8       — primary skill bar (functional)
#  Drag skills from BossSkillWindow onto any slot.
# ============================================================

const COLS       : int   = 8
const ROWS       : int   = 3
const SLOT_COUNT : int   = 8      # functional main row slots
const SLOT_SZ    : float = 44.0
const SLOT_PAD   : float = 4.0
const ROW_PAD    : float = 3.0
const BAR_PAD    : float = 6.0

var _player      : Node          = null
var _slots       : Array         = []   # Array of skill dicts or null (main row only)
var _cooldowns   : Array         = []   # cooldown per main-row slot
var _bar_panel   : Panel         = null
var _slot_panels : Array         = []   # main-row slot panels (index 0..7)
var _deco_panels : Array         = []   # decorative upper-row panels
var _drag_active : bool          = false
var _drag_offset : Vector2       = Vector2.ZERO

# Ghost drag state
var _dragging_from_slot : int    = -1
var _ghost_skill        : Dictionary = {}
var _ghost_visible      : bool       = false
var _ghost_panel        : Panel      = null
var _mouse_was_held     : bool       = false

# Row labels for keybind display
const ROW_LABELS : Array = [
	["C+1","C+2","C+3","C+4","C+5","C+6","C+7","C+8"],
	["S+1","S+2","S+3","S+4","S+5","S+6","S+7","S+8"],
	["1","2","3","4","5","6","7","8"],
]

func init(player: Node) -> void:
	layer   = 12
	_player = player
	_slots.resize(SLOT_COUNT)
	_cooldowns.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_slots[i]     = null
		_cooldowns[i] = 0.0
	_build_ui()

func _build_ui() -> void:
	var vp    = get_viewport().get_visible_rect().size
	var font  = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	var bar_w = COLS * (SLOT_SZ + SLOT_PAD) - SLOT_PAD + BAR_PAD * 2.0
	var bar_h = ROWS * (SLOT_SZ + ROW_PAD) - ROW_PAD + BAR_PAD * 2.0
	var bar_x = vp.x * 0.5 - bar_w * 0.5
	var bar_y = vp.y - bar_h - 10.0

	# ── Bar panel (dark fantasy background) ────────────────────
	_bar_panel          = Panel.new()
	_bar_panel.position = Vector2(bar_x, bar_y)
	_bar_panel.size     = Vector2(bar_w, bar_h)
	var sty             = StyleBoxFlat.new()
	sty.bg_color        = Color(0.04, 0.04, 0.03, 0.88)
	sty.border_color    = Color(0.30, 0.25, 0.15, 0.85)
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(2)
	sty.shadow_color    = Color(0.0, 0.0, 0.0, 0.40)
	sty.shadow_size     = 4
	_bar_panel.add_theme_stylebox_override("panel", sty)
	add_child(_bar_panel)
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar_panel.gui_input.connect(_on_bar_gui_input)

	# ── Build all 3 rows ───────────────────────────────────────
	for row in ROWS:
		var row_y = BAR_PAD + row * (SLOT_SZ + ROW_PAD)
		for col in COLS:
			var slot_x = BAR_PAD + col * (SLOT_SZ + SLOT_PAD)
			var is_main = (row == 2)  # bottom row is functional

			var slot_panel          = Panel.new()
			slot_panel.position     = Vector2(slot_x, row_y)
			slot_panel.size         = Vector2(SLOT_SZ, SLOT_SZ)
			slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP if is_main else Control.MOUSE_FILTER_IGNORE
			var ssty                = StyleBoxFlat.new()
			if is_main:
				ssty.bg_color       = Color(0.06, 0.06, 0.05, 0.92)
				ssty.border_color   = Color(0.40, 0.35, 0.22, 0.75)
			else:
				ssty.bg_color       = Color(0.05, 0.05, 0.04, 0.80)
				ssty.border_color   = Color(0.30, 0.26, 0.16, 0.55)
			ssty.set_border_width_all(1)
			ssty.set_corner_radius_all(2)
			slot_panel.add_theme_stylebox_override("panel", ssty)
			_bar_panel.add_child(slot_panel)

			# Keybind label (top-left corner)
			var key_lbl = Label.new()
			key_lbl.add_theme_font_override("font", font)
			key_lbl.name = "KeyLbl"
			key_lbl.text = ROW_LABELS[row][col]
			key_lbl.add_theme_font_size_override("font_size", 7)
			key_lbl.add_theme_color_override("font_color", Color(0.60, 0.55, 0.40, 0.70))
			key_lbl.position     = Vector2(2, 1)
			key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_panel.add_child(key_lbl)

			if is_main:
				var si = col
				_slot_panels.append(slot_panel)
				slot_panel.gui_input.connect(_on_slot_gui_input.bind(si))

				# Tooltip registration
				slot_panel.mouse_entered.connect(func():
					if not is_instance_valid(_player): return
					var tm = _player.get_node_or_null("TooltipManager")
					if tm == null or not tm.has_method("watch"): return
					if slot_panel.has_meta("tip_registered"): return
					slot_panel.set_meta("tip_registered", true)
					var slots_ref = _slots
					tm.call("watch", slot_panel, func():
						if si < slots_ref.size() and slots_ref[si] != null:
							return tm.get_script().data_for_skill(slots_ref[si])
						return {})
					tm.call("_on_enter", slot_panel, func():
						if si < slots_ref.size() and slots_ref[si] != null:
							return tm.get_script().data_for_skill(slots_ref[si])
						return {}))

				# Skill icon placeholder
				var icon_ctrl = Control.new()
				icon_ctrl.name         = "Icon"
				icon_ctrl.size         = Vector2(SLOT_SZ, SLOT_SZ)
				icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_panel.add_child(icon_ctrl)

				# Cooldown overlay
				var cd_ctrl = Control.new()
				cd_ctrl.name         = "CooldownOverlay"
				cd_ctrl.size         = Vector2(SLOT_SZ, SLOT_SZ)
				cd_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot_panel.add_child(cd_ctrl)
			else:
				_deco_panels.append(slot_panel)

	# Top accent line
	var accent = ColorRect.new()
	accent.color = Color(0.50, 0.40, 0.20, 0.50)
	accent.size  = Vector2(bar_w - 4, 1)
	accent.position = Vector2(2, 2)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_panel.add_child(accent)

	# Ghost drag panel
	_ghost_panel          = Panel.new()
	_ghost_panel.size     = Vector2(SLOT_SZ, SLOT_SZ)
	_ghost_panel.visible  = false
	_ghost_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsty              = StyleBoxFlat.new()
	gsty.bg_color         = Color(0.06, 0.06, 0.05, 0.75)
	gsty.border_color     = Color(0.70, 0.55, 0.25, 0.90)
	gsty.set_border_width_all(1)
	gsty.set_corner_radius_all(2)
	_ghost_panel.add_theme_stylebox_override("panel", gsty)
	add_child(_ghost_panel)

func _process(delta: float) -> void:
	for i in SLOT_COUNT:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			_refresh_slot_overlay(i)
	if _ghost_visible:
		var mp = get_viewport().get_mouse_position()
		_ghost_panel.position = mp - Vector2(SLOT_SZ * 0.5, SLOT_SZ * 0.5)
		var lmb_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if _mouse_was_held and not lmb_held:
			_on_ghost_drop(mp)
		_mouse_was_held = lmb_held

func _refresh_slot(idx: int) -> void:
	if idx < 0 or idx >= _slot_panels.size(): return
	var slot_panel = _slot_panels[idx]
	var old_icon = slot_panel.get_node_or_null("Icon")
	if old_icon:
		slot_panel.remove_child(old_icon)
		old_icon.free()
	var skill     = _slots[idx]
	var icon_ctrl = Control.new()
	icon_ctrl.name         = "Icon"
	icon_ctrl.size         = Vector2(SLOT_SZ, SLOT_SZ)
	icon_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if skill != null:
		icon_ctrl.set_script(_slot_icon_script(skill.get("icon", "")))
	slot_panel.add_child(icon_ctrl)
	var ov = slot_panel.get_node_or_null("CooldownOverlay")
	if ov:
		slot_panel.move_child(icon_ctrl, ov.get_index())

func _refresh_slot_overlay(idx: int) -> void:
	if idx < 0 or idx >= _slot_panels.size(): return
	var slot_panel = _slot_panels[idx]
	var ov         = slot_panel.get_node_or_null("CooldownOverlay")
	if ov == null: return
	var skill = _slots[idx]
	if skill == null or _cooldowns[idx] <= 0.0:
		ov.set_script(null)
		return
	var cd_total = skill.get("cooldown", 1.0)
	var frac     = _cooldowns[idx] / cd_total if cd_total > 0.0 else 0.0
	var cd_txt   = "%ds" % int(ceil(_cooldowns[idx]))
	ov.set_script(_cooldown_overlay_script(frac, cd_txt))

func try_drop_skill(skill: Dictionary, mouse_pos: Vector2, from_slot: int = -1) -> bool:
	for i in SLOT_COUNT:
		var sp      = _slot_panels[i]
		var sp_rect = Rect2(sp.global_position, sp.size)
		if sp_rect.has_point(mouse_pos):
			var plevel = (_player.get("level") as int) if _player else 1
			if plevel < skill.get("req_level", 1):
				_show_level_noob()
				return false
			if from_slot >= 0 and from_slot != i:
				_slots[from_slot]     = null
				_cooldowns[from_slot] = 0.0
				_refresh_slot(from_slot)
			_slots[i]     = skill
			_cooldowns[i] = 0.0
			_refresh_slot(i)
			return true
	if from_slot >= 0:
		_slots[from_slot]     = null
		_cooldowns[from_slot] = 0.0
		_refresh_slot(from_slot)
	return false

func _update_ghost_icon() -> void:
	for ch in _ghost_panel.get_children(): ch.queue_free()
	var icon = Control.new()
	icon.size         = Vector2(SLOT_SZ, SLOT_SZ)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_script(_slot_icon_script(_ghost_skill.get("icon", "")))
	_ghost_panel.add_child(icon)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _activate_slot(0)
			KEY_2: _activate_slot(1)
			KEY_3: _activate_slot(2)
			KEY_4: _activate_slot(3)
			KEY_5: _activate_slot(4)
			KEY_6: _activate_slot(5)
			KEY_7: _activate_slot(6)
			KEY_8: _activate_slot(7)

func _on_ghost_drop(mouse_pos: Vector2) -> void:
	_ghost_panel.visible = false
	_ghost_visible       = false
	var from             = _dragging_from_slot
	_dragging_from_slot  = -1
	try_drop_skill(_ghost_skill, mouse_pos, from)
	_ghost_skill         = {}

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _slots[slot_idx] != null:
			_ghost_skill        = _slots[slot_idx]
			_ghost_visible      = true
			_dragging_from_slot = slot_idx
			_ghost_panel.position = event.global_position - Vector2(SLOT_SZ * 0.5, SLOT_SZ * 0.5)
			_ghost_panel.visible  = true
			_mouse_was_held      = true
			_update_ghost_icon()

func _on_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (
			event.button_index == MOUSE_BUTTON_LEFT or
			event.button_index == MOUSE_BUTTON_RIGHT):
		if event.pressed:
			_drag_active = true
			_drag_offset = event.position
		else:
			_drag_active = false
	elif event is InputEventMouseMotion and _drag_active:
		var new_pos = _bar_panel.position + event.relative
		var vp      = get_viewport().get_visible_rect().size
		new_pos.x   = clampf(new_pos.x, 0.0, vp.x - _bar_panel.size.x)
		new_pos.y   = clampf(new_pos.y, 0.0, vp.y - _bar_panel.size.y)
		_bar_panel.position = new_pos

func _activate_slot(idx: int) -> void:
	if _player == null or not is_instance_valid(_player): return
	if idx >= _slots.size() or _slots[idx] == null: return
	if _cooldowns[idx] > 0.0: return
	var skill = _slots[idx]
	if _player.has_method("activate_skill"):
		_player.call("activate_skill", skill.get("id", ""))
		_cooldowns[idx] = skill.get("cooldown", 0.0)
		_refresh_slot_overlay(idx)

func _show_level_noob() -> void:
	var vp  = get_viewport().get_visible_rect().size
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = "level up noob"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(320, 36)
	lbl.position = Vector2(vp.x * 0.5 - 160.0, vp.y * 0.5 - 80.0)
	add_child(lbl)
	lbl.set_script(_noob_label_script())

# ── Icon scripts ────────────────────────────────────────────────
func _empty_slot_script() -> GDScript:
	var src = """
extends Control
func _draw():
\tpass
"""
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func _slot_icon_script(icon_id: String) -> GDScript:
	var src = """
extends Control
var _t : float = 0.0
func _process(d): _t += d; queue_redraw()
func _draw():
\tvar cx = size.x * 0.5; var cy = size.y * 0.5; var _c = Vector2(cx, cy)
\t_draw_%s(cx, cy)
func _draw_sprint(cx, cy):
\tvar c = Vector2(cx, cy); var p = 0.6 + sin(_t * 4.0) * 0.2
\tdraw_circle(c, 16.0, Color(0.10, 0.40, 0.90, 0.25))
\tfor i in 5:
\t\tvar frac = float(i)/5.0; var x = cx-10.0+frac*20.0
\t\tvar spd = 1.0 - frac*0.35; var yoff = sin(_t*6.0*spd+frac*2.1)*3.0
\t\tdraw_line(Vector2(x,cy+yoff-6),Vector2(x+5.0*spd,cy+yoff+6),Color(0.35,0.80,1.00,p),1.8)
\tdraw_colored_polygon(PackedVector2Array([c+Vector2(5,-4),c+Vector2(12,0),c+Vector2(5,4)]),Color(1.0,1.0,1.0,p))
func _draw_sensu(cx, cy):
\tvar c = Vector2(cx, cy); var p = 0.7 + sin(_t * 2.5) * 0.18
\tdraw_circle(c, 16.0, Color(0.05, 0.30, 0.10, 0.30))
\tvar pts = PackedVector2Array()
\tfor i in 12:
\t\tvar a = float(i)/12.0*6.2832; var r = 8.0+sin(a*2.0+_t*1.8)*2.5
\t\tpts.append(c+Vector2(cos(a)*r,sin(a)*r))
\tdraw_colored_polygon(pts,Color(0.15,0.75,0.25,p*0.55))
\tdraw_circle(c,4.5,Color(0.55,1.0,0.55,p)); draw_circle(c,2.5,Color(1.0,1.0,1.0,p*0.70))
func _draw_triple(cx, cy):
\tvar c = Vector2(cx, cy); var p = 0.65+sin(_t*5.0)*0.20
\tdraw_circle(c,16.0,Color(0.50,0.10,0.10,0.25))
\tvar offsets = [Vector2(-8,0),Vector2(0,0),Vector2(8,0)]
\tfor i in 3:
\t\tvar oc=c+offsets[i]; var tip=oc+Vector2(0,-10); var bl=oc+Vector2(-3,3); var br=oc+Vector2(3,3)
\t\tdraw_colored_polygon(PackedVector2Array([tip,bl,br]),Color(1.0,0.35,0.35,p))
\t\tdraw_circle(oc+Vector2(0,4),2.0,Color(1.0,0.60,0.20,p))
""" % icon_id
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func _cooldown_overlay_script(frac: float, cd_txt: String) -> GDScript:
	var src = """
extends Control
var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
func _draw():
\tvar sz = size.x
\tdraw_rect(Rect2(0, 0, sz, sz), Color(0.0, 0.0, 0.0, %f * 0.65))
\tvar font = _roboto
\tvar tw = font.get_string_size("%s", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
\tdraw_string(font, Vector2(sz*0.5 - tw*0.5, sz*0.5 + 4), "%s",
\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.90, 0.30, 0.95))
""" % [frac, cd_txt, cd_txt]
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func _noob_label_script() -> GDScript:
	var src = """
extends Label
var _t : float = 0.0
func _process(delta):
\t_t += delta
\tposition.y -= 28.0 * delta
\tvar alpha = clampf(1.0 - (_t - 0.6) / 0.8, 0.0, 1.0)
\tadd_theme_color_override("font_color", Color(1.0, 0.15, 0.15, alpha))
\tif _t >= 1.4:
\t\tqueue_free()
"""
	var s = GDScript.new(); s.source_code = src; s.reload(); return s
