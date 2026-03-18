extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  TheedScene.gd — miniSWG | Theed
#
#  Grassy isometric scene with diamond-shaped map.
#  Uses TileMapLayer in isometric mode for the ground,
#  Y-sorted Node2D children for player and objects.
#
#  Attach to: theed.tscn
# ============================================================

# ── ISOMETRIC GRID ──────────────────────────────────────────────
const TILE_W     : int   = 128
const TILE_H     : int   = 64
const GRID_SIZE  : int   = 128
const GRID_CENTER: int   = 64

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

# HUD refs
var _player_frame    : Panel        = null
var _player_name_lbl : Label        = null
var _hp_bar          : ProgressBar  = null  # Health (red)
var _action_hud_bar  : ProgressBar  = null  # Action (yellow)
var _mind_bar        : ProgressBar  = null  # Mind (blue)
var _xp_bar          : ProgressBar  = null
var _hp_bar_lbl      : Label        = null
var _action_bar_lbl  : Label        = null
var _mind_bar_lbl    : Label        = null
# Wound overlays — black bar on right side of each HAM bar
var _hp_wound_ov     : ColorRect    = null
var _action_wound_ov : ColorRect    = null
var _mind_wound_ov   : ColorRect    = null
var _xp_bar_lbl      : Label        = null
var _hp_pct_lbl      : Label        = null  # unused, kept for compat
var _level_lbl       : Label        = null  # unused, kept for compat
var _tgt_panel       : Panel        = null
var _tgt_name_lbl    : Label        = null
var _tgt_hp_bar      : ProgressBar  = null
var _tgt_hp_lbl      : Label        = null
var _tgt_mp_bar      : ProgressBar  = null
var _minimap_panel   : Panel        = null
var _minimap_draw    : Control      = null
var _mm_location_lbl : Label        = null
var _mm_channel_lbl  : Label        = null
var _frame_drag      : bool         = false
var _portrait_rect   : TextureRect  = null

# Audio
var _music_city      : AudioStreamPlayer = null
var _music_adventure : AudioStreamPlayer = null
var _music_fight     : AudioStreamPlayer = null
var _city_vol        : float = 0.0
var _adv_vol         : float = 0.0
var _fight_vol       : float = 0.0
var _is_fighting     : bool = false
var _fight_fade_timer: float = 0.0
var _city_center     : Vector2 = Vector2.ZERO
var _city_music_radius : float = 900.0

# Falling leaves
var _leaves : Array = []

# Multiplayer
var _remote_players  : Dictionary   = {}
var _broadcast_timer : float        = 0.0
var _scene_time      : float        = 0.0

# Social / gameplay systems
var _options_panel : Node = null
var _duel_system   : Node = null
var _party_system  : Node = null
var _trade_system  : Node = null

# Player targeting
var _player_target_peer : int = -1

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_arena_scene")
	add_to_group("ui_layer")
	_setup_tilemap()
	_setup_camera()
	# Ambient flying ships overlay
	var overlay = Node2D.new()
	overlay.set_script(load("res://Scripts/TheedAnimOverlay.gd"))
	add_child(overlay)
	var city_node = get_node_or_null("City")
	# Disable collision on City StaticBody2D so player doesn't get stuck at spawn
	if city_node and city_node is StaticBody2D:
		city_node.collision_layer = 0
		city_node.collision_mask = 0
	var city_pos = city_node.position if city_node else _tile_to_world(20, 76)
	overlay.call("set_city_center", city_pos)
	_show_character_select()
	if not Relay.game_data_received.is_connected(_on_relay_data):
		Relay.game_data_received.connect(_on_relay_data)
	if not Relay.peer_left.is_connected(_on_peer_left):
		Relay.peer_left.connect(_on_peer_left)

# ── TILEMAP SETUP ─────────────────────────────────────────────
func _setup_tilemap() -> void:
	# Tilemap used only for coordinate math (map_to_local / local_to_map)
	var tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_size  = Vector2i(TILE_W, TILE_H)

	_tilemap = TileMapLayer.new()
	_tilemap.tile_set = tileset
	_tilemap.visible  = false
	add_child(_tilemap)

	# Seamless grass background (programmatic — proven to work)
	var bg_node = Node2D.new()
	bg_node.z_index = -10
	bg_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_node.set_script(_make_bg_script())
	add_child(bg_node)

	# City is placed manually in theed.tscn as "City" StaticBody2D

	# Y-sort container for player and objects
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
	_camera.position_smoothing_enabled = false  # We handle smoothing manually
	add_child(_camera)
	_camera.make_current()

# ── COORDINATE HELPERS ────────────────────────────────────────
func _tile_to_world(tx: int, ty: int) -> Vector2:
	if _tilemap:
		return _tilemap.map_to_local(Vector2i(tx, ty))
	return Vector2(float(tx - ty) * TILE_W * 0.5, float(tx + ty) * TILE_H * 0.5)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	if _tilemap:
		return _tilemap.local_to_map(world_pos)
	return Vector2i(0, 0)

func _is_in_diamond(tx: int, ty: int) -> bool:
	return abs(tx - GRID_CENTER) + abs(ty - GRID_CENTER) <= GRID_CENTER

# ── BACKGROUND SCRIPT (seamless tiled grass texture) ─────────
func _make_bg_script() -> GDScript:
	var src = """extends Node2D

var _grass_tex : Texture2D = null

func _ready():
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass_tex = load("res://Assets/Backgrounds/grass.png") as Texture2D

func _draw():
	if _grass_tex == null:
		draw_rect(Rect2(-20000, -20000, 40000, 40000), Color(0.28, 0.52, 0.18))
		return
	var extents := 20000.0
	draw_texture_rect_region(
		_grass_tex,
		Rect2(-extents, -extents, extents * 2.0, extents * 2.0),
		Rect2(0, 0, extents * 2.0, extents * 2.0)
	)
"""
	var s = GDScript.new()
	s.source_code = src
	s.reload()
	return s

# ── PROCESS ───────────────────────────────────────────────────
func _physics_process(phys_delta: float) -> void:
	# Camera follows player with smooth lag — slower catchup for cinematic feel
	if is_instance_valid(_player):
		var target = _player.global_position
		var is_mounted = _player.get("_mounted") as bool if _player.get("_mounted") != null else false
		# Vehicle = slower camera catchup (more cinematic), walking = tighter follow
		var lerp_speed = 2.5 if is_mounted else 6.0
		_camera.global_position = _camera.global_position.lerp(target, 1.0 - exp(-lerp_speed * phys_delta))

var _minimap_timer : float = 0.0

func _process(delta: float) -> void:
	_minimap_timer += delta
	if _minimap_timer >= 0.1 and _minimap_draw != null and is_instance_valid(_minimap_draw):
		_minimap_draw.queue_redraw()
		_minimap_timer = 0.0
	# Smooth zoom interpolation — zoom out when mounted
	var zoom_target = _cam_zoom_target
	if is_instance_valid(_player):
		var is_mounted = _player.get("_mounted") as bool if _player.get("_mounted") != null else false
		if is_mounted:
			zoom_target = minf(zoom_target, 1.4)  # Force zoomed out when in vehicle
	_cam_zoom_base = lerpf(_cam_zoom_base, zoom_target, 1.0 - exp(-3.0 * delta))
	_camera.zoom = Vector2.ONE * _cam_zoom_base
	if is_instance_valid(_player):
		_broadcast_timer += delta
		if _broadcast_timer >= 0.05:
			_broadcast_timer = 0.0
			var _phv = _player.get("hp");     var _php = float(_phv) if _phv != null else 100.0
			var _pmv = _player.get("max_hp"); var _pmp = float(_pmv) if _pmv != null else 100.0
			Relay.send_game_data({
				"cmd":    "move",
				"x":      _player.global_position.x,
				"y":      _player.global_position.y,
				"class":  str(_player.get("character_class") if _player.get("character_class") != null else "melee"),
				"nick":   PlayerData.nickname,
				"hp":     _php,
				"max_hp": _pmp,
			})
	var lerp_w = 1.0 - exp(-12.0 * delta)
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if is_instance_valid(rp) and rp.has_meta("target_pos"):
			rp.position = rp.position.lerp(rp.get_meta("target_pos"), lerp_w)
	_update_hud()
	_tick_music(delta)
	_tick_leaves(delta)
	_scene_time += delta

# ── INPUT ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				var has_target = false
				if is_instance_valid(_player):
					var ct = _player.get("_current_target")
					has_target = (ct != null and is_instance_valid(ct)) or _player_target_peer != -1
				if has_target:
					_clear_target()
				else:
					# No target — toggle settings window ONLY
					for child in get_children():
						var scr = child.get_script()
						if scr != null and scr.resource_path.find("SettingsWindow") != -1:
							if child.has_method("_toggle"):
								child.call("_toggle")
							break
		if is_instance_valid(_player):
			match event.keycode:
				KEY_F1: _spawn_dummy()
				KEY_F2: _spawn_boss()
				KEY_F3: _spawn_cyberlord()
				KEY_F4: _spawn_zerg_mob()
				KEY_F5: _spawn_cyber_mob()
				KEY_F9: _spawn_vampire()
				KEY_F10: _spawn_armored_thug()
				KEY_F11:
					if _player.has_method("reset_skill_points"):
						_player.call("reset_skill_points")
				KEY_H:
					_player.set("credits", (_player.get("credits") as int) + 5000)
				KEY_F6:
					var p = _player.global_position
					print("Player position: Vector2(%.1f, %.1f)" % [p.x, p.y])
				KEY_F7:
					pass  # Reserved
				KEY_F8:
					pass  # Reserved
	# Zoom handled in _input only — removed duplicate here

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.08, 0.5, 3.2)
		elif not _zoom_locked and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.08, 0.5, 3.2)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_click(event)

func _handle_click(event: InputEventMouseButton) -> void:
	if not is_instance_valid(_player): return
	var vp  = get_viewport()
	var cam = vp.get_camera_2d() if vp else null
	if cam == null: return
	var mouse_world = (event.position - vp.get_visible_rect().size * 0.5) / cam.zoom + cam.global_position
	var closest_dist = 40.0
	var closest_pid  = -1
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if not is_instance_valid(rp): continue
		var d = rp.global_position.distance_to(mouse_world)
		if d < closest_dist:
			closest_dist = d
			closest_pid  = pid
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
	bg.color     = Color(0.04, 0.08, 0.03, 0.96)
	_select_layer.add_child(bg)

	var title = Label.new()
	title.add_theme_font_override("font", _roboto)
	title.text = "THEED  —  CHOOSE YOUR CLASS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 0.70))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 55)
	title.position = Vector2(0, vp.y * 0.12)
	_select_layer.add_child(title)

	var hint = Label.new()
	hint.add_theme_font_override("font", _roboto)
	hint.text = "WASD / Arrow Keys to move  ·  Tab to cycle targets  ·  Auto-attack in range  ·  P for Skills  ·  I for Inventory"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.40, 0.55, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size     = Vector2(vp.x, 24)
	hint.position = Vector2(0, vp.y * 0.12 + 62)
	_select_layer.add_child(hint)

	var classes = [
		# Old brawler removed
		{ "key":"ranged",   "label":"MARKSMAN", "color":Color(0.35,0.80,0.95), "desc":"Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"medic",    "label":"MEDIC",    "color":Color(0.30,0.85,0.90), "desc":"Combat medic.\nHeals allies with\ncanisters, poisons\nenemies.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
		{ "key":"scrapper","label":"SCRAPPER","color":Color(0.45,0.90,0.35), "desc":"Tough close-range\nfighter. Takes a\nbeating and hits back.\n\nHP: 500\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"streetfighter","label":"STREET FIGHTER","color":Color(0.90,0.45,0.25), "desc":"Slow but devastating.\nWalk before you run.\nTwo attack styles.\n\nHP: 600\nAtk every: 2.5s\nRange: 130px", "locked":false },
		{ "key":"robo","label":"ROBO","color":Color(0.50,0.70,0.90), "desc":"Combat medic robot.\nHeals allies, poisons\nenemies from range.\n\nHP: 350\nAtk every: 3s\nRange: 500px", "locked":false },
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
	welcome_lbl.add_theme_color_override("font_color", Color(0.50, 0.72, 0.45))
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
	sty.bg_color   = Color(0.04, 0.08, 0.04, 0.92) if not is_locked else Color(0.06, 0.06, 0.08, 0.80)
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
	bsty.bg_color     = Color(0.04, 0.06, 0.04)
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
	_spawn_player(cls)
	_spawn_terminals()
	_spawn_trees()
	_setup_music()
	_setup_hud(cls)
	_init_social_systems()
	_join_theed()

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
		sprite.scale  = Vector2(0.28, 0.28)
		sprite.offset = Vector2(0, -160)
	elif cls == "medic":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "ranged":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "streetfighter":
		sprite.scale  = Vector2(0.28, 0.28)
		sprite.offset = Vector2(0, -160)
	elif cls == "robo":
		sprite.scale  = Vector2(0.28, 0.28)
		sprite.offset = Vector2(0, -160)
	else:
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -12)
	_player.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12.0; shape.height = 20.0
	col.shape = shape
	_player.add_child(col)

	# Spawn at City node position, or fallback to tile coords
	var city_node = get_node_or_null("City")
	if city_node:
		_player.position = city_node.position
	else:
		_player.position = _tile_to_world(20, 76)
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

# ── TERMINALS & NPCs — placed manually in theed.tscn ─────────
func _spawn_terminals() -> void:
	pass

# ── VEGETATION ───────────────────────────────────────────────
func _spawn_trees() -> void:
	var city_node = get_node_or_null("City")
	var city_pos = city_node.position if city_node else _tile_to_world(20, 76)
	var city_radius = 3400.0  # Ring around city — no trees inside this (city is ~5760x3333)
	var map_radius = 8000.0  # How far out to spawn vegetation

	var rng = RandomNumberGenerator.new()
	rng.seed = 77331

	var tree1_tex = load("res://Assets/Backgrounds/tree1.png") as Texture2D
	var tree2_tex = load("res://Assets/Backgrounds/tree2.png") as Texture2D
	var mush_tex  = load("res://Assets/Backgrounds/mushroom.png") as Texture2D
	var bush1_tex = load("res://Assets/Backgrounds/bush1.png") as Texture2D
	var bush3_tex = load("res://Assets/Backgrounds/bush3.png") as Texture2D

	# ── TREES (lots!) ────────────────────────────────────────
	for i in 350:
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(city_radius + 40, map_radius)
		# Cluster trees more densely near the city edge
		if rng.randf() < 0.4:
			dist = rng.randf_range(city_radius + 40, city_radius + 600)
		var pos = city_pos + Vector2(cos(angle), sin(angle)) * dist
		# Slight random offset for natural look
		pos += Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		var tex = tree1_tex if rng.randf() < 0.55 else tree2_tex
		if tex == null: continue
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.position = pos
		var sc = rng.randf_range(0.18, 0.38)
		spr.scale = Vector2(sc, sc)
		spr.z_index = 0
		# Slight random flip for variety
		if rng.randf() < 0.3:
			spr.flip_h = true
		_world_layer.add_child(spr)

	# ── BUSHES (scattered, small) ────────────────────────────
	for i in 200:
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(city_radius - 20, map_radius)
		var pos = city_pos + Vector2(cos(angle), sin(angle)) * dist
		pos += Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		var tex = bush1_tex if rng.randf() < 0.7 else bush3_tex
		if tex == null: continue
		var spr = Sprite2D.new()
		spr.texture = tex
		spr.position = pos
		var sc = rng.randf_range(0.06, 0.18)
		spr.scale = Vector2(sc, sc)
		spr.z_index = 0
		if rng.randf() < 0.4:
			spr.flip_h = true
		_world_layer.add_child(spr)

	# ── MUSHROOMS (sparse, small) ────────────────────────────
	for i in 40:
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(city_radius + 100, map_radius)
		var pos = city_pos + Vector2(cos(angle), sin(angle)) * dist
		if mush_tex == null: continue
		var spr = Sprite2D.new()
		spr.texture = mush_tex
		spr.position = pos
		var sc = rng.randf_range(0.04, 0.10)
		spr.scale = Vector2(sc, sc)
		spr.z_index = 0
		_world_layer.add_child(spr)


# ── MUSIC SYSTEM ─────────────────────────────────────────────
func _setup_music() -> void:
	var _cn = get_node_or_null("City")
	_city_center = _cn.position if _cn else (_player.position if _player else _tile_to_world(20, 76))

	# City ambience
	var city_stream = load("res://Sounds/Music/spaceportambience.mp3") as AudioStream
	if city_stream:
		_music_city = AudioStreamPlayer.new()
		_music_city.stream = city_stream
		_music_city.volume_db = -80.0
		_music_city.bus = "Master"
		add_child(_music_city)
		_music_city.play()

	# Adventure music (outside city)
	var adv_stream = load("res://Sounds/Music/music_adventure.mp3") as AudioStream
	if adv_stream:
		_music_adventure = AudioStreamPlayer.new()
		_music_adventure.stream = adv_stream
		_music_adventure.volume_db = -80.0
		_music_adventure.bus = "Master"
		add_child(_music_adventure)
		_music_adventure.play()

	# Fight music
	var fight_stream = load("res://Sounds/Music/music_fight.mp3") as AudioStream
	if fight_stream:
		_music_fight = AudioStreamPlayer.new()
		_music_fight.stream = fight_stream
		_music_fight.volume_db = -80.0
		_music_fight.bus = "Master"
		add_child(_music_fight)
		_music_fight.play()

func _tick_music(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var dist_to_city = _player.global_position.distance_to(_city_center)
	var in_city = dist_to_city < _city_music_radius

	# Check if player is fighting (attacking or being attacked)
	var attacking = _player.get("_is_attacking") as bool if _player.get("_is_attacking") != null else false
	var target = _player.get("_current_target")
	var has_target = target != null and is_instance_valid(target)

	if attacking or has_target:
		_is_fighting = true
		_fight_fade_timer = 2.0  # keep fight music for 2s after combat ends
	elif _fight_fade_timer > 0:
		_fight_fade_timer -= delta
		if _fight_fade_timer <= 0:
			_is_fighting = false

	# Target volumes
	var city_target : float = 0.0
	var adv_target : float = 0.0
	var fight_target : float = 0.0

	if _is_fighting:
		fight_target = 0.7
		city_target = 0.0
		adv_target = 0.0
	elif in_city:
		var fade = 1.0 - clampf(dist_to_city / _city_music_radius, 0.0, 1.0)
		city_target = fade * 0.6
		adv_target = (1.0 - fade) * 0.4
	else:
		city_target = 0.0
		adv_target = 0.5

	# Smooth volume transitions
	_city_vol = lerpf(_city_vol, city_target, delta * 1.5)
	_adv_vol = lerpf(_adv_vol, adv_target, delta * 1.5)
	_fight_vol = lerpf(_fight_vol, fight_target, delta * (3.0 if _is_fighting else 2.0))

	if _music_city:
		_music_city.volume_db = linear_to_db(maxf(_city_vol, 0.0001)) - 10.0
	if _music_adventure:
		_music_adventure.volume_db = linear_to_db(maxf(_adv_vol, 0.0001)) - 10.0
	if _music_fight:
		_music_fight.volume_db = linear_to_db(maxf(_fight_vol, 0.0001)) - 10.0

# ── FALLING LEAVES ───────────────────────────────────────────
func _tick_leaves(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var dist_to_city = _player.global_position.distance_to(_city_center)
	var in_city = dist_to_city < _city_music_radius

	# Spawn new leaves when in city
	if in_city and _leaves.size() < 30:
		var cam_pos = _camera.global_position if _camera else _player.global_position
		var vp = get_viewport().get_visible_rect().size
		var half_w = vp.x / (_cam_zoom_base * 2.0)
		var half_h = vp.y / (_cam_zoom_base * 2.0)
		_leaves.append({
			"pos": Vector2(
				cam_pos.x + randf_range(-half_w, half_w),
				cam_pos.y - half_h - randf_range(5, 30)),
			"vel": Vector2(randf_range(-12, 8), randf_range(15, 35)),
			"rot": randf() * TAU,
			"rot_speed": randf_range(-2.0, 2.0),
			"size": randf_range(2.0, 4.5),
			"color": [
				Color(0.45, 0.65, 0.20, 0.7),
				Color(0.70, 0.55, 0.15, 0.7),
				Color(0.80, 0.35, 0.10, 0.65),
				Color(0.55, 0.75, 0.25, 0.7),
				Color(0.85, 0.65, 0.20, 0.6),
			][randi() % 5],
			"life": 0.0,
			"max_life": randf_range(3.0, 6.0),
			"sway_phase": randf() * TAU,
		})

	# Update leaves
	var alive = []
	for lf in _leaves:
		lf["life"] += delta
		if lf["life"] >= lf["max_life"]:
			continue
		# Sway sideways
		lf["vel"].x += sin(_scene_time * 1.5 + lf["sway_phase"]) * 8.0 * delta
		lf["pos"] += lf["vel"] * delta
		lf["rot"] += lf["rot_speed"] * delta
		alive.append(lf)
	_leaves = alive

	queue_redraw()

func _draw() -> void:
	# Draw falling leaves on top of everything in world space
	for lf in _leaves:
		var frac = lf["life"] / lf["max_life"]
		var alpha = lf["color"].a * (1.0 - frac * frac)  # fade out
		var col = Color(lf["color"].r, lf["color"].g, lf["color"].b, alpha)
		var sz : float = lf["size"]
		var pos : Vector2 = lf["pos"]
		var rot : float = lf["rot"]
		# Draw leaf as a small rotated diamond
		var fwd = Vector2(cos(rot), sin(rot))
		var side = Vector2(-sin(rot), cos(rot))
		var pts = PackedVector2Array([
			pos + fwd * sz * 1.5,
			pos + side * sz * 0.6,
			pos - fwd * sz * 1.5,
			pos - side * sz * 0.6,
		])
		draw_colored_polygon(pts, col)

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
			var rbase = "res://Characters/NEWFOUNDMETHOD/marksman2/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				# Idle: 3 parts played in sequence (idle1->idle2->idle3)
				var idle_anim = "idle_" + dir
				frames.add_animation(idle_anim)
				frames.set_animation_speed(idle_anim, 20.0)
				frames.set_animation_loop(idle_anim, true)
				for part in ["idle1", "idle2", "idle3"]:
					var path = rbase + "idle/" + part + "/" + part + "_" + dir + ".png"
					if not ResourceLoader.exists(path): continue
					var tex = load(path) as Texture2D
					if tex == null: continue
					var fw = 512
					var fc = int(tex.get_width() / fw)
					for fi in fc:
						var atlas = AtlasTexture.new()
						atlas.atlas = tex
						atlas.region = Rect2(fi * fw, 0, fw, tex.get_height())
						frames.add_frame(idle_anim, atlas)
				# Run
				var run_path = rbase + "run/run_" + dir + ".png"
				var rtex = load(run_path) as Texture2D
				var rfc = int(rtex.get_width() / 512) if rtex else 21
				_add_strip(frames, "run_" + dir, run_path, 512, 512, rfc, 24.0)
				# Attack
				var atk_path = rbase + "attack/attack_" + dir + ".png"
				var atex = load(atk_path) as Texture2D
				var afc = int(atex.get_width() / 512) if atex else 30
				_add_strip(frames, "attack_" + dir, atk_path, 512, 512, afc, 24.0, false)
		"medic":
			var mbase = "res://Characters/NEWFOUNDMETHOD/TechnoNun/"
			var mcw = 768; var mch = 448
			# Idle — per direction, 21 frames (6 rows)
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				_add_grid(frames,"idle_"+dir, mbase+"idle/idle_"+dir+".png", mcw,mch,4,21,10.0)
			# Run — per direction, 29 frames
			for dir in ["s","n","e","ne","se","sw"]:
				_add_grid(frames,"run_"+dir, mbase+"run/run_"+dir+".png", mcw,mch,4,29,18.0)
			for dir in ["w","nw"]:
				_add_grid(frames,"run_"+dir, mbase+"run/run_"+dir+".png", mcw,mch,4,29,18.0,true,true)
			# Attack — per direction, 29 frames (no attack_s, alias to attack_se)
			for dir in ["n","e","ne","se"]:
				_add_grid(frames,"attack_"+dir, mbase+"attack/attack_"+dir+".png", mcw,mch,4,29,24.0,false)
			for dir in ["w","nw"]:
				_add_grid(frames,"attack_"+dir, mbase+"attack/attack_"+dir+".png", mcw,mch,4,29,24.0,false,true)
			_add_grid(frames,"attack_sw", mbase+"attack/attack_sw.png", mcw,mch,4,29,24.0,false)
			_add_grid(frames,"attack_s", mbase+"attack/attack_se.png", mcw,mch,4,29,24.0,false)
		"scrapper":
			var scbase = "res://Characters/NEWFOUNDMETHOD/Brawler3/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				# Idle: 4 parts played in sequence (idle1->idle2->idle3->idle4)
				# Each part is a strip, combined into one animation
				var idle_anim = "idle_" + dir
				frames.add_animation(idle_anim)
				frames.set_animation_speed(idle_anim, 24.0)
				frames.set_animation_loop(idle_anim, true)
				for part in ["idle1", "idle2", "idle3", "idle4"]:
					var path = scbase + "idle/" + part + "/" + part + "_" + dir + ".png"
					if not ResourceLoader.exists(path): continue
					var tex = load(path) as Texture2D
					if tex == null: continue
					var fw = 512
					var fc = int(tex.get_width() / fw)
					for fi in fc:
						var atlas = AtlasTexture.new()
						atlas.atlas = tex
						atlas.region = Rect2(fi * fw, 0, fw, tex.get_height())
						frames.add_frame(idle_anim, atlas)
				_add_strip(frames, "run_"+dir, scbase+"run/run_"+dir+".png", 512, 512, 20, 24.0)
				_add_strip(frames, "attack_"+dir, scbase+"attack/attack_"+dir+".png", 512, 512, 30, 24.0, false)
		"streetfighter":
			var sfbase = "res://Characters/NEWFOUNDMETHOD/Brawler2/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				_add_strip(frames, "idle_"+dir, sfbase+"idle/idle_"+dir+".png", 512, 512, 30, 10.0)
				_add_strip(frames, "walk_"+dir, sfbase+"walk/walk_"+dir+".png", 512, 512, 30, 12.0)
				_add_strip(frames, "run_"+dir, sfbase+"run/run_"+dir+".png", 512, 512, 30, 16.0)
				_add_strip(frames, "attack_"+dir, sfbase+"attack/attack_"+dir+".png", 512, 512, 30, 18.0, false)
				_add_strip(frames, "attack2_"+dir, sfbase+"attack2/attack2_"+dir+".png", 512, 512, 30, 18.0, false)
		"robo":
			var rbase2 = "res://Characters/NEWFOUNDMETHOD/DeadpoolRobot/"
			for dir in ["s","n","e","w","se","sw","ne","nw"]:
				_add_strip(frames, "idle_"+dir, rbase2+"idle/idle_"+dir+".png", 512, 512, 30, 10.0)
				_add_strip(frames, "run_"+dir, rbase2+"run/run_"+dir+".png", 512, 512, 30, 14.0)
				_add_strip(frames, "attack_"+dir, rbase2+"attack/attack_"+dir+".png", 512, 512, 30, 18.0, false)
	return frames

func _add_grid(frames: SpriteFrames, anim_name: String, path: String,
		cell_w: int, cell_h: int, cols: int, total_frames: int, fps: float,
		loop: bool = true, hflip: bool = false) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("TheedScene: could not load " + path)
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
		atlas.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
		frames.add_frame(anim_name, atlas)

func _add_strip(frames: SpriteFrames, anim_name: String, path: String,
		frame_w: int, frame_h: int, frame_count: int, fps: float, loop: bool = true) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("TheedScene: could not load " + path)
		return
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)
	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)

# ── HUD ──────────────────────────────────────────────────────
func _setup_hud(_cls: String) -> void:
	_hud       = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var vp   = get_viewport().get_visible_rect().size
	var font = _roboto
	var bold = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf") if ResourceLoader.exists("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf") else font

	const PF_W  : float = 220.0
	const PF_H  : float = 72.0
	const BAR_X : float = 8.0
	const BAR_W : float = 204.0

	_player_frame          = Panel.new()
	_player_frame.size     = Vector2(PF_W, PF_H)
	_player_frame.position = Vector2(10, 10)
	var pf_sty             = StyleBoxFlat.new()
	pf_sty.bg_color        = Color(0.03, 0.06, 0.12, 0.92)
	pf_sty.border_color    = Color(0.12, 0.40, 0.55, 0.85)
	pf_sty.set_border_width_all(2)
	pf_sty.set_corner_radius_all(2)
	pf_sty.shadow_color    = Color(0.0, 0.0, 0.0, 0.50)
	pf_sty.shadow_size     = 4
	_player_frame.add_theme_stylebox_override("panel", pf_sty)
	_hud.add_child(_player_frame)
	_player_frame.gui_input.connect(_on_frame_drag)

	# Name strip
	_player_name_lbl = Label.new()
	_player_name_lbl.add_theme_font_override("font", bold)
	_player_name_lbl.add_theme_font_size_override("font_size", 10)
	_player_name_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
	_player_name_lbl.position = Vector2(BAR_X, 3)
	_player_name_lbl.size     = Vector2(BAR_W, 14)
	_player_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_player_name_lbl)

	# ── HAM Bars (Health / Action / Mind) ────────────────────
	_hp_bar = _make_bar(Color(0.72, 0.14, 0.10), Vector2(BAR_X, 18), Vector2(BAR_W, 14))
	_player_frame.add_child(_hp_bar)
	_hp_bar_lbl = _make_bar_label(Vector2(BAR_X, 18), Vector2(BAR_W, 14))
	_player_frame.add_child(_hp_bar_lbl)

	_action_hud_bar = _make_bar(Color(0.80, 0.68, 0.10), Vector2(BAR_X, 34), Vector2(BAR_W, 14))
	_player_frame.add_child(_action_hud_bar)
	_action_bar_lbl = _make_bar_label(Vector2(BAR_X, 34), Vector2(BAR_W, 14))
	_player_frame.add_child(_action_bar_lbl)

	_mind_bar = _make_bar(Color(0.15, 0.30, 0.72), Vector2(BAR_X, 50), Vector2(BAR_W, 14))
	_player_frame.add_child(_mind_bar)
	_mind_bar_lbl = _make_bar_label(Vector2(BAR_X, 50), Vector2(BAR_W, 14))
	_player_frame.add_child(_mind_bar_lbl)

	# ── Wound overlays — black bar over right side of each HAM bar ──
	# Added after labels so they render on top of everything
	_hp_wound_ov = _make_wound_overlay(Vector2(BAR_X + BAR_W, 18), 14)
	_player_frame.add_child(_hp_wound_ov)
	_action_wound_ov = _make_wound_overlay(Vector2(BAR_X + BAR_W, 34), 14)
	_player_frame.add_child(_action_wound_ov)
	_mind_wound_ov = _make_wound_overlay(Vector2(BAR_X + BAR_W, 50), 14)
	_player_frame.add_child(_mind_wound_ov)

	# ── XP Bar (positioned at bottom center, under action bar) ──
	var vp2 = get_viewport().get_visible_rect().size
	var xp_w = 380.0
	var xp_panel = Panel.new()
	xp_panel.name = "XPBarPanel"
	xp_panel.size = Vector2(xp_w + 8, 16)
	xp_panel.position = Vector2(vp2.x * 0.5 - (xp_w + 8) * 0.5, vp2.y - 26)
	var xp_sty = StyleBoxFlat.new()
	xp_sty.bg_color = Color(0.03, 0.03, 0.05, 0.75)
	xp_sty.set_border_width_all(0); xp_sty.set_corner_radius_all(2)
	xp_panel.add_theme_stylebox_override("panel", xp_sty)
	xp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(xp_panel)

	_xp_bar = _make_bar(Color(0.60, 0.50, 0.12), Vector2(4, 2), Vector2(xp_w, 12))
	xp_panel.add_child(_xp_bar)
	_xp_bar_lbl = _make_bar_label(Vector2(4, 2), Vector2(xp_w, 12))
	_xp_bar_lbl.add_theme_font_size_override("font_size", 8)
	xp_panel.add_child(_xp_bar_lbl)

	# Target panel
	const TGT_W : float = 280.0
	const TGT_H : float = 72.0
	_tgt_panel          = Panel.new()
	_tgt_panel.size     = Vector2(TGT_W, TGT_H)
	_tgt_panel.position = Vector2(vp.x * 0.5 - TGT_W * 0.5, 10)
	_tgt_panel.visible  = false
	var tp_sty          = StyleBoxFlat.new()
	tp_sty.bg_color     = Color(0.04, 0.06, 0.12, 0.92)
	tp_sty.border_color = Color(0.50, 0.18, 0.14, 0.85)
	tp_sty.set_border_width_all(2)
	tp_sty.set_corner_radius_all(2)
	tp_sty.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	tp_sty.shadow_size  = 4
	_tgt_panel.add_theme_stylebox_override("panel", tp_sty)
	_hud.add_child(_tgt_panel)

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

	# Minimap
	const MMAP_W : float = 180.0
	const MMAP_H : float = 180.0
	const MMAP_X : float = -196.0

	_mm_location_lbl = Label.new()
	_mm_location_lbl.add_theme_font_override("font", bold)
	_mm_location_lbl.add_theme_font_size_override("font_size", 12)
	_mm_location_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	_mm_location_lbl.text = "THEED"
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
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.add_child(_minimap_panel)

	# Reuse LunarMinimapDraw — it reads _player, _remote_players, _world_layer, _tilemap
	var mm_script = load("res://Scripts/LunarMinimapDraw.gd")
	if mm_script:
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

	# Settings & Help
	var btn_y    : float = 28 + MMAP_H + 22
	var btn_half : float = (MMAP_W - 4) * 0.5

	var help_script = load("res://Scripts/HelpWindow.gd")
	if help_script:
		var help_win = CanvasLayer.new()
		help_win.set_script(help_script)
		add_child(help_win)
		help_win.call("init")
		help_win.call("set_btn_pos", Vector2(vp.x + MMAP_X + btn_half + 4, btn_y))
		help_win.get("_btn").size = Vector2(btn_half, 24)

	var settings_script = load("res://Scripts/SettingsWindow.gd")
	if settings_script:
		var settings_win = CanvasLayer.new()
		settings_win.set_script(settings_script)
		add_child(settings_win)
		settings_win.call("init", self)
		settings_win.call("set_btn_pos", Vector2(vp.x + MMAP_X, btn_y))
		settings_win.call("set_fps_pos", Vector2(vp.x + MMAP_X, btn_y + 28))
		settings_win.get("_btn").size = Vector2(btn_half, 24)

func _make_bar(col: Color, pos: Vector2, sz: Vector2) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.size = sz; bar.position = pos
	bar.min_value = 0.0; bar.max_value = 100.0; bar.value = 100.0
	bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = col; fill.set_corner_radius_all(1)
	fill.border_color = col.darkened(0.35); fill.set_border_width_all(1)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.04, 0.06, 0.95); bg.set_corner_radius_all(1)
	bg.border_color = Color(0.15, 0.12, 0.08, 0.80); bg.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar

func _apply_wound_overlay(ov: ColorRect, wound: float, raw_max: float, bar_x: float, bar_w: float) -> void:
	if ov == null or raw_max <= 0.0:
		return
	var frac = clampf(wound / raw_max, 0.0, 1.0)
	var w = frac * bar_w
	ov.size.x    = w
	ov.position.x = bar_x + bar_w - w

func _make_wound_overlay(right_edge: Vector2, h: float) -> ColorRect:
	var cr = ColorRect.new()
	cr.color = Color(0.0, 0.0, 0.0, 0.88)
	cr.size = Vector2(0.0, h)
	cr.position = right_edge  # x will be pushed left as wounds grow
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr

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
	# ── HAM bars ─────────────────────────────────────────────
	var h_cur = _player.get("ham_health") as float
	var h_max = _player.call("get_effective_max_health") as float
	var a_cur = _player.get("ham_action") as float
	var a_max = _player.call("get_effective_max_action") as float
	var m_cur = _player.get("ham_mind") as float
	var m_max = _player.call("get_effective_max_mind") as float
	var xp  = _player.get("exp_points") as float
	var mxp = _player.get("exp_needed") as float

	_hp_bar.max_value = h_max; _hp_bar.value = h_cur
	if _action_hud_bar: _action_hud_bar.max_value = a_max; _action_hud_bar.value = a_cur
	if _mind_bar: _mind_bar.max_value = m_max; _mind_bar.value = m_cur

	# ── Wound overlays (black bar from right, sized by wound / raw max) ──
	const _BAR_W : float = 204.0
	const _BAR_X : float = 8.0
	var w_h = _player.get("wound_health") as float
	var w_a = _player.get("wound_action") as float
	var w_m = _player.get("wound_mind")   as float
	var raw_h = _player.get("ham_health_max") as float
	var raw_a = _player.get("ham_action_max") as float
	var raw_m = _player.get("ham_mind_max")   as float
	_apply_wound_overlay(_hp_wound_ov,     w_h, raw_h, _BAR_X, _BAR_W)
	_apply_wound_overlay(_action_wound_ov, w_a, raw_a, _BAR_X, _BAR_W)
	_apply_wound_overlay(_mind_wound_ov,   w_m, raw_m, _BAR_X, _BAR_W)
	_xp_bar.max_value = mxp; _xp_bar.value = xp

	var hp_pct = int(h_cur / maxf(h_max, 1.0) * 100.0)
	_hp_bar_lbl.text = "%d / %d" % [int(h_cur), int(h_max)]
	if _action_bar_lbl: _action_bar_lbl.text = "%d / %d" % [int(a_cur), int(a_max)]
	if _mind_bar_lbl: _mind_bar_lbl.text = "%d / %d" % [int(m_cur), int(m_max)]
	_xp_bar_lbl.text = "%d / %d" % [int(xp), int(mxp)]
	if _hp_pct_lbl: _hp_pct_lbl.text = "%d%%" % hp_pct
	var tgt = _player.get("_current_target")
	if tgt != null and is_instance_valid(tgt):
		_tgt_panel.visible = true
		_tgt_name_lbl.text = tgt.get("enemy_name") if tgt.get("enemy_name") != null else "Target"
		var ehp = tgt.get("hp") as float; var emhp = tgt.get("max_hp") as float
		_tgt_hp_bar.max_value = emhp; _tgt_hp_bar.value = ehp
		if _tgt_hp_lbl: _tgt_hp_lbl.text = "%d / %d" % [int(ehp), int(emhp)]
		if _tgt_mp_bar: _tgt_mp_bar.value = 0; _tgt_mp_bar.visible = false
	elif _player_target_peer != -1 and _remote_players.has(_player_target_peer):
		var ptgt = _remote_players[_player_target_peer]
		if is_instance_valid(ptgt):
			_tgt_panel.visible = true
			_tgt_name_lbl.text = str(ptgt.get_meta("character_name", "Player_%d" % _player_target_peer))
			var php = float(ptgt.get_meta("hp", 100.0))
			var pmhp = float(ptgt.get_meta("max_hp", 100.0))
			_tgt_hp_bar.max_value = pmhp; _tgt_hp_bar.value = php
			if _tgt_hp_lbl: _tgt_hp_lbl.text = "%d / %d" % [int(php), int(pmhp)]
			if _tgt_mp_bar: _tgt_mp_bar.visible = true; _tgt_mp_bar.value = 100
		else:
			_player_target_peer = -1; _tgt_panel.visible = false
	else:
		_tgt_panel.visible = false

func _on_frame_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_frame_drag = event.pressed
	elif event is InputEventMouseMotion and _frame_drag:
		var np = _player_frame.position + event.relative
		var vp2 = get_viewport().get_visible_rect().size
		np.x = clampf(np.x, 0.0, vp2.x - _player_frame.size.x)
		np.y = clampf(np.y, 0.0, vp2.y - _player_frame.size.y)
		_player_frame.position = np

# ── SOCIAL SYSTEMS ───────────────────────────────────────────
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
		_duel_system = Node.new(); _duel_system.set_script(ds_script)
		add_child(_duel_system); _duel_system.call("init", self)
	var ps_script = load("res://Scripts/PartySystem.gd")
	if ps_script:
		_party_system = Node.new(); _party_system.set_script(ps_script)
		add_child(_party_system); _party_system.call("init", self, _hud, 110.0)
	var tw_script = load("res://Scripts/TradeWindow.gd")
	if tw_script:
		_trade_system = CanvasLayer.new(); _trade_system.set_script(tw_script)
		add_child(_trade_system); _trade_system.call("init", self)

# ── MULTIPLAYER ──────────────────────────────────────────────
func _join_theed() -> void:
	if not Relay.connected: return
	if not Relay.server_list_received.is_connected(_on_server_list):
		Relay.server_list_received.connect(_on_server_list)
	Relay.request_server_list()

func _on_server_list(servers: Array) -> void:
	for s in servers:
		if s.get("name", "") == "MINISWG-THEED":
			Relay.join_server(s.get("id", ""))
			return
	Relay.host_server("MINISWG-THEED", 64)

func _on_relay_data(from_peer: int, data: Dictionary) -> void:
	if from_peer == Relay.my_peer_id: return
	var cmd = data.get("cmd", "")
	match cmd:
		"move":
			_handle_remote_move(data, from_peer)
		"chat":
			var nick = str(data.get("nick", "Player_%d" % from_peer))
			var msg  = str(data.get("msg", ""))
			if msg.length() > 0:
				var rp = _remote_players.get(from_peer)
				if is_instance_valid(rp):
					_show_remote_bubble(rp, nick, msg)
		"duel_request":
			if is_instance_valid(_duel_system):
				_duel_system.call("on_duel_request", from_peer, str(data.get("from_nick", "")))
		"duel_accept":
			if is_instance_valid(_duel_system): _duel_system.call("on_duel_accepted", from_peer)
		"duel_decline":
			if is_instance_valid(_duel_system): _duel_system.call("on_duel_declined", from_peer)
		"party_invite":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_invite", from_peer, str(data.get("nick", "")), data.get("members", []))
		"party_accept":
			if is_instance_valid(_party_system): _party_system.call("on_party_accept", from_peer)
		"party_decline":
			if is_instance_valid(_party_system): _party_system.call("on_party_decline", from_peer)
		"party_update":
			if is_instance_valid(_party_system):
				_party_system.call("on_party_update", int(data.get("leader", -1)), data.get("members", []))
		"trade_request":
			if is_instance_valid(_trade_system):
				_trade_system.call("show_request", from_peer, str(data.get("nick", "")))
		"trade_accept":
			if is_instance_valid(_trade_system):
				var rp3 = _remote_players.get(from_peer)
				var tnick = "Player_%d" % from_peer
				if is_instance_valid(rp3): tnick = str(rp3.get_meta("character_name", tnick))
				_trade_system.call("open_trade", from_peer, tnick)
		"trade_offer":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_offer", data.get("items", []), int(data.get("credits", 0)))
		"trade_confirm":
			if is_instance_valid(_trade_system): _trade_system.call("on_trade_confirm")
		"trade_complete":
			if is_instance_valid(_trade_system):
				_trade_system.call("on_trade_complete", data.get("items_from", []), int(data.get("creds_from", 0)), data.get("items_to", []), int(data.get("creds_to", 0)))
		"trade_cancel":
			if is_instance_valid(_trade_system): _trade_system.call("on_trade_cancel")

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
	rp.set_meta("hp", float(data.get("hp", 100)))
	rp.set_meta("max_hp", float(data.get("max_hp", 100)))
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
	if cls == "melee" or cls == "scrapper":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
	elif cls == "medic":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "ranged":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
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
		if is_instance_valid(rp): rp.queue_free()
		_remote_players.erase(peer_id)
	if is_instance_valid(_party_system):
		_party_system.call("on_peer_disconnected", peer_id)
	if _player_target_peer == peer_id:
		_player_target_peer = -1

# ── COMBAT SPAWNERS (called by BossArenaPlayer) ──────────────
func is_targeted(node: Node) -> bool:
	if not is_instance_valid(_player): return false
	var tgt = _player.get("_current_target")
	return is_instance_valid(tgt) and tgt == node

func spawn_damage_number(world_pos: Vector2, amount: float, col: Color, text_override: String = "") -> void:
	var script = load("res://Scripts/DamageNumber.gd")
	if script == null: return
	var dn = Node2D.new(); dn.set_script(script); dn.position = world_pos
	add_child(dn)
	if text_override != "" and dn.has_method("init_text"):
		dn.call("init_text", text_override, col)
	else:
		dn.call("init", amount, col)

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

# ── CHAT BUBBLES ─────────────────────────────────────────────
func _show_remote_bubble(parent: Node2D, nick: String, msg: String) -> void:
	var old = parent.get_node_or_null("ChatBubble")
	if old: old.queue_free()
	var bubble = Node2D.new(); bubble.name = "ChatBubble"; parent.add_child(bubble)
	var full_msg = "%s: %s" % [nick, msg]
	var max_chars = 28; var font_sz = 8; var char_w = font_sz * 0.62; var line_h = font_sz + 3
	var pad_x = 5; var pad_y = 4
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
	var bx = -bw / 2; var by = -45 - bh
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

# ── TARGET REMOVAL ───────────────────────────────────────────
func _on_targetable_removed(mob: Node) -> void:
	if is_instance_valid(_player):
		var cur = _player.get("_current_target")
		if cur == mob:
			_player.set("_current_target", null)
			if _tgt_panel: _tgt_panel.visible = false

# ── CREATURE SPAWNERS (F1–F5) ────────────────────────────────
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

func _build_boss_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Enemies/ZergBoss/"
	for dir in ["s","n","e","w"]:
		_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   132,132,8,7.0)
		_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    132,132,8,10.0)
		_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",132,132,8,12.0,false)
	return frames

func _build_cyberlord_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Old/melee2/"
	for dir in ["s","n","e","w"]:
		_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   144,144,8,7.0)
		_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    144,144,8,10.0)
		_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",144,144,7,12.0,false)
	return frames

func _build_vampire_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/NEWFOUNDMETHOD/NPC/Vampirething/"
	for dir in ["s","n","e","w","se","sw","ne","nw"]:
		_add_strip(frames, "idle_"+dir, base+"idle/idle_"+dir+".png", 512, 512, 30, 10.0)
		_add_strip(frames, "run_"+dir, base+"run/run_"+dir+".png", 512, 512, 30, 14.0)
		_add_strip(frames, "attack_"+dir, base+"attack/attack_"+dir+".png", 512, 512, 30, 18.0, false)
	return frames

func _spawn_vampire(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/VampireBoss.gd")
	if script == null: return
	var boss = CharacterBody2D.new()
	boss.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_vampire_frames()
	sprite.scale = Vector2(0.25, 0.25); sprite.offset = Vector2(0, -180)
	boss.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 20.0; shape.height = 40.0; col.shape = shape; boss.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("vampire").size()
		var angle = TAU * (float(n) / 6.0); var dist = 200.0 + n * 60.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	boss.position = at_pos; boss.collision_layer = 2; boss.collision_mask = 2
	_world_layer.add_child(boss); boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "vampire", "x": at_pos.x, "y": at_pos.y})

func _build_thug_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/NEWFOUNDMETHOD/NPC/TanArmorGuy/"
	for dir in ["s","n","e","w","se","sw","ne","nw"]:
		_add_strip(frames, "idle_"+dir, base+"idle/idle_"+dir+".png", 512, 512, 30, 10.0)
		_add_strip(frames, "run_"+dir, base+"run/run_"+dir+".png", 512, 512, 30, 14.0)
		_add_strip(frames, "attack_"+dir, base+"attack/attack_"+dir+".png", 512, 512, 30, 18.0, false)
	return frames

func _spawn_armored_thug(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/ArmoredThug.gd")
	if script == null: return
	var mob = CharacterBody2D.new()
	mob.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_thug_frames()
	sprite.scale = Vector2(0.32, 0.32); sprite.offset = Vector2(0, -140)
	mob.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius = 18.0; shape.height = 36.0; col.shape = shape; mob.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("armored_thug").size()
		var angle = TAU * (float(n) / 8.0); var dist = 150.0 + n * 40.0
		at_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	mob.position = at_pos; mob.collision_layer = 2; mob.collision_mask = 2
	_world_layer.add_child(mob); mob.tree_exiting.connect(_on_targetable_removed.bind(mob))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "armored_thug", "x": at_pos.x, "y": at_pos.y})

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
