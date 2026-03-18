@tool
extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  LunarStationScene.gd — miniSWG | Lunar Station
#
#  True 2.5D isometric scene with diamond-shaped map.
#  Uses TileMapLayer in isometric mode for the ground,
#  Y-sorted Node2D children for buildings and player.
#
#  Attach to a bare Node2D scene: lunar_station.tscn
# ============================================================

# ── ISOMETRIC GRID ──────────────────────────────────────────────
const TILE_W     : int   = 128           # tile pixel width (2:1 iso ratio)
const TILE_H     : int   = 64            # tile pixel height
const GRID_SIZE  : int   = 128           # 128×128 tile grid
const GRID_CENTER: int   = 64            # diamond center tile

# ── PALETTE — lunar station theme ──────────────────────────────
const C_SPACE_BG       = Color(0.02, 0.02, 0.06)         # starfield void
const C_LUNAR_GROUND   = Color(0.42, 0.40, 0.38)         # gray regolith
const C_LUNAR_DARK     = Color(0.28, 0.26, 0.24)         # crater shadows
const C_LUNAR_LIGHT    = Color(0.58, 0.56, 0.54)         # ridges
const C_DOME_GLASS     = Color(0.30, 0.75, 0.45, 0.70)   # green geodesic dome glass
const C_DOME_FRAME     = Color(0.70, 0.72, 0.74)         # metallic dome frame
const C_HANGAR_WALL    = Color(0.82, 0.84, 0.86)         # white/gray hangar walls
const C_HANGAR_ACCENT  = Color(0.30, 0.65, 0.72)         # teal accents
const C_SILO           = Color(0.68, 0.70, 0.72)         # storage cylinders
const C_ROCK           = Color(0.35, 0.32, 0.30)         # lunar rock formations
const C_CRATER_RIM     = Color(0.50, 0.48, 0.44)
const C_SHADOW         = Color(0.0, 0.0, 0.0, 0.25)
const C_PAD_SURFACE    = Color(0.48, 0.50, 0.54)         # landing pad metal
const C_PAD_MARKINGS   = Color(0.90, 0.60, 0.10)         # orange landing markers
const C_STATION_GLOW   = Color(0.30, 0.65, 0.90, 0.40)   # blue ambient glow

# ── SCENE NODES ────────────────────────────────────────────────
var _tilemap       : TileMapLayer = null
var _world_layer   : Node2D       = null   # y_sort container for player + buildings
var _camera        : Camera2D     = null
var _player        : Node         = null
var _select_layer  : CanvasLayer  = null
var _hud           : CanvasLayer  = null
var _cam_zoom_base : float        = 2.5
var _cam_zoom_target : float      = 2.5
var _zoom_locked   : bool         = true   # locked at max zoom until unlocked in settings
var _pending_nickname : String    = ""

@warning_ignore("unused_private_class_variable")

# Decorations (seeded, deterministic)
var _stars         : Array = []   # background starfield points
var _rocks         : Array = []   # rock scatter positions
var _craters       : Array = []   # crater positions

# HUD refs
var _player_frame    : Panel        = null
var _player_name_lbl : Label        = null
var _hp_bar          : ProgressBar  = null
var _mp_bar          : ProgressBar  = null
var _xp_bar          : ProgressBar  = null
var _hp_bar_lbl      : Label        = null
var _mp_bar_lbl      : Label        = null
var _xp_bar_lbl      : Label        = null
var _hp_pct_lbl      : Label        = null
var _level_lbl       : Label        = null
var _tgt_panel       : Panel        = null
var _tgt_name_lbl    : Label        = null
var _tgt_hp_bar      : ProgressBar  = null
var _tgt_hp_lbl      : Label        = null
var _tgt_mp_bar      : ProgressBar  = null
var _minimap_panel   : Panel        = null
var _minimap_draw    : Control      = null
var _mm_location_lbl : Label        = null
var _mm_channel_lbl  : Label        = null

# Multiplayer
var _remote_players  : Dictionary   = {}
var _broadcast_timer : float        = 0.0
var _scene_time      : float        = 0.0

# Music
var _music : AudioStreamPlayer = null

# Social / gameplay systems
var _options_panel : Node = null
var _duel_system   : Node = null
var _party_system  : Node = null
var _trade_system  : Node = null

# Mission state
var _mission_active  : bool   = false
var _mission_name    : String = ""
var _mission_payout  : int    = 0
var _target_world    : Vector2 = Vector2.ZERO

# Player targeting
var _player_target_peer : int = -1

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_arena_scene")
	add_to_group("ui_layer")
	_gen_decorations()
	_setup_tilemap()
	_setup_camera()
	_start_music()
	_show_character_select()
	if not Relay.game_data_received.is_connected(_on_relay_data):
		Relay.game_data_received.connect(_on_relay_data)
	if not Relay.peer_left.is_connected(_on_peer_left):
		Relay.peer_left.connect(_on_peer_left)

func _gen_decorations() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 88442
	# Stars for background beyond diamond edge
	for _i in 600:
		_stars.append({
			"pos": Vector2(rng.randf_range(-4000, 20000), rng.randf_range(-4000, 12000)),
			"size": rng.randf_range(0.5, 2.0),
			"brightness": rng.randf_range(0.3, 1.0)
		})

func _start_music() -> void:
	# Reuse spaceport ambience for now — can swap for lunar-specific track later
	var stream = load("res://Sounds/spaceportambience.mp3") as AudioStream
	if stream == null: return
	_music = AudioStreamPlayer.new()
	_music.stream    = stream
	_music.volume_db = -22.0
	_music.bus       = "Master"
	add_child(_music)
	_music.play()

# ── TILEMAP SETUP ─────────────────────────────────────────────
func _setup_tilemap() -> void:
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_size  = Vector2i(TILE_W, TILE_H)

	var source = TileSetAtlasSource.new()
	var tex    = load("res://Assets/Tilesets/lunarterrain.png") as Texture2D
	if tex == null:
		push_warning("LunarStation: could not load lunarterrain.png")
		return
	source.texture             = tex
	source.texture_region_size = Vector2i(TILE_W, TILE_H)

	# Register all tile regions from the atlas (1536x1024 → 12 cols x 16 rows = 192 tiles)
	@warning_ignore("integer_division")
	var atlas_cols : int = int(tex.get_width())  / TILE_W   # 12
	@warning_ignore("integer_division")
	var atlas_rows : int = int(tex.get_height()) / TILE_H   # 16
	var tile_coords : Array[Vector2i] = []
	for ay in atlas_rows:
		for ax in atlas_cols:
			source.create_tile(Vector2i(ax, ay))
			tile_coords.append(Vector2i(ax, ay))
	tileset.add_source(source, 0)

	# Background node — draws space/starfield BEHIND the tilemap
	var bg_node = Node2D.new()
	bg_node.z_index = -10
	bg_node.set_script(_make_bg_script())
	add_child(bg_node)

	_tilemap = TileMapLayer.new()
	_tilemap.tile_set = tileset
	add_child(_tilemap)

	# Paint diamond-shaped ground with randomly selected tiles (seeded for determinism)
	var tile_rng = RandomNumberGenerator.new()
	tile_rng.seed = 55123
	var num_tiles = tile_coords.size()
	for tx in GRID_SIZE:
		for ty in GRID_SIZE:
			if abs(tx - GRID_CENTER) + abs(ty - GRID_CENTER) <= GRID_CENTER:
				var pick = tile_coords[tile_rng.randi_range(0, num_tiles - 1)]
				_tilemap.set_cell(Vector2i(tx, ty), 0, pick)

	# Y-sort container for player, buildings, and objects
	_world_layer = Node2D.new()
	_world_layer.y_sort_enabled = true
	add_child(_world_layer)

# ── CAMERA ────────────────────────────────────────────────────
func _setup_camera() -> void:
	_camera      = Camera2D.new()
	_camera.name = "Camera"
	# Start at diamond center
	_camera.position = _tile_to_world(GRID_CENTER, GRID_CENTER)
	_camera.zoom     = Vector2(2.5, 2.5)
	# Set limits based on isometric world extents
	var top_left  = _tile_to_world(0, 0)
	var bot_right = _tile_to_world(GRID_SIZE, GRID_SIZE)
	var left_pt   = _tile_to_world(0, GRID_SIZE)
	var right_pt  = _tile_to_world(GRID_SIZE, 0)
	_camera.limit_left   = int(left_pt.x) - 200
	_camera.limit_right  = int(right_pt.x) + 200
	_camera.limit_top    = int(top_left.y) - 200
	_camera.limit_bottom = int(bot_right.y) + 200
	add_child(_camera)
	_camera.make_current()

# ── COORDINATE HELPERS ────────────────────────────────────────
func _tile_to_world(tx: int, ty: int) -> Vector2:
	if _tilemap:
		return _tilemap.map_to_local(Vector2i(tx, ty))
	# Fallback manual calc
	return Vector2(float(tx - ty) * TILE_W * 0.5, float(tx + ty) * TILE_H * 0.5)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	if _tilemap:
		return _tilemap.local_to_map(world_pos)
	return Vector2i(0, 0)

func _is_in_diamond(tx: int, ty: int) -> bool:
	return abs(tx - GRID_CENTER) + abs(ty - GRID_CENTER) <= GRID_CENTER

# ── BACKGROUND SCRIPT (runs on a child node behind tilemap) ───
func _make_bg_script() -> GDScript:
	var src = """extends Node2D
var _scene : Node = null
func _ready():
	_scene = get_parent()
func _process(_d):
	queue_redraw()
func _draw():
	var extents = 20000.0
	draw_rect(Rect2(-extents, -extents, extents * 2, extents * 2), Color(0.02, 0.02, 0.06))
	var stars = _scene.get("_stars")
	var t = _scene.get("_scene_time")
	if stars == null or t == null: return
	for star in stars:
		var twinkle = 0.6 + 0.4 * sin(float(t) * 1.5 + star.pos.x * 0.01)
		var alpha = star.brightness * twinkle
		draw_circle(star.pos, star.size, Color(0.85, 0.88, 1.0, alpha))
"""
	var s = GDScript.new()
	s.source_code = src
	s.reload()
	return s

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	_cam_zoom_base = lerpf(_cam_zoom_base, _cam_zoom_target, 1.0 - exp(-8.0 * delta))
	_camera.zoom = Vector2.ONE * _cam_zoom_base
	if _minimap_draw != null and is_instance_valid(_minimap_draw):
		_minimap_draw.queue_redraw()
	if is_instance_valid(_player):
		# Dreadmyst-style camera: player runs ahead, camera smoothly catches up
		# Low lerp speed = more lag = player visibly leads the camera
		# When player stops, camera gently glides to center on them
		_camera.global_position = _camera.global_position.lerp(_player.global_position, 1.0 - exp(-3.0 * delta))
		_broadcast_timer += delta
		if _broadcast_timer >= 0.05:
			_broadcast_timer = 0.0
			var _mv = _player.get("_mounted")
			var _is_mnt  = (_mv != null and _mv == true)
			var _m_angle = 0.0
			var _m_type  = "fighter"
			if _is_mnt:
				var _av = _player.get("_mount_angle")
				if _av != null: _m_angle = float(_av)
				var _mi = _player.get("_mount_item")
				if _mi is Dictionary: _m_type = str(_mi.get("subtype", "fighter"))
			var _phv = _player.get("hp");     var _php = float(_phv) if _phv != null else 100.0
			var _pmv = _player.get("max_hp"); var _pmp = float(_pmv) if _pmv != null else 100.0
			Relay.send_game_data({
				"cmd":         "move",
				"x":           _player.global_position.x,
				"y":           _player.global_position.y,
				"class":       str(_player.get("character_class") if _player.get("character_class") != null else "melee"),
				"nick":        PlayerData.nickname,
				"mounted":     _is_mnt,
				"mount_angle": _m_angle,
				"mount_type":  _m_type,
				"hp":          _php,
				"max_hp":      _pmp,
			})
	# Smooth remote player positions
	var lerp_w = 1.0 - exp(-12.0 * delta)
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if is_instance_valid(rp) and rp.has_meta("target_pos"):
			rp.position = rp.position.lerp(rp.get_meta("target_pos"), lerp_w)
	_update_hud()
	_update_mission_compass()
	_tick_poison(delta)
	_scene_time += delta

# ── INPUT ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_clear_target()
		if is_instance_valid(_player):
			match event.keycode:
				KEY_F1: _spawn_dummy()
				KEY_F2: _spawn_boss()
				KEY_F3: _spawn_cyberlord()
				KEY_F4: _spawn_zerg_mob()
				KEY_F5: _spawn_cyber_mob()
				KEY_H:
					if _player.has_method("add_credits"):
						_player.call("add_credits", 5000)
					else:
						_player.set("credits", (_player.get("credits") as int) + 5000)
	if not _zoom_locked and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.15, 0.5, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.15, 0.5, 4.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.15, 0.5, 4.0)
		elif not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.15, 0.5, 4.0)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_click(event)

func _handle_click(event: InputEventMouseButton) -> void:
	if not is_instance_valid(_player): return
	var vp  = get_viewport()
	var cam = vp.get_camera_2d() if vp else null
	if cam == null: return
	var mouse_world = (event.position - vp.get_visible_rect().size * 0.5) / cam.zoom + cam.global_position

	# Check click near a remote player (targeting)
	var closest_dist = 40.0
	var closest_pid  = -1
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if not is_instance_valid(rp): continue
		var d = rp.global_position.distance_to(mouse_world)
		if d < closest_dist:
			closest_dist = d
			closest_pid  = pid
	# Check click near a targetable mob
	var closest_mob : Node = null
	var mob_dist    = 40.0
	for node in get_tree().get_nodes_in_group("targetable"):
		if not is_instance_valid(node): continue
		var d2 = node.global_position.distance_to(mouse_world)
		if d2 < mob_dist:
			mob_dist    = d2
			closest_mob = node

	if closest_mob != null:
		_player.set("_current_target", closest_mob)
		_player_target_peer = -1
		_update_target_panel(closest_mob)
	elif closest_pid >= 0:
		_player_target_peer = closest_pid
		_player.set("_current_target", null)
		_update_target_panel_player(closest_pid)
		if event.button_index == MOUSE_BUTTON_RIGHT and _options_panel != null:
			var rp2 = _remote_players[closest_pid]
			if is_instance_valid(rp2):
				_options_panel.call("show_for", closest_pid,
					str(rp2.get_meta("character_name")), event.position)
	else:
		_clear_target()

func _clear_target() -> void:
	_player_target_peer = -1
	if is_instance_valid(_player):
		_player.set("_current_target", null)
	if _tgt_panel and is_instance_valid(_tgt_panel):
		_tgt_panel.visible = false

func _update_target_panel(_mob: Node) -> void:
	if _tgt_panel == null: return
	_tgt_panel.visible = true
	var mob_name = ""
	if _mob.has_method("get") and _mob.get("mob_name") != null:
		mob_name = str(_mob.get("mob_name"))
	else:
		mob_name = _mob.name
	_tgt_name_lbl.text = mob_name

func _update_target_panel_player(pid: int) -> void:
	if _tgt_panel == null: return
	if not _remote_players.has(pid): return
	var rp = _remote_players[pid]
	if not is_instance_valid(rp): return
	_tgt_panel.visible = true
	_tgt_name_lbl.text = str(rp.get_meta("character_name"))

# ============================================================
#  CHARACTER SELECT
# ============================================================
func _show_character_select() -> void:
	_select_layer       = CanvasLayer.new()
	_select_layer.layer = 20
	add_child(_select_layer)

	var vp = get_viewport().get_visible_rect().size

	var bg       = ColorRect.new()
	bg.size      = vp
	bg.color     = Color(0.02, 0.03, 0.08, 0.96)
	_select_layer.add_child(bg)

	var title = Label.new()
	title.add_theme_font_override("font", _roboto)
	title.text = "LUNAR STATION  —  CHOOSE YOUR CLASS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 55)
	title.position = Vector2(0, vp.y * 0.12)
	_select_layer.add_child(title)

	var hint = Label.new()
	hint.add_theme_font_override("font", _roboto)
	hint.text = "WASD / Arrow Keys to move  ·  Tab to cycle targets  ·  Auto-attack in range  ·  P for Skills  ·  I for Inventory"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.68))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size     = Vector2(vp.x, 24)
	hint.position = Vector2(0, vp.y * 0.12 + 62)
	_select_layer.add_child(hint)

	var classes = [
		{ "key":"scrapper",  "label":"BRAWLER",  "color":Color(0.40,0.85,0.30), "desc":"Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"ranged",   "label":"MARKSMAN", "color":Color(0.35,0.80,0.95), "desc":"Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"medic",    "label":"MEDIC",    "color":Color(0.30,0.85,0.90), "desc":"Combat medic.\nHeals allies with\ncanisters, poisons\nenemies.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
		{ "key":"scrapper","label":"BRAWLER II","color":Color(0.45,0.90,0.35), "desc":"Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"future2",  "label":"?",        "color":Color(0.40,0.40,0.50), "desc":"Coming soon...", "locked":true },
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

	var uname = PlayerData.username if PlayerData.username.length() > 0 else "Adventurer"
	var welcome_lbl = Label.new()
	welcome_lbl.add_theme_font_override("font", _roboto)
	welcome_lbl.text = "Welcome,  %s  —  choose your class" % uname
	welcome_lbl.add_theme_font_size_override("font_size", 15)
	welcome_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 0.92))
	welcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome_lbl.size         = Vector2(vp.x, 28)
	welcome_lbl.position     = Vector2(0, card_y + card_h + 28.0)
	welcome_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_layer.add_child(welcome_lbl)

	for i in select_buttons.size():
		if not classes[i].get("locked", false):
			select_buttons[i].disabled = false

func _build_class_card(cls: Dictionary, pos: Vector2, sz: Vector2) -> Button:
	var is_locked = cls.get("locked", false)
	var panel      = Panel.new()
	panel.position = pos; panel.size = sz
	var sty        = StyleBoxFlat.new()
	sty.bg_color   = Color(0.04, 0.05, 0.12, 0.92) if not is_locked else Color(0.06, 0.06, 0.08, 0.80)
	sty.border_color = cls.color if not is_locked else Color(0.25, 0.25, 0.30, 0.60)
	sty.set_border_width_all(2); sty.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sty)
	_select_layer.add_child(panel)

	if is_locked:
		var q_lbl = Label.new()
		q_lbl.add_theme_font_override("font", _roboto)
		q_lbl.text = "?"
		q_lbl.add_theme_font_size_override("font_size", 72)
		q_lbl.add_theme_color_override("font_color", Color(0.30, 0.30, 0.38, 0.50))
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.size = Vector2(sz.x, sz.y)
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(q_lbl)
		var sub = Label.new()
		sub.add_theme_font_override("font", _roboto)
		sub.text = "COMING SOON"
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.35, 0.35, 0.42, 0.50))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(sz.x, 20); sub.position = Vector2(0, sz.y - 36)
		panel.add_child(sub)
		var dummy_btn = Button.new()
		dummy_btn.visible = false; dummy_btn.disabled = true
		panel.add_child(dummy_btn)
		return dummy_btn

	var lbl = Label.new()
	lbl.add_theme_font_override("font", _roboto)
	lbl.text = cls.label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", cls.color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(sz.x, 36); lbl.position = Vector2(0, 16)
	panel.add_child(lbl)

	var desc = Label.new()
	desc.add_theme_font_override("font", _roboto)
	desc.text = cls.desc
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	desc.size = Vector2(sz.x - 16, sz.y - 110); desc.position = Vector2(8, 58)
	panel.add_child(desc)

	var btn           = Button.new()
	btn.text          = "PLAY AS " + cls.label
	btn.size          = Vector2(sz.x - 16, 40)
	btn.position      = Vector2(8, sz.y - 50)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", cls.color)
	var bsty          = StyleBoxFlat.new()
	bsty.bg_color     = Color(0.06, 0.04, 0.14)
	bsty.border_color = cls.color
	bsty.set_border_width_all(1); bsty.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bsty)
	btn.pressed.connect(_on_class_selected.bind(cls.key))
	panel.add_child(btn)
	return btn

# ── CLASS SELECTED → SPAWN EVERYTHING ────────────────────────
func _on_class_selected(cls: String) -> void:
	_pending_nickname = PlayerData.nickname
	_select_layer.queue_free()
	_select_layer = null
	_spawn_buildings()
	_spawn_player(cls)
	_spawn_shop_terminal()
	_spawn_mission_terminal()
	_spawn_bank_terminal()
	_setup_hud(cls)
	_init_social_systems()
	_spawn_aadu_herds()
	_join_lunar()

# ── BUILDINGS (sprite-based from tileset atlas) ──────────────
# Grid layout: 6 columns × 10 rows per sheet
const SHEET_COLS : int = 6
const SHEET_ROWS : int = 10

func _spawn_buildings() -> void:
	var bscript = load("res://Scripts/LunarBuilding.gd")
	var s3 = load("res://Assets/Tilesets/moonshyt3_alpha.png") as Texture2D
	var s2 = load("res://Assets/Tilesets/moonshyt2_alpha.png") as Texture2D

	# Cell size auto-calculated from texture dimensions (works at any resolution)
	@warning_ignore("integer_division")
	var CW3 = int(s3.get_width())  / SHEET_COLS
	@warning_ignore("integer_division")
	var CH3 = int(s3.get_height()) / SHEET_ROWS
	@warning_ignore("integer_division")
	var CW2 = int(s2.get_width())  / SHEET_COLS
	@warning_ignore("integer_division")
	var CH2 = int(s2.get_height()) / SHEET_ROWS

	# ── Major Structures (from moonshyt3) ──
	_place_sprite(bscript, s3, _cell(0, 0, CW3, CH3), 64, 64, "COMMAND CENTER")
	_place_sprite(bscript, s3, _cell(2, 1, CW3, CH3), 56, 52, "NORTH HANGAR")
	_place_sprite(bscript, s3, _cell(4, 1, CW3, CH3), 72, 76, "SOUTH HANGAR")
	_place_sprite(bscript, s3, _cell(2, 0, CW3, CH3), 70, 64, "RESEARCH LAB")
	_place_sprite(bscript, s3, _cell(1, 1, CW3, CH3), 68, 60, "MEDICAL BAY")
	_place_sprite(bscript, s3, _cell(0, 1, CW3, CH3), 74, 58, "STORAGE")
	_place_sprite(bscript, s3, _cell(3, 0, CW3, CH3), 58, 70, "BARRACKS")
	_place_sprite(bscript, s3, _cell(5, 1, CW3, CH3), 66, 72, "REFINERY")
	_place_sprite(bscript, s3, _cell(2, 2, CW3, CH3), 80, 54, "OBSERVATORY")
	_place_sprite(bscript, s3, _cell(3, 1, CW3, CH3), 62, 58, "SUPPLY DEPOT")
	_place_sprite(bscript, s3, _cell(1, 0, CW3, CH3), 66, 74, "CREW QUARTERS")
	_place_sprite(bscript, s3, _cell(4, 0, CW3, CH3), 55, 62, "BIODOME")
	_place_sprite(bscript, s3, _cell(5, 0, CW3, CH3), 76, 66, "GREENHOUSE")
	_place_sprite(bscript, s3, _cell(3, 2, CW3, CH3), 60, 56, "COMM ARRAY")
	_place_sprite(bscript, s3, _cell(0, 2, CW3, CH3), 54, 64, "OPERATIONS")

	# ── Additional structures (from moonshyt2) ──
	_place_sprite(bscript, s2, _cell(0, 5, CW2, CH2), 50, 68, "POWER STATION")
	_place_sprite(bscript, s2, _cell(1, 5, CW2, CH2), 78, 60, "SHIELD ARRAY")
	_place_sprite(bscript, s2, _cell(0, 6, CW2, CH2), 60, 66, "PROCESSING")
	_place_sprite(bscript, s2, _cell(1, 6, CW2, CH2), 72, 68, "COMMS TOWER")

	# ── Rock formations (scattered near diamond edges) ──
	var rock_cells = [
		_cell(0, 4, CW3, CH3), _cell(1, 4, CW3, CH3), _cell(2, 4, CW3, CH3),
		_cell(3, 4, CW3, CH3), _cell(4, 4, CW3, CH3), _cell(5, 4, CW3, CH3),
		_cell(0, 5, CW3, CH3), _cell(1, 5, CW3, CH3),
	]
	var rock_tiles = [
		Vector2i(30, 40), Vector2i(95, 38), Vector2i(20, 60),
		Vector2i(100, 65), Vector2i(35, 85), Vector2i(90, 80),
		Vector2i(45, 30), Vector2i(85, 30), Vector2i(25, 75),
		Vector2i(98, 72), Vector2i(40, 95), Vector2i(88, 92),
	]
	for i in rock_tiles.size():
		var rt = rock_tiles[i]
		if _is_in_diamond(rt.x, rt.y):
			_place_sprite(bscript, s3, rock_cells[i % rock_cells.size()], rt.x, rt.y, "")

	# ── Craters ──
	var crater_cells_arr = [
		_cell(2, 5, CW3, CH3), _cell(3, 5, CW3, CH3),
		_cell(4, 5, CW3, CH3), _cell(5, 5, CW3, CH3),
	]
	var crater_tiles = [
		Vector2i(42, 50), Vector2i(82, 55), Vector2i(55, 82),
		Vector2i(75, 45), Vector2i(48, 74), Vector2i(92, 68),
	]
	for i in crater_tiles.size():
		var ct = crater_tiles[i]
		if _is_in_diamond(ct.x, ct.y):
			_place_sprite(bscript, s3, crater_cells_arr[i % crater_cells_arr.size()], ct.x, ct.y, "")

# ── Sprite grid helper — returns Rect2 for a grid cell ───────
func _cell(col: int, row: int, cw: int, ch: int) -> Rect2:
	return Rect2(col * cw, row * ch, cw, ch)

# ── Place a sprite-based building at tile coords ─────────────
func _place_sprite(bscript: GDScript, tex: Texture2D, region: Rect2,
		tx: int, ty: int, label: String, sprite_scale: float = 1.0) -> Node2D:
	var node = Node2D.new()
	node.set_script(bscript)
	node.position = _tile_to_world(tx, ty)
	node.set_meta("label", label)
	node.set_meta("label_y", -region.size.y * sprite_scale * 0.38)

	var atlas = AtlasTexture.new()
	atlas.atlas  = tex
	atlas.region = region

	var sprite    = Sprite2D.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale  = Vector2(sprite_scale, sprite_scale)
	# Offset so building base aligns with Y-sort anchor (node origin)
	sprite.offset = Vector2(0, -region.size.y * 0.35)
	node.add_child(sprite)

	_world_layer.add_child(node)
	return node

# ── PLAYER SPAWN ─────────────────────────────────────────────
func _spawn_player(cls: String) -> void:
	var script = load("res://Scripts/BossArenaPlayer.gd")
	_player    = CharacterBody2D.new()
	_player.set_script(script)
	_player.set("character_class", cls)

	var sprite          = AnimatedSprite2D.new()
	sprite.name         = "Sprite"
	sprite.sprite_frames = _build_frames(cls)
	if cls == "melee":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
	elif cls == "scrapper":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "medic":
		sprite.scale  = Vector2(44.0 / 144.0, 44.0 / 144.0)
		sprite.offset = Vector2(0, -72)
	elif cls == "ranged":
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -16)
	else:
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -12)
	_player.add_child(sprite)

	if cls == "scrapper":
		_attach_split_body_shaders(sprite, _build_frames(cls))

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12.0; shape.height = 20.0
	col.shape = shape
	_player.add_child(col)

	# Spawn at diamond center
	_player.position = _tile_to_world(GRID_CENTER, GRID_CENTER)
	_world_layer.add_child(_player)
	if _pending_nickname.length() > 0:
		_player.set("character_name", _pending_nickname)

# ── Split-body blend (upper/lower clip shaders for brawlernew) ──
func _attach_split_body_shaders(lower_sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	var upper = AnimatedSprite2D.new()
	upper.name = "SpriteUpper"
	upper.sprite_frames = frames
	upper.scale  = lower_sprite.scale
	upper.offset = lower_sprite.offset
	upper.visible = false
	var upper_shader = Shader.new()
	upper_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tif (UV.y > 0.55) discard;\n}\n"
	var upper_mat = ShaderMaterial.new()
	upper_mat.shader = upper_shader
	upper.material = upper_mat
	lower_sprite.get_parent().add_child(upper)

# ── SPRITE FRAMES ────────────────────────────────────────────
func _build_frames(cls: String) -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	match cls:
		"melee":
			var base = "res://Characters/minimmo/meleenew/"
			for dir in ["s","n","e","w","se","sw","nw"]:
				_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   160,160,8,8.0)
				_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    160,160,8,10.0)
				_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",160,160,6,12.0,false)
		"mage":
			var base = "res://Characters/minimmo/mage/"
			for dir in ["s","n","e","w"]:
				_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   24,24,8,8.0)
				_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    24,24,4,10.0)
				_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",24,24,6,12.0,false)
		"ranged":
			var base = "res://Characters/minimmo/ranged/"
			for dir in ["s","n","e","w"]:
				_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   24,24,8,8.0)
				_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    24,24,8,10.0)
				_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",32,32,16,14.0,false)
		"medic":
			var base = "res://Characters/minimmo/medic/"
			for dir in ["s","n","e","w","se","sw","nw"]:
				_add_strip(frames,"idle_"+dir,   base+"idle/idle_"+dir+".png",   144,144,8,8.0)
				_add_strip(frames,"run_"+dir,    base+"run/run_"+dir+".png",     144,144,8,10.0)
				_add_strip(frames,"attack_"+dir, base+"toss/toss_"+dir+".png",   144,144,7,12.0,false)
		"scrapper":
			var bnbase = "res://Characters/NEWFOUNDMETHOD/Brawler/"
			var cw = 768; var ch = 448
			for dir in ["n","e","w","se","sw","nw"]:
				_add_grid(frames,"idle_"+dir, bnbase+"idle/idle_"+dir+".png", cw,ch,4,29,10.0)
			_add_grid(frames,"idle_s", bnbase+"idle/idle_sw.png", cw,ch,4,29,10.0)
			_add_grid(frames,"idle_ne", bnbase+"idle/idle_ne.png", cw,ch,4,28,10.0)
			for dir in ["n","e","ne","se","sw"]:
				_add_grid(frames,"run_"+dir, bnbase+"run/run_"+dir+".png", cw,ch,4,17,20.0)
			for dir in ["w","nw"]:
				_add_grid(frames,"run_"+dir, bnbase+"run/run_"+dir+".png", cw,ch,4,17,14.0,true,true)
			_add_grid(frames,"run_s", bnbase+"run/run_s.png", cw,ch,4,17,20.0)
			for dir in ["s","n","ne","se"]:
				_add_grid(frames,"attack_"+dir, bnbase+"attack/attack_"+dir+".png", cw,ch,4,29,24.0,false)
			_add_grid(frames,"attack_e", bnbase+"attack/attack_e.png", cw,ch,4,24,24.0,false)
			for dir in ["sw","nw"]:
				_add_grid(frames,"attack_"+dir, bnbase+"attack/attack_"+dir+".png", cw,ch,4,29,24.0,false,true)
			_add_grid(frames,"attack_w", bnbase+"attack/attack_w.png", cw,ch,4,24,24.0,false,true)
	return frames

func _add_grid(frames:SpriteFrames, anim_name:String, path:String,
		cell_w:int, cell_h:int, cols:int, total_frames:int, fps:float,
		loop:bool=true, hflip:bool=false) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("LunarStation: could not load "+path)
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in total_frames:
		var col = i % cols
		var row = i / cols
		if hflip:
			col = (cols - 1) - col
		var atlas = AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(col*cell_w, row*cell_h, cell_w, cell_h)
		frames.add_frame(anim_name, atlas)

func _add_strip(frames:SpriteFrames, anim_name:String, path:String,
		frame_w:int, frame_h:int, frame_count:int, fps:float, loop:bool=true) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("LunarStation: could not load "+path)
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i*frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)

func _build_boss_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Enemies/ZergBoss/"
	for dir in ["s","n","e","w"]:
		_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   132,132,8,7.0)
		_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    132,132,8,10.0)
		_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",132,132,8,12.0,false)
	return frames

func _build_aadu_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Enemies/Aadu/"
	var dirs = ["s","n","e","w","se","sw","ne","nw"]
	for dir in dirs:
		_add_strip(frames, "idle_"   + dir, base + "idle/idle_"    + dir + ".png", 160, 160, 5,  7.0)
		_add_strip(frames, "run_"    + dir, base + "run/run_"       + dir + ".png", 160, 160, 8, 10.0)
		_add_strip(frames, "attack_" + dir, base + "attack/attack_" + dir + ".png", 160, 160, 8, 11.0, false)
		_add_strip(frames, "eat_"    + dir, base + "eat/eat_"       + dir + ".png", 160, 160, 8,  6.0)
		_add_strip(frames, "die_"    + dir, base + "die/die_"       + dir + ".png", 160, 160, 8,  8.0, false)
	return frames

# ── HUD (Dreadmyst dark-fantasy MMO style) ────────────────────
var _frame_drag      : bool        = false
var _portrait_rect   : TextureRect = null
var _mission_compass : Control     = null
var _mission_terminal_pos : Vector2 = Vector2.ZERO

func _setup_hud(_cls: String) -> void:
	_hud       = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var vp   = get_viewport().get_visible_rect().size
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	var bold = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf") if ResourceLoader.exists("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf") else font

	# ── Player frame (top-left) ── portrait + name + bars ──────
	const PF_W  : float = 290.0
	const PF_H  : float = 100.0
	const PORT  : float = 64.0
	const BAR_X : float = 78.0
	const BAR_W : float = 200.0

	_player_frame          = Panel.new()
	_player_frame.size     = Vector2(PF_W, PF_H)
	_player_frame.position = Vector2(10, 10)
	var pf_sty             = StyleBoxFlat.new()
	pf_sty.bg_color        = Color(0.06, 0.05, 0.04, 0.92)
	pf_sty.border_color    = Color(0.35, 0.28, 0.18, 0.90)
	pf_sty.set_border_width_all(2)
	pf_sty.shadow_color    = Color(0.0, 0.0, 0.0, 0.50)
	pf_sty.shadow_size     = 4
	_player_frame.add_theme_stylebox_override("panel", pf_sty)
	_hud.add_child(_player_frame)
	_player_frame.gui_input.connect(_on_frame_drag)

	# Portrait background
	var port_bg       = ColorRect.new()
	port_bg.color     = Color(0.03, 0.03, 0.03, 1.0)
	port_bg.size      = Vector2(PORT + 4, PORT + 4)
	port_bg.position  = Vector2(5, 5)
	port_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(port_bg)

	_portrait_rect          = TextureRect.new()
	_portrait_rect.size     = Vector2(PORT, PORT)
	_portrait_rect.position = Vector2(7, 7)
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_portrait_rect)

	var cls_letter        = Label.new()
	cls_letter.name       = "PortraitLetter"
	cls_letter.add_theme_font_override("font", bold)
	cls_letter.add_theme_font_size_override("font_size", 28)
	cls_letter.add_theme_color_override("font_color", Color(0.85, 0.78, 0.60))
	cls_letter.text       = _cls.substr(0, 1).to_upper() if _cls.length() > 0 else "?"
	cls_letter.size       = Vector2(PORT, PORT)
	cls_letter.position   = Vector2(7, 7)
	cls_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_letter.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cls_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(cls_letter)

	# Level badge
	_level_lbl = Label.new()
	_level_lbl.add_theme_font_override("font", bold)
	_level_lbl.add_theme_font_size_override("font_size", 11)
	_level_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_level_lbl.text     = "1"
	_level_lbl.size     = Vector2(22, 16)
	_level_lbl.position = Vector2(7, PORT - 6)
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_level_lbl)
	var lvl_bg        = ColorRect.new()
	lvl_bg.color      = Color(0.10, 0.08, 0.04, 0.95)
	lvl_bg.size       = Vector2(22, 16)
	lvl_bg.position   = Vector2(7, PORT - 6)
	lvl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(lvl_bg)
	_player_frame.move_child(lvl_bg, _player_frame.get_child_count() - 2)

	# Player name
	_player_name_lbl = Label.new()
	var archivo = load("res://Assets/Fonts/Archivo_Black/ArchivoBlack-Regular.ttf")
	_player_name_lbl.add_theme_font_override("font", archivo if archivo else font)
	_player_name_lbl.add_theme_font_size_override("font_size", 13)
	_player_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
	_player_name_lbl.position = Vector2(BAR_X, 6)
	_player_name_lbl.size     = Vector2(BAR_W, 18)
	_player_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_player_name_lbl)

	# HP bar
	_hp_bar = _make_bar(Color(0.72, 0.14, 0.10), Vector2(BAR_X, 26), Vector2(BAR_W, 18))
	_player_frame.add_child(_hp_bar)
	_hp_bar_lbl = _make_bar_label(Vector2(BAR_X, 26), Vector2(BAR_W, 18))
	_player_frame.add_child(_hp_bar_lbl)

	# MP bar
	_mp_bar = _make_bar(Color(0.15, 0.30, 0.72), Vector2(BAR_X, 48), Vector2(BAR_W, 16))
	_player_frame.add_child(_mp_bar)
	_mp_bar_lbl = _make_bar_label(Vector2(BAR_X, 48), Vector2(BAR_W, 16))
	_player_frame.add_child(_mp_bar_lbl)

	# XP bar
	_xp_bar = _make_bar(Color(0.82, 0.68, 0.15), Vector2(BAR_X, 68), Vector2(BAR_W, 8))
	_player_frame.add_child(_xp_bar)
	_xp_bar_lbl = _make_bar_label(Vector2(BAR_X, 67), Vector2(BAR_W, 10))
	_xp_bar_lbl.add_theme_font_size_override("font_size", 8)
	_player_frame.add_child(_xp_bar_lbl)

	# HP percentage overlay
	_hp_pct_lbl = Label.new()
	_hp_pct_lbl.name = "HPPct"
	_hp_pct_lbl.add_theme_font_override("font", font)
	_hp_pct_lbl.add_theme_font_size_override("font_size", 10)
	_hp_pct_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_hp_pct_lbl.size     = Vector2(40, 18)
	_hp_pct_lbl.position = Vector2(BAR_X + BAR_W - 42, 26)
	_hp_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_hp_pct_lbl)

	# Top gold accent line
	var pf_accent        = ColorRect.new()
	pf_accent.color      = Color(0.55, 0.42, 0.18, 0.70)
	pf_accent.size       = Vector2(PF_W - 4, 1)
	pf_accent.position   = Vector2(2, 2)
	pf_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(pf_accent)

	# ── Target panel (top-center) ────────────────────────────────
	const TGT_W : float = 280.0
	const TGT_H : float = 72.0
	_tgt_panel          = Panel.new()
	_tgt_panel.size     = Vector2(TGT_W, TGT_H)
	_tgt_panel.position = Vector2(vp.x * 0.5 - TGT_W * 0.5, 10)
	_tgt_panel.visible  = false
	var tp_sty          = StyleBoxFlat.new()
	tp_sty.bg_color     = Color(0.06, 0.04, 0.04, 0.92)
	tp_sty.border_color = Color(0.50, 0.18, 0.12, 0.90)
	tp_sty.set_border_width_all(2)
	tp_sty.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	tp_sty.shadow_size  = 3
	_tgt_panel.add_theme_stylebox_override("panel", tp_sty)
	_hud.add_child(_tgt_panel)

	var tgt_accent        = ColorRect.new()
	tgt_accent.color      = Color(0.65, 0.18, 0.12, 0.80)
	tgt_accent.size       = Vector2(TGT_W - 4, 1)
	tgt_accent.position   = Vector2(2, 2)
	tgt_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tgt_panel.add_child(tgt_accent)

	_tgt_name_lbl = Label.new()
	_tgt_name_lbl.add_theme_font_override("font", bold)
	_tgt_name_lbl.add_theme_font_size_override("font_size", 13)
	_tgt_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.72, 0.65))
	_tgt_name_lbl.position = Vector2(10, 6)
	_tgt_name_lbl.size     = Vector2(TGT_W - 20, 18)
	_tgt_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tgt_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tgt_panel.add_child(_tgt_name_lbl)

	_tgt_hp_bar = _make_bar(Color(0.72, 0.14, 0.10), Vector2(10, 28), Vector2(TGT_W - 20, 16))
	_tgt_panel.add_child(_tgt_hp_bar)
	_tgt_hp_lbl = _make_bar_label(Vector2(10, 28), Vector2(TGT_W - 20, 16))
	_tgt_panel.add_child(_tgt_hp_lbl)

	_tgt_mp_bar = _make_bar(Color(0.15, 0.30, 0.72), Vector2(10, 48), Vector2(TGT_W - 20, 12))
	_tgt_panel.add_child(_tgt_mp_bar)

	# ── Minimap (top-right, diamond-shaped) ───────────────────
	const MMAP_W : float = 180.0
	const MMAP_H : float = 180.0
	const MMAP_X : float = -196.0

	_mm_location_lbl = Label.new()
	_mm_location_lbl.add_theme_font_override("font", bold)
	_mm_location_lbl.add_theme_font_size_override("font_size", 12)
	_mm_location_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
	_mm_location_lbl.text = "LUNAR STATION"
	_mm_location_lbl.size = Vector2(MMAP_W, 18)
	_mm_location_lbl.position = Vector2(vp.x + MMAP_X, 10)
	_mm_location_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mm_location_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_mm_location_lbl)

	_minimap_panel          = Panel.new()
	_minimap_panel.size     = Vector2(MMAP_W, MMAP_H)
	_minimap_panel.position = Vector2(vp.x + MMAP_X, 28)
	var mm_sty            = StyleBoxFlat.new()
	mm_sty.bg_color       = Color(0.02, 0.02, 0.03, 1.0)
	mm_sty.border_color   = Color(0.0, 0.0, 0.0, 1.0)
	mm_sty.set_border_width_all(3)
	mm_sty.set_corner_radius_all(1)
	mm_sty.shadow_color   = Color(0.0, 0.0, 0.0, 0.65)
	mm_sty.shadow_size    = 8
	_minimap_panel.add_theme_stylebox_override("panel", mm_sty)
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_minimap_panel)

	var mm_script = load("res://Scripts/LunarMinimapDraw.gd")
	_minimap_draw             = mm_script.new()
	_minimap_draw.set("scene_ref", self)
	_minimap_draw.size        = Vector2(MMAP_W, MMAP_H)
	_minimap_draw.position    = Vector2.ZERO
	_minimap_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_minimap_panel.add_child(_minimap_draw)

	_mm_channel_lbl = Label.new()
	_mm_channel_lbl.add_theme_font_override("font", font)
	_mm_channel_lbl.add_theme_font_size_override("font_size", 10)
	_mm_channel_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.58))
	_mm_channel_lbl.text = "CHANNEL 1"
	_mm_channel_lbl.size = Vector2(MMAP_W, 16)
	_mm_channel_lbl.position = Vector2(vp.x + MMAP_X, 28 + MMAP_H + 4)
	_mm_channel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mm_channel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_mm_channel_lbl)

	# ── Settings & Help buttons below minimap ─────────────────
	var btn_y    : float = 28 + MMAP_H + 22
	var btn_half : float = (MMAP_W - 4) * 0.5

	var help_script = load("res://Scripts/HelpWindow.gd")
	if help_script:
		var help_win    = CanvasLayer.new()
		help_win.set_script(help_script)
		add_child(help_win)
		help_win.call("init")
		help_win.call("set_btn_pos", Vector2(vp.x + MMAP_X + btn_half + 4, btn_y))
		help_win.get("_btn").size = Vector2(btn_half, 24)

	var settings_script = load("res://Scripts/SettingsWindow.gd")
	if settings_script:
		var settings_win    = CanvasLayer.new()
		settings_win.set_script(settings_script)
		add_child(settings_win)
		settings_win.call("init", self)
		settings_win.call("set_btn_pos",  Vector2(vp.x + MMAP_X, btn_y))
		settings_win.call("set_fps_pos",  Vector2(vp.x + MMAP_X, btn_y + 28))
		settings_win.get("_btn").size     = Vector2(btn_half, 24)

	# Mission compass
	_mission_compass               = Control.new()
	_mission_compass.set_script(_mission_compass_script())
	_mission_compass.size          = vp
	_mission_compass.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_mission_compass.visible       = false
	_hud.add_child(_mission_compass)

func _make_bar(col: Color, pos: Vector2, sz: Vector2) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.size = sz; bar.position = pos
	bar.min_value = 0.0; bar.max_value = 100.0; bar.value = 100.0
	bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(1)
	fill.border_color = col.darkened(0.35)
	fill.set_border_width_all(1)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	bg.set_corner_radius_all(1)
	bg.border_color = Color(0.15, 0.12, 0.08, 0.80)
	bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _make_bar_label(pos: Vector2, sz: Vector2) -> Label:
	var l = Label.new()
	l.add_theme_font_override("font", _roboto)
	l.size = sz; l.position = pos
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.90))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _update_hud() -> void:
	if not is_instance_valid(_player): return
	if _player_name_lbl == null: return
	var cls    = _player.get("character_class") as String
	var name_s = _player.get("character_name") as String
	var lvl    = _player.get("level") as int
	_player_name_lbl.text = "%s  [%s]" % [name_s, cls.to_upper()]
	if _level_lbl: _level_lbl.text = str(lvl)
	var hp  = _player.get("hp") as float;       var mhp = _player.get("max_hp") as float
	var mp  = _player.get("mp") as float;       var mmp = _player.get("max_mp") as float
	var xp  = _player.get("exp_points") as float; var mxp = _player.get("exp_needed") as float
	_hp_bar.max_value = mhp; _hp_bar.value = hp
	_mp_bar.max_value = mmp; _mp_bar.value = mp
	_xp_bar.max_value = mxp; _xp_bar.value = xp
	var hp_pct = int(hp / maxf(mhp, 1.0) * 100.0)
	_hp_bar_lbl.text = "%d / %d" % [int(hp), int(mhp)]
	_mp_bar_lbl.text = "%d / %d" % [int(mp), int(mmp)]
	_xp_bar_lbl.text = "%d / %d" % [int(xp), int(mxp)]
	if _hp_pct_lbl: _hp_pct_lbl.text = "%d%%" % hp_pct
	# Target
	var tgt = _player.get("_current_target")
	if tgt != null and is_instance_valid(tgt):
		_tgt_panel.visible = true
		_tgt_name_lbl.text = tgt.get("enemy_name") if tgt.get("enemy_name") != null else "Target"
		var ehp  = tgt.get("hp") as float; var emhp = tgt.get("max_hp") as float
		_tgt_hp_bar.max_value = emhp; _tgt_hp_bar.value = ehp
		if _tgt_hp_lbl: _tgt_hp_lbl.text = "%d / %d" % [int(ehp), int(emhp)]
		if _tgt_mp_bar: _tgt_mp_bar.value = 0; _tgt_mp_bar.visible = false
	elif _player_target_peer != -1 and _remote_players.has(_player_target_peer):
		var ptgt = _remote_players[_player_target_peer]
		if is_instance_valid(ptgt):
			_tgt_panel.visible = true
			var ptgt_name = ptgt.get_meta("character_name", "Player_%d" % _player_target_peer)
			_tgt_name_lbl.text = str(ptgt_name)
			var php  = float(ptgt.get_meta("hp", 100.0))
			var pmhp = float(ptgt.get_meta("max_hp", 100.0))
			_tgt_hp_bar.max_value = pmhp; _tgt_hp_bar.value = php
			if _tgt_hp_lbl: _tgt_hp_lbl.text = "%d / %d" % [int(php), int(pmhp)]
			if _tgt_mp_bar: _tgt_mp_bar.visible = true; _tgt_mp_bar.value = 100
		else:
			_player_target_peer = -1
			_tgt_panel.visible  = false
	else:
		_tgt_panel.visible = false

func _on_frame_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_frame_drag = event.pressed
	elif event is InputEventMouseMotion and _frame_drag:
		var np = _player_frame.position + event.relative
		var vp2 = get_viewport().get_visible_rect().size
		np.x   = clampf(np.x, 0.0, vp2.x - _player_frame.size.x)
		np.y   = clampf(np.y, 0.0, vp2.y - _player_frame.size.y)
		_player_frame.position = np

func _mission_compass_script() -> GDScript:
	var src = """extends Control
var _target_world : Vector2 = Vector2.ZERO
var _player       : Node    = null
var _t            : float   = 0.0
func _process(d): _t += d; queue_redraw()
func _draw():
	if not is_instance_valid(_player): return
	if _target_world == Vector2.ZERO: return
	var vp    = get_viewport_rect().size
	var cx    = vp.x * 0.5
	var cy    = vp.y * 0.5
	var cam   = get_viewport().get_camera_2d()
	if cam == null: return
	var pscreen = Vector2(cx, cy)
	var zoom    = cam.zoom
	var cam_pos = cam.global_position
	var rel     = (_target_world - cam_pos) * zoom + vp * 0.5
	var dist_m  = int(_player.global_position.distance_to(_target_world) / 10.0)
	var angle   = pscreen.direction_to(rel).angle()
	var margin  = 48.0
	var edge    = Vector2(
		clampf(rel.x, margin, vp.x - margin),
		clampf(rel.y, margin, vp.y - margin)
	)
	if rel.x >= margin and rel.x <= vp.x - margin and rel.y >= margin and rel.y <= vp.y - margin:
		return
	var pulse = 0.75 + sin(_t * 4.0) * 0.25
	draw_set_transform(edge, angle + PI * 0.5, Vector2.ONE)
	var tip = Vector2(0, -14)
	var bl  = Vector2(-8,  6)
	var br  = Vector2( 8,  6)
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), Color(0.95, 0.82, 0.10, pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	if font:
		draw_string(font, edge + Vector2(-20, 20), "WAYPOINT", HORIZONTAL_ALIGNMENT_LEFT, 60, 9, Color(0.95, 0.82, 0.10, pulse))
		draw_string(font, edge + Vector2(-16, 31), "%dm" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, 40, 8, Color(1, 1, 1, pulse * 0.8))
"""
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func _mission_complete_label_script(payout: int) -> GDScript:
	var src = """extends Label
var _t : float = 0.0
func _ready(): text = "MISSION COMPLETE  +%dCR"
func _process(d):
	_t += d
	position.y -= d * 18.0
	modulate.a = clampf(1.0 - (_t - 2.5) / 1.5, 0.0, 1.0)
	if _t > 4.0: get_parent().queue_free()
""" % payout
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

# ── MULTIPLAYER ──────────────────────────────────────────────
func _join_lunar() -> void:
	if not Relay.connected: return
	if not Relay.server_list_received.is_connected(_on_server_list):
		Relay.server_list_received.connect(_on_server_list)
	Relay.request_server_list()

func _on_server_list(servers: Array) -> void:
	for s in servers:
		if s.get("name", "") == "MINISWG-LUNAR":
			Relay.join_server(s.get("id", ""))
			return
	Relay.host_server("MINISWG-LUNAR", 64)

func _on_relay_data(from_peer: int, data: Dictionary) -> void:
	if from_peer == Relay.my_peer_id: return
	var cmd = data.get("cmd", "")
	match cmd:
		"move":
			_handle_remote_move(data, from_peer)
		"chat":
			var nick = str(data.get("nick", "Player_%d" % from_peer))
			var msg  = str(data.get("msg",  ""))
			if msg.length() == 0: return
			var rp = _remote_players.get(from_peer)
			if is_instance_valid(rp):
				_show_remote_bubble(rp, nick, msg)
			_add_to_chat_log(nick, msg)
		"fireball":
			var sx = float(data.get("sx", 0.0)); var sy = float(data.get("sy", 0.0))
			var tx = float(data.get("tx", 0.0)); var ty = float(data.get("ty", 0.0))
			var ghost = Node2D.new(); ghost.position = Vector2(tx, ty); add_child(ghost)
			spawn_fireball(Vector2(sx, sy), ghost, 0.0, false)
			get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(ghost): ghost.queue_free())
		"bullet":
			var sx = float(data.get("sx", 0.0)); var sy = float(data.get("sy", 0.0))
			var tx = float(data.get("tx", 0.0)); var ty = float(data.get("ty", 0.0))
			var ghost = Node2D.new(); ghost.position = Vector2(tx, ty); add_child(ghost)
			spawn_bullet(Vector2(sx, sy), ghost, 0.0, false)
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(ghost): ghost.queue_free())
		"melee_hit":
			var wx  = float(data.get("x", 0.0)); var wy = float(data.get("y", 0.0))
			var col = Color(float(data.get("r", 1.0)), float(data.get("g", 0.3)), float(data.get("b", 0.1)))
			spawn_melee_hit(Vector2(wx, wy), col, false)
		"canister":
			var sx = float(data.get("sx", 0.0)); var sy = float(data.get("sy", 0.0))
			var tx = float(data.get("tx", 0.0)); var ty = float(data.get("ty", 0.0))
			var ghost = Node2D.new(); ghost.position = Vector2(tx, ty); add_child(ghost)
			spawn_canister(Vector2(sx, sy), ghost, 0.0, bool(data.get("heal", false)), false)
			get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(ghost): ghost.queue_free())
		"swing":
			var rp2 = _remote_players.get(from_peer)
			if not is_instance_valid(rp2): return
			var sw_script = load("res://Scripts/BossWeaponSwing.gd")
			if sw_script:
				var sw = Node2D.new(); sw.set_script(sw_script)
				sw.position = Vector2(0, -15)
				rp2.add_child(sw)
				var sw_item = {"type": str(data.get("itype", "knife")), "rarity": str(data.get("rarity", "white"))}
				sw.call("init", sw_item, str(data.get("facing", "s")))
		"death":
			_remove_remote_player(from_peer)
		"spawn_creature":
			var sx = float(data.get("x", 0.0))
			var sy = float(data.get("y", 0.0))
			var sp = Vector2(sx, sy)
			match str(data.get("type", "")):
				"dummy":      _spawn_dummy(sp, false)
				"boss":       _spawn_boss(sp, false)
				"cyberlord":  _spawn_cyberlord(sp, false)
				"zerg_mob":   _spawn_zerg_mob(sp, false)
				"cyber_mob":  _spawn_cyber_mob(sp, false)
		# ── Duel ─────────────────────────────────────────────────
		"duel_request":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_request", from_peer,
					str(data.get("from_nick", "Player_%d" % from_peer)))
		"duel_accept":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_accepted", from_peer)
		"duel_decline":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_declined", from_peer)
		"duel_damage":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_damage", float(data.get("amount", 0.0)))
		"duel_end":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_ended_by_peer", from_peer,
					bool(data.get("i_won", false)))
		# ── Party ─────────────────────────────────────────────────
		"party_invite":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_invite", from_peer,
					str(data.get("nick", "Player_%d" % from_peer)),
					data.get("members", []))
		"party_accept":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_accept", from_peer)
		"party_decline":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_decline", from_peer)
		"party_update":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_update",
					int(data.get("leader", -1)), data.get("members", []))
		"party_kick":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_kick", int(data.get("peer_id", -1)))
		"party_leave":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_leave", int(data.get("peer_id", from_peer)))
		# ── Trade ─────────────────────────────────────────────────
		"trade_request":
			if is_instance_valid(_trade_system):
				_trade_system.call("show_request", from_peer,
					str(data.get("nick", "Player_%d" % from_peer)))
		"trade_accept":
			if is_instance_valid(_trade_system):
				var rp3 = _remote_players.get(from_peer)
				var tnick = "Player_%d" % from_peer
				if is_instance_valid(rp3):
					var tn = rp3.get_meta("character_name", tnick)
					tnick = str(tn)
				_trade_system.call("open_trade", from_peer, tnick)
		"trade_decline":
			pass
		"trade_offer":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_offer",
					data.get("items", []), int(data.get("credits", 0)))
		"trade_confirm":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_confirm")
		"trade_complete":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_complete",
					data.get("items_from", []), int(data.get("creds_from", 0)),
					data.get("items_to",   []), int(data.get("creds_to",   0)))
		"trade_cancel":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_cancel")
		"party_xp":
			var xp_amt = float(data.get("amount", 0.0))
			if is_instance_valid(_player) and xp_amt > 0.0:
				_player.call("add_exp", xp_amt)
		"party_loot":
			if is_instance_valid(_player):
				var loot_item : Dictionary = data.get("item", {})
				if loot_item.size() > 0:
					_player.call("add_item_to_inventory", loot_item)
				var loot_creds = int(data.get("credits", 0))
				if loot_creds > 0:
					var cur_cr = int(_player.get("credits")) if _player.get("credits") != null else 0
					_player.set("credits", cur_cr + loot_creds)

func _handle_remote_move(data: Dictionary, from_peer: int) -> void:
	var target_pos = Vector2(float(data.get("x", 0)), float(data.get("y", 0)))
	var cls  = str(data.get("class", "melee"))
	var nick = str(data.get("nick", "???"))

	if not _remote_players.has(from_peer):
		_add_remote_player(from_peer, cls, nick, target_pos)
	var rp = _remote_players[from_peer]
	if not is_instance_valid(rp): return
	rp.set_meta("target_pos", target_pos)
	rp.set_meta("character_name", nick)

	# Update HP
	var hp  = float(data.get("hp", 100))
	var mhp = float(data.get("max_hp", 100))
	rp.set_meta("hp", hp)
	rp.set_meta("max_hp", mhp)

	# Update animation based on movement
	var diff = target_pos - rp.position
	var sprite = rp.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null: return
	if diff.length() > 3.0:
		var angle = diff.angle()
		var dir_name = _angle_to_dir(angle, cls)
		var anim = "run_" + dir_name
		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != anim: sprite.play(anim)
	else:
		var cur = sprite.animation as String
		if cur.begins_with("run_"):
			var idle_anim = "idle_" + cur.substr(4)
			if sprite.sprite_frames.has_animation(idle_anim):
				sprite.play(idle_anim)

func _angle_to_dir(angle: float, cls: String) -> String:
	var has_8dir = (cls == "melee" or cls == "scrapper" or cls == "medic")
	var deg = rad_to_deg(angle)
	if deg < 0: deg += 360.0
	if has_8dir:
		if deg < 22.5 or deg >= 337.5: return "e"
		elif deg < 67.5:  return "se"
		elif deg < 112.5: return "s"
		elif deg < 157.5: return "sw"
		elif deg < 202.5: return "w"
		elif deg < 247.5: return "nw"
		elif deg < 292.5: return "n"
		else:             return "ne"
	else:
		if deg < 45.0 or deg >= 315.0: return "e"
		elif deg < 135.0: return "s"
		elif deg < 225.0: return "w"
		else:             return "n"

func _add_remote_player(peer_id: int, cls: String, nick: String, pos: Vector2) -> void:
	var rp = Node2D.new()
	rp.set_script(load("res://Scripts/RemotePlayerProxy.gd"))
	rp.name = "Remote_%d" % peer_id
	rp.position = pos
	rp.set_meta("target_pos", pos)
	rp.set_meta("cls", cls)
	rp.set_meta("character_name", nick)
	rp.set_meta("hp", 100.0)
	rp.set_meta("max_hp", 100.0)

	var sprite           = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_frames(cls)
	if cls == "melee":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
	elif cls == "scrapper":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "medic":
		sprite.scale  = Vector2(44.0 / 144.0, 44.0 / 144.0)
		sprite.offset = Vector2(0, -72)
	elif cls == "ranged":
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -16)
	else:
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -12)
	sprite.animation = "idle_s"
	sprite.play()
	rp.add_child(sprite)

	_world_layer.add_child(rp)
	_remote_players[peer_id] = rp

func _on_peer_left(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	if is_instance_valid(_party_system):
		_party_system.call("on_peer_disconnected", peer_id)
	if _player_target_peer == peer_id:
		_player_target_peer = -1

func _remove_remote_player(peer_id: int) -> void:
	if _remote_players.has(peer_id):
		var rp = _remote_players[peer_id]
		if is_instance_valid(rp):
			rp.queue_free()
		_remote_players.erase(peer_id)

# ── TARGETABLE CLEANUP ───────────────────────────────────────
func _on_targetable_removed(mob: Node) -> void:
	if is_instance_valid(_player):
		var cur = _player.get("_current_target")
		if cur == mob:
			_player.set("_current_target", null)
			if _tgt_panel: _tgt_panel.visible = false

# ── DAMAGE NUMBERS ───────────────────────────────────────────
func spawn_damage_number(world_pos: Vector2, amount: float, col: Color) -> void:
	var dn = Node2D.new()
	dn.set_script(load("res://Scripts/DamageNumber.gd"))
	dn.position = world_pos
	dn.set("damage_amount", amount)
	dn.set("color", col)
	add_child(dn)

# ── HELPER — crisp text (zoom-compensated) ───────────────────
func _draw_label(font: Font, pos: Vector2, text: String, sz: int, col: Color) -> void:
	var ct_sc = get_canvas_transform().get_scale()
	var inv = Vector2(1.0 / ct_sc.x, 1.0 / ct_sc.y)
	var rend_sz = maxi(1, int(round(sz * ct_sc.x)))
	draw_set_transform(pos, 0.0, inv)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, rend_sz, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── ELLIPSE HELPER ───────────────────────────────────────────
func _ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts   = PackedVector2Array()
	var cos_r = cos(rot); var sin_r = sin(rot)
	for i in n + 1:
		var a  = float(i) / float(n) * TAU
		var lx = cos(a) * rx; var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cos_r - ly * sin_r, lx * sin_r + ly * cos_r))
	return pts

# ============================================================
#  SOCIAL SYSTEMS
# ============================================================
func _init_social_systems() -> void:
	var op_script = load("res://Scripts/PlayerOptionsPanel.gd")
	if op_script:
		_options_panel = CanvasLayer.new()
		_options_panel.set_script(op_script)
		add_child(_options_panel)
		_options_panel.call("init")
		_options_panel.connect("duel_requested", func(pid, nick):
			if is_instance_valid(_duel_system): _duel_system.call("request_duel", pid, nick))
		_options_panel.connect("invite_requested", func(pid, nick):
			if is_instance_valid(_party_system): _party_system.call("send_invite", pid, nick))
		_options_panel.connect("trade_requested", func(pid, _nick2):
			Relay.send_game_data({"cmd": "trade_request", "nick": PlayerData.nickname}, pid))
	var ds_script = load("res://Scripts/DuelSystem.gd")
	if ds_script:
		_duel_system = Node.new()
		_duel_system.set_script(ds_script)
		add_child(_duel_system)
		_duel_system.call("init", self)
	var ps_script = load("res://Scripts/PartySystem.gd")
	if ps_script:
		_party_system = Node.new()
		_party_system.set_script(ps_script)
		add_child(_party_system)
		_party_system.call("init", self, _hud, 110.0)
	var tw_script = load("res://Scripts/TradeWindow.gd")
	if tw_script:
		_trade_system = CanvasLayer.new()
		_trade_system.set_script(tw_script)
		add_child(_trade_system)
		_trade_system.call("init", self)

# ============================================================
#  TERMINALS
# ============================================================
func _spawn_shop_terminal() -> void:
	var script = load("res://Scripts/BossShopTerminal.gd")
	if script == null: return
	var terminal = Node2D.new()
	terminal.set_script(script)
	terminal.position = _tile_to_world(74, 59)
	_world_layer.add_child(terminal)

func _spawn_mission_terminal() -> void:
	var script = load("res://Scripts/MissionTerminal.gd")
	if script == null: return
	var terminal = Node2D.new()
	terminal.set_script(script)
	terminal.position = _tile_to_world(58, 71)
	_mission_terminal_pos = terminal.position
	_world_layer.add_child(terminal)

func _spawn_bank_terminal() -> void:
	var script = load("res://Scripts/BankTerminal.gd")
	if script == null: return
	var terminal = Node2D.new()
	terminal.set_script(script)
	terminal.position = _tile_to_world(65, 65)
	_world_layer.add_child(terminal)

# ============================================================
#  CREATURES
# ============================================================
func _spawn_dummy(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/TrainingDummy.gd")
	if script == null: return
	var dummy = Node2D.new()
	dummy.set_script(script)
	dummy.scale = Vector2(0.7, 0.7)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("training_dummy").size()
		at_pos = _player.global_position + Vector2(80.0 + n * 50.0, 0.0)
	dummy.position = at_pos
	_world_layer.add_child(dummy)
	dummy.tree_exiting.connect(_on_targetable_removed.bind(dummy))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "dummy", "x": at_pos.x, "y": at_pos.y})

func _spawn_boss(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/ZergBoss.gd")
	if script == null: return
	var boss = CharacterBody2D.new()
	boss.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_boss_frames()
	sprite.scale = Vector2(2.0, 2.0); sprite.offset = Vector2(0, -33)
	boss.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 52.0; shape.height = 90.0; col.shape = shape; boss.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("boss").size()
		var angle = TAU * (float(n) / 6.0); var dist = 280.0 + n * 50.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	boss.position = at_pos; boss.collision_layer = 2; boss.collision_mask = 2
	_world_layer.add_child(boss); boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "boss", "x": at_pos.x, "y": at_pos.y})

func _spawn_cyberlord(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/CyberLord.gd")
	if script == null: return
	var boss = CharacterBody2D.new()
	boss.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_cyberlord_frames()
	sprite.scale = Vector2(264.0 / 144.0, 264.0 / 144.0); sprite.offset = Vector2(0, -72)
	boss.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 52.0; shape.height = 90.0; col.shape = shape; boss.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("boss").size()
		var angle = TAU * (float(n) / 6.0); var dist = 280.0 + n * 50.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	boss.position = at_pos; boss.collision_layer = 2; boss.collision_mask = 2
	_world_layer.add_child(boss); boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "cyberlord", "x": at_pos.x, "y": at_pos.y})

func _build_cyberlord_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Old/melee2/"
	for dir in ["s", "n", "e", "w"]:
		_add_strip(frames, "idle_" + dir, base + "idle/idle_" + dir + ".png", 144, 144, 8, 7.0)
		_add_strip(frames, "run_" + dir, base + "run/run_" + dir + ".png", 144, 144, 8, 10.0)
		_add_strip(frames, "attack_" + dir, base + "attack/attack_" + dir + ".png", 144, 144, 7, 12.0, false)
	return frames

func _spawn_zerg_mob(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/ZergMob.gd")
	if script == null: return
	var mob = CharacterBody2D.new(); mob.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_boss_frames()
	sprite.scale = Vector2(1.0, 1.0); sprite.offset = Vector2(0, -33)
	mob.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 26.0; shape.height = 45.0; col.shape = shape; mob.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("mob").size()
		var angle = TAU * (float(n) / 8.0); var dist = 180.0 + n * 30.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	mob.position = at_pos; mob.collision_layer = 2; mob.collision_mask = 2
	_world_layer.add_child(mob); mob.tree_exiting.connect(_on_targetable_removed.bind(mob))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "zerg_mob", "x": at_pos.x, "y": at_pos.y})

func _spawn_cyber_mob(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/CyberMob.gd")
	if script == null: return
	var mob = CharacterBody2D.new(); mob.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_cyberlord_frames()
	sprite.scale = Vector2(264.0 / 144.0 * 0.5, 264.0 / 144.0 * 0.5); sprite.offset = Vector2(0, -72)
	mob.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 26.0; shape.height = 45.0; col.shape = shape; mob.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("mob").size()
		var angle = TAU * (float(n) / 8.0); var dist = 180.0 + n * 30.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	mob.position = at_pos; mob.collision_layer = 2; mob.collision_mask = 2
	_world_layer.add_child(mob); mob.tree_exiting.connect(_on_targetable_removed.bind(mob))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "cyber_mob", "x": at_pos.x, "y": at_pos.y})

# ── AADU HERDS ────────────────────────────────────────────────
func _spawn_aadu_herds() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77331
	for _i in 8:
		var tx = rng.randi_range(20, GRID_SIZE - 20)
		var ty = rng.randi_range(20, GRID_SIZE - 20)
		if not _is_in_diamond(tx, ty): continue
		if abs(tx - GRID_CENTER) + abs(ty - GRID_CENTER) < 20: continue
		var world_pos = _tile_to_world(tx, ty)
		var count = rng.randi_range(2, 6)
		_spawn_aadu_herd(world_pos, count, rng.randf_range(140.0, 280.0), 0.25)

func _spawn_aadu_herd(center: Vector2, count: int, wander_r: float, baby_chance_p: float) -> void:
	var frames = _build_aadu_frames()
	for i in count:
		var angle = float(i) / float(count) * TAU + randf() * 0.6
		var offset = randf_range(20.0, minf(wander_r * 0.5, 120.0))
		var pos = center + Vector2(cos(angle), sin(angle)) * offset
		var baby = (randf() < baby_chance_p)
		_spawn_single_aadu(pos, center, wander_r, baby, frames)

func _spawn_single_aadu(pos: Vector2, herd_center: Vector2, wander_r: float, is_baby: bool, frames: SpriteFrames, mission_mob: bool = false) -> void:
	var script = load("res://Scripts/Aadu.gd")
	if script == null: return
	var mob = CharacterBody2D.new()
	mob.set_script(script)
	mob.set("is_baby", is_baby)
	mob.set("wander_radius", wander_r)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = frames
	var sc = 0.55 if is_baby else 1.0
	sprite.scale = Vector2(sc, sc); sprite.offset = Vector2(0, -48)
	sprite.animation = "idle_s"
	mob.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 18.0 if is_baby else 28.0
	shape.height = 32.0 if is_baby else 52.0
	col.shape = shape; mob.add_child(col)
	mob.position = pos; mob.collision_layer = 2; mob.collision_mask = 2
	_world_layer.add_child(mob)
	mob.set("spawn_pos", herd_center)
	if mission_mob: mob.add_to_group("mission_mob")
	mob.tree_exiting.connect(_on_targetable_removed.bind(mob))

func on_aadu_died(xp: float, world_pos: Vector2) -> void:
	if is_instance_valid(_player): _player.call("add_exp", xp)
	_share_xp_with_party(xp)
	_check_mission_complete()
	spawn_damage_number(world_pos, 0.0, Color(0.75, 0.90, 0.35))

func _share_xp_with_party(xp: float) -> void:
	if not is_instance_valid(_party_system): return
	if not bool(_party_system.get("in_party")): return
	var members: Array = _party_system.get("members")
	for m in members:
		var pid = int(m.get("peer_id", -1))
		if pid == Relay.my_peer_id or pid == -1: continue
		Relay.send_game_data({"cmd": "party_xp", "amount": xp}, pid)

# ============================================================
#  COMBAT SPAWNERS (called by BossArenaPlayer)
# ============================================================
func is_targeted(node: Node) -> bool:
	if not is_instance_valid(_player): return false
	var tgt = _player.get("_current_target")
	return is_instance_valid(tgt) and tgt == node

func spawn_fireball(spawn_pos: Vector2, target: Node, dmg: float, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/Fireball.gd")
	if script == null: return
	var fb = Node2D.new(); fb.set_script(script); fb.position = spawn_pos
	add_child(fb); fb.call("init", target, dmg)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({"cmd": "fireball", "sx": spawn_pos.x, "sy": spawn_pos.y, "tx": target.global_position.x, "ty": target.global_position.y})

func spawn_bullet(spawn_pos: Vector2, target: Node, dmg: float, _broadcast: bool = true) -> Node:
	var script = load("res://Scripts/Bullet.gd")
	if script == null: return null
	var b = Node2D.new(); b.set_script(script); b.position = spawn_pos
	add_child(b); b.call("init", target, dmg)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({"cmd": "bullet", "sx": spawn_pos.x, "sy": spawn_pos.y, "tx": target.global_position.x, "ty": target.global_position.y})
	return b

func spawn_canister(spawn_pos: Vector2, target: Node, dmg: float, is_heal: bool, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/MedicCanister.gd")
	if script == null: return
	var c = Node2D.new(); c.set_script(script); c.position = spawn_pos
	add_child(c); c.call("init", target, dmg, is_heal)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({"cmd": "canister", "sx": spawn_pos.x, "sy": spawn_pos.y, "tx": target.global_position.x, "ty": target.global_position.y, "heal": is_heal})

func spawn_melee_hit(world_pos: Vector2, col: Color, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/MeleeHit.gd")
	if script == null: return
	var hit = Node2D.new(); hit.set_script(script); hit.position = world_pos
	add_child(hit); hit.call("init", col)
	if _broadcast and Relay.connected:
		Relay.send_game_data({"cmd": "melee_hit", "x": world_pos.x, "y": world_pos.y, "r": col.r, "g": col.g, "b": col.b})

# ============================================================
#  MISSION SYSTEM
# ============================================================
func start_mission(data: Dictionary) -> void:
	_mission_active = true
	_mission_name = data.get("name", "Lunar Extermination")
	_mission_payout = data.get("payout", 10)
	var rng = RandomNumberGenerator.new(); rng.randomize()
	var spawn_pos = Vector2.ZERO
	for _attempt in 30:
		var tx = rng.randi_range(20, GRID_SIZE - 20)
		var ty = rng.randi_range(20, GRID_SIZE - 20)
		if not _is_in_diamond(tx, ty): continue
		var candidate = _tile_to_world(tx, ty)
		if candidate.distance_to(_mission_terminal_pos) >= 800.0:
			spawn_pos = candidate; break
	if spawn_pos == Vector2.ZERO: spawn_pos = _tile_to_world(40, 40)
	_target_world = spawn_pos
	var count = randi_range(8, 12)
	var frames = _build_aadu_frames()
	for i in count:
		var angle = float(i) / float(count) * TAU + randf() * 0.5
		var dist = randf_range(60.0, 180.0)
		var pos = spawn_pos + Vector2(cos(angle), sin(angle)) * dist
		_spawn_single_aadu(pos, spawn_pos, 150.0, false, frames, true)
	if _mission_compass:
		_mission_compass.set("_target_world", _target_world)
		_mission_compass.set("_player", _player)
		_mission_compass.visible = true

func on_mob_died(world_pos: Vector2) -> void:
	spawn_damage_number(world_pos, 0.0, Color(1, 0.3, 0.3))
	_check_mission_complete()

func on_mob_dropped_loot(world_pos: Vector2) -> void:
	var script = load("res://Scripts/LootBag.gd")
	if script == null: return
	var bag = Node2D.new(); bag.set_script(script); bag.position = world_pos
	add_child(bag)

func share_loot_with_party(item: Dictionary, credits: int) -> void:
	if not is_instance_valid(_party_system): return
	if not bool(_party_system.get("in_party")): return
	var members: Array = _party_system.get("members")
	for m in members:
		var pid = int(m.get("peer_id", -1))
		if pid == Relay.my_peer_id or pid == -1: continue
		Relay.send_game_data({"cmd": "party_loot", "item": item, "credits": credits}, pid)

func on_lair_died(lair_pos: Vector2) -> void:
	spawn_damage_number(lair_pos, 0.0, Color(1, 0.6, 0.1))
	_check_mission_complete()

func _check_mission_complete() -> void:
	if not _mission_active: return
	if get_tree().get_nodes_in_group("mission_mob").size() > 0: return
	if get_tree().get_nodes_in_group("mission_lair").size() > 0: return
	_mission_active = false
	if _mission_compass: _mission_compass.visible = false
	if is_instance_valid(_player):
		var cur_credits = int(_player.get("credits")) if _player.get("credits") != null else 0
		_player.set("credits", cur_credits + _mission_payout)
		_player.call("add_exp", 250.0)
	_share_xp_with_party(250.0)
	_show_mission_complete()

func _show_mission_complete() -> void:
	var cl = CanvasLayer.new(); cl.layer = 15; add_child(cl)
	var lbl = Label.new()
	lbl.add_theme_font_override("font", _roboto)
	lbl.set_script(_mission_complete_label_script(_mission_payout))
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.15))
	var vp2 = get_viewport().get_visible_rect().size
	lbl.size = Vector2(vp2.x, 60); lbl.position = Vector2(0, vp2.y * 0.38)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(lbl)

func _update_mission_compass() -> void:
	if not _mission_compass or not is_instance_valid(_mission_compass): return
	if not _mission_active:
		_mission_compass.visible = false
		return
	if is_instance_valid(_player):
		_mission_compass.set("_target_world", _target_world)
		_mission_compass.set("_player", _player)

# ============================================================
#  CHAT BUBBLES & LOG
# ============================================================
func _show_remote_bubble(parent: Node2D, nick: String, msg: String) -> void:
	var old = parent.get_node_or_null("ChatBubble")
	if old: old.queue_free()
	var bubble = Node2D.new(); bubble.name = "ChatBubble"; parent.add_child(bubble)
	var full_msg = "%s: %s" % [nick, msg]
	var max_chars = 28; var font_sz = 12; var char_w = font_sz * 0.62; var line_h = font_sz + 4
	var pad_x = 8; var pad_y = 6
	var words = full_msg.split(" ")
	var lines: Array = []; var cur = ""
	for word in words:
		var candidate = (cur + " " + word).strip_edges()
		if candidate.length() > max_chars and cur.length() > 0:
			lines.append(cur); cur = word
		else: cur = candidate
	if cur.length() > 0: lines.append(cur)
	var bw = 0
	for ln in lines: bw = max(bw, int(ln.length() * char_w))
	bw = max(bw + pad_x * 2, 60)
	var bh = lines.size() * line_h + pad_y * 2
	var bx = -bw / 2; var by = -80 - bh
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.04, 0.90)
	bg.position = Vector2(bx, by); bg.size = Vector2(bw, bh)
	bubble.add_child(bg)
	for i in lines.size():
		var lbl = Label.new()
		lbl.add_theme_font_override("font", _roboto)
		lbl.text = lines[i]
		lbl.position = Vector2(bx + pad_x, by + pad_y + i * line_h)
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
		bubble.add_child(lbl)
	var tw = bubble.create_tween()
	tw.tween_interval(4.4)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.6)
	tw.tween_callback(bubble.queue_free)

func _add_to_chat_log(nick: String, msg: String) -> void:
	var win = _find_chat_window()
	if win and win.has_method("_add_log_line"):
		win.call("_add_log_line", nick, msg, false)

func _find_chat_window() -> Node:
	for child in get_children():
		if child is CanvasLayer and child.has_method("_add_log_line"):
			return child
	if is_instance_valid(_player):
		for child in _player.get_children():
			if child is CanvasLayer and child.has_method("_add_log_line"):
				return child
	return null

# ============================================================
#  POISON TICK
# ============================================================
func _tick_poison(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("targetable"):
		if not is_instance_valid(node): continue
		if not node.has_meta("poison_remaining"): continue
		var remaining = node.get_meta("poison_remaining") - delta
		if remaining <= 0.0:
			node.remove_meta("poison_remaining")
			node.remove_meta("poison_dps")
			continue
		node.set_meta("poison_remaining", remaining)
		var dps = node.get_meta("poison_dps")
		if node.has_method("take_damage"):
			node.take_damage(dps * delta)
