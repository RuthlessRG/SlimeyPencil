extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  ElyciaScene.gd — miniSWG | TERMINUS STATION
#
#  Orbital mercenary waypoint. Seedy spaceport docking bay
#  with neon lights, rain, contract brokers, and dueling pits.
#  Players arrive here to socialize, form groups, trade, duel.
#
#  Terrain is hand-painted via TileMapLayer in the editor.
#  Attach to: elycia.tscn
# ============================================================

# ── ISOMETRIC GRID ──────────────────────────────────────────────
const TILE_W     : int   = 256
const TILE_H     : int   = 128
const GRID_SIZE  : int   = 64
const GRID_CENTER: int   = 32

# ── SCENE NODES ────────────────────────────────────────────────
var _tilemap       : TileMapLayer = null
var _world_layer   : Node2D       = null
var _camera        : Camera2D     = null
var _player        : Node         = null
var _select_layer  : CanvasLayer  = null
var _hud           : CanvasLayer  = null
var _cam_zoom_base : float        = 2.5
var _cam_zoom_target : float      = 3.2
var _zoom_locked   : bool         = true
var _pending_nickname : String    = ""

# HUD refs (same structure as TheedScene for compatibility)
var _player_frame    : Panel        = null
var _player_name_lbl : Label        = null
var _hp_bar          : ProgressBar  = null
var _action_hud_bar  : ProgressBar  = null
var _mind_bar        : ProgressBar  = null
var _hp_bar_lbl      : Label        = null
var _action_bar_lbl  : Label        = null
var _mind_bar_lbl    : Label        = null
var _hp_wound_ov     : ColorRect    = null
var _action_wound_ov : ColorRect    = null
var _mind_wound_ov   : ColorRect    = null
var _hp_pct_lbl      : Label        = null
var _level_lbl       : Label        = null
var _tgt_panel       : Panel        = null
var _tgt_name_lbl    : Label        = null
var _tgt_hp_bar      : ProgressBar  = null
var _tgt_hp_lbl      : Label        = null
var _tgt_action_bar  : ProgressBar  = null
var _tgt_mp_bar      : ProgressBar  = null
var _tgt_debuff_lbl  : Label        = null
var _xp_panel        : Panel        = null
var _xp_bar          : ProgressBar  = null
var _xp_bar_lbl      : Label        = null
var _minimap_panel   : Panel        = null
const UI_LAYOUT_PATH : String       = "user://ui_layout.cfg"
var _minimap_draw    : Control      = null
var _mm_location_lbl : Label        = null
var _mm_channel_lbl  : Label        = null
var _frame_drag      : bool         = false

# Multiplayer
var _remote_players  : Dictionary   = {}
var _broadcast_timer : float        = 0.0
var _scene_time      : float        = 0.0

# Social systems
var _options_panel : Node = null
var _duel_system   : Node = null
var _party_system  : Node = null
var _trade_system  : Node = null
var _player_target_peer : int = -1

# Rain particles
var _rain_particles : Array = []
var _rain_timer     : float = 0.0

# Neon flicker
var _neon_lights : Array = []
var _neon_t      : float = 0.0

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_arena_scene")
	add_to_group("ui_layer")
	_setup_background()
	_setup_tilemap()
	_setup_camera()
	_setup_rain()
	_show_character_select()
	if not Relay.game_data_received.is_connected(_on_relay_data):
		Relay.game_data_received.connect(_on_relay_data)
	if not Relay.peer_left.is_connected(_on_peer_left):
		Relay.peer_left.connect(_on_peer_left)

# ── BACKGROUND ────────────────────────────────────────────────
func _setup_background() -> void:
	# Dark space-station floor color behind the tilemap
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.z_index = -20
	bg.size = Vector2(16000, 16000)
	bg.position = Vector2(-8000, -8000)
	add_child(bg)

# ── TILEMAP SETUP ─────────────────────────────────────────────
func _setup_tilemap() -> void:
	_tilemap = get_node_or_null("TerrainTiles") as TileMapLayer

	_world_layer = Node2D.new()
	_world_layer.name = "WorldLayer"
	_world_layer.y_sort_enabled = true
	add_child(_world_layer)

# ── CAMERA ────────────────────────────────────────────────────
func _setup_camera() -> void:
	_camera      = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = Vector2.ZERO
	_camera.zoom     = Vector2(3.2, 3.2)
	_camera.position_smoothing_enabled = false
	add_child(_camera)
	_camera.make_current()

# ── RAIN EFFECT ───────────────────────────────────────────────
func _setup_rain() -> void:
	# Rain particle layer above the world but below HUD
	var rain_node = Node2D.new()
	rain_node.name = "RainLayer"
	rain_node.z_index = 5
	rain_node.set_script(_make_rain_script())
	add_child(rain_node)

func _make_rain_script() -> GDScript:
	var src = """extends Node2D

var _drops : Array = []
var _cam : Camera2D = null

func _ready():
	for i in 120:
		_drops.append({
			"x": randf_range(-600, 600),
			"y": randf_range(-400, 400),
			"speed": randf_range(280, 450),
			"len": randf_range(8, 18),
			"alpha": randf_range(0.08, 0.22),
		})

func _process(delta):
	_cam = get_viewport().get_camera_2d()
	for d in _drops:
		d["y"] += d["speed"] * delta
		d["x"] += d["speed"] * delta * 0.15
		if d["y"] > 500:
			d["y"] = randf_range(-500, -400)
			d["x"] = randf_range(-700, 600)
	queue_redraw()

func _draw():
	if _cam == null: return
	var cam_pos = _cam.global_position
	for d in _drops:
		var start = cam_pos + Vector2(d["x"], d["y"])
		var end_pt = start + Vector2(d["len"] * 0.15, d["len"])
		draw_line(start, end_pt, Color(0.6, 0.7, 0.85, d["alpha"]), 1.0)
"""
	var s = GDScript.new()
	s.source_code = src
	s.reload()
	return s

# ── COORDINATE HELPERS ────────────────────────────────────────
func _tile_to_world(tx: int, ty: int) -> Vector2:
	if _tilemap:
		return _tilemap.map_to_local(Vector2i(tx, ty))
	return Vector2(float(tx - ty) * TILE_W * 0.5, float(tx + ty) * TILE_H * 0.5)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	if _tilemap:
		return _tilemap.local_to_map(world_pos)
	return Vector2i(0, 0)

# ── CHARACTER SELECT ──────────────────────────────────────────
func _show_character_select() -> void:
	_select_layer = CanvasLayer.new()
	_select_layer.layer = 10
	add_child(_select_layer)

	var vp = get_viewport().get_visible_rect().size

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.08, 0.92)
	overlay.size  = vp
	_select_layer.add_child(overlay)

	# Title
	var title = Label.new()
	title.add_theme_font_override("font", _roboto)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	title.text = "TERMINUS STATION  —  CHOOSE YOUR CLASS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(vp.x, 40)
	title.position = Vector2(0, vp.y * 0.12)
	_select_layer.add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.add_theme_font_override("font", _roboto)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	sub.text = "Docking Bay 7  ·  Mercenary Registration"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(vp.x, 20)
	sub.position = Vector2(0, vp.y * 0.12 + 36)
	_select_layer.add_child(sub)

	var classes = [
		{ "key":"streetfighter","label":"BRAWLER","color":Color(0.90,0.45,0.25), "desc":"Slow but devastating.\nWalk before you run.\nTwo attack styles.\n\nHP: 600\nAtk every: 2.5s\nRange: 130px", "locked":false },
		{ "key":"scrapper","label":"SCRAPPER","color":Color(0.45,0.90,0.35), "desc":"Tough close-range\nfighter. Takes a\nbeating and hits back.\n\nHP: 500\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"ranged",   "label":"MARKSMAN", "color":Color(0.35,0.80,0.95), "desc":"Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"smuggler", "label":"SMUGGLER", "color":Color(0.85,0.65,0.25), "desc":"Cunning gunfighter.\nSame range as Marksman.\nStarts with Novice\nMarksman skills.\n\nHP: 300\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"medic",    "label":"MEDIC",    "color":Color(0.30,0.85,0.90), "desc":"Combat medic.\nHeals allies with\ncanisters, poisons\nenemies.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
		{ "key":"medic",    "label":"TECHNO NUN", "color":Color(0.75,0.30,0.85), "desc":"Holy tech warrior.\nSame loadout as Medic.\nAlternate appearance.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
	]

	var card_w  = 180.0; var card_h  = 300.0; var gap = 28.0
	var total_w = card_w * classes.size() + gap * (classes.size() - 1)
	var start_x = (vp.x - total_w) * 0.5
	var card_y  = vp.y * 0.30

	var select_buttons : Array = []
	for i in classes.size():
		var b = _build_class_card(classes[i], Vector2(start_x + i * (card_w + gap), card_y), Vector2(card_w, card_h))
		b.disabled = true
		select_buttons.append(b)

	var uname = PlayerData.username if PlayerData.username.length() > 0 else "Mercenary"
	var welcome_lbl = Label.new()
	welcome_lbl.add_theme_font_override("font", _roboto)
	welcome_lbl.text = "Welcome,  %s  —  choose your class" % uname
	welcome_lbl.add_theme_font_size_override("font_size", 14)
	welcome_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.80))
	welcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome_lbl.size = Vector2(vp.x, 24)
	welcome_lbl.position = Vector2(0, card_y + card_h + 20)
	_select_layer.add_child(welcome_lbl)

	# Nickname input
	var nick_panel = Panel.new()
	nick_panel.size = Vector2(340, 46)
	nick_panel.position = Vector2(vp.x * 0.5 - 170, card_y + card_h + 54)
	var np_sty = StyleBoxFlat.new()
	np_sty.bg_color = Color(0.06, 0.07, 0.12, 0.90)
	np_sty.border_color = Color(0.25, 0.55, 0.70, 0.70)
	np_sty.set_border_width_all(1); np_sty.set_corner_radius_all(3)
	nick_panel.add_theme_stylebox_override("panel", np_sty)
	_select_layer.add_child(nick_panel)

	var nick_lbl = Label.new()
	nick_lbl.add_theme_font_override("font", _roboto)
	nick_lbl.text = "Callsign:"
	nick_lbl.add_theme_font_size_override("font_size", 13)
	nick_lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	nick_lbl.position = Vector2(10, 12); nick_lbl.size = Vector2(70, 22)
	nick_panel.add_child(nick_lbl)

	var nick_input = LineEdit.new()
	nick_input.add_theme_font_override("font", _roboto)
	nick_input.placeholder_text = PlayerData.nickname if PlayerData.nickname.length() > 0 else "Enter callsign..."
	nick_input.text = PlayerData.nickname
	nick_input.add_theme_font_size_override("font_size", 14)
	nick_input.position = Vector2(82, 8); nick_input.size = Vector2(248, 28)
	nick_panel.add_child(nick_input)

	# Enable buttons after nickname entered
	nick_input.text_changed.connect(func(txt: String):
		var valid = txt.strip_edges().length() >= 2
		for btn in select_buttons:
			btn.disabled = not valid
		PlayerData.nickname = txt.strip_edges()
	)
	if PlayerData.nickname.length() >= 2:
		for btn in select_buttons:
			btn.disabled = false

func _build_class_card(cls: Dictionary, pos: Vector2, sz: Vector2) -> Button:
	var panel = Panel.new()
	panel.size = sz; panel.position = pos
	var sty = StyleBoxFlat.new()
	sty.bg_color    = Color(0.06, 0.07, 0.10, 0.94)
	sty.border_color = cls.color * 0.6
	sty.set_border_width_all(2); sty.set_corner_radius_all(4)
	sty.shadow_color = Color(0.0, 0.0, 0.0, 0.40); sty.shadow_size = 5
	panel.add_theme_stylebox_override("panel", sty)
	_select_layer.add_child(panel)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", _roboto)
	lbl.text = cls.label
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", cls.color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(sz.x, 24); lbl.position = Vector2(0, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	var desc = Label.new()
	desc.add_theme_font_override("font", _roboto)
	desc.text = cls.desc
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.60, 0.65, 0.72))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size = Vector2(sz.x - 20, sz.y - 80); desc.position = Vector2(10, 44)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(desc)

	var btn = Button.new()
	btn.text = "SELECT"
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", cls.color)
	btn.size = Vector2(sz.x - 20, 32); btn.position = Vector2(10, sz.y - 42)
	btn.pressed.connect(_on_class_selected.bind(cls.key))
	panel.add_child(btn)
	return btn

# ── CLASS SELECTED → SPAWN EVERYTHING ────────────────────────
func _on_class_selected(cls: String) -> void:
	_pending_nickname = PlayerData.nickname
	_select_layer.queue_free()
	_select_layer = null
	_zoom_locked = false
	_spawn_player(cls)

# ── PLAYER SPAWN ─────────────────────────────────────────────
func _spawn_player(cls: String) -> void:
	# Reuse TheedScene's full player spawn by loading the main scene script
	# For now, basic spawn — full HUD/combat integration comes next
	var script = load("res://Scripts/BossArenaPlayer.gd")
	_player    = CharacterBody2D.new()
	_player.set_script(script)
	_player.set("character_class", cls)

	var sprite          = AnimatedSprite2D.new()
	sprite.name         = "Sprite"
	# Build frames using TheedScene's frame builder (loaded dynamically)
	var theed_scene_script = load("res://Scripts/TheedScene.gd")
	var temp_builder = Node2D.new()
	temp_builder.set_script(theed_scene_script)
	sprite.sprite_frames = temp_builder.call("_build_frames", cls)
	temp_builder.queue_free()

	if cls == "melee":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
	elif cls in ["scrapper", "streetfighter"]:
		sprite.scale  = Vector2(0.28, 0.28)
		sprite.offset = Vector2(0, -160)
	elif cls == "medic":
		sprite.scale  = Vector2(0.173, 0.173)
		sprite.offset = Vector2(0, -121)
	elif cls == "ranged":
		sprite.scale  = Vector2(0.228, 0.228)
		sprite.offset = Vector2(0, -73)
	elif cls == "smuggler":
		sprite.scale  = Vector2(0.194, 0.194)
		sprite.offset = Vector2(0, -73)
	else:
		sprite.scale  = Vector2(0.28, 0.28)
		sprite.offset = Vector2(0, -160)
	sprite.play("idle_s")
	_player.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12.0; shape.height = 20.0
	col.shape = shape
	_player.add_child(col)

	_player.add_to_group("player")
	_player.collision_layer = 1; _player.collision_mask = 3
	_world_layer.add_child(_player)
	_player.global_position = Vector2(0, 0)

# ── PROCESS ───────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_scene_time += delta

	# Camera follow
	if is_instance_valid(_player) and is_instance_valid(_camera):
		_camera.global_position = _player.global_position
		_camera.zoom = _camera.zoom.lerp(Vector2(_cam_zoom_target, _cam_zoom_target), delta * 6.0)

# ── INPUT ─────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _minimap_panel != null:
				var mp = get_viewport().get_mouse_position()
				var mm_rect = Rect2(_minimap_panel.global_position, _minimap_panel.size)
				if mm_rect.has_point(mp):
					get_viewport().set_input_as_handled()
					return
		if not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.08, 0.5, 3.2)
		elif not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.08, 0.5, 3.2)

# ── RELAY STUBS ───────────────────────────────────────────────
func _on_relay_data(_from_peer: int, _data: Dictionary) -> void:
	pass  # TODO: multiplayer sync

func _on_peer_left(_peer_id: int) -> void:
	pass  # TODO: remove remote player
