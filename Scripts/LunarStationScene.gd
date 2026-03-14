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
	_scene_time += delta

# ── INPUT ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			_clear_target()
		# Zoom
	if not _zoom_locked and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_base = clampf(_cam_zoom_base + 0.1, 0.5, 2.5)
			_camera.zoom = Vector2.ONE * _cam_zoom_base
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_base = clampf(_cam_zoom_base - 0.1, 0.5, 2.5)
			_camera.zoom = Vector2.ONE * _cam_zoom_base

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_base = clampf(_cam_zoom_base + 0.1, 0.5, 2.5)
			_camera.zoom = Vector2.ONE * _cam_zoom_base
		elif not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_base = clampf(_cam_zoom_base - 0.1, 0.5, 2.5)
			_camera.zoom = Vector2.ONE * _cam_zoom_base
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
		{ "key":"brawler",  "label":"BRAWLER",  "color":Color(0.40,0.85,0.30), "desc":"Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"ranged",   "label":"MARKSMAN", "color":Color(0.35,0.80,0.95), "desc":"Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"medic",    "label":"MEDIC",    "color":Color(0.30,0.85,0.90), "desc":"Combat medic.\nHeals allies with\ncanisters, poisons\nenemies.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
		{ "key":"future1",  "label":"?",        "color":Color(0.40,0.40,0.50), "desc":"Coming soon...", "locked":true },
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
	_setup_hud(cls)
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
	elif cls == "brawler":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
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

# ── SPRITE FRAMES ────────────────────────────────────────────
func _build_frames(cls: String) -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	match cls:
		"melee":
			var base = "res://Characters/minimmo/meleenew/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
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
		"brawler":
			var base = "res://Characters/minimmo/brawler/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   160,160,8,8.0)
				_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",     160,160,8,10.0)
				_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",160,160,6,12.0,false)
		"medic":
			var base = "res://Characters/minimmo/medic/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				_add_strip(frames,"idle_"+dir,   base+"idle/idle_"+dir+".png",   144,144,8,8.0)
				_add_strip(frames,"run_"+dir,    base+"run/run_"+dir+".png",     144,144,8,10.0)
				_add_strip(frames,"attack_"+dir, base+"toss/toss_"+dir+".png",   144,144,7,12.0,false)
	return frames

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

# ── HUD (stub — will be expanded) ────────────────────────────
func _setup_hud(_cls: String) -> void:
	_hud       = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	# Placeholder — full HUD will be added in next step

func _update_hud() -> void:
	pass   # stub — will be expanded

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

func _on_relay_data(data: Dictionary, from_peer: int) -> void:
	var cmd = data.get("cmd", "")
	match cmd:
		"move":
			_handle_remote_move(data, from_peer)
		"chat":
			pass   # stub — chat will be connected with HUD
		"fireball", "bullet", "canister", "melee_hit":
			pass   # stub — projectile visuals
		"spawn_creature":
			pass   # stub — creature sync

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
	var has_8dir = (cls == "melee" or cls == "brawler" or cls == "medic")
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
	if cls == "melee" or cls == "brawler":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
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
	if _remote_players.has(peer_id):
		var rp = _remote_players[peer_id]
		if is_instance_valid(rp):
			rp.queue_free()
		_remote_players.erase(peer_id)
	if _player_target_peer == peer_id:
		_clear_target()

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
