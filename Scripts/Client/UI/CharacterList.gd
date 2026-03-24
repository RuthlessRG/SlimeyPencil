extends Node2D

## Character List Screen — shows up to 3 character slots.
## Filled slots: play or delete. Empty slots: create new character.

var _canvas : CanvasLayer
var _confirm_index : int = -1  # for delete confirmation

func _ready() -> void:
	_build_ui()

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
	overlay.color = Color(0.0, 0.0, 0.05, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(overlay)

	# Title
	var title_glow = Label.new()
	title_glow.add_theme_font_override("font", font)
	title_glow.text = "SELECT CHARACTER"
	title_glow.add_theme_font_size_override("font_size", 52)
	title_glow.add_theme_color_override("font_color", Color(0.20, 0.55, 1.00, 0.30))
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.size = Vector2(vp.x, 64)
	title_glow.position = Vector2(0, 42)
	title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title_glow)

	var title = Label.new()
	title.add_theme_font_override("font", font)
	title.text = "SELECT CHARACTER"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.00))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.45, 0.95, 0.90))
	title.add_theme_constant_override("outline_size", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 64)
	title.position = Vector2(0, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(title)

	# Character slots — 3 across
	var slot_w := 340.0
	var slot_h := 420.0
	var gap := 40.0
	var total_w := slot_w * 3.0 + gap * 2.0
	var start_x := (vp.x - total_w) * 0.5
	var slot_y := 140.0

	for i in range(3):
		var pos = Vector2(start_x + i * (slot_w + gap), slot_y)
		if i < PlayerData.characters.size():
			_make_character_slot(PlayerData.characters[i], i, pos, Vector2(slot_w, slot_h), font, roboto)
		else:
			_make_empty_slot(pos, Vector2(slot_w, slot_h), font)

	# Back button
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
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/start_screen.tscn"))
	_canvas.add_child(back_btn)

func _make_character_slot(char_data: Dictionary, index: int, pos: Vector2, sz: Vector2, font: Font, roboto: Font) -> void:
	var slot := Panel.new()
	slot.position = pos
	slot.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.12, 0.92)
	sb.border_color = Color(0.25, 0.50, 0.85, 0.70)
	sb.set_border_width_all(2); sb.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", sb)
	_canvas.add_child(slot)

	var prof = char_data.get("profession", "")
	var prof_name = "Street Fighter" if prof == "streetfighter" else "Gunslinger"
	var prof_col = Color(0.95, 0.55, 0.20) if prof == "streetfighter" else Color(0.30, 0.70, 1.00)

	# Accent bar
	var accent := ColorRect.new()
	accent.size = Vector2(sz.x, 4)
	accent.color = prof_col
	slot.add_child(accent)

	# Nickname
	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", font)
	name_lbl.text = char_data.get("nickname", "Unknown")
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.94, 1.00))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 25)
	name_lbl.size = Vector2(sz.x, 46)
	slot.add_child(name_lbl)

	# Profession
	var prof_lbl := Label.new()
	prof_lbl.add_theme_font_override("font", roboto)
	prof_lbl.text = prof_name
	prof_lbl.add_theme_font_size_override("font_size", 16)
	prof_lbl.add_theme_color_override("font_color", prof_col)
	prof_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prof_lbl.position = Vector2(0, 74)
	prof_lbl.size = Vector2(sz.x, 24)
	slot.add_child(prof_lbl)

	# Divider
	var div := ColorRect.new()
	div.position = Vector2(20, 108)
	div.size = Vector2(sz.x - 40, 1)
	div.color = Color(0.25, 0.30, 0.45, 0.50)
	slot.add_child(div)

	# Skin
	var skin_lbl := Label.new()
	skin_lbl.add_theme_font_override("font", roboto)
	skin_lbl.text = "Skin: " + char_data.get("skin", "Default")
	skin_lbl.add_theme_font_size_override("font_size", 14)
	skin_lbl.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	skin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skin_lbl.position = Vector2(0, 120)
	skin_lbl.size = Vector2(sz.x, 22)
	slot.add_child(skin_lbl)

	# Level
	var lvl_lbl := Label.new()
	lvl_lbl.add_theme_font_override("font", font)
	lvl_lbl.text = "LEVEL " + str(int(char_data.get("level", 1)))
	lvl_lbl.add_theme_font_size_override("font_size", 44)
	lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.80, 0.50))
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.position = Vector2(0, 170)
	lvl_lbl.size = Vector2(sz.x, 52)
	slot.add_child(lvl_lbl)

	# Credits
	var cr_lbl := Label.new()
	cr_lbl.add_theme_font_override("font", roboto)
	cr_lbl.text = str(int(char_data.get("credits", 0))) + " credits"
	cr_lbl.add_theme_font_size_override("font_size", 15)
	cr_lbl.add_theme_color_override("font_color", Color(0.80, 0.72, 0.25))
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_lbl.position = Vector2(0, 228)
	cr_lbl.size = Vector2(sz.x, 24)
	slot.add_child(cr_lbl)

	# PLAY button
	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(20, sz.y - 120)
	play_btn.size = Vector2(sz.x - 40, 48)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.add_theme_font_override("font", font)
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.22, 0.10, 0.95)
	ps.border_color = Color(0.20, 0.90, 0.35, 1.00)
	ps.set_border_width_all(2); ps.set_corner_radius_all(6)
	var psh = ps.duplicate() as StyleBoxFlat
	psh.bg_color = Color(0.10, 0.30, 0.14, 0.98)
	play_btn.add_theme_stylebox_override("normal", ps)
	play_btn.add_theme_stylebox_override("hover", psh)
	play_btn.add_theme_color_override("font_color", Color(0.30, 0.95, 0.45))
	play_btn.pressed.connect(_on_select.bind(index))
	slot.add_child(play_btn)

	# DELETE button
	var del_btn := Button.new()
	del_btn.text = "DELETE"
	del_btn.position = Vector2(20, sz.y - 58)
	del_btn.size = Vector2(sz.x - 40, 36)
	del_btn.add_theme_font_size_override("font_size", 13)
	del_btn.add_theme_font_override("font", roboto)
	var ds = StyleBoxFlat.new()
	ds.bg_color = Color(0.16, 0.05, 0.05, 0.80)
	ds.border_color = Color(0.70, 0.20, 0.18, 0.50)
	ds.set_border_width_all(1); ds.set_corner_radius_all(4)
	var dsh = ds.duplicate() as StyleBoxFlat
	dsh.bg_color = Color(0.30, 0.08, 0.08, 0.95)
	del_btn.add_theme_stylebox_override("normal", ds)
	del_btn.add_theme_stylebox_override("hover", dsh)
	del_btn.add_theme_color_override("font_color", Color(0.85, 0.35, 0.30))
	del_btn.pressed.connect(_on_delete_click.bind(index, del_btn))
	slot.add_child(del_btn)

func _make_empty_slot(pos: Vector2, sz: Vector2, font: Font) -> void:
	var slot := Panel.new()
	slot.position = pos
	slot.size = sz
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.75)
	sb.border_color = Color(0.18, 0.22, 0.32, 0.40)
	sb.set_border_width_all(2); sb.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", sb)
	_canvas.add_child(slot)

	# Plus icon
	var plus := Label.new()
	plus.add_theme_font_override("font", font)
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 80)
	plus.add_theme_color_override("font_color", Color(0.25, 0.40, 0.60, 0.40))
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.position = Vector2(0, sz.y * 0.22)
	plus.size = Vector2(sz.x, 90)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(plus)

	# Empty slot text
	var empty_lbl := Label.new()
	empty_lbl.add_theme_font_override("font", font)
	empty_lbl.text = "EMPTY SLOT"
	empty_lbl.add_theme_font_size_override("font_size", 20)
	empty_lbl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50, 0.50))
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.position = Vector2(0, sz.y * 0.48)
	empty_lbl.size = Vector2(sz.x, 28)
	empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(empty_lbl)

	# Create button
	var create_btn := Button.new()
	create_btn.text = "CREATE NEW"
	create_btn.position = Vector2(40, sz.y * 0.60)
	create_btn.size = Vector2(sz.x - 80, 48)
	create_btn.add_theme_font_size_override("font_size", 18)
	create_btn.add_theme_font_override("font", font)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.10, 0.22, 0.92)
	cs.border_color = Color(0.30, 0.60, 1.00, 0.80)
	cs.set_border_width_all(2); cs.set_corner_radius_all(6)
	var csh = cs.duplicate() as StyleBoxFlat
	csh.bg_color = Color(0.10, 0.16, 0.34, 0.98)
	create_btn.add_theme_stylebox_override("normal", cs)
	create_btn.add_theme_stylebox_override("hover", csh)
	create_btn.add_theme_color_override("font_color", Color(0.50, 0.75, 1.00))
	create_btn.pressed.connect(_on_create)
	slot.add_child(create_btn)

# ── Actions ────────────────────────────────────────────────────────

func _on_select(index: int) -> void:
	PlayerData.select_character(index)
	# Bridge: map profession to existing character ID for CoronetPlayer
	var prof = PlayerData.profession
	var char_id = "WhiteSoldier" if prof == "streetfighter" else "RedSoldier"
	get_tree().root.set_meta("selected_character", char_id)
	get_tree().change_scene_to_file("res://Scenes/Coronet.tscn")

func _on_delete_click(index: int, btn: Button) -> void:
	if _confirm_index == index:
		# Second click — actually delete
		_confirm_index = -1
		await PlayerData.delete_character(index)
		_rebuild()
	else:
		# First click — ask for confirmation
		_confirm_index = index
		btn.text = "CONFIRM DELETE?"
		btn.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))

func _on_create() -> void:
	get_tree().change_scene_to_file("res://Scenes/character_create.tscn")

func _rebuild() -> void:
	for child in _canvas.get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_ui()
