extends CanvasLayer

# ============================================================
#  MissionWindow.gd  — Mission Board UI
#  Opened when player presses F near the mission terminal.
#  Shows 3 randomly-generated kill missions.
#  On Accept → arena.start_mission(data) spawns targets.
#  While a mission is active, shows live kill-count status.
# ============================================================

const W : float = 390.0
const H : float = 310.0

var _player    : Node  = null
var _missions  : Array = []
var _win_panel : Panel = null
var _drag      : bool  = false

func init(player: Node) -> void:
	layer   = 14
	_player = player
	_missions = _generate_missions()
	_build_ui()

func _generate_missions() -> Array:
	var pool = [
		{"name": "Zerg Extermination",      "type": "zerg", "desc": "Destroy 10 Zerg mobs and their Lair",          "targets": "10 Zerg + 1 Lair"},
		{"name": "Eliminate Infestation",   "type": "zerg", "desc": "Clear a Zerg infestation from the area",        "targets": "10 Zerg + 1 Lair"},
		{"name": "Destroy Zerg Colony",     "type": "zerg", "desc": "Wipe out an advancing Zerg colony",             "targets": "10 Zerg + 1 Lair"},
		{"name": "Clear Zerg Nest",         "type": "zerg", "desc": "Neutralise a Zerg nest near the perimeter",     "targets": "10 Zerg + 1 Lair"},
		{"name": "Purge Zerg Hive",         "type": "zerg", "desc": "Eradicate a Zerg hive threatening the port",    "targets": "10 Zerg + 1 Lair"},
		{"name": "Aadu Culling",            "type": "aadu", "desc": "Cull an overpopulated Aadu herd in the plains", "targets": "8–12 Aadu"},
		{"name": "Hunt Aadu Herd",          "type": "aadu", "desc": "Reduce an Aadu herd disrupting the farmland",   "targets": "8–12 Aadu"},
		{"name": "Aadu Population Control", "type": "aadu", "desc": "Keep Aadu numbers sustainable near the port",   "targets": "8–12 Aadu"},
	]
	pool.shuffle()
	var result = []
	for i in 3:
		result.append({
			"name":    pool[i]["name"],
			"type":    pool[i]["type"],
			"desc":    pool[i]["desc"],
			"targets": pool[i]["targets"],
			"payout":  randi_range(2, 10) * 5,
		})
	return result

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
	title_lbl.text = "≡  MISSION BOARD"
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

	# ── Content ────────────────────────────────────────────────
	var arena          = _player.get_parent()
	var mission_active = arena.get("_mission_active")
	if mission_active:
		_build_status_view()
	else:
		_build_mission_list()

# ── No active mission — show 3 missions ───────────────────────
func _build_mission_list() -> void:
	var PAD   = 10.0
	var ROW_H = 74.0
	var y     = 38.0

	for i in _missions.size():
		var m = _missions[i]

		var row = Panel.new()
		row.position     = Vector2(PAD, y)
		row.size         = Vector2(W - PAD * 2, ROW_H)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rsty = StyleBoxFlat.new()
		rsty.bg_color     = Color(0.07, 0.05, 0.02, 0.90)
		rsty.border_color = Color(0.55, 0.38, 0.08, 0.55)
		rsty.set_border_width_all(1)
		rsty.set_corner_radius_all(3)
		row.add_theme_stylebox_override("panel", rsty)
		_win_panel.add_child(row)

		# Mission name
		var name_lbl = Label.new()
		name_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		name_lbl.text = m["name"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.25))
		name_lbl.position     = Vector2(8, 6)
		name_lbl.size         = Vector2(250, 18)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		# Payout
		var pay_lbl = Label.new()
		pay_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		pay_lbl.text = "%d CR" % m["payout"]
		pay_lbl.add_theme_font_size_override("font_size", 12)
		pay_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.20))
		pay_lbl.position              = Vector2(W - PAD * 2 - 58, 6)
		pay_lbl.size                  = Vector2(50, 18)
		pay_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		pay_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		row.add_child(pay_lbl)

		# Description
		var desc_lbl = Label.new()
		desc_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		desc_lbl.text = m.get("desc", "Complete the mission objectives")
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.58, 0.50))
		desc_lbl.position     = Vector2(8, 25)
		desc_lbl.size         = Vector2(W - PAD * 2 - 16, 16)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(desc_lbl)

		# Location info
		var loc_lbl = Label.new()
		loc_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		loc_lbl.text = "Location: assigned on accept  ·  %s" % m.get("targets", "")
		loc_lbl.add_theme_font_size_override("font_size", 9)
		loc_lbl.add_theme_color_override("font_color", Color(0.48, 0.46, 0.40))
		loc_lbl.position     = Vector2(8, 40)
		loc_lbl.size         = Vector2(W - PAD * 2 - 16, 14)
		loc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(loc_lbl)

		# Accept button
		var accept_btn = Button.new()
		accept_btn.text     = "ACCEPT"
		accept_btn.position = Vector2(W - PAD * 2 - 78, ROW_H - 26)
		accept_btn.size     = Vector2(70, 20)
		accept_btn.add_theme_font_size_override("font_size", 10)
		var absty = StyleBoxFlat.new()
		absty.bg_color     = Color(0.08, 0.20, 0.04, 0.90)
		absty.border_color = Color(0.50, 0.80, 0.12, 0.75)
		absty.set_border_width_all(1)
		absty.set_corner_radius_all(2)
		accept_btn.add_theme_stylebox_override("normal",  absty)
		accept_btn.add_theme_stylebox_override("hover",   absty)
		accept_btn.add_theme_stylebox_override("pressed", absty)
		accept_btn.add_theme_color_override("font_color", Color(0.55, 1.0, 0.20))
		accept_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		accept_btn.pressed.connect(_accept_mission.bind(m))
		row.add_child(accept_btn)

		y += ROW_H + 6.0

# ── Active mission — show status ──────────────────────────────
func _build_status_view() -> void:
	var arena      = _player.get_parent()
	var mobs_left  = get_tree().get_nodes_in_group("mission_mob").size()
	var lair_left  = get_tree().get_nodes_in_group("mission_lair").size()
	var payout     = arena.get("_mission_payout")
	var m_name     = arena.get("_mission_name")
	if m_name == null or m_name == "":
		m_name = "Zerg Extermination"

	var PAD = 14.0
	var y   = 44.0

	var hdr = Label.new()
	hdr.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hdr.text = "MISSION IN PROGRESS"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.95, 0.70, 0.10))
	hdr.position             = Vector2(PAD, y)
	hdr.size                 = Vector2(W - PAD * 2, 22)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(hdr)
	y += 30.0

	# Divider
	var div = Control.new()
	div.set_script(_hline_script(W - PAD * 2))
	div.position     = Vector2(PAD, y)
	div.size         = Vector2(W - PAD * 2, 2)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(div)
	y += 12.0

	_add_row("Mission:",   m_name, W, y,
		Color(0.90, 0.78, 0.22), Color(0.88, 0.85, 0.68))
	y += 26.0

	var mission_type = arena.get("_mission_type") if arena.get("_mission_type") != null else "zerg"
	var mob_label = "Aadu:" if mission_type == "aadu" else "Zerg Mobs:"
	var mob_col = Color(1.0, 0.35, 0.25) if mobs_left > 0 else Color(0.25, 0.88, 0.35)
	_add_row(mob_label, "%d remaining" % mobs_left, W, y,
		Color(0.72, 0.72, 0.72), mob_col)
	y += 26.0

	if mission_type != "aadu":
		var lair_text = "Alive — destroy it!" if lair_left > 0 else "Destroyed ✓"
		var lair_col  = Color(1.0, 0.38, 0.18) if lair_left > 0 else Color(0.25, 0.88, 0.35)
		_add_row("Lair:", lair_text, W, y, Color(0.72, 0.72, 0.72), lair_col)
		y += 26.0

	_add_row("Reward:", "%d CR on completion" % payout, W, y,
		Color(0.72, 0.72, 0.72), Color(0.95, 0.85, 0.20))
	y += 36.0

	var hint = Label.new()
	hint.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hint.text = "Follow the yellow WAYPOINT arrow to reach the mission site."
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.45))
	hint.position             = Vector2(PAD, y)
	hint.size                 = Vector2(W - PAD * 2, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(hint)

func _add_row(key: String, val: String, win_w: float, y: float,
              key_col: Color, val_col: Color) -> void:
	var PAD = 14.0
	var kl = Label.new()
	kl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	kl.text = key
	kl.add_theme_font_size_override("font_size", 11)
	kl.add_theme_color_override("font_color", key_col)
	kl.position     = Vector2(PAD, y)
	kl.size         = Vector2(120, 18)
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(kl)

	var vl = Label.new()
	vl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	vl.text = val
	vl.add_theme_font_size_override("font_size", 11)
	vl.add_theme_color_override("font_color", val_col)
	vl.position     = Vector2(PAD + 120, y)
	vl.size         = Vector2(win_w - PAD * 2 - 120, 18)
	vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_panel.add_child(vl)

# ── Helpers ───────────────────────────────────────────────────
func _accept_mission(m: Dictionary) -> void:
	var arena = _player.get_parent()
	if is_instance_valid(arena) and arena.has_method("start_mission"):
		arena.call("start_mission", m)
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
