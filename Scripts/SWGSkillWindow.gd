extends CanvasLayer

# ============================================================
#  SWGSkillWindow.gd — Kodan-style SWG Profession Calculator
#  Press K to toggle. Click any profession name to view its tree.
# ============================================================

var _player : Node = null
var _panel  : Panel = null
var _nav_panel : Panel = null  # Side panel with profession list
var _roboto : Font = null
var _bold   : Font = null
var _tooltip_panel : Panel = null

const NAV_W : float = 130.0  # Width of side nav panel

const WIN_W : float = 560.0
const WIN_H : float = 420.0
const BOX_W : float = 125.0
const BOX_H : float = 38.0
const BOX_PAD : float = 2.0

var _current_prof_id : String = "scrapper"
var _dragging : bool = false
var _dirty : bool = true

# Profession categories for the top nav
const BASIC_PROFS = ["scrapper", "marksman", "medic"]
const ELITE_PROFS = ["teras_kasi", "fencer", "swordsman", "pikeman", "pistoleer", "carbineer", "rifleman", "doctor", "combat_medic", "commando", "bounty_hunter"]
const FORCE_PROFS = ["forcesensitive"]

func init(player: Node) -> void:
	layer = 15
	_player = player
	_roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	_bold = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf")
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size
	var total_w = NAV_W + WIN_W

	# Side nav panel (profession list)
	_nav_panel = Panel.new()
	_nav_panel.position = Vector2(vp.x * 0.5 - total_w * 0.5, vp.y * 0.5 - WIN_H * 0.5)
	_nav_panel.size = Vector2(NAV_W, WIN_H)
	var nav_sty = StyleBoxFlat.new()
	nav_sty.bg_color = Color(0.03, 0.05, 0.10, 0.97)
	nav_sty.border_color = Color(0.12, 0.38, 0.55, 0.75)
	nav_sty.set_border_width_all(1)
	nav_sty.set_corner_radius_all(2)
	_nav_panel.add_theme_stylebox_override("panel", nav_sty)
	_nav_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_nav_panel.gui_input.connect(_on_panel_input)
	add_child(_nav_panel)
	_build_nav_list()

	# Main tree panel (to the right of nav)
	_panel = Panel.new()
	_panel.position = Vector2(vp.x * 0.5 - total_w * 0.5 + NAV_W, vp.y * 0.5 - WIN_H * 0.5)
	_panel.size = Vector2(WIN_W, WIN_H)
	_panel.clip_contents = true
	var sty = StyleBoxFlat.new()
	sty.bg_color = Color(0.04, 0.06, 0.12, 0.97)
	sty.border_color = Color(0.15, 0.45, 0.65, 0.80)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", sty)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)

	# Tooltip (hidden)
	_tooltip_panel = Panel.new()
	_tooltip_panel.name = "Tooltip"
	_tooltip_panel.visible = false
	_tooltip_panel.size = Vector2(220, 140)
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ttsty = StyleBoxFlat.new()
	ttsty.bg_color = Color(0.04, 0.05, 0.12, 0.97)
	ttsty.border_color = Color(0.35, 0.60, 0.85, 0.85)
	ttsty.set_border_width_all(1); ttsty.set_corner_radius_all(3)
	_tooltip_panel.add_theme_stylebox_override("panel", ttsty)
	_panel.add_child(_tooltip_panel)

	_refresh()

func _refresh() -> void:
	if not is_instance_valid(_player): return
	_dirty = false

	# Clear main panel except tooltip
	for c in _panel.get_children():
		if c != _tooltip_panel:
			c.queue_free()

	# Rebuild side nav (to update highlighted profession)
	if _nav_panel:
		for c in _nav_panel.get_children():
			c.queue_free()
		_build_nav_list()

	var y = 6.0

	# ── SKILL POINTS BAR ─────────────────────────────────────
	var avail = _player.call("get_skill_points_available") if _player.has_method("get_skill_points_available") else 250
	var sp_lbl = Label.new()
	sp_lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	sp_lbl.add_theme_font_size_override("font_size", 11)
	sp_lbl.text = "Skill Points Remaining:  %d / 250" % avail
	sp_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	sp_lbl.position = Vector2(10, y); sp_lbl.size = Vector2(WIN_W - 20, 16)
	sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sp_lbl)
	y += 18

	# SP bar visual
	var sp_bg = ColorRect.new()
	sp_bg.color = Color(0.08, 0.08, 0.12)
	sp_bg.position = Vector2(20, y); sp_bg.size = Vector2(WIN_W - 40, 8)
	_panel.add_child(sp_bg)
	var sp_fill = ColorRect.new()
	var fill_pct = float(250 - avail) / 250.0
	sp_fill.color = Color(0.8, 0.2, 0.15) if fill_pct > 0.9 else Color(0.15, 0.65, 0.85)
	sp_fill.position = Vector2(20, y); sp_fill.size = Vector2((WIN_W - 40) * fill_pct, 8)
	_panel.add_child(sp_fill)
	y += 14

	_add_divider(y); y += 6

	# ── PROFESSION TREE ──────────────────────────────────────
	var profs = ProfessionData.get_all_professions()
	var prof : Dictionary = {}
	for p in profs:
		if p.id == _current_prof_id:
			prof = p
			break
	if prof.is_empty(): return

	var learned : Array = _player.get("learned_boxes") if _player.get("learned_boxes") != null else []
	var _tree_top = y

	# Profession title
	var title = Label.new()
	title.add_theme_font_override("font", _bold if _bold else _roboto)
	title.add_theme_font_size_override("font_size", 16)
	title.text = prof.name
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	title.position = Vector2(0, y); title.size = Vector2(WIN_W, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)
	y += 22

	# Elite profession links above columns (what this tree leads to)
	var elite_links = _get_elite_links(prof.id)
	if elite_links.size() > 0:
		var link_x = WIN_W * 0.5 - (elite_links.size() * 100) * 0.5
		for elink in elite_links:
			var ebtn = _make_link_button(elink.name, elink.id)
			ebtn.position = Vector2(link_x, y)
			ebtn.size = Vector2(96, 16)
			ebtn.add_theme_font_size_override("font_size", 11)
			_panel.add_child(ebtn)
			link_x += 100
		y += 18

	# Master box
	var master = prof.master
	var master_x = WIN_W * 0.5 - BOX_W * 0.5
	_add_box_button(master, master_x, y, learned)
	# SP cost label
	_add_sp_label(master, master_x + BOX_W + 2, y)
	y += BOX_H + 4

	# Discipline columns
	var col_spacing = (WIN_W - 16) / 4.0

	# Discipline header buttons
	for di in prof.disciplines.size():
		var disc = prof.disciplines[di]
		var dbtn = _make_disc_header(disc.name, di, col_spacing)
		dbtn.position = Vector2(8 + di * col_spacing + 1, y)
		_panel.add_child(dbtn)
	y += 18

	# Tier 4 down to Tier 1
	for ti in range(3, -1, -1):
		for di in prof.disciplines.size():
			var disc = prof.disciplines[di]
			if ti < disc.boxes.size():
				var box = disc.boxes[ti]
				var col_x = 8 + di * col_spacing + col_spacing * 0.5 - BOX_W * 0.5
				_add_box_button(box, col_x, y, learned)
				_add_sp_label(box, col_x + BOX_W + 1, y)
		y += BOX_H + BOX_PAD

	# Novice box at bottom
	var nov = prof.novice
	var nov_x = WIN_W * 0.5 - BOX_W * 0.5
	_add_box_button(nov, nov_x, y, learned)
	_add_sp_label(nov, nov_x + BOX_W + 2, y)
	y += BOX_H + 6

	# Prerequisites (what professions are needed)
	var prereq_text = _get_prereq_text(prof.id)
	if prereq_text != "":
		var pq = Label.new()
		pq.add_theme_font_override("font", _roboto)
		pq.add_theme_font_size_override("font_size", 11)
		pq.text = prereq_text
		pq.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
		pq.position = Vector2(0, y); pq.size = Vector2(WIN_W, 14)
		pq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(pq)

	# Close button (top right)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(WIN_W - 24, 4); close_btn.size = Vector2(20, 18)
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(queue_free)
	var cbsty = StyleBoxFlat.new()
	cbsty.bg_color = Color(0.15, 0.05, 0.05, 0.8)
	cbsty.border_color = Color(0.6, 0.25, 0.25, 0.6)
	cbsty.set_border_width_all(1); cbsty.set_corner_radius_all(2)
	close_btn.add_theme_stylebox_override("normal", cbsty)
	_panel.add_child(close_btn)

# ── SIDE NAV PANEL ───────────────────────────────────────────
func _build_nav_list() -> void:
	var y = 8.0
	# Section: Basic
	_nav_section_label("Basic Professions", y)
	y += 16
	for pid in BASIC_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		if pdata.is_empty(): continue
		_nav_prof_button(pdata.name, pid, y)
		y += 20
	y += 8
	# Section: Elite
	_nav_section_label("Elite Professions", y)
	y += 16
	for pid in ELITE_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		var display = pid.replace("_", " ").capitalize() if pdata.is_empty() else pdata.name
		_nav_prof_button(display, pid, y)
		y += 20
	y += 8
	# Section: Force
	_nav_section_label("Force Sensitive", y)
	y += 16
	for pid in FORCE_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		if pdata.is_empty(): continue
		_nav_prof_button(pdata.name, pid, y)
		y += 20

func _nav_section_label(text: String, y: float) -> void:
	var lbl = Label.new()
	lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70, 0.7))
	lbl.position = Vector2(6, y); lbl.size = Vector2(NAV_W - 12, 14)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_panel.add_child(lbl)

func _nav_prof_button(text: String, prof_id: String, y: float) -> void:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_override("font", _roboto)
	btn.add_theme_font_size_override("font_size", 10)
	btn.position = Vector2(4, y); btn.size = Vector2(NAV_W - 8, 18)
	btn.clip_text = true
	if prof_id == _current_prof_id:
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	else:
		btn.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
	var bsty = StyleBoxFlat.new()
	bsty.bg_color = Color(0, 0, 0, 0)
	bsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", bsty)
	var hsty = StyleBoxFlat.new()
	hsty.bg_color = Color(0.12, 0.22, 0.38, 0.5)
	hsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("hover", hsty)
	btn.pressed.connect(func(): _navigate_to(prof_id))
	_nav_panel.add_child(btn)

# ── OLD TOP NAV (kept for reference, no longer called) ───────
func _draw_nav_section(y: float) -> float:
	# Basic Professions
	var lbl_basic = Label.new()
	lbl_basic.add_theme_font_override("font", _roboto)
	lbl_basic.add_theme_font_size_override("font_size", 10)
	lbl_basic.text = "Basic Professions"
	lbl_basic.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.6))
	lbl_basic.position = Vector2(8, y); lbl_basic.size = Vector2(100, 12)
	lbl_basic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lbl_basic)

	var lbl_elite = Label.new()
	lbl_elite.add_theme_font_override("font", _roboto)
	lbl_elite.add_theme_font_size_override("font_size", 10)
	lbl_elite.text = "Elite and Hybrid Professions"
	lbl_elite.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.6))
	lbl_elite.position = Vector2(140, y); lbl_elite.size = Vector2(180, 12)
	lbl_elite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lbl_elite)

	var lbl_force = Label.new()
	lbl_force.add_theme_font_override("font", _roboto)
	lbl_force.add_theme_font_size_override("font_size", 10)
	lbl_force.text = "Force Sensitive"
	lbl_force.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.6))
	lbl_force.position = Vector2(420, y); lbl_force.size = Vector2(110, 12)
	lbl_force.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lbl_force)
	y += 14

	# Basic profession links
	var bx = 8.0
	for pid in BASIC_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		if pdata.is_empty(): continue
		var btn = _make_link_button(pdata.name, pid)
		btn.position = Vector2(bx, y); btn.size = Vector2(80, 14)
		btn.add_theme_font_size_override("font_size", 11)
		_panel.add_child(btn)
		bx += 84
	# Elite links
	var ex = 140.0
	var ey = y
	var col = 0
	for pid in ELITE_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		var display_name = pid.replace("_", " ").capitalize() if pdata.is_empty() else pdata.name
		var btn = _make_link_button(display_name, pid)
		btn.position = Vector2(ex + (col % 3) * 92, ey + (col / 3) * 14)
		btn.size = Vector2(88, 13)
		btn.add_theme_font_size_override("font_size", 10)
		_panel.add_child(btn)
		col += 1

	# Force links
	var fx = 420.0
	for pid in FORCE_PROFS:
		var pdata = ProfessionData.get_profession(pid)
		if pdata.is_empty(): continue
		var btn = _make_link_button(pdata.name, pid)
		btn.position = Vector2(fx, y); btn.size = Vector2(110, 14)
		btn.add_theme_font_size_override("font_size", 11)
		_panel.add_child(btn)
		fx += 114

	# Calculate max y
	var nav_bottom = ey + ((col + 2) / 3) * 14
	return maxf(y + 16, nav_bottom + 4)

func _make_link_button(text: String, prof_id: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_override("font", _roboto)
	btn.add_theme_font_size_override("font_size", 11)
	# Highlight current profession
	if prof_id == _current_prof_id:
		btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	else:
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90))
	var bsty = StyleBoxFlat.new()
	bsty.bg_color = Color(0, 0, 0, 0)
	bsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", bsty)
	var hsty = StyleBoxFlat.new()
	hsty.bg_color = Color(0.15, 0.25, 0.40, 0.4)
	hsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("hover", hsty)
	btn.pressed.connect(func(): _navigate_to(prof_id))
	return btn

func _make_disc_header(disc_name: String, _di: int, col_w: float) -> Button:
	var btn = Button.new()
	btn.text = disc_name
	btn.add_theme_font_override("font", _bold if _bold else _roboto)
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	btn.size = Vector2(col_w - 4, 16)
	var bsty = StyleBoxFlat.new()
	bsty.bg_color = Color(0, 0, 0, 0)
	bsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", bsty)
	var hsty = StyleBoxFlat.new()
	hsty.bg_color = Color(0.12, 0.20, 0.35, 0.5)
	hsty.set_border_width_all(0)
	btn.add_theme_stylebox_override("hover", hsty)
	# Try to navigate to elite profession for this discipline
	btn.pressed.connect(func(): _on_discipline_clicked(disc_name))
	return btn

func _navigate_to(prof_id: String) -> void:
	# Check if profession exists
	var pdata = ProfessionData.get_profession(prof_id)
	if pdata.is_empty():
		if is_instance_valid(_player) and _player.has_method("_spawn_floating_text"):
			_player.call("_spawn_floating_text", prof_id.replace("_"," ").capitalize() + " — Coming Soon", Color(0.6, 0.8, 1.0))
		return
	_current_prof_id = prof_id
	_dirty = true

func _on_discipline_clicked(disc_name: String) -> void:
	# Map discipline names to elite profession IDs
	var elite_map = {
		"Unarmed": "teras_kasi", "One Hand": "fencer", "Two Hand": "swordsman", "Pikeman": "pikeman",
		"Pistol": "pistoleer", "Rifle": "rifleman", "Carbine": "carbineer", "Ranged Support": "bounty_hunter",
		"First Aid": "doctor", "Pharmacology": "combat_medic", "Organic Chemistry": "combat_medic", "Diagnose": "doctor",
		"Force Powers": "forcesensitive", "Force Defense": "forcesensitive", "Force Healing": "forcesensitive", "Lightsaber": "forcesensitive",
	}
	var target = elite_map.get(disc_name, "")
	if target != "":
		_navigate_to(target)

# ── SKILLBOX BUTTONS ─────────────────────────────────────────
func _add_box_button(box: Dictionary, x: float, y: float, learned: Array) -> void:
	var btn = Button.new()
	# Two-line text: name + subtitle
	btn.text = box.name
	btn.position = Vector2(x, y)
	btn.size = Vector2(BOX_W, BOX_H)
	btn.add_theme_font_override("font", _roboto)
	btn.add_theme_font_size_override("font_size", 10)
	btn.clip_text = true

	var is_learned = box.id in learned
	var xp_pools = _player.get("xp_pools") as Dictionary if _player.get("xp_pools") != null else {}
	var sp_avail = _player.call("get_skill_points_available") if _player.has_method("get_skill_points_available") else 0
	var creds = _player.get("credits") as int if _player.get("credits") != null else 0
	var can_info = ProfessionData.can_learn_box(box, learned, xp_pools, sp_avail, creds)

	var bsty = StyleBoxFlat.new()
	bsty.set_border_width_all(1)
	bsty.set_corner_radius_all(2)

	var title_cyan = Color(0.90, 0.90, 0.95)
	if is_learned:
		bsty.bg_color = Color(0.06, 0.18, 0.10, 0.85)
		bsty.border_color = Color(0.25, 0.75, 0.35, 0.7)
		btn.add_theme_color_override("font_color", title_cyan)
	elif can_info.can_learn:
		bsty.bg_color = Color(0.20, 0.18, 0.06, 0.85)
		bsty.border_color = Color(0.75, 0.65, 0.25, 0.7)
		btn.add_theme_color_override("font_color", title_cyan)
	else:
		bsty.bg_color = Color(0.06, 0.06, 0.10, 0.6)
		bsty.border_color = Color(0.20, 0.25, 0.35, 0.45)
		btn.add_theme_color_override("font_color", title_cyan.darkened(0.35))

	btn.add_theme_stylebox_override("normal", bsty)
	var hsty = bsty.duplicate()
	hsty.bg_color = bsty.bg_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hsty)
	btn.add_theme_stylebox_override("pressed", bsty)

	var box_id = box.id
	var box_ref = box
	var info_ref = can_info
	var learned_ref = is_learned
	btn.pressed.connect(func(): _on_box_pressed(box_id))
	btn.mouse_entered.connect(func(): _show_tooltip(btn, box_ref, info_ref, learned_ref))
	btn.mouse_exited.connect(func(): _hide_tooltip())
	_panel.add_child(btn)

func _add_sp_label(box: Dictionary, x: float, y: float) -> void:
	var lbl = Label.new()
	lbl.add_theme_font_override("font", _roboto)
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.text = str(box.cost_sp)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.5))
	lbl.position = Vector2(x, y + BOX_H - 12); lbl.size = Vector2(14, 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(lbl)

func _add_divider(y: float) -> void:
	var div = ColorRect.new()
	div.color = Color(0.15, 0.40, 0.60, 0.35)
	div.position = Vector2(8, y); div.size = Vector2(WIN_W - 16, 1)
	_panel.add_child(div)

# ── ELITE LINKS ABOVE COLUMNS ────────────────────────────────
func _get_elite_links(prof_id: String) -> Array:
	match prof_id:
		"scrapper": return [
			{"name": "Teras Kasi", "id": "teras_kasi"}, {"name": "Fencer", "id": "fencer"},
			{"name": "Swordsman", "id": "swordsman"}, {"name": "Pikeman", "id": "pikeman"}]
		"marksman": return [
			{"name": "Pistoleer", "id": "pistoleer"}, {"name": "Carbineer", "id": "carbineer"},
			{"name": "Rifleman", "id": "rifleman"}, {"name": "Bounty Hunter", "id": "bounty_hunter"}]
		"medic": return [
			{"name": "Doctor", "id": "doctor"}, {"name": "Combat Medic", "id": "combat_medic"}]
	return []

func _get_prereq_text(prof_id: String) -> String:
	match prof_id:
		"teras_kasi": return "Requires: Scrapper (Unarmed IV)"
		"fencer": return "Requires: Scrapper (One Hand IV)"
		"swordsman": return "Requires: Scrapper (Two Hand IV)"
		"pikeman": return "Requires: Scrapper (Pikeman IV)"
		"pistoleer": return "Requires: Marksman (Pistol IV)"
		"carbineer": return "Requires: Marksman (Carbine IV)"
		"rifleman": return "Requires: Marksman (Rifle IV)"
		"doctor": return "Requires: Medic (First Aid IV)"
		"combat_medic": return "Requires: Medic + Scrapper"
		"commando": return "Requires: Scrapper + Marksman"
		"bounty_hunter": return "Requires: Marksman + Scout"
	return ""

# ── BOX INTERACTION ──────────────────────────────────────────
func _on_box_pressed(box_id: String) -> void:
	if not is_instance_valid(_player): return
	if _player.has_method("learn_box"):
		_player.call("learn_box", box_id)
		_dirty = true

func _show_tooltip(btn: Button, box: Dictionary, info: Dictionary, is_learned: bool) -> void:
	if _tooltip_panel == null: return
	for c in _tooltip_panel.get_children(): c.queue_free()
	_tooltip_panel.visible = true

	var bpos = btn.position
	_tooltip_panel.position = Vector2(bpos.x + BOX_W + 4, bpos.y)
	if _tooltip_panel.position.x + 220 > WIN_W:
		_tooltip_panel.position.x = bpos.x - 224

	var ty = 6.0

	var name_lbl = Label.new()
	name_lbl.add_theme_font_override("font", _bold if _bold else _roboto)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.text = box.name
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	name_lbl.position = Vector2(8, ty); name_lbl.size = Vector2(204, 16)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(name_lbl)
	ty += 16

	# Cost
	var cost_lbl = Label.new()
	cost_lbl.add_theme_font_override("font", _roboto)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.text = "SP: %d  |  XP: %d %s  |  Credits: %d" % [box.cost_sp, box.xp_cost, box.xp_type.to_upper(), box.credit_cost]
	cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	cost_lbl.position = Vector2(8, ty); cost_lbl.size = Vector2(204, 12)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(cost_lbl)
	ty += 14

	# Status
	var status_lbl = Label.new()
	status_lbl.add_theme_font_override("font", _roboto)
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_lbl.position = Vector2(8, ty); status_lbl.size = Vector2(204, 12)
	if is_learned:
		status_lbl.text = "LEARNED"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif info.can_learn:
		status_lbl.text = "AVAILABLE — Click to learn"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	else:
		status_lbl.text = info.reason
		status_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	_tooltip_panel.add_child(status_lbl)
	ty += 14

	var div = ColorRect.new()
	div.color = Color(0.2, 0.4, 0.7, 0.3)
	div.position = Vector2(8, ty); div.size = Vector2(204, 1)
	_tooltip_panel.add_child(div)
	ty += 4

	# Modifiers
	var mods = box.get("modifiers", {})
	for stat_key in mods:
		var mod_lbl = Label.new()
		mod_lbl.add_theme_font_override("font", _roboto)
		mod_lbl.add_theme_font_size_override("font_size", 11)
		mod_lbl.text = "+%d %s" % [mods[stat_key], stat_key.replace("_", " ").capitalize()]
		mod_lbl.add_theme_color_override("font_color", Color(0.45, 0.80, 1.0))
		mod_lbl.position = Vector2(12, ty); mod_lbl.size = Vector2(196, 12)
		mod_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip_panel.add_child(mod_lbl)
		ty += 12

	# Abilities
	var abilities = box.get("abilities", [])
	for ab_id in abilities:
		var ab_lbl = Label.new()
		ab_lbl.add_theme_font_override("font", _bold if _bold else _roboto)
		ab_lbl.add_theme_font_size_override("font_size", 11)
		ab_lbl.text = "Unlocks: " + ab_id.replace("_", " ").capitalize()
		ab_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
		ab_lbl.position = Vector2(12, ty); ab_lbl.size = Vector2(196, 12)
		ab_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tooltip_panel.add_child(ab_lbl)
		ty += 12

	_tooltip_panel.size = Vector2(220, ty + 6)

func _hide_tooltip() -> void:
	if _tooltip_panel: _tooltip_panel.visible = false

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed and event.position.y < 30
	elif event is InputEventMouseMotion and _dragging:
		_panel.position += event.relative
		if _nav_panel:
			_nav_panel.position += event.relative

func _process(_delta: float) -> void:
	if _dirty and is_instance_valid(_player):
		_refresh()
