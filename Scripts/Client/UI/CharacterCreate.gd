extends Node2D

## Character Creation Screen — SWG-inspired.
## Left: 3D rotating skin carousel. Right: profession, name, stats panel.

# ── Skin definitions (one per color variant) ───────────────────────
const SKINS := {
	"CloudTrooper": {
		"display_name": "Cloud Trooper",
		"fbx": "res://Coronet/charactercolors/CloudTrooper/Meshy_AI_Azure_Sentinel_biped/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_withSkin.fbx",
		"color": Color(0.70, 0.82, 0.95),
		"offset": Vector3.ZERO,
	},
	"CyberBH": {
		"display_name": "Cyber BH",
		"fbx": "res://Coronet/charactercolors/CyberBH/Meshy_AI_Azure_Sentinel_0324195504_texture_fbx/Meshy_AI_Azure_Sentinel_0324195504_texture.fbx",
		"color": Color(0.20, 0.80, 0.92),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"DarkForest": {
		"display_name": "Dark Forest",
		"fbx": "res://Coronet/charactercolors/DarkForest/Meshy_AI_Azure_Sentinel_0324195217_texture_fbx/Meshy_AI_Azure_Sentinel_0324195217_texture.fbx",
		"color": Color(0.22, 0.50, 0.28),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"DesertStorm": {
		"display_name": "Desert Storm",
		"fbx": "res://Coronet/charactercolors/DesertStorm/Meshy_AI_Azure_Sentinel_0324195344_texture_fbx/Meshy_AI_Azure_Sentinel_0324195344_texture.fbx",
		"color": Color(0.88, 0.78, 0.52),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"MoltenCore": {
		"display_name": "Molten Core",
		"fbx": "res://Coronet/charactercolors/MoltenCore/Meshy_AI_Azure_Sentinel_0324195410_texture_fbx/Meshy_AI_Azure_Sentinel_0324195410_texture.fbx",
		"color": Color(0.92, 0.38, 0.15),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"RedWedding": {
		"display_name": "Red Wedding",
		"fbx": "res://Coronet/charactercolors/RedWedding/Meshy_AI_Azure_Sentinel_biped/Meshy_AI_Azure_Sentinel_biped_Animation_Walking_withSkin.fbx",
		"color": Color(0.88, 0.18, 0.22),
		"offset": Vector3.ZERO,
	},
	"Silverium": {
		"display_name": "Silverium",
		"fbx": "res://Coronet/charactercolors/Silverium/Meshy_AI_Azure_Sentinel_0324195433_texture_fbx/Meshy_AI_Azure_Sentinel_0324195433_texture.fbx",
		"color": Color(0.75, 0.78, 0.84),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"GilleCamo": {
		"display_name": "Gille Camo",
		"fbx": "res://Coronet/charactercolors/GilleCamo/Meshy_AI_Azure_Sentinel_0325071735_texture_fbx/Meshy_AI_Azure_Sentinel_0325071735_texture.fbx",
		"color": Color(0.45, 0.55, 0.35),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"Tron": {
		"display_name": "Tron",
		"fbx": "res://Coronet/charactercolors/Tron/Meshy_AI_Azure_Sentinel_0325070913_texture_fbx/Meshy_AI_Azure_Sentinel_0325070913_texture.fbx",
		"color": Color(0.10, 0.85, 0.95),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
	"TindremicSteel": {
		"display_name": "Tindremic Steel",
		"fbx": "res://Coronet/charactercolors/TindremicSteel/Meshy_AI_Azure_Sentinel_0325070948_texture_fbx/Meshy_AI_Azure_Sentinel_0325070948_texture.fbx",
		"color": Color(0.60, 0.62, 0.68),
		"offset": Vector3(0.0, 0.85, 0.0),
	},
}

# ── Profession definitions ─────────────────────────────────────────
const PROFESSIONS := {
	"streetfighter": {
		"display_name": "Street Fighter",
		"description": "Close-quarters brawler who dominates with fists and melee weapons. Devastating combos at short range. High health and strength.\n\n[color=#aaaacc]Upgrade path:[/color]\n  [color=#ddaa44]MMA Fighter[/color]  —  ground & pound specialist\n  [color=#ddaa44]Fencer[/color]  —  precise blade master",
		"class": "melee",
		"stats": {
			"Health": 1350, "Strength": 850, "Constitution": 550,
			"Action": 1000, "Quickness": 450, "Stamina": 450,
			"Mind": 600, "Focus": 450, "Willpower": 400,
		},
		"color": Color(0.95, 0.55, 0.20),
	},
	"gunslinger": {
		"display_name": "Gunslinger",
		"description": "Ranged combat specialist and expert marksman. Precise shots from distance with deadly accuracy. High action and mind pools.\n\n[color=#aaaacc]Upgrade path:[/color]\n  [color=#55bbff]Pistoleer[/color]  —  dual-wield blaster expert\n  [color=#55bbff]Sniper[/color]  —  long-range elimination",
		"class": "ranged",
		"stats": {
			"Health": 1000, "Strength": 400, "Constitution": 450,
			"Action": 1200, "Quickness": 700, "Stamina": 500,
			"Mind": 800, "Focus": 550, "Willpower": 500,
		},
		"color": Color(0.30, 0.70, 1.00),
	},
}

const STAT_NAMES := ["Health", "Strength", "Constitution", "Action", "Quickness", "Stamina", "Mind", "Focus", "Willpower"]
const HAM_COLORS := {
	"Health": Color(0.85, 0.25, 0.25), "Strength": Color(0.85, 0.25, 0.25), "Constitution": Color(0.85, 0.25, 0.25),
	"Action": Color(0.25, 0.85, 0.25), "Quickness": Color(0.25, 0.85, 0.25), "Stamina": Color(0.25, 0.85, 0.25),
	"Mind": Color(0.30, 0.50, 0.95), "Focus": Color(0.30, 0.50, 0.95), "Willpower": Color(0.30, 0.50, 0.95),
}
const MAX_STAT := 1500.0

# ── State ──────────────────────────────────────────────────────────
var _skin_keys : Array = []
var _skin_idx  : int = 0
var _selected_profession : String = ""
var _busy : bool = false

# ── UI refs ────────────────────────────────────────────────────────
var _canvas       : CanvasLayer
var _skin_name_lbl : Label
var _skin_dot_lbl  : Label
var _nick_field   : LineEdit
var _create_btn   : Button
var _desc_label   : RichTextLabel
var _status_lbl   : Label
var _prof_btns    := {}
var _stat_labels  := {}

# ── 3D preview ────────────────────────────────────────────────────
var _viewport     : SubViewport
var _model_pivot  : Node3D
var _current_model : Node3D
var _dragging     : bool = false
var _preview_rect : Rect2 = Rect2()

func _ready() -> void:
	_skin_keys = SKINS.keys()
	_build_ui()
	_load_skin(_skin_idx)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _preview_rect.has_point(mb.position):
				_dragging = true
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging and _current_model:
		var mm := event as InputEventMouseMotion
		_current_model.rotate_y(mm.relative.x * 0.008)

# ── UI BUILD ──────────────────────────────────────────────────────
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)
	var vp := get_viewport().get_visible_rect().size
	var font = load("res://Assets/Fonts/Bebas_Neue/BebasNeue-Regular.ttf")
	var roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

	# Background
	var bg_tex = load("res://Coronet/gamecover.png") as Texture2D
	if bg_tex:
		var bg_img = TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.size = vp
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(bg_img)
	var overlay = ColorRect.new()
	overlay.size  = vp
	overlay.color = Color(0.0, 0.0, 0.05, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# Title
	var title_glow = Label.new()
	title_glow.add_theme_font_override("font", font)
	title_glow.text = "CHARACTER CREATION"
	title_glow.add_theme_font_size_override("font_size", 52)
	title_glow.add_theme_color_override("font_color", Color(0.20, 0.55, 1.00, 0.30))
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.size = Vector2(vp.x, 64)
	title_glow.position = Vector2(0, 17)
	title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title_glow)

	var title = Label.new()
	title.add_theme_font_override("font", font)
	title.text = "CHARACTER CREATION"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.00))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.45, 0.95, 0.90))
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 64)
	title.position = Vector2(0, 15)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title)

	# ── Left: 3D Character Preview ──────────────────────────────
	var preview_x := vp.x * 0.05
	var preview_y := 90.0
	var preview_w := vp.x * 0.42
	var preview_h := vp.y - 190.0

	# SubViewport for 3D
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(preview_w), int(preview_h))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.2)
	cam.rotation.x = deg_to_rad(-5.5)
	cam.fov = 38
	_viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.transform = Transform3D(Basis.looking_at(Vector3(-1, -2, -1)), Vector3(0, 5, 0))
	light.light_energy = 1.8
	_viewport.add_child(light)

	var fill := DirectionalLight3D.new()
	fill.transform = Transform3D(Basis.looking_at(Vector3(1, -0.5, 1)), Vector3(0, 3, 0))
	fill.light_energy = 0.4
	_viewport.add_child(fill)

	_model_pivot = Node3D.new()
	_viewport.add_child(_model_pivot)

	var svc := SubViewportContainer.new()
	svc.position = Vector2(preview_x, preview_y)
	svc.size = Vector2(preview_w, preview_h)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	svc.add_child(_viewport)
	_canvas.add_child(svc)
	_preview_rect = Rect2(Vector2(preview_x, preview_y), Vector2(preview_w, preview_h))

	# Skin name label
	_skin_name_lbl = Label.new()
	_skin_name_lbl.add_theme_font_override("font", font)
	_skin_name_lbl.add_theme_font_size_override("font_size", 30)
	_skin_name_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 1.00))
	_skin_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_name_lbl.size = Vector2(preview_w, 38)
	_skin_name_lbl.position = Vector2(preview_x, preview_y + preview_h + 2)
	_skin_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_skin_name_lbl)

	# Dot indicators (shows which skin out of total)
	_skin_dot_lbl = Label.new()
	_skin_dot_lbl.add_theme_font_override("font", roboto)
	_skin_dot_lbl.add_theme_font_size_override("font_size", 14)
	_skin_dot_lbl.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	_skin_dot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_dot_lbl.size = Vector2(preview_w, 22)
	_skin_dot_lbl.position = Vector2(preview_x, preview_y + preview_h + 38)
	_skin_dot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_skin_dot_lbl)

	# Left / Right arrows
	var arrow_y = preview_y + preview_h * 0.42
	var arrow_style = StyleBoxFlat.new()
	arrow_style.bg_color = Color(0.08, 0.10, 0.20, 0.85)
	arrow_style.border_color = Color(0.30, 0.50, 0.85, 0.60)
	arrow_style.set_border_width_all(1); arrow_style.set_corner_radius_all(4)

	var left_btn := Button.new()
	left_btn.text = "◀"
	left_btn.position = Vector2(preview_x + 5, arrow_y)
	left_btn.size = Vector2(50, 50)
	left_btn.add_theme_font_size_override("font_size", 22)
	left_btn.add_theme_stylebox_override("normal", arrow_style)
	left_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.00))
	left_btn.pressed.connect(_on_prev_skin)
	_canvas.add_child(left_btn)

	var right_btn := Button.new()
	right_btn.text = "▶"
	right_btn.position = Vector2(preview_x + preview_w - 55, arrow_y)
	right_btn.size = Vector2(50, 50)
	right_btn.add_theme_font_size_override("font_size", 22)
	right_btn.add_theme_stylebox_override("normal", arrow_style.duplicate())
	right_btn.add_theme_color_override("font_color", Color(0.70, 0.80, 1.00))
	right_btn.pressed.connect(_on_next_skin)
	_canvas.add_child(right_btn)

	# ── Right: Profession + Name + Stats Panel ──────────────────
	var panel_x := vp.x * 0.52
	var panel_w := vp.x * 0.44
	var panel_y := 85.0
	var panel_h := vp.y - 140.0

	var panel := Panel.new()
	panel.position = Vector2(panel_x, panel_y)
	panel.size = Vector2(panel_w, panel_h)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.03, 0.04, 0.10, 0.92)
	psb.border_color = Color(0.22, 0.40, 0.75, 0.55)
	psb.set_border_width_all(2); psb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", psb)
	_canvas.add_child(panel)

	# ── Nickname ────────────────────────────────────────────────
	var nick_lbl := Label.new()
	nick_lbl.add_theme_font_override("font", roboto)
	nick_lbl.text = "CHARACTER NAME"
	nick_lbl.add_theme_font_size_override("font_size", 12)
	nick_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 1.00))
	nick_lbl.position = Vector2(20, 20)
	nick_lbl.size = Vector2(panel_w - 40, 18)
	panel.add_child(nick_lbl)

	_nick_field = LineEdit.new()
	_nick_field.position = Vector2(20, 42)
	_nick_field.size = Vector2(panel_w - 40, 40)
	_nick_field.add_theme_font_size_override("font_size", 17)
	_nick_field.add_theme_color_override("font_color", Color(1, 1, 1))
	_nick_field.placeholder_text = "Enter a name..."
	_nick_field.max_length = 20
	var fs = StyleBoxFlat.new()
	fs.bg_color = Color(0.07, 0.06, 0.15)
	fs.border_color = Color(0.30, 0.50, 0.85, 0.70)
	fs.set_border_width_all(1); fs.set_corner_radius_all(3)
	_nick_field.add_theme_stylebox_override("normal", fs)
	_nick_field.add_theme_stylebox_override("focus", fs)
	panel.add_child(_nick_field)

	# ── Profession Selection ────────────────────────────────────
	var prof_header := Label.new()
	prof_header.add_theme_font_override("font", font)
	prof_header.text = "STARTING PROFESSION"
	prof_header.add_theme_font_size_override("font_size", 26)
	prof_header.add_theme_color_override("font_color", Color(0.82, 0.88, 1.00))
	prof_header.position = Vector2(20, 100)
	prof_header.size = Vector2(panel_w - 40, 32)
	panel.add_child(prof_header)

	var btn_y := 138.0
	var btn_w := (panel_w - 55) * 0.5
	var prof_ids = PROFESSIONS.keys()
	for i in range(prof_ids.size()):
		var prof_id = prof_ids[i]
		var pdata = PROFESSIONS[prof_id]
		var btn := Button.new()
		btn.text = pdata["display_name"].to_upper()
		btn.size = Vector2(btn_w, 44)
		btn.position = Vector2(20 + i * (btn_w + 15), btn_y)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_font_override("font", font)
		btn.pressed.connect(_on_select_profession.bind(prof_id))
		_prof_btns[prof_id] = btn
		panel.add_child(btn)
		_style_prof_btn(btn, pdata["color"], false)

	# ── Description ─────────────────────────────────────────────
	_desc_label = RichTextLabel.new()
	_desc_label.position = Vector2(20, 200)
	_desc_label.size = Vector2(panel_w - 40, 150)
	_desc_label.bbcode_enabled = true
	_desc_label.add_theme_font_size_override("normal_font_size", 13)
	_desc_label.add_theme_color_override("default_color", Color(0.68, 0.72, 0.80))
	_desc_label.text = "[center]Select a profession to view details.[/center]"
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_desc_label)

	# ── Attributes (SWG-style HAM bars) ─────────────────────────
	var stats_y := 360.0
	var stat_header := Label.new()
	stat_header.add_theme_font_override("font", font)
	stat_header.text = "ATTRIBUTES"
	stat_header.add_theme_font_size_override("font_size", 22)
	stat_header.add_theme_color_override("font_color", Color(0.68, 0.78, 0.90))
	stat_header.position = Vector2(20, stats_y)
	stat_header.size = Vector2(panel_w - 40, 28)
	panel.add_child(stat_header)

	for i in range(STAT_NAMES.size()):
		var stat_name = STAT_NAMES[i]
		var sy = stats_y + 32 + i * 24

		var slbl := Label.new()
		slbl.add_theme_font_override("font", roboto)
		slbl.text = stat_name
		slbl.add_theme_font_size_override("font_size", 13)
		slbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78))
		slbl.position = Vector2(25, sy)
		slbl.size = Vector2(110, 20)
		panel.add_child(slbl)

		var vlbl := Label.new()
		vlbl.add_theme_font_override("font", roboto)
		vlbl.text = "---"
		vlbl.add_theme_font_size_override("font_size", 13)
		vlbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vlbl.position = Vector2(135, sy)
		vlbl.size = Vector2(55, 20)
		panel.add_child(vlbl)

		var bar_bg := ColorRect.new()
		bar_bg.position = Vector2(200, sy + 4)
		bar_bg.size = Vector2(panel_w - 230, 13)
		bar_bg.color = Color(0.08, 0.09, 0.13)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bar_bg)

		var bar := ColorRect.new()
		bar.position = Vector2(200, sy + 4)
		bar.size = Vector2(0, 13)
		bar.color = HAM_COLORS.get(stat_name, Color(0.5, 0.5, 0.5))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bar)

		_stat_labels[stat_name] = {"value": vlbl, "bar": bar, "bar_max_w": panel_w - 230}

	# ── Status label ────────────────────────────────────────────
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", roboto)
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.90, 0.60, 0.20))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.size = Vector2(panel_w - 40, 20)
	_status_lbl.position = Vector2(20, panel_h - 85)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_status_lbl)

	# ── CREATE button ───────────────────────────────────────────
	_create_btn = Button.new()
	_create_btn.text = "CREATE CHARACTER"
	_create_btn.position = Vector2(20, panel_h - 60)
	_create_btn.size = Vector2(panel_w - 40, 48)
	_create_btn.add_theme_font_size_override("font_size", 22)
	_create_btn.add_theme_font_override("font", font)
	_create_btn.disabled = true
	_style_create_btn()
	_create_btn.pressed.connect(_on_create)
	panel.add_child(_create_btn)

	# ── Back button ─────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.position = Vector2(20, vp.y - 60)
	back_btn.size = Vector2(120, 42)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_font_override("font", font)
	var bbs = StyleBoxFlat.new()
	bbs.bg_color = Color(0.06, 0.08, 0.16, 0.90)
	bbs.border_color = Color(0.35, 0.40, 0.55, 0.60)
	bbs.set_border_width_all(1); bbs.set_corner_radius_all(4)
	back_btn.add_theme_stylebox_override("normal", bbs)
	back_btn.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/character_list.tscn"))
	_canvas.add_child(back_btn)

	_nick_field.call_deferred("grab_focus")

# ── Skin Carousel ─────────────────────────────────────────────────

func _load_skin(idx: int) -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	var skin_id = _skin_keys[idx]
	var skin_data = SKINS[skin_id]
	_skin_name_lbl.text = skin_data["display_name"]
	_skin_name_lbl.add_theme_color_override("font_color", skin_data["color"])

	# Dot indicator: "● ○ ○ ○ ○ ○ ○"
	var dots = ""
	for i in range(_skin_keys.size()):
		dots += " ● " if i == idx else " ○ "
	_skin_dot_lbl.text = dots.strip_edges()

	var fbx = load(skin_data["fbx"]) as PackedScene
	if fbx:
		_current_model = fbx.instantiate()
		_current_model.transform = Transform3D.IDENTITY
		_current_model.position = skin_data.get("offset", Vector3.ZERO)
		_current_model.rotate_y(deg_to_rad(0))
		_model_pivot.add_child(_current_model)

func _on_prev_skin() -> void:
	_skin_idx = (_skin_idx - 1) % _skin_keys.size()
	if _skin_idx < 0:
		_skin_idx = _skin_keys.size() - 1
	_load_skin(_skin_idx)

func _on_next_skin() -> void:
	_skin_idx = (_skin_idx + 1) % _skin_keys.size()
	_load_skin(_skin_idx)

# ── Profession Selection ──────────────────────────────────────────

func _on_select_profession(prof_id: String) -> void:
	_selected_profession = prof_id
	var pdata = PROFESSIONS[prof_id]

	# Update button styles
	for pid in _prof_btns:
		_style_prof_btn(_prof_btns[pid], PROFESSIONS[pid]["color"], pid == prof_id)

	# Update description
	_desc_label.text = pdata["description"]

	# Update stat bars
	for stat_name in STAT_NAMES:
		var info = _stat_labels[stat_name]
		var val = pdata["stats"].get(stat_name, 0)
		info["value"].text = str(val)
		var ratio = float(val) / MAX_STAT
		info["bar"].size.x = ratio * info["bar_max_w"]

	_style_create_btn()

func _style_prof_btn(btn: Button, col: Color, selected: bool) -> void:
	var bs = StyleBoxFlat.new()
	if selected:
		bs.bg_color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.95)
		bs.border_color = col
		bs.set_border_width_all(3)
	else:
		bs.bg_color = Color(0.06, 0.08, 0.18, 0.90)
		bs.border_color = Color(col.r, col.g, col.b, 0.40)
		bs.set_border_width_all(1)
	bs.set_corner_radius_all(5)
	var bsh = bs.duplicate() as StyleBoxFlat
	bsh.bg_color = bs.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bsh)
	btn.add_theme_color_override("font_color", col if selected else Color(col.r, col.g, col.b, 0.70))

func _style_create_btn() -> void:
	var is_ready = _selected_profession != ""
	_create_btn.disabled = not is_ready
	var bs = StyleBoxFlat.new()
	if is_ready:
		bs.bg_color = Color(0.06, 0.22, 0.10, 0.95)
		bs.border_color = Color(0.20, 0.90, 0.35, 1.00)
	else:
		bs.bg_color = Color(0.08, 0.08, 0.10, 0.80)
		bs.border_color = Color(0.30, 0.30, 0.35, 0.50)
	bs.set_border_width_all(2); bs.set_corner_radius_all(6)
	var bsh = bs.duplicate() as StyleBoxFlat
	bsh.bg_color = bs.bg_color.lightened(0.08)
	_create_btn.add_theme_stylebox_override("normal", bs)
	_create_btn.add_theme_stylebox_override("disabled", bs)
	_create_btn.add_theme_stylebox_override("hover", bsh)
	var col = Color(0.30, 0.95, 0.45) if is_ready else Color(0.40, 0.40, 0.45)
	_create_btn.add_theme_color_override("font_color", col)
	_create_btn.add_theme_color_override("font_disabled_color", col)

# ── Create Character ──────────────────────────────────────────────

func _on_create() -> void:
	if _busy:
		return
	var nick = _nick_field.text.strip_edges()
	if nick.length() < 2:
		_set_status("Name must be at least 2 characters.", Color(0.90, 0.60, 0.20))
		return
	if nick.length() > 20:
		_set_status("Name must be 20 characters or less.", Color(0.90, 0.60, 0.20))
		return
	if _selected_profession == "":
		_set_status("Select a profession first.", Color(0.90, 0.60, 0.20))
		return

	var skin_id = _skin_keys[_skin_idx]
	_busy = true
	_create_btn.disabled = true
	_set_status("Creating character...", Color(0.55, 0.75, 1.00))

	var success = await PlayerData.create_character(nick, _selected_profession, skin_id)
	_busy = false
	if success:
		_set_status("Character created!", Color(0.30, 0.85, 0.45))
		# Bridge: map to existing CoronetPlayer character IDs
		var char_id = "WhiteSoldier" if _selected_profession == "streetfighter" else "RedSoldier"
		get_tree().root.set_meta("selected_character", char_id)
		get_tree().change_scene_to_file("res://Scenes/Coronet.tscn")
	else:
		_set_status(PlayerData.last_error, Color(0.90, 0.35, 0.25))
		_style_create_btn()

func _set_status(msg: String, col: Color) -> void:
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", col)
