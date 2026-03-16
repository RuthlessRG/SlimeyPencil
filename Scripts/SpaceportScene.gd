extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  SpaceportScene.gd — miniSWG | Level 1: Coronet Spaceport
#
#  World layout (8192 x 8192):
#   TOP-LEFT quadrant  — Coronet Spaceport complex
#   Rest of world      — Open grasslands, rivers, road network
#
#  Attach to a bare Node2D scene: spaceport.tscn
#  Add this to group "boss_arena_scene" for player compat.
# ============================================================

# ── WORLD ─────────────────────────────────────────────────────
const WORLD_W : float = 16384.0
const WORLD_H : float = 16384.0

# Spaceport complex sits in the top-left quadrant
const PORT_X  : float = 80.0
const PORT_Y  : float = 80.0
const PORT_W  : float = 2600.0
const PORT_H  : float = 2400.0

# ── PALETTE ───────────────────────────────────────────────────
# Sky-blue tarmac, warm tan earth, vivid greens
const C_TARMAC        = Color(0.62, 0.66, 0.72)    # blue-grey landing pad concrete
const C_TARMAC_DARK   = Color(0.50, 0.54, 0.60)
const C_TARMAC_LINE   = Color(0.95, 0.85, 0.20)    # yellow runway markings
const C_EARTH         = Color(0.68, 0.52, 0.28)    # tan dirt roads / paths
const C_GRASS_BASE    = Color(0.36, 0.62, 0.22)    # vibrant open grassland
const C_GRASS_DARK    = Color(0.28, 0.50, 0.16)
const C_GRASS_LIGHT   = Color(0.50, 0.76, 0.30)
const C_RIVER         = Color(0.22, 0.52, 0.82)
const C_RIVER_FOAM    = Color(0.60, 0.80, 1.00, 0.55)
const C_BUILDING_WALL = Color(0.88, 0.88, 0.90)    # white-ish durasteel
const C_BUILDING_TRIM = Color(0.55, 0.60, 0.70)
const C_BUILDING_DARK = Color(0.40, 0.44, 0.52)
const C_DOME          = Color(0.72, 0.80, 0.88)
const C_DOME_SHINE    = Color(0.95, 0.97, 1.00, 0.60)
const C_TOWER_BASE    = Color(0.78, 0.80, 0.84)
const C_TOWER_GLASS   = Color(0.45, 0.72, 0.95, 0.80)
const C_SHIP_HULL     = Color(0.90, 0.92, 0.95)
const C_SHIP_DARK     = Color(0.60, 0.64, 0.70)
const C_SHIP_ACCENT   = Color(0.25, 0.55, 0.95)
const C_PALACE_STONE  = Color(0.82, 0.78, 0.70)
const C_PALACE_TRIM   = Color(0.60, 0.50, 0.30)
const C_PALACE_GOLD   = Color(0.90, 0.72, 0.15)
const C_ROAD          = Color(0.58, 0.52, 0.42)
const C_ROAD_LINE     = Color(0.85, 0.80, 0.65, 0.60)
const C_SHADOW        = Color(0.00, 0.00, 0.00, 0.18)

# ── 2.5D ISOMETRIC PROJECTION ─────────────────────────────────
# Per unit of building depth: this is how far right (ISO_DX) and
# how far UP (ISO_DY) it shifts in screen space.
const ISO_DX : float =  0.44
const ISO_DY : float = -0.34
const C_TREE_DARK     = Color(0.18, 0.42, 0.12)
const C_TREE_MID      = Color(0.28, 0.58, 0.18)
const C_TREE_LIGHT    = Color(0.44, 0.76, 0.26)
const C_HILL_BASE     = Color(0.30, 0.55, 0.18)
const C_HILL_LIGHT    = Color(0.44, 0.72, 0.28)

# ── SCENE NODES ───────────────────────────────────────────────
var _camera        : Camera2D    = null
var _player        : Node        = null
var _select_layer  : CanvasLayer = null
var _hud           : CanvasLayer = null
var _cam_zoom_base : float       = 1.1
var _cam_zoom_target : float     = 1.1
var _pending_nickname : String   = ""

# Pre-generated decoration data (seeded RNG so it's deterministic)
var _grass_tufts   : Array = []
var _trees         : Array = []
var _field_stones  : Array = []

# HUD refs
var _player_name_lbl : Label       = null
var _hp_bar          : ProgressBar = null
var _mp_bar          : ProgressBar = null
var _xp_bar          : ProgressBar = null
var _hp_bar_lbl      : Label       = null
var _mp_bar_lbl      : Label       = null
var _xp_bar_lbl      : Label       = null
var _tgt_panel       : Panel       = null
var _tgt_name_lbl    : Label       = null
var _tgt_hp_bar      : ProgressBar = null
var _tgt_hp_lbl      : Label       = null
var _tgt_mp_bar      : ProgressBar = null
var _player_frame    : Panel       = null
var _frame_drag      : bool        = false
var _portrait_rect   : TextureRect = null
var _level_lbl       : Label       = null
var _mm_location_lbl : Label       = null
var _mm_channel_lbl  : Label       = null

# ── NICKNAME FILTER ───────────────────────────────────────────
const BAD_WORDS : Array = [
	"ass","asshole","bastard","bitch","cock","cunt","damn",
	"dick","douche","fuck","homo","jackass","jerk","moron",
	"nigga","nigger","piss","prick","pussy","shit","slut","twat","whore",
]
func _contains_bad_word(text: String) -> bool:
	for w in BAD_WORDS:
		if text.find(w) >= 0: return true
	return false

# ── MUSIC ─────────────────────────────────────────────────────
var _music      : AudioStreamPlayer = null
var _theed      : AudioStreamPlayer = null   # extra ambient near spaceport
var _theed_vol  : float = 0.0               # current linear volume (0-1)

# ── MISSION STATE ─────────────────────────────────────────────
var _mission_active       : bool    = false
var _mission_name         : String  = ""
var _mission_payout       : int     = 0
var _mission_type         : String  = "zerg"   # "zerg" | "aadu"
var _mission_target_pos   : Vector2 = Vector2.ZERO
var _mission_terminal_pos : Vector2 = Vector2.ZERO
var _mission_compass      : Control = null

# ── SCENE ANIMATION ────────────────────────────────────────────
var _scene_time : float = 0.0   # used for neon/light animation

# ── MULTIPLAYER ────────────────────────────────────────────────
var _remote_players  : Dictionary = {}   # peer_id (int) → Node2D
var _broadcast_timer : float      = 0.0
var _minimap_draw    : Control    = null

# ── SOCIAL SYSTEMS ─────────────────────────────────────────────
var _duel_system       : Node = null
var _party_system      : Node = null
var _trade_system      : Node = null
var _options_panel     : Node = null
var _player_target_peer : int = -1   # peer_id of visually-targeted remote player

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("boss_arena_scene")
	add_to_group("ui_layer")
	_gen_decorations()
	_setup_camera()
	_start_music()
	_show_character_select()
	# Animated overlay — handles birds + flying ships in its own redraw loop
	var overlay        = Node2D.new()
	overlay.set_script(load("res://Scripts/AnimOverlay.gd"))
	add_child(overlay)
	if not Relay.game_data_received.is_connected(_on_relay_data):
		Relay.game_data_received.connect(_on_relay_data)
	if not Relay.peer_left.is_connected(_on_peer_left):
		Relay.peer_left.connect(_on_peer_left)

func _start_music() -> void:
	var stream = load("res://Sounds/spaceportambience.mp3") as AudioStream
	if stream == null: return
	_music = AudioStreamPlayer.new()
	_music.stream    = stream
	_music.volume_db = -20.0
	_music.bus       = "Master"
	add_child(_music)
	_music.play()

	var theed_stream = load("res://Sounds/Music/theed.mp3") as AudioStream
	if theed_stream != null:
		_theed             = AudioStreamPlayer.new()
		_theed.stream      = theed_stream
		_theed.volume_db   = -80.0   # start silent
		_theed.bus         = "Master"
		add_child(_theed)
		_theed.play()

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	_cam_zoom_base = lerpf(_cam_zoom_base, _cam_zoom_target, 1.0 - exp(-8.0 * delta))
	_camera.zoom = Vector2.ONE * _cam_zoom_base
	if _minimap_draw != null:
		_minimap_draw.queue_redraw()
	# Theed ambient music fades in near spaceport, out when player leaves
	if _theed != null and is_instance_valid(_player):
		var pp : Vector2 = _player.global_position
		var edge_dx : float = maxf(maxf(PORT_X - pp.x, pp.x - (PORT_X + PORT_W)), 0.0)
		var edge_dy : float = maxf(maxf(PORT_Y - pp.y, pp.y - (PORT_Y + PORT_H)), 0.0)
		var dist_outside : float = sqrt(edge_dx * edge_dx + edge_dy * edge_dy)
		var target_vol : float = clampf(1.0 - dist_outside / 500.0, 0.0, 1.0) * 0.70
		_theed_vol = lerpf(_theed_vol, target_vol, delta * 1.2)
		_theed.volume_db = linear_to_db(maxf(_theed_vol, 0.0001))
	if is_instance_valid(_player):
		_camera.global_position = _player.global_position
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
	var lerp_w = 1.0 - exp(-12.0 * delta)   # frame-rate independent smoothing
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if is_instance_valid(rp) and rp.has_meta("target_pos"):
			rp.position = rp.position.lerp(rp.get_meta("target_pos"), lerp_w)
	_update_hud()
	_update_mission_compass()
	_tick_poison(delta)
	_scene_time += delta

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.15, 0.5, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.15, 0.5, 4.0)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			# Check click near a remote player
			var world_pos = _camera.get_screen_center_position() + \
				(event.position - get_viewport().get_visible_rect().size * 0.5) / _cam_zoom_base
			var best_peer : int = -1
			var best_dist : float = 32.0   # click radius in world px
			for pid in _remote_players:
				var rp = _remote_players[pid]
				if not is_instance_valid(rp): continue
				var d = rp.global_position.distance_to(world_pos)
				if d < best_dist:
					best_dist = d
					best_peer = pid
			if best_peer != -1:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_player_target_peer = best_peer
				else:
					var rp2 = _remote_players.get(best_peer)
					var nick2 = ""
					if is_instance_valid(rp2):
						var nn2 = rp2.get("character_name")
						nick2 = str(nn2) if nn2 != null else "Player_%d" % best_peer
					if is_instance_valid(_options_panel):
						_options_panel.call("show_for", best_peer, nick2, event.position)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_player_target_peer = -1   # deselect on empty click
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_player_target_peer = -1
	if not is_instance_valid(_player): return
	if event is InputEventKey and event.pressed and not event.echo:
		if   event.keycode == KEY_F1: _spawn_dummy()
		elif event.keycode == KEY_F2: _spawn_boss()
		elif event.keycode == KEY_F3: _spawn_cyberlord()
		elif event.keycode == KEY_F4: _spawn_zerg_mob()
		elif event.keycode == KEY_F5: _spawn_cyber_mob()
		elif event.keycode == KEY_H:
			if _player.has_method("add_credits"):
				_player.call("add_credits", 5000)
			else:
				_player.set("credits", (_player.get("credits") as int) + 5000)
		elif event.keycode == KEY_L:
			_spawn_teleporter_at_player()

func _spawn_dummy(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/TrainingDummy.gd")
	var dummy  = Node2D.new()
	dummy.set_script(script)
	dummy.scale = Vector2(0.7, 0.7)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("training_dummy").size()
		at_pos = _player.global_position + Vector2(80.0 + n * 50.0, 0.0)
	dummy.position = at_pos
	add_child(dummy)
	dummy.tree_exiting.connect(_on_targetable_removed.bind(dummy))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "dummy", "x": at_pos.x, "y": at_pos.y})

func _spawn_boss(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/ZergBoss.gd")
	var boss   = CharacterBody2D.new()
	boss.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_boss_frames()
	sprite.scale = Vector2(2.0,2.0); sprite.offset = Vector2(0,-33)
	boss.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius=52.0; shape.height=90.0; col.shape=shape; boss.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("boss").size()
		var angle = TAU*(float(n)/6.0); var dist = 280.0+n*50.0
		at_pos = _player.global_position + Vector2(cos(angle),sin(angle))*dist
	boss.position = at_pos
	boss.collision_layer=2; boss.collision_mask=2
	add_child(boss); boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "boss", "x": at_pos.x, "y": at_pos.y})

func _spawn_cyberlord(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/CyberLord.gd")
	var boss   = CharacterBody2D.new()
	boss.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"; sprite.sprite_frames = _build_cyberlord_frames()
	sprite.scale = Vector2(264.0/144.0,264.0/144.0); sprite.offset = Vector2(0,-72)
	boss.add_child(sprite)
	var col = CollisionShape2D.new(); var shape = CapsuleShape2D.new()
	shape.radius=52.0; shape.height=90.0; col.shape=shape; boss.add_child(col)
	if at_pos == Vector2.ZERO:
		var n = get_tree().get_nodes_in_group("boss").size()
		var angle = TAU*(float(n)/6.0); var dist = 280.0+n*50.0
		at_pos = _player.global_position + Vector2(cos(angle),sin(angle))*dist
	boss.position = at_pos
	boss.collision_layer=2; boss.collision_mask=2
	add_child(boss); boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "cyberlord", "x": at_pos.x, "y": at_pos.y})

func _spawn_zerg_mob(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/ZergMob.gd")
	var mob = CharacterBody2D.new(); mob.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name="Sprite"; sprite.sprite_frames=_build_boss_frames()
	sprite.scale=Vector2(1.0,1.0); sprite.offset=Vector2(0,-33)
	mob.add_child(sprite)
	var col=CollisionShape2D.new(); var shape=CapsuleShape2D.new()
	shape.radius=26.0; shape.height=45.0; col.shape=shape; mob.add_child(col)
	if at_pos == Vector2.ZERO:
		var n=get_tree().get_nodes_in_group("mob").size()
		var angle=TAU*(float(n)/8.0); var dist=180.0+n*30.0
		at_pos=_player.global_position+Vector2(cos(angle),sin(angle))*dist
	mob.position=at_pos
	mob.collision_layer=2; mob.collision_mask=2
	add_child(mob); mob.tree_exiting.connect(_on_targetable_removed.bind(mob))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "zerg_mob", "x": at_pos.x, "y": at_pos.y})

func _spawn_cyber_mob(at_pos: Vector2 = Vector2.ZERO, broadcast: bool = true) -> void:
	var script = load("res://Scripts/CyberMob.gd")
	var mob = CharacterBody2D.new(); mob.set_script(script)
	var sprite = AnimatedSprite2D.new()
	sprite.name="Sprite"; sprite.sprite_frames=_build_cyberlord_frames()
	sprite.scale=Vector2(264.0/144.0*0.5,264.0/144.0*0.5); sprite.offset=Vector2(0,-72)
	mob.add_child(sprite)
	var col=CollisionShape2D.new(); var shape=CapsuleShape2D.new()
	shape.radius=26.0; shape.height=45.0; col.shape=shape; mob.add_child(col)
	if at_pos == Vector2.ZERO:
		var n=get_tree().get_nodes_in_group("mob").size()
		var angle=TAU*(float(n)/8.0); var dist=180.0+n*30.0
		at_pos=_player.global_position+Vector2(cos(angle),sin(angle))*dist
	mob.position=at_pos
	mob.collision_layer=2; mob.collision_mask=2
	add_child(mob); mob.tree_exiting.connect(_on_targetable_removed.bind(mob))
	if broadcast:
		Relay.send_game_data({"cmd": "spawn_creature", "type": "cyber_mob", "x": at_pos.x, "y": at_pos.y})

# ── CAMERA ────────────────────────────────────────────────────
func _setup_camera() -> void:
	_camera             = Camera2D.new()
	_camera.name        = "Camera"
	_camera.position    = Vector2(PORT_X + PORT_W * 0.5, PORT_Y + PORT_H * 0.5)
	_camera.zoom        = Vector2(1.1, 1.1)
	_camera.limit_left  = 0
	_camera.limit_top   = 0
	_camera.limit_right = int(WORLD_W)
	_camera.limit_bottom = int(WORLD_H)
	add_child(_camera)
	_camera.make_current()

# ── PRE-GEN DECORATION DATA ────────────────────────────────────
func _gen_decorations() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337

	# Grass tufts scattered across the open field (outside spaceport)
	for _i in 1800:
		var gx = rng.randf_range(0, WORLD_W)
		var gy = rng.randf_range(0, WORLD_H)
		# Skip spaceport footprint
		if gx < PORT_X + PORT_W + 60 and gy < PORT_Y + PORT_H + 60:
			continue
		_grass_tufts.append({
			"pos": Vector2(gx, gy),
			"h":   rng.randf_range(4.0, 11.0),
			"w":   rng.randf_range(2.0, 5.0),
			"lean": rng.randf_range(-0.4, 0.4),
			"shade": rng.randf_range(0.0, 1.0),
		})

	# Trees — clusters in the mid-to-far field
	for _i in 420:
		var tx = rng.randf_range(2800, WORLD_W - 100)
		var ty = rng.randf_range(600, WORLD_H - 100)
		_trees.append({
			"pos":  Vector2(tx, ty),
			"r":    rng.randf_range(14.0, 28.0),
			"hue":  rng.randf_range(0.0, 1.0),
		})
	# Some trees along the left edge too (south of spaceport)
	for _i in 80:
		var tx = rng.randf_range(PORT_X, PORT_X + PORT_W * 0.5)
		var ty = rng.randf_range(PORT_Y + PORT_H + 200, WORLD_H - 100)
		_trees.append({
			"pos":  Vector2(tx, ty),
			"r":    rng.randf_range(12.0, 22.0),
			"hue":  rng.randf_range(0.0, 1.0),
		})

	# Small field stones
	for _i in 340:
		var sx = rng.randf_range(400, WORLD_W - 200)
		var sy = rng.randf_range(400, WORLD_H - 200)
		if sx < PORT_X + PORT_W + 100 and sy < PORT_Y + PORT_H + 100:
			continue
		_field_stones.append({
			"pos": Vector2(sx, sy),
			"rx":  rng.randf_range(4.0, 10.0),
			"ry":  rng.randf_range(3.0, 7.0),
			"rot": rng.randf_range(0.0, TAU),
		})

# ============================================================
#  MAIN DRAW
# ============================================================
func _draw() -> void:
	_draw_ground()
	_draw_rivers()
	_draw_field_details()
	_draw_spaceport()

# ── GROUND ────────────────────────────────────────────────────
func _draw_ground() -> void:
	# Base grass fills entire world
	draw_rect(Rect2(0, 0, WORLD_W, WORLD_H), C_GRASS_BASE)

	# Subtle variation stripes — rolling hills effect
	var step = 120.0
	var y = 0.0
	while y < WORLD_H:
		var alpha = 0.06 + sin(y * 0.003) * 0.04
		draw_rect(Rect2(0, y, WORLD_W, step * 0.5), Color(C_GRASS_LIGHT.r, C_GRASS_LIGHT.g, C_GRASS_LIGHT.b, alpha))
		y += step

	# Distant hills along the far edges (top and right)
	_draw_hills()

	# Grass tufts
	for t in _grass_tufts:
		var col = C_GRASS_DARK if t.shade < 0.5 else C_GRASS_LIGHT
		var base = t.pos
		# 3 blades per tuft
		for b in 3:
			var bx = base.x + (b - 1) * t.w * 0.8
			var lean = t.lean + (b - 1) * 0.15
			draw_line(Vector2(bx, base.y),
				Vector2(bx + lean * t.h, base.y - t.h),
				Color(col.r, col.g, col.b, 0.70), 1.2)

	# Field stones — only draw stones large enough to triangulate safely
	for s in _field_stones:
		if s.rx < 5.0 or s.ry < 4.0: continue
		if s.ry * 0.5 >= 2.5:
			var shd = _ellipse(s.pos + Vector2(2, 4), s.rx * 0.9, s.ry * 0.5, s.rot, 8)
			draw_colored_polygon(shd, C_SHADOW)
		var pts = _ellipse(s.pos, s.rx, s.ry, s.rot, 8)
		draw_colored_polygon(pts, Color(0.65, 0.63, 0.58))

func _draw_hills() -> void:
	# Background hill silhouettes along the top horizon
	var hill_data = [
		[0.0, 220.0, 900.0, 180.0], [700.0, 180.0, 1100.0, 220.0],
		[1500.0, 190.0, 1400.0, 200.0], [2700.0, 160.0, 1600.0, 240.0],
		[4000.0, 200.0, 1200.0, 190.0], [5100.0, 170.0, 1500.0, 210.0],
		[6400.0, 190.0, 1300.0, 200.0], [7400.0, 160.0, 1000.0, 230.0],
		[8800.0, 200.0, 1400.0, 210.0], [10200.0, 175.0, 1600.0, 240.0],
		[11800.0, 185.0, 1200.0, 200.0], [13200.0, 165.0, 1500.0, 220.0],
		[14600.0, 195.0, 1100.0, 190.0],
	]
	for hd in hill_data:
		var pts = PackedVector2Array()
		var hx = hd[0]; var hy = hd[1]; var hw = hd[2]; var hh = hd[3]
		pts.append(Vector2(hx - hw * 0.5, hy))
		var steps = 24
		for i in (steps + 1):
			var t = float(i) / float(steps)
			var px = hx - hw * 0.5 + t * hw
			var py = hy - sin(t * PI) * hh
			pts.append(Vector2(px, py))
		pts.append(Vector2(hx + hw * 0.5, hy))
		draw_colored_polygon(pts, C_HILL_BASE)
		# Lighter top edge
		var top_pts = PackedVector2Array()
		for i in (steps + 1):
			var t = float(i) / float(steps)
			var px = hx - hw * 0.5 + t * hw
			var py = hy - sin(t * PI) * hh
			top_pts.append(Vector2(px, py))
		if top_pts.size() >= 2:
			for i in (top_pts.size() - 1):
				draw_line(top_pts[i], top_pts[i+1], Color(C_HILL_LIGHT.r, C_HILL_LIGHT.g, C_HILL_LIGHT.b, 0.60), 3.0)

# ── ROADS ─────────────────────────────────────────────────────
func _draw_roads() -> void:
	pass   # Roads removed — open world

# ── RIVERS & LAKES ────────────────────────────────────────────
func _draw_rivers() -> void:
	# ── Lake 1 — mid-east region ──────────────────────────────
	var lake1_c = Vector2(WORLD_W * 0.72, WORLD_H * 0.38)
	var lake1_rx = 620.0; var lake1_ry = 390.0
	_draw_lake(lake1_c, lake1_rx, lake1_ry)

	# ── Lake 2 — south-west region ────────────────────────────
	var lake2_c = Vector2(WORLD_W * 0.22, WORLD_H * 0.74)
	var lake2_rx = 500.0; var lake2_ry = 310.0
	_draw_lake(lake2_c, lake2_rx, lake2_ry)

	# ── River A — flows from north, widens into Lake 1 ─────────
	# Starts near the spaceport east edge, winds south-east into lake 1
	_draw_river_segment(
		Vector2(PORT_X + PORT_W + 380, PORT_Y + PORT_H),   # start
		Vector2(lake1_c.x - lake1_rx * 0.6, lake1_c.y),    # end mouth
		28.0, 0.006)

	# ── River B — flows from lake 1 south to lake 2 ────────────
	_draw_river_segment(
		Vector2(lake1_c.x, lake1_c.y + lake1_ry * 0.7),
		Vector2(lake2_c.x + lake2_rx * 0.5, lake2_c.y - lake2_ry * 0.4),
		22.0, 0.005)

	# ── River C — drains lake 2 to west edge ──────────────────
	_draw_river_segment(
		Vector2(lake2_c.x - lake2_rx * 0.8, lake2_c.y),
		Vector2(0, lake2_c.y + 80),
		18.0, 0.007)

func _draw_lake(center: Vector2, rx: float, ry: float) -> void:
	# Deep lake fill — layered for depth effect
	var rng2 = RandomNumberGenerator.new()
	rng2.seed = int(center.x + center.y)
	# Outer shallow water
	var outer = PackedVector2Array()
	for i in 40:
		var a   = float(i)/40.0 * TAU
		var jit = rng2.randf_range(0.92, 1.06)
		outer.append(center + Vector2(cos(a)*rx*jit, sin(a)*ry*jit))
	draw_colored_polygon(outer, Color(0.18, 0.44, 0.72))
	# Mid water
	var mid_pts = PackedVector2Array()
	for i in 36:
		var a   = float(i)/36.0 * TAU
		var jit = rng2.randf_range(0.88, 1.02)
		mid_pts.append(center + Vector2(cos(a)*rx*0.82*jit, sin(a)*ry*0.82*jit))
	draw_colored_polygon(mid_pts, Color(0.15, 0.38, 0.68))
	# Deep centre
	var deep = PackedVector2Array()
	for i in 28:
		var a = float(i)/28.0 * TAU
		deep.append(center + Vector2(cos(a)*rx*0.50, sin(a)*ry*0.50))
	draw_colored_polygon(deep, Color(0.10, 0.28, 0.58))
	# Specular highlight
	var hi_c = center + Vector2(-rx*0.22, -ry*0.18)
	var hi = PackedVector2Array()
	for i in 20:
		var a = float(i)/20.0 * TAU
		hi.append(hi_c + Vector2(cos(a)*rx*0.28, sin(a)*ry*0.16))
	draw_colored_polygon(hi, Color(0.55, 0.78, 1.00, 0.28))
	# Shoreline foam ring
	for i in 40:
		var a0 = float(i)/40.0 * TAU
		var a1 = float(i+1)/40.0 * TAU
		var p0 = center + Vector2(cos(a0)*rx, sin(a0)*ry)
		var p1 = center + Vector2(cos(a1)*rx, sin(a1)*ry)
		draw_line(p0, p1, Color(0.55, 0.80, 1.00, 0.45), 3.0)

func _draw_river_segment(start: Vector2, end_pos: Vector2, width: float, _freq: float) -> void:
	# Draw a curving river from start to end using a bezier-like S-curve
	var ctrl_mid = (start + end_pos) * 0.5 + Vector2(
		sin(start.x * 0.0003) * 400.0,
		cos(start.y * 0.0003) * 300.0)
	var segs = 48
	var pts_top = PackedVector2Array()
	var pts_bot = PackedVector2Array()
	for i in (segs + 1):
		var t   = float(i) / segs
		# Quadratic bezier
		var p   = start.lerp(ctrl_mid, t).lerp(ctrl_mid.lerp(end_pos, t), t)
		var _tang : Vector2
		if i < segs:
			var t2  = float(i+1)/segs
			var p2  = start.lerp(ctrl_mid,t2).lerp(ctrl_mid.lerp(end_pos,t2),t2)
			_tang = (p2 - p).normalized()
		else:
			_tang = (end_pos - ctrl_mid).normalized()
		var perp = Vector2(-_tang.y, _tang.x)
		var w    = width * (0.8 + 0.2 * sin(t * PI))   # slight widening in middle
		var wave = sin(t * 8.0 * PI) * 4.0
		pts_top.append(p + perp * (w + wave))
		pts_bot.append(p - perp * (w - wave))
	# Combine into closed polygon
	var rpts = PackedVector2Array()
	for pt in pts_top: rpts.append(pt)
	for i in range(pts_bot.size()-1, -1, -1): rpts.append(pts_bot[i])
	draw_colored_polygon(rpts, C_RIVER)
	# Foam edges
	for i in (segs):
		draw_line(pts_top[i], pts_top[i+1], C_RIVER_FOAM, 1.8)

# ── FIELD DETAILS ─────────────────────────────────────────────
func _draw_field_details() -> void:
	# Trees
	for t in _trees:
		var r  = t.r
		var h  = t.hue
		# Trunk
		draw_rect(Rect2(t.pos.x - 2.5, t.pos.y - r * 0.3, 5.0, r * 0.5), Color(0.35, 0.22, 0.10))
		# Shadow
		draw_colored_polygon(_ellipse(t.pos + Vector2(r * 0.3, r * 0.2), r * 0.9, r * 0.4, 0.0, 12), C_SHADOW)
		# Dark outer
		draw_colored_polygon(_ellipse(t.pos, r, r * 0.88, 0.0, 14),
			Color(C_TREE_DARK.r, C_TREE_DARK.g * (0.85 + h * 0.15), C_TREE_DARK.b))
		# Bright inner highlight
		draw_colored_polygon(_ellipse(t.pos + Vector2(-r*0.15, -r*0.18), r * 0.58, r * 0.52, 0.0, 12),
			Color(C_TREE_LIGHT.r, C_TREE_LIGHT.g * (0.9 + h * 0.1), C_TREE_LIGHT.b))

# ============================================================
#  SPACEPORT COMPLEX  (top-left)
# ============================================================
func _draw_spaceport() -> void:
	_draw_port_ground()
	_draw_port_waterway()       # canal cut into tarmac, drawn before buildings
	_draw_perimeter_wall()
	_draw_docking_pads()
	_draw_control_tower()
	_draw_hangars()
	_draw_palace()
	_draw_port_buildings()
	_draw_extra_buildings()
	_draw_bottom_buildings()    # new district buildings in lower quadrants
	_draw_neon_signs()
	_draw_port_details()
	_draw_southern_district()   # extra southern buildings
	_draw_ships()   # ships drawn last — always on top of buildings

# ── PORT GROUND ───────────────────────────────────────────────
func _draw_port_ground() -> void:
	# Main tarmac fill
	draw_rect(Rect2(PORT_X, PORT_Y, PORT_W, PORT_H), C_TARMAC)

	# Subtle grid pattern on tarmac
	var grid = 80.0
	var gx = PORT_X
	while gx < PORT_X + PORT_W:
		draw_line(Vector2(gx, PORT_Y), Vector2(gx, PORT_Y + PORT_H),
			Color(C_TARMAC_DARK.r, C_TARMAC_DARK.g, C_TARMAC_DARK.b, 0.25), 1.0)
		gx += grid
	var gy = PORT_Y
	while gy < PORT_Y + PORT_H:
		draw_line(Vector2(PORT_X, gy), Vector2(PORT_X + PORT_W, gy),
			Color(C_TARMAC_DARK.r, C_TARMAC_DARK.g, C_TARMAC_DARK.b, 0.25), 1.0)
		gy += grid

	# Main taxiway — vertical yellow line down the center
	var cx = PORT_X + PORT_W * 0.5
	draw_rect(Rect2(cx - 3, PORT_Y, 6, PORT_H), C_TARMAC_LINE)
	# Horizontal cross taxiway
	var cy = PORT_Y + PORT_H * 0.55
	draw_rect(Rect2(PORT_X, cy - 3, PORT_W, 6), C_TARMAC_LINE)

	# Circular apron around control tower
	var tower_pos = Vector2(PORT_X + PORT_W * 0.5, PORT_Y + PORT_H * 0.42)
	for ring in [200.0, 240.0]:
		draw_arc(tower_pos, ring, 0.0, TAU, 64, C_TARMAC_LINE, 2.5)

	# ── Runway markings ──────────────────────────────────────────
	var rwy_cx = PORT_X + PORT_W * 0.5
	var lc     = Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.75)
	var lc_dim = Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.45)

	# Threshold piano-keys — north + south ends
	for thresh_y in [PORT_Y + 18, PORT_Y + PORT_H - 52]:
		for bi in 7:
			var bx = rwy_cx - 56 + bi * 18
			if absf(bx - rwy_cx) < 10: continue
			draw_rect(Rect2(bx, thresh_y, 12, 32), lc)

	# Runway numbers: "09" top, "27" bottom
	var rfont = _roboto
	_draw_label(rfont, Vector2(rwy_cx - 14, PORT_Y + 68), "09", 18, lc)
	_draw_label(rfont, Vector2(rwy_cx - 14, PORT_Y + PORT_H - 24), "27", 18, lc)

	# Centerline dashes along the main runway
	var dash_y = PORT_Y + 100.0
	while dash_y < PORT_Y + PORT_H - 80:
		if absf(dash_y - (PORT_Y + PORT_H * 0.42)) > 260:   # skip apron area
			draw_rect(Rect2(rwy_cx - 1.5, dash_y, 3, 20), lc_dim)
		dash_y += 40.0

	# Taxiway edge lines flanking the main taxiway
	for se in [-1, 1]:
		var ex = rwy_cx + se * 40
		draw_line(Vector2(ex, PORT_Y + 80), Vector2(ex, PORT_Y + PORT_H - 80), lc_dim, 1.5)

	# Hold-short bars at the horizontal taxiway crossing
	var hcy = PORT_Y + PORT_H * 0.55
	for side2 in [-1, 1]:
		for hdi in 4:
			var hbx = rwy_cx + side2 * (60 + hdi * 14)
			draw_rect(Rect2(hbx, hcy - 26, 8, 14), lc)
			draw_rect(Rect2(hbx, hcy + 12, 8, 14), lc)

	# Taxiway letter labels ("A" down the main spine)
	for tli in 5:
		var tly = PORT_Y + 180 + tli * (PORT_H - 360) / 4.0
		if absf(tly - hcy) < 80: continue
		_draw_label(rfont, Vector2(rwy_cx - 8, tly), "A", 15, lc_dim)

	# Taxiway branch markers along horizontal cross-taxiway ("B", "C")
	for tbi in 4:
		var tbx = PORT_X + 200 + tbi * (PORT_W - 400) / 3.0
		if absf(tbx - rwy_cx) < 60: continue
		_draw_label(rfont, Vector2(tbx, hcy - 14), ("B" if tbx < rwy_cx else "C"), 14, lc_dim)

	# Parking stall lines alongside hangars (left side)
	for pi in 5:
		var psx = PORT_X + 88 + pi * 20
		draw_line(Vector2(psx, PORT_Y + 430), Vector2(psx, PORT_Y + 560), lc_dim, 1.5)
		draw_line(Vector2(psx, PORT_Y + 1010), Vector2(psx, PORT_Y + 1140), lc_dim, 1.5)

	# Arrow chevrons pointing down the runway (touchdown zone)
	for ci in 3:
		var chy = PORT_Y + 150 + ci * 80
		var pts = PackedVector2Array([
			Vector2(rwy_cx, chy + 18), Vector2(rwy_cx - 10, chy), Vector2(rwy_cx + 10, chy)
		])
		draw_colored_polygon(pts, Color(lc.r, lc.g, lc.b, 0.55))
	for ci in 3:
		var chy = PORT_Y + PORT_H - 170 - ci * 80
		var pts = PackedVector2Array([
			Vector2(rwy_cx, chy - 18), Vector2(rwy_cx - 10, chy), Vector2(rwy_cx + 10, chy)
		])
		draw_colored_polygon(pts, Color(lc.r, lc.g, lc.b, 0.55))

# ── PERIMETER WALL ────────────────────────────────────────────
func _draw_perimeter_wall() -> void:
	var wall_t = 14.0
	# Outer wall shadow
	draw_rect(Rect2(PORT_X - 4, PORT_Y - 4, PORT_W + 8, wall_t + 8), C_SHADOW)
	draw_rect(Rect2(PORT_X - 4, PORT_Y + PORT_H - wall_t - 4, PORT_W + 8, wall_t + 8), C_SHADOW)
	draw_rect(Rect2(PORT_X - 4, PORT_Y - 4, wall_t + 8, PORT_H + 8), C_SHADOW)
	draw_rect(Rect2(PORT_X + PORT_W - wall_t - 4, PORT_Y - 4, wall_t + 8, PORT_H + 8), C_SHADOW)
	# Wall faces
	draw_rect(Rect2(PORT_X, PORT_Y, PORT_W, wall_t), C_BUILDING_WALL)
	draw_rect(Rect2(PORT_X, PORT_Y + PORT_H - wall_t, PORT_W, wall_t), C_BUILDING_WALL)
	draw_rect(Rect2(PORT_X, PORT_Y, wall_t, PORT_H), C_BUILDING_WALL)
	draw_rect(Rect2(PORT_X + PORT_W - wall_t, PORT_Y, wall_t, PORT_H), C_BUILDING_WALL)
	# Wall top trim line
	draw_line(Vector2(PORT_X, PORT_Y + wall_t), Vector2(PORT_X + PORT_W, PORT_Y + wall_t),
		Color(C_BUILDING_TRIM.r, C_BUILDING_TRIM.g, C_BUILDING_TRIM.b, 0.5), 2.0)

	# Gate openings — south gate (main road) and east gate
	var south_gate_x = PORT_X + PORT_W * 0.5 - 36.0
	draw_rect(Rect2(south_gate_x, PORT_Y + PORT_H - wall_t, 72.0, wall_t + 2), C_TARMAC)
	draw_rect(Rect2(PORT_X + PORT_W - wall_t, PORT_Y + PORT_H * 0.55 - 36.0, wall_t + 2, 72.0), C_TARMAC)

	# Gate pillars
	for gp in [Vector2(south_gate_x - 12, PORT_Y + PORT_H - wall_t - 16),
				Vector2(south_gate_x + 72, PORT_Y + PORT_H - wall_t - 16)]:
		draw_rect(Rect2(gp.x, gp.y, 12, 30), C_BUILDING_WALL)
		draw_rect(Rect2(gp.x - 2, gp.y - 4, 16, 8), C_BUILDING_TRIM)

# ── DOCKING PADS ──────────────────────────────────────────────
func _draw_docking_pads() -> void:
	# Six pads in a 3×2 grid between the hangars and the control tower.
	# Columns at x = PORT_X+580, +840, +1100  (clear of hangars which end ~520)
	# Rows    at y = PORT_Y+380, +600          (well above the lower hangar at +800)
	var pads = _docking_bay_positions()
	for pd in pads:
		var r = 110.0
		draw_colored_polygon(_ellipse(pd + Vector2(6, 10), r + 8, r * 0.35, 0.0, 32), C_SHADOW)
		draw_colored_polygon(_ellipse(pd, r, r, 0.0, 40), C_TARMAC_DARK)
		draw_colored_polygon(_ellipse(pd, r - 12, r - 12, 0.0, 40), Color(0.58, 0.62, 0.68))
		draw_arc(pd, r - 6,  0.0, TAU, 48, C_TARMAC_LINE, 3.0)
		draw_arc(pd, r - 20, 0.0, TAU, 48, Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.50), 1.5)
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var tip = pd + Vector2(cos(ang), sin(ang)) * (r - 26)
			var bl  = pd + Vector2(cos(ang + 2.4), sin(ang + 2.4)) * (r - 44)
			var br  = pd + Vector2(cos(ang - 2.4), sin(ang - 2.4)) * (r - 44)
			draw_colored_polygon(PackedVector2Array([tip, bl, br]),
				Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.70))
	# Docking bay label on the tarmac between the rows
	var font = _roboto
	_draw_label(font, Vector2(PORT_X + 630, PORT_Y + 510), "DOCKING BAY", 11,
		Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.65))

	# Top-right quadrant — 2 large pads (r=150) + 2 medium pads (r=110)
	var tr_pads = _tr_pad_positions()
	var tr_radii = [150.0, 150.0, 110.0, 110.0]
	for i in tr_pads.size():
		var pd = tr_pads[i];  var r = tr_radii[i]
		draw_colored_polygon(_ellipse(pd + Vector2(8, 14), r + 12, r * 0.40, 0.0, 32), C_SHADOW)
		draw_colored_polygon(_ellipse(pd, r, r, 0.0, 48), C_TARMAC_DARK)
		draw_colored_polygon(_ellipse(pd, r - 14, r - 14, 0.0, 48), Color(0.56, 0.60, 0.66))
		draw_arc(pd, r - 7,  0.0, TAU, 56, C_TARMAC_LINE, 3.5)
		draw_arc(pd, r - 24, 0.0, TAU, 56, Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.45), 1.5)
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var tip = pd + Vector2(cos(ang), sin(ang)) * (r - 32)
			var bl  = pd + Vector2(cos(ang + 2.4), sin(ang + 2.4)) * (r - 52)
			var br  = pd + Vector2(cos(ang - 2.4), sin(ang - 2.4)) * (r - 52)
			draw_colored_polygon(PackedVector2Array([tip, bl, br]),
				Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.70))
	_draw_label(font, Vector2(_tr_pad_positions()[0].x - 60, PORT_Y + 370), "CAPITAL DOCKS", 11,
		Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.65))

	# Top-left small personal pads (r=70) beside hangars
	for pd in _tl_small_pad_positions():
		var r = 70.0
		draw_colored_polygon(_ellipse(pd + Vector2(5, 8), r + 6, r * 0.32, 0.0, 24), C_SHADOW)
		draw_colored_polygon(_ellipse(pd, r, r, 0.0, 32), C_TARMAC_DARK)
		draw_colored_polygon(_ellipse(pd, r - 10, r - 10, 0.0, 32), Color(0.58, 0.62, 0.68))
		draw_arc(pd, r - 5, 0.0, TAU, 40, C_TARMAC_LINE, 2.5)
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var tip = pd + Vector2(cos(ang), sin(ang)) * (r - 16)
			var bl  = pd + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * (r - 30)
			var br  = pd + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * (r - 30)
			draw_colored_polygon(PackedVector2Array([tip, bl, br]),
				Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.65))

func _docking_bay_positions() -> Array:
	# Shared by pads and ships so positions are always in sync
	return [
		Vector2(PORT_X + 580,  PORT_Y + 380),   # Row 1 col 1
		Vector2(PORT_X + 840,  PORT_Y + 380),   # Row 1 col 2
		Vector2(PORT_X + 1100, PORT_Y + 380),   # Row 1 col 3
		Vector2(PORT_X + 580,  PORT_Y + 600),   # Row 2 col 1
		Vector2(PORT_X + 840,  PORT_Y + 600),   # Row 2 col 2
		Vector2(PORT_X + 1100, PORT_Y + 600),   # Row 2 col 3
	]

func _tr_pad_positions() -> Array:
	# Top-right quadrant: 2 large pads for freighters, 2 medium for transports
	return [
		Vector2(PORT_X + PORT_W * 0.61, PORT_Y + 240),   # large 1
		Vector2(PORT_X + PORT_W * 0.81, PORT_Y + 220),   # large 2
		Vector2(PORT_X + PORT_W * 0.61, PORT_Y + 480),   # medium 1
		Vector2(PORT_X + PORT_W * 0.82, PORT_Y + 460),   # medium 2
	]

func _tl_small_pad_positions() -> Array:
	# Top-left: 3 small personal pads tucked beside each hangar
	return [
		Vector2(PORT_X + 460, PORT_Y + 330),   # beside upper hangar
		Vector2(PORT_X + 460, PORT_Y + 510),   # between hangars
		Vector2(PORT_X + 460, PORT_Y + 930),   # beside lower hangar
	]

# ── SHIPS ─────────────────────────────────────────────────────
func _draw_ships() -> void:
	# ── Main docking bay (top-left center) ───────────────────────
	var pads = _docking_bay_positions()
	_draw_ship_fighter  (pads[0], 0.0, C_SHIP_HULL, C_SHIP_ACCENT)
	_draw_ship_transport(pads[1], 0.0, C_SHIP_HULL, C_SHIP_ACCENT)
	_draw_ship_fighter  (pads[2], 0.0, Color(0.08, 0.08, 0.10), Color(0.80, 0.20, 0.18))
	_draw_ship_transport(pads[3], 0.0, Color(0.85, 0.70, 0.18), Color(0.95, 0.88, 0.35))
	_draw_ship_fighter  (pads[4], 0.0, Color(0.80, 0.16, 0.14), Color(1.0,  0.55, 0.10))
	_draw_ship_freighter(pads[5], 0.0, Color(0.70, 0.75, 0.82), Color(0.40, 0.65, 0.95))

	# ── Capital Docks — top-right quadrant ───────────────────────
	# 2 big freighters, 2 medium transports
	var cap_pads = _tr_pad_positions()
	_draw_ship_freighter(cap_pads[0], PI * 0.5,
		Color(0.88, 0.92, 0.98), Color(0.20, 0.45, 0.90))   # silver-blue freighter
	_draw_ship_freighter(cap_pads[1], PI * 0.5,
		Color(0.22, 0.22, 0.26), Color(0.80, 0.65, 0.10))   # black & gold freighter
	_draw_ship_transport(cap_pads[2], PI * 0.5,
		Color(0.72, 0.85, 0.55), Color(0.30, 0.60, 0.20))   # green transport
	_draw_ship_transport(cap_pads[3], PI * 0.5,
		Color(0.90, 0.55, 0.18), Color(0.98, 0.82, 0.22))   # orange-gold transport

	# ── Personal pads — beside hangars (top-left) ────────────────
	# 3 small personal fighters, each a different color
	var tl = _tl_small_pad_positions()
	_draw_ship_fighter(tl[0], PI * 0.5,
		Color(0.92, 0.28, 0.22), Color(1.0,  0.70, 0.12))   # red & orange
	_draw_ship_fighter(tl[1], PI * 0.5,
		Color(0.30, 0.75, 0.92), Color(0.90, 0.95, 1.00))   # cyan & white
	_draw_ship_fighter(tl[2], PI * 0.5,
		Color(0.55, 0.35, 0.88), Color(0.88, 0.55, 1.00))   # purple & lavender

func _draw_ship_fighter(pos: Vector2, rot: float,
		hull_col: Color = C_SHIP_HULL, accent_col: Color = C_SHIP_ACCENT) -> void:
	# Shadow
	draw_colored_polygon(_ellipse(pos + Vector2(8, 14), 110, 28, rot, 16), C_SHADOW)
	# Main hull — elongated teardrop pointing in rot direction
	var fwd = Vector2(cos(rot), sin(rot))
	var side = Vector2(-sin(rot), cos(rot))
	var pts  = PackedVector2Array()
	var n    = 20
	for i in (n + 1):
		var t  = float(i) / float(n)
		var px : float
		var py : float
		if t <= 0.5:
			# Nose half — narrow
			px = lerpf(-85, 100, t * 2.0) * 1.0
			py = sin(t * 2.0 * PI) * 32.0
		else:
			# Tail half — wider
			px = lerpf(100, -85, (t - 0.5) * 2.0)
			py = -sin((t - 0.5) * 2.0 * PI) * 32.0
		pts.append(pos + fwd * px + side * py)
	draw_colored_polygon(pts, hull_col)
	# Cockpit glass dome
	var cockpit_pts = _ellipse(pos + fwd * 30, 26, 14, rot, 14)
	draw_colored_polygon(cockpit_pts, C_TOWER_GLASS)
	draw_colored_polygon(_ellipse(pos + fwd * 32 + side * (-6), 10, 5, rot, 10),
		Color(1.0, 1.0, 1.0, 0.55))
	# Engine nacelles
	for side_m in [-1.0, 1.0]:
		var eng_pos = pos - fwd * 60 + side * side_m * 26
		draw_colored_polygon(_ellipse(eng_pos, 18, 10, rot, 10), hull_col.darkened(0.35))
		draw_colored_polygon(_ellipse(eng_pos - fwd * 18, 10, 9, rot, 10), Color(0.35, 0.70, 1.0, 0.80))
	# Hull accent stripe
	draw_line(pos - fwd * 80 + side * 8, pos + fwd * 80 + side * 8, accent_col, 3.0)
	draw_line(pos - fwd * 80 - side * 8, pos + fwd * 80 - side * 8, accent_col, 3.0)

func _draw_ship_transport(pos: Vector2, rot: float,
		hull_col: Color = C_SHIP_HULL, accent_col: Color = C_SHIP_ACCENT) -> void:
	var fwd  = Vector2(cos(rot), sin(rot))
	var side = Vector2(-sin(rot), cos(rot))
	# Shadow
	draw_colored_polygon(_ellipse(pos + Vector2(10, 16), 95, 48, rot, 16), C_SHADOW)
	# Wide boxy hull
	var hull = PackedVector2Array([
		pos - fwd * 90 - side * 44,
		pos + fwd * 70 - side * 30,
		pos + fwd * 90 + side * 0,
		pos + fwd * 70 + side * 30,
		pos - fwd * 90 + side * 44,
	])
	draw_colored_polygon(hull, hull_col)
	# Top superstructure
	var super_hull = PackedVector2Array([
		pos - fwd * 50 - side * 20,
		pos + fwd * 40 - side * 15,
		pos + fwd * 40 + side * 15,
		pos - fwd * 50 + side * 20,
	])
	draw_colored_polygon(super_hull, hull_col.lightened(0.15))
	# Bridge windows
	for wi in 4:
		var wp = pos + fwd * (10 + wi * 10) + side * (-12 + wi * 2)
		draw_circle(wp, 4.5, C_TOWER_GLASS)
	# Cargo dome on top
	draw_colored_polygon(_ellipse(pos - fwd * 20, 30, 18, rot, 14), hull_col.lightened(0.20))
	draw_colored_polygon(_ellipse(pos - fwd * 18, 14, 8, rot, 10), Color(1.0, 1.0, 1.0, 0.35))
	# Accent
	draw_line(pos - fwd * 80, pos + fwd * 80, accent_col, 2.0)

func _draw_ship_freighter(pos: Vector2, rot: float,
		hull_col: Color = C_SHIP_HULL, accent_col: Color = C_SHIP_ACCENT) -> void:
	var fwd  = Vector2(cos(rot), sin(rot))
	var side = Vector2(-sin(rot), cos(rot))
	# Shadow
	draw_colored_polygon(_ellipse(pos + Vector2(12, 18), 135, 42, rot, 16), C_SHADOW)
	# Main rectangular hull
	var hull = PackedVector2Array([
		pos - fwd * 130 - side * 38,
		pos + fwd * 110 - side * 30,
		pos + fwd * 130 - side * 10,
		pos + fwd * 130 + side * 10,
		pos + fwd * 110 + side * 30,
		pos - fwd * 130 + side * 38,
	])
	draw_colored_polygon(hull, hull_col)
	# Cargo pods along the hull
	for ci in 4:
		var cp = pos + fwd * (-80 + ci * 50)
		draw_colored_polygon(_ellipse(cp - side * 30, 24, 14, rot, 10), hull_col.darkened(0.20))
		draw_colored_polygon(_ellipse(cp + side * 30, 24, 14, rot, 10), hull_col.darkened(0.20))
	# Bridge superstructure
	var bridge = PackedVector2Array([
		pos + fwd * 60 - side * 18,
		pos + fwd * 110 - side * 12,
		pos + fwd * 110 + side * 12,
		pos + fwd * 60 + side * 18,
	])
	draw_colored_polygon(bridge, hull_col.lightened(0.18))
	# Bridge windows
	for wi in 3:
		draw_circle(pos + fwd * (70 + wi * 12), 5.0, C_TOWER_GLASS)
	# Engine array
	for ei in 3:
		var ep = pos - fwd * 120 + side * (-24 + ei * 24)
		draw_colored_polygon(_ellipse(ep, 12, 10, rot, 10), hull_col.darkened(0.40))
		draw_colored_polygon(_ellipse(ep - fwd * 14, 8, 7, rot, 8), Color(0.35, 0.70, 1.0, 0.85))
	# Accent stripe
	draw_line(pos - fwd * 120 + side * 2, pos + fwd * 120 + side * 2, accent_col, 3.5)

# ── CONTROL TOWER ─────────────────────────────────────────────
func _draw_control_tower() -> void:
	var tx = PORT_X + PORT_W * 0.5
	var ty = PORT_Y + PORT_H * 0.42
	var tp = Vector2(tx, ty)

	# ── Base platform ──────────────────────────────────────────
	# Shadow
	draw_colored_polygon(_ellipse(tp + Vector2(8, 14), 90, 30, 0.0, 24), C_SHADOW)
	draw_colored_polygon(_ellipse(tp, 84, 30, 0.0, 32), C_BUILDING_TRIM)
	draw_colored_polygon(_ellipse(tp, 78, 26, 0.0, 32), C_BUILDING_WALL)
	# Outer ring detail
	draw_arc(tp, 78, 0.0, TAU, 40, C_BUILDING_TRIM, 3.0)

	# ── Tower shaft — wide at base, tapers upward ──────────────
	# Drawn as a trapezoid going upward
	var shaft_pts = PackedVector2Array([
		Vector2(tx - 28, ty),
		Vector2(tx + 28, ty),
		Vector2(tx + 18, ty - 220),
		Vector2(tx - 18, ty - 220),
	])
	draw_colored_polygon(shaft_pts, C_TOWER_BASE)
	# Highlight / shading side panels
	var left_face = PackedVector2Array([
		Vector2(tx - 28, ty), Vector2(tx - 18, ty - 220),
		Vector2(tx - 12, ty - 220), Vector2(tx - 22, ty),
	])
	draw_colored_polygon(left_face, Color(C_BUILDING_DARK.r, C_BUILDING_DARK.g, C_BUILDING_DARK.b, 0.35))
	# Horizontal band details on shaft
	for band_y in [ty - 55, ty - 110, ty - 165]:
		draw_rect(Rect2(tx - 20, band_y, 40, 6), C_BUILDING_TRIM)

	# ── Mid observation deck ───────────────────────────────────
	var deck_y = ty - 220
	var deck_pts = PackedVector2Array([
		Vector2(tx - 52, deck_y + 4),
		Vector2(tx + 52, deck_y + 4),
		Vector2(tx + 46, deck_y - 26),
		Vector2(tx - 46, deck_y - 26),
	])
	draw_colored_polygon(deck_pts, C_BUILDING_WALL)
	draw_rect(Rect2(tx - 52, deck_y - 26, 104, 4), C_BUILDING_TRIM)
	draw_rect(Rect2(tx - 52, deck_y + 4, 104, 4), C_BUILDING_TRIM)

	# ── Upper control room — glass dome ───────────────────────
	var top_y = deck_y - 26
	# Neck piece
	var neck = PackedVector2Array([
		Vector2(tx - 16, top_y),
		Vector2(tx + 16, top_y),
		Vector2(tx + 12, top_y - 35),
		Vector2(tx - 12, top_y - 35),
	])
	draw_colored_polygon(neck, C_TOWER_BASE)

	# Glass orb — the iconic control room
	var orb_c = Vector2(tx, top_y - 68)
	draw_colored_polygon(_ellipse(orb_c + Vector2(4, 6), 44, 16, 0.0, 20), C_SHADOW)
	draw_colored_polygon(_ellipse(orb_c, 44, 44, 0.0, 36), C_TOWER_GLASS)
	# Glass reflection
	draw_colored_polygon(_ellipse(orb_c + Vector2(-12, -14), 18, 12, -0.4, 12),
		Color(1.0, 1.0, 1.0, 0.45))
	# Rim
	draw_arc(orb_c, 44, 0.0, TAU, 36, C_BUILDING_TRIM, 2.5)
	# Antenna mast
	draw_line(orb_c, orb_c - Vector2(0, 52), C_BUILDING_DARK, 3.0)
	draw_circle(orb_c - Vector2(0, 52), 5.0, Color(1.0, 0.30, 0.20))   # red beacon
	# Cross antenna arms
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_line(orb_c - Vector2(0, 40),
			orb_c - Vector2(0, 40) + Vector2(cos(ang), sin(ang)) * 14.0,
			C_BUILDING_DARK, 2.0)

	# ── Spotlights on the deck railing ────────────────────────
	for sl in [-40.0, -20.0, 20.0, 40.0]:
		draw_circle(Vector2(tx + sl, deck_y - 22), 4.0, Color(1.0, 0.92, 0.60))
		draw_circle(Vector2(tx + sl, deck_y - 22), 2.0, Color(1.0, 1.0, 1.0))

# ── HANGARS ───────────────────────────────────────────────────
func _draw_hangars() -> void:
	# Two large hangar buildings — 2.5D barrel-vault treatment
	var hangar_data = [
		Vector2(PORT_X + 80, PORT_Y + 220),   # upper left
		Vector2(PORT_X + 80, PORT_Y + 800),   # lower left
	]
	for hp in hangar_data:
		var hw      = 360.0
		var hbd     = 180.0   # ISO depth
		var hbh     = 200.0   # front wall height
		var vault_h = 58.0    # barrel vault peak above FL
		var hid  = Vector2(ISO_DX * hbd, ISO_DY * hbd)
		var HFL  = hp;                    var HFR  = hp + Vector2(hw, 0)
		var HBL  = hp + hid;              var HBR  = hp + Vector2(hw, 0) + hid
		var HFLb = HFL + Vector2(0, hbh); var HFRb = HFR + Vector2(0, hbh)
		var HBRb = HBR + Vector2(0, hbh)

		# Shadow
		draw_colored_polygon(PackedVector2Array([
			HFLb + Vector2(10, 10), HFRb + Vector2(10, 10),
			HBRb + Vector2(10, 10), HBL  + Vector2(10, hbh + 10)
		]), C_SHADOW)

		# East side wall (flat face)
		draw_colored_polygon(PackedVector2Array([HFR, HBR, HBRb, HFRb]),
			C_BUILDING_WALL.darkened(0.22))
		# Side vault profile on east wall
		var sv = PackedVector2Array()
		for i in 13:
			var t = float(i) / 12.0
			var p = HFR.lerp(HBR, t)
			sv.append(p + Vector2(0, -sin(t * PI) * vault_h * 0.6))
		sv.append(HBR); sv.append(HFR)
		draw_colored_polygon(sv, C_DOME.darkened(0.28))
		draw_line(HFR, HBR, C_BUILDING_TRIM, 2.0)
		draw_line(HFR, HFRb, C_BUILDING_TRIM.darkened(0.05), 1.5)
		draw_line(HBR, HBRb, C_BUILDING_TRIM.darkened(0.1), 1.5)

		# Roof face (parallelogram)
		draw_colored_polygon(PackedVector2Array([HFL, HFR, HBR, HBL]),
			C_BUILDING_WALL.lightened(0.08))
		draw_line(HFL, HFR, C_BUILDING_TRIM, 2.5)
		draw_line(HFL, HBL, C_BUILDING_TRIM.darkened(0.1), 1.5)
		draw_line(HFR, HBR, C_BUILDING_TRIM.darkened(0.1), 1.5)
		draw_line(HBL, HBR, C_BUILDING_TRIM.darkened(0.2), 1.5)

		# Barrel vault arch above the front edge
		var vault_pts = PackedVector2Array()
		for i in 25:
			var t = float(i) / 24.0
			vault_pts.append(Vector2(HFL.x + t * hw, HFL.y - sin(t * PI) * vault_h))
		vault_pts.append(HFR); vault_pts.append(HFL)
		draw_colored_polygon(vault_pts, C_DOME)
		draw_arc(Vector2(HFL.x + hw * 0.46, HFL.y), hw * 0.28,
			PI + 0.30, TAU - 0.30, 14, Color(1.0, 1.0, 1.0, 0.28), 7.0)
		draw_line(HFL, HFR, C_BUILDING_TRIM, 3.0)

		# Front / south wall
		draw_colored_polygon(PackedVector2Array([HFL, HFR, HFRb, HFLb]), C_BUILDING_WALL)
		draw_line(HFL, HFR, C_BUILDING_TRIM, 3.0)
		draw_line(HFLb, HFRb, C_BUILDING_TRIM.darkened(0.1), 2.5)
		draw_line(HFL, HFLb, C_BUILDING_TRIM.darkened(0.05), 1.5)
		draw_line(HFR, HFRb, C_BUILDING_TRIM.darkened(0.05), 1.5)
		draw_rect(Rect2(HFL.x, HFL.y, hw, 8), C_BUILDING_TRIM)   # trim band

		# Large hangar bay door
		var door_x = HFL.x + hw * 0.25
		var door_w = hw * 0.50;  var door_h = hbh * 0.65
		draw_rect(Rect2(door_x, HFLb.y - door_h, door_w, door_h), C_BUILDING_DARK)
		draw_rect(Rect2(door_x, HFLb.y - door_h, door_w, 6), C_BUILDING_TRIM)
		draw_rect(Rect2(door_x - 6, HFLb.y - door_h - 6, 6, door_h + 6), C_BUILDING_TRIM)
		draw_rect(Rect2(door_x + door_w, HFLb.y - door_h - 6, 6, door_h + 6), C_BUILDING_TRIM)

		# Flanking windows on front face
		for wx2 in [HFL.x + 20, HFL.x + hw - 40]:
			draw_rect(Rect2(wx2, HFL.y + hbh * 0.15, 18, 28), C_TOWER_GLASS)
			draw_line(Vector2(wx2 + 9, HFL.y + hbh * 0.15),
				Vector2(wx2 + 9, HFL.y + hbh * 0.15 + 28), C_BUILDING_TRIM, 1.5)

# ── PALACE ────────────────────────────────────────────────────
func _draw_palace() -> void:
	# Political Palace — 2.5D treatment with colonnade, pediment, flanking towers
	var px  = PORT_X + PORT_W * 0.58
	var py  = PORT_Y + PORT_H * 0.55 + 100
	var pw  = 580.0
	var pbd = 280.0   # ISO depth
	var pbh = 300.0   # front wall height
	var pid = Vector2(ISO_DX * pbd, ISO_DY * pbd)
	var PFL  = Vector2(px, py);              var PFR  = PFL + Vector2(pw, 0)
	var PBL  = PFL + pid;                    var PBR  = PFR + pid
	var PFLb = PFL + Vector2(0, pbh);        var PFRb = PFR + Vector2(0, pbh)
	var PBRb = PBR + Vector2(0, pbh)

	# Grand plaza courtyard
	draw_rect(Rect2(px - 30, py - 60, pw + 60, 60), Color(0.72, 0.68, 0.60))

	# Shadow
	draw_colored_polygon(PackedVector2Array([
		PFLb + Vector2(12, 12), PFRb + Vector2(12, 12),
		PBRb + Vector2(12, 12), PBL  + Vector2(12, pbh + 12)
	]), C_SHADOW)

	# East side wall
	draw_colored_polygon(PackedVector2Array([PFR, PBR, PBRb, PFRb]),
		C_PALACE_STONE.darkened(0.22))
	draw_line(PFR, PBR, C_PALACE_TRIM.darkened(0.1), 1.5)
	draw_line(PFR, PFRb, C_PALACE_TRIM.darkened(0.05), 1.5)
	draw_line(PBR, PBRb, C_PALACE_TRIM.darkened(0.1), 1.5)
	draw_line(PFRb, PBRb, C_PALACE_TRIM.darkened(0.15), 1.5)
	# Side face windows
	for _wr in 2:
		var wp  = PFR.lerp(PBR, 0.28)
		var wy2 = PFL.y + pbh * (0.25 + _wr * 0.30)
		draw_rect(Rect2(wp.x, wy2, 20, 28), C_TOWER_GLASS)
		draw_arc(Vector2(wp.x + 10, wy2), 10, PI, TAU, 8, C_PALACE_TRIM, 1.5)

	# Roof face (parallelogram)
	draw_colored_polygon(PackedVector2Array([PFL, PFR, PBR, PBL]),
		C_PALACE_STONE.lightened(0.10))
	draw_line(PFL, PFR, C_PALACE_GOLD, 3.0)
	draw_line(PFL, PBL, C_PALACE_TRIM.darkened(0.1), 1.5)
	draw_line(PFR, PBR, C_PALACE_TRIM.darkened(0.1), 1.5)
	draw_line(PBL, PBR, C_PALACE_TRIM.darkened(0.2), 1.5)

	# Pediment (triangular gable) above the front roof edge
	var ped_peak = Vector2(px + pw * 0.5, py - 90.0)
	draw_colored_polygon(PackedVector2Array([
		PFL - Vector2(20, 0), PFR + Vector2(20, 0), ped_peak
	]), C_PALACE_STONE)
	draw_polyline(PackedVector2Array([
		PFL - Vector2(20, 0), ped_peak, PFR + Vector2(20, 0)
	]), C_PALACE_TRIM, 4.0)
	draw_line(PFL - Vector2(20, 0), PFR + Vector2(20, 0), C_PALACE_GOLD, 5.0)

	# Front / south wall
	draw_colored_polygon(PackedVector2Array([PFL, PFR, PFRb, PFLb]), C_PALACE_STONE)
	draw_line(PFL, PFR, C_PALACE_GOLD, 3.0)
	draw_line(PFLb, PFRb, C_PALACE_TRIM, 3.0)
	draw_line(PFL, PFLb, C_PALACE_TRIM.darkened(0.05), 1.5)
	draw_line(PFR, PFRb, C_PALACE_TRIM.darkened(0.05), 1.5)

	# Colonnade — columns in front of the wall
	var col_count = 10
	var col_spacing = pw / (col_count + 1)
	for ci in col_count:
		var col_x = px + col_spacing * (ci + 1) - 7
		draw_rect(Rect2(col_x + 3, py - 80, 14, 88), C_SHADOW)
		draw_rect(Rect2(col_x, py - 80, 14, 88), C_PALACE_STONE)
		draw_rect(Rect2(col_x - 4, py - 84, 22, 8), C_PALACE_TRIM)
		draw_rect(Rect2(col_x - 3, py, 20, 6), C_PALACE_TRIM)

	# Flanking towers — each with its own 2.5D east face + dome
	for ti in 2:
		var tx   = px + 20 if ti == 0 else px + pw - 80
		var tw   = 60.0;  var tbd = 50.0;  var tbh = 200.0
		var tid  = Vector2(ISO_DX * tbd, ISO_DY * tbd)
		var TFL  = Vector2(tx, py - 120);   var TFR  = TFL + Vector2(tw, 0)
		var TBL  = TFL + tid;               var TBR  = TFR + tid
		var TFLb = TFL + Vector2(0, tbh);   var TFRb = TFR + Vector2(0, tbh)
		var TBRb = TBR + Vector2(0, tbh)
		# Tower east side
		draw_colored_polygon(PackedVector2Array([TFR, TBR, TBRb, TFRb]),
			C_PALACE_STONE.darkened(0.28))
		draw_line(TFR, TBR, C_PALACE_TRIM, 1.5)
		# Tower roof
		draw_colored_polygon(PackedVector2Array([TFL, TFR, TBR, TBL]),
			C_PALACE_STONE.lightened(0.08))
		draw_line(TFL, TFR, C_PALACE_TRIM, 2.0)
		draw_line(TFL, TBL, C_PALACE_TRIM.darkened(0.1), 1.5)
		# Tower front face
		draw_colored_polygon(PackedVector2Array([TFL, TFR, TFRb, TFLb]), C_PALACE_STONE)
		draw_line(TFL, TFR, C_PALACE_TRIM, 2.0)
		draw_line(TFLb, TFRb, C_PALACE_TRIM, 2.0)
		draw_line(TFL, TFLb, C_PALACE_TRIM, 1.5)
		draw_line(TFR, TFRb, C_PALACE_TRIM, 1.5)
		draw_rect(Rect2(TFL.x - 6, TFL.y, tw + 12, 10), C_PALACE_TRIM)
		# Tower dome
		var dome_cx = Vector2(tx + 30, TFL.y - 12)
		draw_colored_polygon(_ellipse(dome_cx, 36, 36, 0.0, 24), C_DOME)
		draw_colored_polygon(_ellipse(dome_cx + Vector2(-8, -8), 14, 10, 0.0, 12), C_DOME_SHINE)
		draw_arc(dome_cx, 36, 0.0, TAU, 24, C_PALACE_TRIM, 2.0)
		# Tower flag
		draw_line(dome_cx, dome_cx - Vector2(0, 40), C_BUILDING_DARK, 2.5)
		draw_colored_polygon(PackedVector2Array([
			dome_cx - Vector2(0, 40),
			dome_cx - Vector2(-28, 30),
			dome_cx - Vector2(-2, 20),
		]), Color(0.85, 0.15, 0.15))
		# Tower windows on front face
		for wy_t in [TFL.y + 22, TFL.y + 66, TFL.y + 110]:
			draw_rect(Rect2(tx + 18, wy_t, 24, 30), C_TOWER_GLASS)
			draw_arc(Vector2(tx + 30, wy_t), 12, PI, TAU, 10, C_PALACE_TRIM, 1.5)

	# Facade windows on front face
	for row in 3:
		for col in 7:
			var wx = px + 60 + col * 66
			var wy = py + 30 + row * 80
			if abs(wx - (px + pw * 0.5)) < 55: continue
			draw_rect(Rect2(wx, wy, 28, 38), C_TOWER_GLASS)
			draw_arc(Vector2(wx + 14, wy), 14, PI, TAU, 8, C_PALACE_TRIM, 1.5)

	# Central entrance archway on front face
	var arch_x   = px + pw * 0.5 - 38
	var arch_w   = 76.0;  var arch_h = 110.0
	var arch_cx  = arch_x + arch_w * 0.5
	var arch_top = PFLb.y - arch_h
	draw_rect(Rect2(arch_x, arch_top, arch_w, arch_h), C_BUILDING_DARK)
	var arch_pts = PackedVector2Array()
	for i in 17:
		var ang = PI + float(i) / 16.0 * PI
		arch_pts.append(Vector2(arch_cx + cos(ang) * arch_w * 0.5,
			arch_top + sin(ang) * arch_w * 0.5 + arch_w * 0.5))
	arch_pts.append(Vector2(arch_x + arch_w, arch_top + arch_w * 0.5))
	arch_pts.append(Vector2(arch_x, arch_top + arch_w * 0.5))
	draw_colored_polygon(arch_pts, C_BUILDING_DARK)
	draw_polyline(arch_pts, C_PALACE_GOLD, 3.0)

	# BANK nameplate
	var font = _roboto
	_draw_label(font, Vector2(px + pw * 0.5 - 40, py - 96), "BANK", 16, C_PALACE_GOLD)

# ── PORT BUILDINGS — smaller utility buildings ─────────────────
func _draw_port_buildings() -> void:
	# Fuel depot — right side north
	var fd_x = PORT_X + PORT_W * 0.68
	var fd_y = PORT_Y + 120.0
	_draw_box_building(Vector2(fd_x, fd_y), 140.0, 110.0, Color(0.80, 0.76, 0.68), C_BUILDING_TRIM)
	# Fuel tanks — 3 cylindrical tanks
	for ti in 3:
		var tank_c = Vector2(fd_x - 20 + ti * 50, fd_y - 35)
		draw_colored_polygon(_ellipse(tank_c + Vector2(4, 6), 20, 7, 0.0, 14), C_SHADOW)
		draw_colored_polygon(_ellipse(tank_c, 20, 20, 0.0, 20), Color(0.70, 0.72, 0.76))
		draw_colored_polygon(_ellipse(tank_c, 10, 10, 0.0, 14), C_DOME_SHINE)
		draw_arc(tank_c, 20, 0.0, TAU, 20, Color(0.50, 0.55, 0.60), 2.0)

	# Customs office — south of tower, on left
	var co_x = PORT_X + 100; var co_y = PORT_Y + PORT_H * 0.78
	_draw_box_building(Vector2(co_x, co_y), 180.0, 130.0, C_BUILDING_WALL, C_BUILDING_TRIM)
	var font = _roboto
	_draw_label(font, Vector2(co_x + 14, co_y + 28), "CUSTOMS", 11, C_BUILDING_DARK)

	# Small maintenance depot
	var md_x = PORT_X + PORT_W * 0.72; var md_y = PORT_Y + PORT_H * 0.75
	_draw_box_building(Vector2(md_x, md_y), 130.0, 90.0, Color(0.75, 0.70, 0.62), C_BUILDING_TRIM)

# ── 2.5D BUILDING CORE ────────────────────────────────────────
# pos   = front-left corner (SW ground level)
# bw    = width  (east-west)
# bd    = depth  (north-south footprint)
# bh    = wall height shown in front / side faces
# roof_col / front_col / side_col / trim_col = face colours
func _draw_2d5_building(pos: Vector2, bw: float, bd: float, bh: float,
		roof_col: Color, front_col: Color, side_col: Color, trim_col: Color) -> void:
	var id  = Vector2(ISO_DX * bd, ISO_DY * bd)   # depth offset in screen space
	var FL  = pos
	var FR  = pos + Vector2(bw, 0)
	var BL  = pos + id
	var BR  = pos + Vector2(bw, 0) + id
	var FLb = FL + Vector2(0, bh)
	var FRb = FR + Vector2(0, bh)
	var BRb = BR + Vector2(0, bh)
	# Shadow
	draw_colored_polygon(PackedVector2Array([
		FLb + Vector2(7, 7), FRb + Vector2(7, 7), BRb + Vector2(7, 7), BL + Vector2(7, bh + 7)
	]), C_SHADOW)
	# East side wall (slightly darker, recedes)
	draw_colored_polygon(PackedVector2Array([FR, BR, BRb, FRb]), side_col)
	draw_line(FR, BR, trim_col.darkened(0.15), 1.5)
	draw_line(BR, BRb, trim_col.darkened(0.15), 1.5)
	# Roof (top face)
	draw_colored_polygon(PackedVector2Array([FL, FR, BR, BL]), roof_col)
	draw_line(FL, FR, trim_col, 2.5)
	draw_line(FL, BL, trim_col.darkened(0.1), 1.5)
	draw_line(FR, BR, trim_col.darkened(0.1), 1.5)
	draw_line(BL, BR, trim_col.darkened(0.2), 1.5)
	# Front/south wall (brightest, faces player)
	draw_colored_polygon(PackedVector2Array([FL, FR, FRb, FLb]), front_col)
	draw_line(FL, FR, trim_col, 2.5)
	draw_line(FLb, FRb, trim_col.darkened(0.1), 2.0)
	draw_line(FL, FLb, trim_col.darkened(0.05), 1.5)
	draw_line(FR, FRb, trim_col.darkened(0.05), 1.5)

func _draw_box_building(pos: Vector2, w: float, h: float, wall_col: Color, trim_col: Color) -> void:
	# Remap flat footprint to 2.5D: split h into depth + wall height
	var bd = h * 0.55;  var bh = h * 1.2
	_draw_2d5_building(pos, w, bd, bh,
		wall_col.lightened(0.12),          # roof slightly lighter
		wall_col,                           # front wall
		wall_col.darkened(0.28),            # side wall darker
		trim_col)
	# Door on front face
	var door_x = pos.x + w * 0.5 - 12
	var door_y = pos.y + bh - 28
	draw_rect(Rect2(door_x, door_y, 24, 28), C_BUILDING_DARK)
	# Window on front face
	var win_y = pos.y + bh * 0.25
	draw_rect(Rect2(pos.x + 14, win_y, 22, 18), C_TOWER_GLASS)
	draw_rect(Rect2(pos.x + 14, win_y, 22, 18), trim_col, false, 1.2)

# ── PORT DETAILS — small human-scale props ────────────────────
func _draw_port_details() -> void:
	# Ground vehicles / speeders — tiny shapes on the tarmac
	var vehicles = [
		Vector2(PORT_X + 180, PORT_Y + PORT_H * 0.50),
		Vector2(PORT_X + PORT_W * 0.60, PORT_Y + PORT_H * 0.20),
		Vector2(PORT_X + PORT_W * 0.70, PORT_Y + PORT_H * 0.70),
	]
	for vp2 in vehicles:
		draw_rect(Rect2(vp2.x - 12, vp2.y - 6, 24, 12), Color(0.85, 0.88, 0.92))
		draw_rect(Rect2(vp2.x - 8,  vp2.y - 4, 16,  8), Color(0.30, 0.55, 0.90, 0.70))
		draw_circle(Vector2(vp2.x - 7, vp2.y + 6), 4.0, Color(0.15, 0.15, 0.15))
		draw_circle(Vector2(vp2.x + 7, vp2.y + 6), 4.0, Color(0.15, 0.15, 0.15))

	# Tiny NPC figures standing around
	var npcs = [
		Vector2(PORT_X + 200, PORT_Y + PORT_H * 0.52),
		Vector2(PORT_X + 220, PORT_Y + PORT_H * 0.52),
		Vector2(PORT_X + PORT_W * 0.55, PORT_Y + PORT_H * 0.65),
		Vector2(PORT_X + PORT_W * 0.57, PORT_Y + PORT_H * 0.65),
		Vector2(PORT_X + PORT_W * 0.59, PORT_Y + PORT_H * 0.65),
	]
	for np2 in npcs:
		draw_circle(np2 - Vector2(0, 12), 5.0, Color(0.85, 0.72, 0.58))   # head
		draw_rect(Rect2(np2.x - 4, np2.y - 8, 8, 12), Color(0.40, 0.45, 0.55))   # body
		draw_line(np2 - Vector2(0, 8), np2 + Vector2(0, 8), Color(0.30, 0.35, 0.45), 2.0)

	# Detailed streetlights along taxiway
	var pole_y = PORT_Y + 40.0
	while pole_y < PORT_Y + PORT_H - 40:
		for px2 in [PORT_X + PORT_W * 0.5 - 28, PORT_X + PORT_W * 0.5 + 28]:
			_draw_detailed_streetlight(Vector2(px2, pole_y))
		pole_y += 140.0
	# Extra lights along south boulevard
	var bvd_y = PORT_Y + PORT_H * 0.80
	var bvd_x = PORT_X + PORT_W * 0.20
	while bvd_x < PORT_X + PORT_W * 0.85:
		_draw_detailed_streetlight(Vector2(bvd_x, bvd_y - 20))
		bvd_x += 160.0

	# "CORONET SPACEPORT" signage above north wall
	var font = _roboto
	_draw_label(font, Vector2(PORT_X + PORT_W * 0.5 - 100, PORT_Y + 55), "CORONET SPACEPORT", 14,
		Color(C_TARMAC_LINE.r, C_TARMAC_LINE.g, C_TARMAC_LINE.b, 0.90))

# ============================================================
#  EXTRA BUILDINGS — Naboo Theed style
# ============================================================

func _draw_extra_buildings() -> void:
	var font = _roboto

	# ── SHOP — arched Naboo market building ───────────────────
	var sx = PORT_X + PORT_W * 0.36;  var sy = PORT_Y + PORT_H * 0.83
	_draw_naboo_building(Vector2(sx, sy), 220.0, 160.0,
		Color(0.92, 0.90, 0.82), Color(0.78, 0.62, 0.18))
	_draw_label(font, Vector2(sx + 52, sy + 30), "SHOP", 14, Color(0.22, 0.18, 0.06))

	# ── JOBS — civic office building ──────────────────────────
	var jx = PORT_X + PORT_W * 0.22;  var jy = PORT_Y + PORT_H * 0.58
	_draw_naboo_building(Vector2(jx, jy), 200.0, 150.0,
		Color(0.88, 0.85, 0.78), Color(0.60, 0.48, 0.14))
	_draw_label(font, Vector2(jx + 44, jy + 28), "JOBS", 14, Color(0.22, 0.18, 0.06))

	# ── CANTINA — large entertainment venue, moved off yellow line ─
	var cx2 = PORT_X + 120;  var cy2 = PORT_Y + PORT_H * 0.84
	var cw2 = 380.0;  var ch2 = 280.0
	_draw_naboo_building(Vector2(cx2, cy2), cw2, ch2,
		Color(0.14, 0.08, 0.22), Color(0.72, 0.18, 0.55))
	# ── Cantina facade extras ───────────────────────────────────
	# Coloured entry awning
	var awn = PackedVector2Array([
		Vector2(cx2 - 10, cy2 + ch2 * 0.52),
		Vector2(cx2 + cw2 + 10, cy2 + ch2 * 0.52),
		Vector2(cx2 + cw2 + 22, cy2 + ch2 * 0.52 + 18),
		Vector2(cx2 - 22, cy2 + ch2 * 0.52 + 18),
	])
	draw_colored_polygon(awn, Color(0.60, 0.10, 0.38, 0.90))
	for ai in 8:
		draw_rect(Rect2(cx2 + ai * (cw2 / 7.0) - 4, cy2 + ch2 * 0.52, 8, 18),
			Color(0.88, 0.22, 0.60) if ai % 2 == 0 else Color(0.22, 0.18, 0.42))
	# ── Neon girl silhouette ────────────────────────────────────
	var ng_x = cx2 + cw2 * 0.72;  var ng_y = cy2 - ch2 * 0.08
	var ng_col = Color(1.0, 0.18, 0.58, 0.80 + sin(_scene_time * 3.0) * 0.20)
	# Body
	draw_colored_polygon(PackedVector2Array([
		Vector2(ng_x,      ng_y),
		Vector2(ng_x - 16, ng_y + 30),
		Vector2(ng_x - 10, ng_y + 65),
		Vector2(ng_x + 10, ng_y + 65),
		Vector2(ng_x + 16, ng_y + 30),
	]), ng_col)
	# Head
	draw_circle(Vector2(ng_x, ng_y - 12), 10.0, ng_col)
	# Arms — animated
	var arm_ang = sin(_scene_time * 1.8) * 0.6
	draw_line(Vector2(ng_x - 4, ng_y + 18),
		Vector2(ng_x - 4 + cos(PI + arm_ang) * 22, ng_y + 18 + sin(PI + arm_ang) * 22),
		ng_col, 3.5)
	draw_line(Vector2(ng_x + 4, ng_y + 18),
		Vector2(ng_x + 4 + cos(-arm_ang) * 22, ng_y + 18 + sin(-arm_ang) * 22),
		ng_col, 3.5)
	# Legs
	draw_line(Vector2(ng_x - 5, ng_y + 65), Vector2(ng_x - 10, ng_y + 95), ng_col, 3.0)
	draw_line(Vector2(ng_x + 5, ng_y + 65), Vector2(ng_x + 10, ng_y + 95), ng_col, 3.0)
	# Glow halo around figure
	draw_arc(Vector2(ng_x, ng_y + 45), 50, 0.0, TAU, 32,
		Color(1.0, 0.18, 0.58, 0.12 + sin(_scene_time * 3.0) * 0.08), 18.0)
	# ── Spot lights on facade ────────────────────────────────────
	for sli in 5:
		var slx = cx2 + 28 + sli * (cw2 - 56) / 4.0
		var sl_on = sin(_scene_time * 2.2 + sli * 1.1) > 0.0
		if sl_on:
			draw_circle(Vector2(slx, cy2 - 6), 7.0, Color(1.0, 0.85, 0.30, 0.90))
			draw_circle(Vector2(slx, cy2 - 6), 3.5, Color(1.0, 1.0, 0.90))
		else:
			draw_circle(Vector2(slx, cy2 - 6), 5.0, Color(0.30, 0.26, 0.35, 0.70))

	# ── GRAND DOME HALL — 2.5D base + dome ───────────────────
	var dx   = PORT_X + PORT_W * 0.68;  var dy = PORT_Y + PORT_H * 0.70
	var dw   = 280.0;  var dbd = 150.0;  var dbh = 360.0
	var gdc  = Color(0.90, 0.88, 0.80)
	var gdtc = Color(0.72, 0.58, 0.22)
	var did  = Vector2(ISO_DX * dbd, ISO_DY * dbd)
	var DFL  = Vector2(dx, dy);             var DFR  = DFL + Vector2(dw, 0)
	var DBL  = DFL + did;                   var DBR  = DFR + did
	var DFLb = DFL + Vector2(0, dbh);       var DFRb = DFR + Vector2(0, dbh)
	var DBRb = DBR + Vector2(0, dbh)
	var dome_rise = 140.0

	# Shadow
	draw_colored_polygon(PackedVector2Array([
		DFLb + Vector2(10, 10), DFRb + Vector2(10, 10),
		DBRb + Vector2(10, 10), DBL  + Vector2(10, dbh + 10)
	]), C_SHADOW)
	# East side wall
	draw_colored_polygon(PackedVector2Array([DFR, DBR, DBRb, DFRb]), gdc.darkened(0.25))
	draw_line(DFR, DBR, gdtc, 1.5)
	draw_line(DFR, DFRb, gdtc.darkened(0.05), 1.5)
	draw_line(DBR, DBRb, gdtc.darkened(0.1), 1.5)
	# Roof face
	draw_colored_polygon(PackedVector2Array([DFL, DFR, DBR, DBL]), gdc.lightened(0.08))
	draw_line(DFL, DFR, gdtc, 3.0)
	draw_line(DFL, DBL, gdtc.darkened(0.1), 1.5)
	draw_line(DFR, DBR, gdtc.darkened(0.1), 1.5)
	draw_line(DBL, DBR, gdtc.darkened(0.2), 1.5)
	# Grand dome arch above front edge
	var dome_pts = PackedVector2Array()
	for i in 25:
		var t = float(i) / 24.0
		dome_pts.append(Vector2(dx + t * dw, dy - sin(t * PI) * dome_rise))
	dome_pts.append(DFR); dome_pts.append(DFL)
	draw_colored_polygon(dome_pts, Color(0.78, 0.85, 0.92))
	draw_arc(Vector2(dx + dw * 0.46, dy), dw * 0.28, PI + 0.30, TAU - 0.30, 14,
		Color(1.0, 1.0, 1.0, 0.30), 8.0)
	draw_line(DFL, DFR, gdtc, 4.0)
	# Front / south wall
	draw_colored_polygon(PackedVector2Array([DFL, DFR, DFRb, DFLb]), gdc)
	draw_line(DFL, DFR, gdtc, 4.0)
	draw_line(DFLb, DFRb, gdtc.darkened(0.1), 2.5)
	draw_line(DFL, DFLb, gdtc.darkened(0.05), 1.5)
	draw_line(DFR, DFRb, gdtc.darkened(0.05), 1.5)
	# Columns on front face
	for ci in 6:
		var col_x = dx + 24 + ci * (dw - 48) / 5.0
		draw_rect(Rect2(col_x - 5, dy, 10, dbh), Color(0.95, 0.92, 0.85))
		draw_rect(Rect2(col_x - 7, dy - 6, 14, 6), gdtc)
		draw_rect(Rect2(col_x - 6, DFLb.y - 5, 12, 5), gdtc)
	# Doorway on front face
	var dome_cx_x = dx + dw * 0.5
	draw_rect(Rect2(dome_cx_x - 28, DFLb.y - 80, 56, 80), C_BUILDING_DARK)
	var door_arc = PackedVector2Array()
	for i in 11:
		var ang = PI + float(i) / 10.0 * PI
		door_arc.append(Vector2(dome_cx_x + cos(ang) * 28,
			DFLb.y - 80 + sin(ang) * 28 + 28))
	draw_colored_polygon(door_arc, C_BUILDING_DARK)
	draw_polyline(door_arc, gdtc, 2.5)
	_draw_label(font, Vector2(dx + dw * 0.5 - 52, dy - dome_rise - 8), "GRAND HALL", 11, gdtc)

	# ── SMALL DINER ────────────────────────────────────────────
	var dn_x = PORT_X + PORT_W * 0.56;  var dn_y = PORT_Y + PORT_H * 0.83 - 40
	_draw_naboo_building(Vector2(dn_x, dn_y), 160.0, 120.0,
		Color(0.84, 0.78, 0.65), Color(0.58, 0.38, 0.10))
	_draw_label(font, Vector2(dn_x + 18, dn_y + 24), "DEXTER'S", 10, Color(0.22, 0.14, 0.04))
	_draw_label(font, Vector2(dn_x + 26, dn_y + 36), "DINER", 10, Color(0.22, 0.14, 0.04))

func _draw_naboo_building(pos: Vector2, w: float, h: float,
		wall_col: Color, trim_col: Color) -> void:
	# 2.5D Naboo-style building: box + barrel arch on roof + colonnade on front
	var bd        = h * 0.48    # ISO depth
	var bh        = h * 1.3     # front wall height — tall Naboo architecture
	var arch_rise = h * 0.35    # how high the arch peaks above FL
	var nid  = Vector2(ISO_DX * bd, ISO_DY * bd)
	var NFL  = pos;                    var NFR  = pos + Vector2(w, 0)
	var NBL  = pos + nid;              var NBR  = pos + Vector2(w, 0) + nid
	var NFLb = NFL + Vector2(0, bh);   var NFRb = NFR + Vector2(0, bh)
	var NBRb = NBR + Vector2(0, bh)

	# Shadow
	draw_colored_polygon(PackedVector2Array([
		NFLb + Vector2(8, 8), NFRb + Vector2(8, 8),
		NBRb + Vector2(8, 8), NBL  + Vector2(8, bh + 8)
	]), C_SHADOW)

	# East side wall
	draw_colored_polygon(PackedVector2Array([NFR, NBR, NBRb, NFRb]), wall_col.darkened(0.25))
	# Side arch profile on east top edge
	var se = PackedVector2Array()
	for i in 13:
		var t = float(i) / 12.0
		var np2 = NFR.lerp(NBR, t)
		se.append(np2 + Vector2(0, -sin(t * PI) * arch_rise * 0.55))
	se.append(NBR); se.append(NFR)
	draw_colored_polygon(se, wall_col.darkened(0.18))
	draw_line(NFR, NBR, trim_col.darkened(0.15), 1.5)
	draw_line(NFR, NFRb, trim_col.darkened(0.05), 1.5)
	draw_line(NBR, NBRb, trim_col.darkened(0.10), 1.5)

	# Roof face (parallelogram)
	draw_colored_polygon(PackedVector2Array([NFL, NFR, NBR, NBL]), wall_col.lightened(0.10))
	draw_line(NFL, NFR, trim_col, 2.0)
	draw_line(NFL, NBL, trim_col.darkened(0.1), 1.5)
	draw_line(NFR, NBR, trim_col.darkened(0.1), 1.5)
	draw_line(NBL, NBR, trim_col.darkened(0.2), 1.5)

	# Arch dome above the front roof edge
	var ap = PackedVector2Array()
	for i in 21:
		var t = float(i) / 20.0
		ap.append(Vector2(NFL.x + t * w, NFL.y - sin(t * PI) * arch_rise))
	ap.append(NFR); ap.append(NFL)
	draw_colored_polygon(ap, wall_col.lightened(0.08))
	draw_line(NFL, NFR, trim_col, 3.5)

	# Front / south wall
	draw_colored_polygon(PackedVector2Array([NFL, NFR, NFRb, NFLb]), wall_col)
	draw_line(NFL, NFR, trim_col, 3.5)
	draw_line(NFLb, NFRb, trim_col.darkened(0.1), 2.0)
	draw_line(NFL, NFLb, trim_col.darkened(0.05), 1.5)
	draw_line(NFR, NFRb, trim_col.darkened(0.05), 1.5)
	draw_rect(Rect2(NFLb.x, NFLb.y - 5, w, 5), trim_col)

	# Columns on front face
	var col_count = maxi(2, int(w / 72))
	var col_spacing = w / (col_count + 1)
	for ci in col_count:
		var col_x = NFL.x + col_spacing * (ci + 1) - 4
		draw_rect(Rect2(col_x, NFL.y, 8, bh), wall_col.darkened(0.08))
		draw_rect(Rect2(col_x - 3, NFL.y - 6, 14, 6), trim_col)
		draw_rect(Rect2(col_x - 2, NFLb.y - 5, 12, 5), trim_col)

	# Arched windows on front face
	var win_y   = NFL.y + bh * 0.18
	var win_cols = maxi(2, int(w / 60))
	for wci in win_cols:
		var wx = NFL.x + 18 + wci * (w - 36) / win_cols
		draw_rect(Rect2(wx, win_y, 22, 28), C_TOWER_GLASS)
		draw_arc(Vector2(wx + 11, win_y), 11, PI, TAU, 8, trim_col, 1.5)

	# Grand entrance arch on front face
	var door_cx = NFL.x + w * 0.5
	draw_rect(Rect2(door_cx - 16, NFLb.y - 54, 32, 54), C_BUILDING_DARK)
	var da = PackedVector2Array()
	for i in 9:
		var ang2 = PI + float(i) / 8.0 * PI
		da.append(Vector2(door_cx + cos(ang2) * 16,
			NFLb.y - 54 + sin(ang2) * 16 + 16))
	draw_colored_polygon(da, C_BUILDING_DARK)
	draw_polyline(da, trim_col, 2.0)

# ── PORT WATERWAY ─────────────────────────────────────────────
func _draw_port_waterway() -> void:
	# A canal cuts east-west through the lower half of the spaceport.
	# Enters west wall at ~77% height, curves east, exits east wall at ~73%.
	# Bridges span the canal wherever taxiways cross.
	var w_start = Vector2(PORT_X,          PORT_Y + PORT_H * 0.77)
	var w_ctrl  = Vector2(PORT_X + PORT_W * 0.50, PORT_Y + PORT_H * 0.80)
	var w_end   = Vector2(PORT_X + PORT_W, PORT_Y + PORT_H * 0.73)
	var segs    = 64
	var c_width = 38.0

	var pts_top = PackedVector2Array()
	var pts_bot = PackedVector2Array()
	for i in (segs + 1):
		var t   = float(i) / segs
		var p   = w_start.lerp(w_ctrl, t).lerp(w_ctrl.lerp(w_end, t), t)
		var t2  = min(t + 0.01, 1.0)
		var p2  = w_start.lerp(w_ctrl, t2).lerp(w_ctrl.lerp(w_end, t2), t2)
		var tang = (p2 - p).normalized()
		var perp  = Vector2(-tang.y, tang.x)
		var wave  = sin(t * 6.0 * PI) * 3.0
		pts_top.append(p + perp * (c_width + wave))
		pts_bot.append(p - perp * (c_width - wave))

	# Water fill
	var all_pts = PackedVector2Array()
	for pt in pts_top: all_pts.append(pt)
	for i in range(pts_bot.size() - 1, -1, -1): all_pts.append(pts_bot[i])
	draw_colored_polygon(all_pts, Color(0.20, 0.48, 0.78))
	# Deep centre stripe
	var mid_pts = PackedVector2Array()
	for i in (segs + 1):
		var t  = float(i) / segs
		var p  = w_start.lerp(w_ctrl, t).lerp(w_ctrl.lerp(w_end, t), t)
		mid_pts.append(p)
	if mid_pts.size() >= 2:
		for i in (mid_pts.size() - 1):
			draw_line(mid_pts[i], mid_pts[i + 1], Color(0.12, 0.34, 0.65, 0.55), 14.0)
	# Foam edges
	for i in segs:
		draw_line(pts_top[i], pts_top[i + 1], Color(0.55, 0.78, 1.00, 0.40), 1.8)
		draw_line(pts_bot[i], pts_bot[i + 1], Color(0.55, 0.78, 1.00, 0.40), 1.8)
	# Stone embankment strips
	for i in segs:
		draw_line(pts_top[i], pts_top[i + 1], Color(0.50, 0.50, 0.54, 0.60), 3.5)
		draw_line(pts_bot[i], pts_bot[i + 1], Color(0.50, 0.50, 0.54, 0.60), 3.5)

	# ── Bridges — draw tarmac deck over canal where taxiways cross ──
	# Bridge 1: main vertical taxiway (cx ≈ PORT_X + PORT_W*0.5)
	# Bridge 2: hangar-side path (cx ≈ PORT_X + PORT_W*0.18)
	var bridge_xs = [PORT_X + PORT_W * 0.18, PORT_X + PORT_W * 0.50]
	for bx in bridge_xs:
		# Find the approximate y of the canal at this x
		var t_est = clampf((bx - PORT_X) / PORT_W, 0.0, 1.0)
		var bp    = w_start.lerp(w_ctrl, t_est).lerp(w_ctrl.lerp(w_end, t_est), t_est)
		var by    = bp.y
		var bw2   = 52.0   # bridge road width (half)
		var bspan = c_width + 18.0   # how far either side beyond canal edge
		# Road deck
		draw_rect(Rect2(bx - bw2, by - bspan, bw2 * 2, bspan * 2), C_TARMAC)
		# Yellow centerline on bridge
		draw_rect(Rect2(bx - 2, by - bspan, 4, bspan * 2), C_TARMAC_LINE)
		# Bridge railings (stone ledge)
		draw_rect(Rect2(bx - bw2, by - bspan - 5, bw2 * 2, 5), Color(0.72, 0.70, 0.66))
		draw_rect(Rect2(bx - bw2, by + bspan,     bw2 * 2, 5), Color(0.72, 0.70, 0.66))
		# Railing posts
		for pi in 5:
			var prx = bx - bw2 + 10 + pi * (bw2 * 2 - 20) / 4.0
			draw_rect(Rect2(prx - 3, by - bspan - 10, 6, 15), Color(0.60, 0.58, 0.54))
			draw_rect(Rect2(prx - 3, by + bspan - 5,  6, 15), Color(0.60, 0.58, 0.54))

# ── BOTTOM DISTRICT BUILDINGS ──────────────────────────────────
func _draw_bottom_buildings() -> void:
	var font = _roboto
	# ─── BOTTOM-LEFT QUADRANT ────────────────────────────────────
	# Canal sits at y ≈ PORT_Y + PORT_H*0.77-0.83 — buildings go above or below it.

	# Municipal Tower — tall narrow, above canal
	var mt_pos = Vector2(PORT_X + 100, PORT_Y + PORT_H * 0.67 - 100)
	_draw_2d5_building(mt_pos, 90.0, 65.0, 480.0,
		Color(0.84, 0.82, 0.76).lightened(0.10),
		Color(0.84, 0.82, 0.76),
		Color(0.84, 0.82, 0.76).darkened(0.28),
		Color(0.55, 0.44, 0.14))
	# Dome cap on tower
	draw_colored_polygon(_ellipse(mt_pos + Vector2(45, -12), 50, 50, 0.0, 24), C_DOME)
	draw_colored_polygon(_ellipse(mt_pos + Vector2(32, -24), 16, 12, 0.0, 12), C_DOME_SHINE)
	draw_arc(mt_pos + Vector2(45, -12), 50, 0.0, TAU, 24, Color(0.55, 0.44, 0.14), 2.0)
	_draw_label(font, mt_pos + Vector2(8, 26), "MUNICIPAL", 10, Color(0.25, 0.18, 0.06))

	# Trade Hall — wide, above canal
	var th_pos = Vector2(PORT_X + 660, PORT_Y + PORT_H * 0.66)
	_draw_naboo_building(th_pos, 260.0, 170.0,
		Color(0.88, 0.85, 0.76), Color(0.60, 0.46, 0.12))
	_draw_label(font, th_pos + Vector2(62, 26), "TRADE HALL", 11, Color(0.22, 0.16, 0.04))

	# Clinic — below canal (north 150 px, east 50 px)
	var cl_pos = Vector2(PORT_X + 530, PORT_Y + PORT_H * 0.90 - 150)
	_draw_naboo_building(cl_pos, 190.0, 130.0,
		Color(0.90, 0.93, 0.89), Color(0.28, 0.70, 0.38))
	_draw_label(font, cl_pos + Vector2(44, 24), "MEDICAL", 11, Color(0.08, 0.35, 0.16))

	# Market Row — long low arcade, below canal
	var mr_pos = Vector2(PORT_X + 660, PORT_Y + PORT_H * 0.89)
	_draw_2d5_building(mr_pos, 240.0, 80.0, 250.0,
		Color(0.86, 0.80, 0.68).lightened(0.10),
		Color(0.86, 0.80, 0.68),
		Color(0.86, 0.80, 0.68).darkened(0.25),
		Color(0.62, 0.42, 0.12))
	# Stall arches along front
	var ma_cols = 5
	for ai in ma_cols:
		var ax = mr_pos.x + 28 + ai * (240.0 - 56) / (ma_cols - 1)
		draw_rect(Rect2(ax - 10, mr_pos.y + 90 * 0.45 * 0.55, 20, 90 * 0.45 * 0.45), C_BUILDING_DARK)
		var ap2 = PackedVector2Array()
		for si in 9:
			var ang = PI + float(si) / 8.0 * PI
			ap2.append(Vector2(ax + cos(ang) * 10, mr_pos.y + 90 * 0.45 * 0.55 + sin(ang) * 10 + 10))
		draw_colored_polygon(ap2, C_BUILDING_DARK)
	_draw_label(font, mr_pos + Vector2(60, 16), "MARKET ARCADE", 10, Color(0.25, 0.15, 0.04))

	# Library — below canal
	var lb_pos = Vector2(PORT_X + 940, PORT_Y + PORT_H * 0.88)
	_draw_naboo_building(lb_pos, 190.0, 130.0,
		Color(0.87, 0.84, 0.76), Color(0.52, 0.40, 0.10))
	_draw_label(font, lb_pos + Vector2(40, 24), "LIBRARY", 12, Color(0.22, 0.16, 0.04))

	# ─── BOTTOM-RIGHT QUADRANT ───────────────────────────────────
	# Observatory — far right, above canal (tall with large dome)
	var ob_pos = Vector2(PORT_X + PORT_W * 0.86, PORT_Y + PORT_H * 0.62)
	_draw_2d5_building(ob_pos, 100.0, 75.0, 440.0,
		Color(0.82, 0.80, 0.74).lightened(0.10),
		Color(0.82, 0.80, 0.74),
		Color(0.82, 0.80, 0.74).darkened(0.28),
		Color(0.58, 0.46, 0.14))
	draw_colored_polygon(_ellipse(ob_pos + Vector2(50, -14), 60, 60, 0.0, 28), Color(0.68, 0.78, 0.88))
	draw_colored_polygon(_ellipse(ob_pos + Vector2(36, -28), 20, 16, 0.0, 14), C_DOME_SHINE)
	draw_arc(ob_pos + Vector2(50, -14), 60, 0.0, TAU, 28, Color(0.58, 0.46, 0.14), 2.0)
	# Telescope slit
	draw_rect(Rect2(ob_pos.x + 46, ob_pos.y - 74, 8, 22), Color(0.12, 0.16, 0.24))
	_draw_label(font, ob_pos + Vector2(8, 24), "OBSERVATORY", 10, Color(0.28, 0.22, 0.08))

	# Residential block — below canal, left of grand hall
	var rb_pos = Vector2(PORT_X + PORT_W * 0.54, PORT_Y + PORT_H * 0.88 + 20)
	_draw_2d5_building(rb_pos, 240.0, 130.0, 380.0,
		Color(0.80, 0.78, 0.72).lightened(0.10),
		Color(0.80, 0.78, 0.72),
		Color(0.80, 0.78, 0.72).darkened(0.26),
		Color(0.52, 0.42, 0.12))
	# Row of windows
	for wi in 5:
		var wx = rb_pos.x + 22 + wi * 42
		var wy = rb_pos.y + 160.0 * 0.52 * 0.25
		draw_rect(Rect2(wx, wy, 20, 26), C_TOWER_GLASS)
		draw_arc(Vector2(wx + 10, wy), 10, PI, TAU, 8, Color(0.52, 0.42, 0.12), 1.5)
	_draw_label(font, rb_pos + Vector2(50, 20), "RESIDENCES", 10, Color(0.25, 0.18, 0.06))

	# Engineering Works — far right, below canal
	var ew_pos = Vector2(PORT_X + PORT_W * 0.85 + 20, PORT_Y + PORT_H * 0.87)
	_draw_2d5_building(ew_pos, 200.0, 110.0, 340.0,
		Color(0.66, 0.68, 0.72).lightened(0.10),
		Color(0.66, 0.68, 0.72),
		Color(0.66, 0.68, 0.72).darkened(0.28),
		Color(0.44, 0.50, 0.56))
	# Industrial pipes on side
	for pi2 in 3:
		var px3 = ew_pos.x + ew_pos.x * 0.0 + pi2 * 62
		draw_circle(Vector2(px3 + 30, ew_pos.y + 10), 12.0, Color(0.50, 0.52, 0.56))
		draw_circle(Vector2(px3 + 30, ew_pos.y + 10), 7.0, Color(0.34, 0.38, 0.44))
	_draw_label(font, ew_pos + Vector2(32, 20), "ENGINEERING", 10, Color(0.20, 0.24, 0.28))

	# Multi-dome civic complex — right side below grand hall
	var md_x = PORT_X + PORT_W * 0.73;  var md_y = PORT_Y + PORT_H * 0.93
	_draw_2d5_building(Vector2(md_x, md_y), 280.0, 140.0, 320.0,
		Color(0.88, 0.86, 0.78).lightened(0.10),
		Color(0.88, 0.86, 0.78),
		Color(0.88, 0.86, 0.78).darkened(0.25),
		Color(0.62, 0.50, 0.16))
	# Three small domes on the roof
	for di in 3:
		var dc = Vector2(md_x + 46 + di * 90, md_y - 6)
		draw_colored_polygon(_ellipse(dc, 32, 32, 0.0, 20), Color(0.72, 0.82, 0.90))
		draw_colored_polygon(_ellipse(dc + Vector2(-8, -8), 11, 9, 0.0, 10), C_DOME_SHINE)
		draw_arc(dc, 32, 0.0, TAU, 20, Color(0.62, 0.50, 0.16), 1.8)
	_draw_label(font, Vector2(md_x + 54, md_y + 18), "CIVIC COMPLEX", 10, Color(0.25, 0.18, 0.06))

# ── SOUTHERN DISTRICT — extra Naboo-style buildings ───────────
func _draw_southern_district() -> void:
	var font = _roboto
	# ── Bottom-left extras ────────────────────────────────────
	# Cylindrical drum tower
	var ct_x = PORT_X + 640;  var ct_y = PORT_Y + PORT_H * 0.67
	draw_colored_polygon(_ellipse(Vector2(ct_x, ct_y + 8), 52, 18, 0.0, 20), C_SHADOW)
	# Cylinder sides (east darker, west lighter)
	for si2 in 20:
		var a0 = float(si2) / 20.0 * PI
		var a1 = float(si2 + 1) / 20.0 * PI
		var x0 = ct_x + cos(a0) * 52;  var _x1 = ct_x + cos(a1) * 52
		var shade = 0.55 + 0.35 * (1.0 - cos(a0))
		draw_line(Vector2(x0, ct_y), Vector2(x0, ct_y + 400),
			Color(shade * 0.84, shade * 0.82, shade * 0.74), 3.8)
	draw_colored_polygon(_ellipse(Vector2(ct_x, ct_y), 52, 18, 0.0, 20),
		Color(0.86, 0.84, 0.76))
	# Cap dome
	draw_colored_polygon(_ellipse(Vector2(ct_x, ct_y - 10), 56, 38, 0.0, 24), Color(0.72, 0.82, 0.90))
	draw_colored_polygon(_ellipse(Vector2(ct_x - 14, ct_y - 22), 18, 12, 0.0, 12), C_DOME_SHINE)
	draw_arc(Vector2(ct_x, ct_y - 10), 56, PI, TAU, 24, Color(0.58, 0.46, 0.14), 2.0)
	# Cylinder base cap
	draw_colored_polygon(_ellipse(Vector2(ct_x, ct_y + 400), 52, 18, 0.0, 20),
		Color(0.62, 0.60, 0.54))
	# Ring bands
	for bi2 in 5:
		var by2 = ct_y + 50 + bi2 * 75
		draw_colored_polygon(_ellipse(Vector2(ct_x, by2), 54, 10, 0.0, 20),
			Color(0.65, 0.50, 0.16))
	_draw_label(font, Vector2(ct_x - 28, ct_y + 418), "ARCHIVE", 10, Color(0.30, 0.22, 0.06))

	# Triumphal arch / gate
	var ga_x = PORT_X + 980;  var ga_y = PORT_Y + PORT_H * 0.67
	var ga_w = 180.0;  var _ga_h = 200.0
	_draw_2d5_building(Vector2(ga_x, ga_y), ga_w, 90.0, 150.0,
		Color(0.88, 0.86, 0.78).lightened(0.10), Color(0.88, 0.86, 0.78),
		Color(0.88, 0.86, 0.78).darkened(0.26), Color(0.62, 0.50, 0.16))
	# Right tower
	_draw_2d5_building(Vector2(ga_x + ga_w - 38, ga_y - 200), 38.0, 44.0, 360.0,
		Color(0.88, 0.86, 0.78).lightened(0.10), Color(0.88, 0.86, 0.78),
		Color(0.88, 0.86, 0.78).darkened(0.26), Color(0.62, 0.50, 0.16))
	# Left tower
	_draw_2d5_building(Vector2(ga_x, ga_y - 200), 38.0, 44.0, 360.0,
		Color(0.88, 0.86, 0.78).lightened(0.10), Color(0.88, 0.86, 0.78),
		Color(0.88, 0.86, 0.78).darkened(0.26), Color(0.62, 0.50, 0.16))
	# Arch opening
	var arch_cx3 = ga_x + ga_w * 0.5
	var arch_top3 = ga_y + 60.0 * 0.45 - 110
	draw_rect(Rect2(arch_cx3 - 38, arch_top3, 76, 110), C_TARMAC_DARK)
	var ag = PackedVector2Array()
	for i in 15:
		var ang3 = PI + float(i) / 14.0 * PI
		ag.append(Vector2(arch_cx3 + cos(ang3) * 38, arch_top3 + sin(ang3) * 38 + 38))
	draw_colored_polygon(ag, C_TARMAC_DARK)
	draw_polyline(ag, Color(0.62, 0.50, 0.16), 3.0)
	_draw_label(font, Vector2(ga_x + 18, ga_y - 128), "NORTH GATE", 10, Color(0.30, 0.22, 0.06))

	# Small dome rotunda near JOBS
	var rd_x = PORT_X + PORT_W * 0.10;  var rd_y = PORT_Y + PORT_H * 0.52
	_draw_2d5_building(Vector2(rd_x, rd_y), 120.0, 80.0, 280.0,
		Color(0.84, 0.82, 0.75).lightened(0.1), Color(0.84, 0.82, 0.75),
		Color(0.84, 0.82, 0.75).darkened(0.26), Color(0.58, 0.46, 0.14))
	draw_colored_polygon(_ellipse(Vector2(rd_x + 60, rd_y - 8), 68, 68, 0.0, 28), C_DOME)
	draw_colored_polygon(_ellipse(Vector2(rd_x + 45, rd_y - 24), 22, 18, 0.0, 14), C_DOME_SHINE)
	draw_arc(Vector2(rd_x + 60, rd_y - 8), 68, 0.0, TAU, 28, Color(0.58, 0.46, 0.14), 2.0)
	_draw_label(font, Vector2(rd_x + 10, rd_y + 18), "EMBASSY", 11, Color(0.25, 0.18, 0.06))

	# Wide colonnaded hall — bottom-left
	var ch_x = PORT_X + 640;  var ch_y = PORT_Y + PORT_H * 0.93
	_draw_2d5_building(Vector2(ch_x, ch_y), 300.0, 120.0, 340.0,
		Color(0.90, 0.88, 0.80).lightened(0.1), Color(0.90, 0.88, 0.80),
		Color(0.90, 0.88, 0.80).darkened(0.24), Color(0.65, 0.52, 0.16))
	for ci3 in 7:
		var col_x3 = ch_x + 20 + ci3 * (260.0 / 6.0)
		draw_rect(Rect2(col_x3 - 5, ch_y, 10, 340), Color(0.95, 0.93, 0.86))
		draw_rect(Rect2(col_x3 - 7, ch_y - 8, 14, 8), Color(0.65, 0.52, 0.16))
		draw_rect(Rect2(col_x3 - 6, ch_y + 330, 12, 10), Color(0.65, 0.52, 0.16))
	_draw_label(font, Vector2(ch_x + 72, ch_y + 20), "SENATE HALL", 11, Color(0.25, 0.18, 0.06))

	# ── Bottom-right extras ─────────────────────────────────────
	# Second drum tower — far right
	var ct2_x = PORT_X + PORT_W * 0.94;  var ct2_y = PORT_Y + PORT_H * 0.70
	draw_colored_polygon(_ellipse(Vector2(ct2_x, ct2_y + 8), 44, 15, 0.0, 18), C_SHADOW)
	for si3 in 18:
		var a0b = float(si3) / 18.0 * PI
		var shade2 = 0.50 + 0.38 * (1.0 - cos(a0b))
		draw_line(Vector2(ct2_x + cos(a0b) * 44, ct2_y),
			Vector2(ct2_x + cos(a0b) * 44, ct2_y + 360),
			Color(shade2 * 0.80, shade2 * 0.78, shade2 * 0.70), 3.5)
	draw_colored_polygon(_ellipse(Vector2(ct2_x, ct2_y), 44, 15, 0.0, 18),
		Color(0.82, 0.80, 0.72))
	draw_colored_polygon(_ellipse(Vector2(ct2_x, ct2_y - 8), 48, 34, 0.0, 22), Color(0.70, 0.80, 0.88))
	draw_colored_polygon(_ellipse(Vector2(ct2_x - 12, ct2_y - 18), 15, 10, 0.0, 10), C_DOME_SHINE)
	draw_arc(Vector2(ct2_x, ct2_y - 8), 48, PI, TAU, 22, Color(0.55, 0.44, 0.14), 2.0)
	for bi3 in 5:
		var by3 = ct2_y + 45 + bi3 * 65
		draw_colored_polygon(_ellipse(Vector2(ct2_x, by3), 46, 9, 0.0, 18),
			Color(0.62, 0.50, 0.16))
	_draw_label(font, Vector2(ct2_x - 32, ct2_y + 378), "TRIBUNAL", 10, Color(0.30, 0.22, 0.06))

	# Triumphal arch gate — east side
	var ga2_x = PORT_X + PORT_W * 0.78;  var ga2_y = PORT_Y + PORT_H * 0.65
	_draw_2d5_building(Vector2(ga2_x, ga2_y), 200.0, 90.0, 160.0,
		Color(0.84, 0.82, 0.74).lightened(0.1), Color(0.84, 0.82, 0.74),
		Color(0.84, 0.82, 0.74).darkened(0.26), Color(0.60, 0.48, 0.14))
	_draw_2d5_building(Vector2(ga2_x, ga2_y - 200), 40.0, 46.0, 360.0,
		Color(0.84, 0.82, 0.74).lightened(0.1), Color(0.84, 0.82, 0.74),
		Color(0.84, 0.82, 0.74).darkened(0.26), Color(0.60, 0.48, 0.14))
	_draw_2d5_building(Vector2(ga2_x + 160, ga2_y - 200), 40.0, 46.0, 360.0,
		Color(0.84, 0.82, 0.74).lightened(0.1), Color(0.84, 0.82, 0.74),
		Color(0.84, 0.82, 0.74).darkened(0.26), Color(0.60, 0.48, 0.14))
	var ag2_cx = ga2_x + 100
	var ag2_top = ga2_y + 70.0 * 0.45 - 120
	draw_rect(Rect2(ag2_cx - 42, ag2_top, 84, 120), C_TARMAC_DARK)
	var ag2 = PackedVector2Array()
	for i2 in 15:
		var ang4 = PI + float(i2) / 14.0 * PI
		ag2.append(Vector2(ag2_cx + cos(ang4) * 42, ag2_top + sin(ang4) * 42 + 42))
	draw_colored_polygon(ag2, C_TARMAC_DARK)
	draw_polyline(ag2, Color(0.60, 0.48, 0.14), 3.0)
	_draw_label(font, Vector2(ga2_x + 38, ga2_y - 138), "EAST GATE", 10, Color(0.30, 0.22, 0.06))

	# Compact chapel/temple with pointed roof
	var tp_x = PORT_X + PORT_W * 0.67;  var tp_y = PORT_Y + PORT_H * 0.89
	_draw_2d5_building(Vector2(tp_x, tp_y), 160.0, 100.0, 360.0,
		Color(0.88, 0.86, 0.78).lightened(0.1), Color(0.88, 0.86, 0.78),
		Color(0.88, 0.86, 0.78).darkened(0.25), Color(0.62, 0.50, 0.16))
	# Pointed pediment / spire
	var spire_tip = Vector2(tp_x + 80, tp_y - 140)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tp_x - 10, tp_y), Vector2(tp_x + 170, tp_y), spire_tip
	]), Color(0.86, 0.84, 0.76))
	draw_polyline(PackedVector2Array([
		Vector2(tp_x - 10, tp_y), spire_tip, Vector2(tp_x + 170, tp_y)
	]), Color(0.62, 0.50, 0.16), 2.5)
	# Spire needle
	draw_line(spire_tip, spire_tip - Vector2(0, 44), Color(0.42, 0.38, 0.30), 3.0)
	draw_circle(spire_tip - Vector2(0, 44), 5.0, Color(0.88, 0.70, 0.14))
	_draw_label(font, Vector2(tp_x + 20, tp_y + 18), "TEMPLE", 11, Color(0.25, 0.18, 0.06))

	# Fan-shaped amphitheatre (curved rows visible from above)
	var am_cx = PORT_X + PORT_W * 0.72;  var am_cy = PORT_Y + PORT_H * 0.93
	for ri in 5:
		var arc_r = 50.0 + ri * 28.0
		var shade3 = Color(0.78 - ri * 0.04, 0.76 - ri * 0.04, 0.68 - ri * 0.04)
		draw_arc(Vector2(am_cx, am_cy), arc_r, PI * 1.15, TAU * 0.5 - 0.15, 24, shade3, 10.0)
	_draw_label(font, Vector2(am_cx - 50, am_cy + 20), "AMPHITHEATRE", 10, Color(0.30, 0.22, 0.06))

# (NPCs/vehicles moved to AnimOverlay.gd for animated walking)

func _draw_port_people_REMOVED() -> void:  # kept as dead stub — do not call
	var rng = RandomNumberGenerator.new()
	rng.seed = 5557
	# Businessman type: suit, briefcase, hat
	# Politician type: long robe
	# Droid type: boxy metallic
	# Worker: vest + hard hat
	var people_data = [
		# near JOBS
		{"pos": Vector2(PORT_X + PORT_W*0.22 + 220, PORT_Y + PORT_H*0.58 + 40), "type": "biz"},
		{"pos": Vector2(PORT_X + PORT_W*0.22 + 250, PORT_Y + PORT_H*0.58 + 20), "type": "biz"},
		{"pos": Vector2(PORT_X + PORT_W*0.22 + 180, PORT_Y + PORT_H*0.58 + 60), "type": "pol"},
		# near BANK
		{"pos": Vector2(PORT_X + PORT_W*0.58 + 30, PORT_Y + PORT_H*0.55 + 310), "type": "pol"},
		{"pos": Vector2(PORT_X + PORT_W*0.58 + 80, PORT_Y + PORT_H*0.55 + 320), "type": "pol"},
		{"pos": Vector2(PORT_X + PORT_W*0.58 + 60, PORT_Y + PORT_H*0.55 + 340), "type": "droid"},
		# near docking bay
		{"pos": Vector2(PORT_X + 640, PORT_Y + 490), "type": "worker"},
		{"pos": Vector2(PORT_X + 700, PORT_Y + 510), "type": "worker"},
		{"pos": Vector2(PORT_X + 760, PORT_Y + 480), "type": "droid"},
		{"pos": Vector2(PORT_X + 820, PORT_Y + 500), "type": "worker"},
		# near CANTINA
		{"pos": Vector2(PORT_X + 510, PORT_Y + PORT_H*0.84 + 110), "type": "biz"},
		{"pos": Vector2(PORT_X + 540, PORT_Y + PORT_H*0.84 + 90), "type": "alien"},
		{"pos": Vector2(PORT_X + 480, PORT_Y + PORT_H*0.84 + 130), "type": "alien"},
		# near Trade Hall
		{"pos": Vector2(PORT_X + 830, PORT_Y + PORT_H*0.66 + 80), "type": "biz"},
		{"pos": Vector2(PORT_X + 860, PORT_Y + PORT_H*0.66 + 60), "type": "pol"},
		# scattered workers by hangars
		{"pos": Vector2(PORT_X + 180, PORT_Y + 500), "type": "worker"},
		{"pos": Vector2(PORT_X + 210, PORT_Y + 520), "type": "droid"},
		{"pos": Vector2(PORT_X + 180, PORT_Y + 1060), "type": "worker"},
		{"pos": Vector2(PORT_X + 215, PORT_Y + 1080), "type": "worker"},
	]

	for pd in people_data:
		var p : Vector2 = pd["pos"]
		var kind : String = pd["type"]
		rng.seed = rng.seed * 6364136223846793005 + 1442695040888963407
		var hue_r = rng.randf()

		match kind:
			"biz":  # Businessman — suit, briefcase, hat
				var suit_col = Color(0.20 + hue_r * 0.15, 0.20, 0.28 + hue_r * 0.12)
				# Shadow
				draw_colored_polygon(_ellipse(p + Vector2(2, 4), 7, 3, 0.0, 8), C_SHADOW)
				# Legs
				draw_line(p + Vector2(-3, 0), p + Vector2(-5, 14), suit_col.darkened(0.3), 3.0)
				draw_line(p + Vector2(3, 0), p + Vector2(5, 14), suit_col.darkened(0.3), 3.0)
				# Body/jacket
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 6, p.y - 18), Vector2(p.x + 6, p.y - 18),
					Vector2(p.x + 8, p.y),      Vector2(p.x - 8, p.y),
				]), suit_col)
				# White shirt
				draw_rect(Rect2(p.x - 2, p.y - 17, 4, 12), Color(0.92, 0.92, 0.92))
				# Tie
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 1, p.y - 16), Vector2(p.x + 1, p.y - 16),
					Vector2(p.x + 2, p.y - 8), Vector2(p.x, p.y - 6), Vector2(p.x - 2, p.y - 8)
				]), Color(0.72, 0.10, 0.12))
				# Arms
				draw_line(p + Vector2(-6, -16), p + Vector2(-10, -6), suit_col, 2.5)
				draw_line(p + Vector2(6, -16),  p + Vector2(14, -12), suit_col, 2.5)
				# Briefcase
				draw_rect(Rect2(p.x + 10, p.y - 14, 9, 7), Color(0.55, 0.38, 0.14))
				draw_rect(Rect2(p.x + 10, p.y - 14, 9, 7), Color(0.35, 0.22, 0.06), false, 1.0)
				draw_rect(Rect2(p.x + 12, p.y - 15, 5, 2), Color(0.35, 0.22, 0.06))
				# Head + face
				draw_circle(p + Vector2(0, -26), 7.0, Color(0.82 + hue_r * 0.10, 0.65, 0.48))
				# Hat (fedora)
				draw_rect(Rect2(p.x - 8, p.y - 36, 16, 4), suit_col)
				draw_rect(Rect2(p.x - 5, p.y - 40, 10, 6), suit_col)

			"pol":  # Politician in robes
				var robe_col = Color(0.65 + hue_r * 0.25, 0.60 + hue_r * 0.10, 0.30 + hue_r * 0.30)
				draw_colored_polygon(_ellipse(p + Vector2(2, 4), 8, 3, 0.0, 8), C_SHADOW)
				# Wide flowing robe
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 4, p.y - 22), Vector2(p.x + 4, p.y - 22),
					Vector2(p.x + 14, p.y + 8), Vector2(p.x - 14, p.y + 8),
				]), robe_col)
				# Robe trim
				draw_line(Vector2(p.x - 4, p.y - 22), Vector2(p.x - 14, p.y + 8),
					robe_col.darkened(0.30), 1.5)
				draw_line(Vector2(p.x + 4, p.y - 22), Vector2(p.x + 14, p.y + 8),
					robe_col.darkened(0.30), 1.5)
				# Sash
				draw_line(Vector2(p.x - 2, p.y - 20), Vector2(p.x + 6, p.y + 4),
					Color(0.85, 0.65, 0.10), 1.8)
				# Head
				draw_circle(p + Vector2(0, -30), 7.5, Color(0.80 + hue_r * 0.12, 0.64, 0.46))
				# Hood / headpiece
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 7, p.y - 26), Vector2(p.x + 7, p.y - 26),
					Vector2(p.x + 9, p.y - 38), Vector2(p.x - 9, p.y - 38),
				]), robe_col.darkened(0.22))

			"droid":  # Droid/Robot — boxy metallic
				var d_col = Color(0.62 + hue_r * 0.15, 0.64, 0.68)
				draw_colored_polygon(_ellipse(p + Vector2(1, 3), 7, 2, 0.0, 8), C_SHADOW)
				# Body box
				draw_rect(Rect2(p.x - 7, p.y - 18, 14, 18), d_col)
				draw_rect(Rect2(p.x - 7, p.y - 18, 14, 18), d_col.darkened(0.35), false, 1.0)
				# Chest panel
				draw_rect(Rect2(p.x - 4, p.y - 14, 8, 6), d_col.darkened(0.25))
				draw_circle(Vector2(p.x - 2, p.y - 11), 2.0, Color(0.20, 0.80, 0.35))
				draw_circle(Vector2(p.x + 2, p.y - 11), 1.5, Color(0.80, 0.20, 0.20))
				# Arms
				draw_rect(Rect2(p.x - 12, p.y - 17, 5, 14), d_col.darkened(0.18))
				draw_rect(Rect2(p.x + 7,  p.y - 17, 5, 14), d_col.darkened(0.18))
				# Legs (treads)
				draw_rect(Rect2(p.x - 8, p.y, 7, 12), d_col.darkened(0.28))
				draw_rect(Rect2(p.x + 1, p.y, 7, 12), d_col.darkened(0.28))
				# Head box + eye visor
				draw_rect(Rect2(p.x - 6, p.y - 28, 12, 10), d_col.lightened(0.12))
				draw_rect(Rect2(p.x - 5, p.y - 26, 10, 4), Color(0.20, 0.55, 0.90, 0.85))
				# Antenna
				draw_line(Vector2(p.x + 2, p.y - 28), Vector2(p.x + 4, p.y - 35), d_col, 1.5)
				draw_circle(Vector2(p.x + 4, p.y - 35), 2.0, Color(1.0, 0.50, 0.10))

			"worker":  # Ground crew — vest, hard hat
				var vest_col = Color(0.85, 0.50 + hue_r * 0.25, 0.08)
				draw_colored_polygon(_ellipse(p + Vector2(2, 4), 6, 2, 0.0, 8), C_SHADOW)
				# Legs with pants
				draw_line(p + Vector2(-3, 0), p + Vector2(-4, 14),
					Color(0.22, 0.24, 0.30), 3.0)
				draw_line(p + Vector2(3, 0), p + Vector2(4, 14),
					Color(0.22, 0.24, 0.30), 3.0)
				# Body + hi-vis vest
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 6, p.y - 18), Vector2(p.x + 6, p.y - 18),
					Vector2(p.x + 7, p.y),      Vector2(p.x - 7, p.y),
				]), vest_col)
				# Reflective stripe
				draw_line(Vector2(p.x - 7, p.y - 9), Vector2(p.x + 7, p.y - 9),
					Color(0.95, 0.95, 0.20), 2.0)
				# Arms
				draw_line(p + Vector2(-6, -16), p + Vector2(-11, -4), vest_col, 2.5)
				draw_line(p + Vector2(6, -16),  p + Vector2(11, -4),  vest_col, 2.5)
				# Head
				draw_circle(p + Vector2(0, -26), 6.5, Color(0.75 + hue_r * 0.15, 0.60, 0.44))
				# Hard hat
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 9, p.y - 30), Vector2(p.x + 9, p.y - 30),
					Vector2(p.x + 7, p.y - 38), Vector2(p.x - 7, p.y - 38),
				]), Color(0.90, 0.80, 0.10))
				draw_rect(Rect2(p.x - 9, p.y - 30, 18, 3), Color(0.80, 0.70, 0.08))

			"alien":  # Green-skinned alien patron
				draw_colored_polygon(_ellipse(p + Vector2(2, 4), 7, 2, 0.0, 8), C_SHADOW)
				var a_col = Color(0.30 + hue_r * 0.20, 0.70 + hue_r * 0.10, 0.35)
				draw_line(p + Vector2(-3, 0), p + Vector2(-4, 14), Color(0.28, 0.22, 0.38), 3.0)
				draw_line(p + Vector2(3, 0),  p + Vector2(4, 14),  Color(0.28, 0.22, 0.38), 3.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(p.x - 6, p.y - 18), Vector2(p.x + 6, p.y - 18),
					Vector2(p.x + 7, p.y),      Vector2(p.x - 7, p.y),
				]), Color(0.38, 0.28, 0.55))
				draw_line(p + Vector2(-6, -16), p + Vector2(-10, -5), a_col, 2.5)
				draw_line(p + Vector2(6, -16),  p + Vector2(10, -5),  a_col, 2.5)
				draw_circle(p + Vector2(0, -26), 8.0, a_col)
				# Large alien eyes
				draw_circle(p + Vector2(-3, -27), 3.0, Color(0.05, 0.05, 0.10))
				draw_circle(p + Vector2(3, -27),  3.0, Color(0.05, 0.05, 0.10))
				draw_circle(p + Vector2(-3, -27), 1.2, Color(0.80, 0.90, 0.20))
				draw_circle(p + Vector2(3, -27),  1.2, Color(0.80, 0.90, 0.20))
				# Head ridges
				for ri2 in 3:
					draw_line(Vector2(p.x - 5 + ri2 * 5, p.y - 34),
						Vector2(p.x - 4 + ri2 * 5, p.y - 30), a_col.darkened(0.30), 1.5)

	# ── Loading vehicles near docking bay ───────────────────────
	var vehicles2 = [
		Vector2(PORT_X + 660, PORT_Y + 680),
		Vector2(PORT_X + 900, PORT_Y + 660),
	]
	for vpos in vehicles2:
		# Shadow
		draw_colored_polygon(_ellipse(vpos + Vector2(6, 12), 42, 12, 0.0, 14), C_SHADOW)
		# Cargo flatbed
		draw_colored_polygon(PackedVector2Array([
			vpos + Vector2(-38, -8), vpos + Vector2(38, -8),
			vpos + Vector2(42, 0),   vpos + Vector2(38, 8),
			vpos + Vector2(-38, 8),
		]), Color(0.55, 0.58, 0.62))
		# Cab
		draw_colored_polygon(PackedVector2Array([
			vpos + Vector2(24, -10), vpos + Vector2(44, -8),
			vpos + Vector2(46, 8),   vpos + Vector2(24, 10),
		]), Color(0.68, 0.70, 0.75))
		# Cab window
		draw_colored_polygon(PackedVector2Array([
			vpos + Vector2(26, -8), vpos + Vector2(42, -6),
			vpos + Vector2(42, 2),  vpos + Vector2(26, 4),
		]), C_TOWER_GLASS)
		# Cargo boxes
		for bi4 in 3:
			draw_rect(Rect2(vpos.x - 30 + bi4 * 22, vpos.y - 14, 18, 14),
				Color(0.70, 0.62, 0.40))
			draw_rect(Rect2(vpos.x - 30 + bi4 * 22, vpos.y - 14, 18, 14),
				Color(0.48, 0.42, 0.28), false, 1.0)
		# Wheels
		for wx3 in [-24.0, 24.0]:
			draw_colored_polygon(_ellipse(vpos + Vector2(wx3, 10), 9, 5, 0.0, 10),
				Color(0.12, 0.12, 0.14))
			draw_colored_polygon(_ellipse(vpos + Vector2(wx3, 10), 5, 3, 0.0, 8),
				Color(0.55, 0.55, 0.58))

# ── NEON SIGNS ────────────────────────────────────────────────

func _draw_neon_signs() -> void:
	# Place neon signs along the southern entertainment strip
	var t = _scene_time
	_draw_neon_sign(
		Vector2(PORT_X + PORT_W * 0.36 + 24, PORT_Y + PORT_H * 0.83 - 38),
		"★ BEST PRICES ★", Color(0.20, 1.00, 0.35), t, 8)
	_draw_neon_sign(
		Vector2(PORT_X + 140, PORT_Y + PORT_H * 0.84 - 48),
		"♦ CANTINA ♦", Color(1.00, 0.20, 0.65), t + 0.4, 12)
	_draw_neon_sign(
		Vector2(PORT_X + 158, PORT_Y + PORT_H * 0.84 - 30),
		"LIVE MUSIC  DRINKS  DANCING", Color(0.85, 0.18, 0.50), t + 1.1, 8)
	_draw_neon_sign(
		Vector2(PORT_X + 330, PORT_Y + PORT_H * 0.84 - 50),
		"★ OPEN ★", Color(0.22, 0.90, 0.55), t + 0.7, 9)
	_draw_neon_sign(
		Vector2(PORT_X + PORT_W * 0.56 + 10, PORT_Y + PORT_H * 0.83 - 36),
		"DANCING GIRLS ♠", Color(1.00, 0.22, 0.65), t + 0.9, 8)
	_draw_neon_sign(
		Vector2(PORT_X + PORT_W * 0.22 + 18, PORT_Y + PORT_H * 0.58 - 36),
		"JOBS  BOARD", Color(0.95, 0.78, 0.10), t + 0.2, 9)
	_draw_neon_sign(
		Vector2(PORT_X + PORT_W * 0.46 - 8, PORT_Y + PORT_H * 0.83 + 128),
		"★  SABACC  ★", Color(0.95, 0.55, 0.08), t + 1.1, 9)
	_draw_neon_sign(
		Vector2(PORT_X + PORT_W * 0.68 + 40, PORT_Y + PORT_H * 0.70 - 38),
		"GRAND HALL", Color(0.75, 0.38, 1.00), t + 0.6, 10)

func _draw_neon_sign(pos: Vector2, text: String, col: Color, t: float, fsize: int) -> void:
	var font   = ThemeDB.fallback_font
	var glow  = 0.60 + sin(t * 2.5) * 0.40
	var txt_w = text.length() * fsize * 0.70 + 16
	# Backing panel
	draw_rect(Rect2(pos.x - 4, pos.y - 4, txt_w, fsize + 12),
		Color(0.04, 0.02, 0.06, 0.88))
	draw_rect(Rect2(pos.x - 4, pos.y - 4, txt_w, fsize + 12),
		Color(col.r, col.g, col.b, 0.18 * glow), false, 1.5)
	# Glow halo (outer)
	draw_rect(Rect2(pos.x - 7, pos.y - 7, txt_w + 6, fsize + 18),
		Color(col.r, col.g, col.b, 0.06 * glow), false, 3.0)
	# Text
	draw_string(font, Vector2(pos.x + 4, pos.y + fsize),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
		Color(col.r, col.g, col.b, 0.65 + glow * 0.35))

func _draw_detailed_streetlight(pos: Vector2) -> void:
	var glow = 0.70 + sin(_scene_time * 1.8 + pos.x * 0.01) * 0.08
	# Base plate
	draw_rect(Rect2(pos.x - 6, pos.y - 4, 12, 4), C_BUILDING_DARK)
	# Pole shaft
	draw_line(Vector2(pos.x, pos.y - 4), Vector2(pos.x, pos.y - 52), C_BUILDING_DARK, 3.0)
	draw_line(Vector2(pos.x + 1, pos.y - 4), Vector2(pos.x + 1, pos.y - 52),
		Color(0.65, 0.65, 0.68, 0.40), 1.0)
	# Decorative band mid-pole
	draw_rect(Rect2(pos.x - 4, pos.y - 32, 8, 5), C_BUILDING_TRIM)
	# Curved arm extending to the right
	draw_line(Vector2(pos.x, pos.y - 52), Vector2(pos.x + 16, pos.y - 58), C_BUILDING_DARK, 2.5)
	draw_line(Vector2(pos.x + 16, pos.y - 58), Vector2(pos.x + 22, pos.y - 54), C_BUILDING_DARK, 2.5)
	# Lantern housing
	draw_rect(Rect2(pos.x + 14, pos.y - 62, 16, 12), Color(0.22, 0.22, 0.26))
	draw_rect(Rect2(pos.x + 15, pos.y - 61, 14, 10), Color(0.16, 0.16, 0.20))
	# Light bulb glow core
	draw_circle(Vector2(pos.x + 22, pos.y - 57), 4.5, Color(1.0, 0.96, 0.72, glow))
	draw_circle(Vector2(pos.x + 22, pos.y - 57), 2.2, Color(1.0, 1.0, 0.92))
	# Glow halo on ground
	draw_colored_polygon(_ellipse(Vector2(pos.x + 22, pos.y - 10), 28, 8, 0.0, 14),
		Color(1.0, 0.95, 0.65, 0.07 * glow))

# ============================================================
#  CHARACTER SELECT  (copied verbatim from BossArenaScene)
# ============================================================
func _show_character_select() -> void:
	_select_layer       = CanvasLayer.new()
	_select_layer.layer = 20
	add_child(_select_layer)

	var vp = get_viewport().get_visible_rect().size

	var bg       = ColorRect.new()
	bg.size      = vp
	bg.color     = Color(0.04, 0.05, 0.12, 0.96)
	_select_layer.add_child(bg)

	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = "CORONET SPACEPORT  —  CHOOSE YOUR CLASS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 55)
	title.position = Vector2(0, vp.y * 0.12)
	_select_layer.add_child(title)

	var hint = Label.new()
	hint.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hint.text = "WASD / Arrow Keys to move  ·  Tab to cycle targets  ·  Auto-attack in range  ·  P for Skills  ·  I for Inventory"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size     = Vector2(vp.x, 24)
	hint.position = Vector2(0, vp.y * 0.12 + 62)
	_select_layer.add_child(hint)

	var classes = [
		{ "key":"brawler",  "label":"BRAWLER",  "color":Color(0.40,0.85,0.30), "desc":"Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px", "locked":false },
		{ "key":"ranged",   "label":"MARKSMAN", "color":Color(0.35,0.80,0.95), "desc":"Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 2.5s\nRange: 700px", "locked":false },
		{ "key":"medic",    "label":"MEDIC",    "color":Color(0.30,0.85,0.90), "desc":"Combat medic.\nHeals allies with\ncanisters, poisons\nenemies.\n\nHP: 220\nAtk every: 3s\nRange: 500px", "locked":false },
		{ "key":"brawler","label":"BRAWLER II","color":Color(0.45,0.90,0.35), "desc":"Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px", "locked":false },
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

	# Welcome label — username set on start screen via PlayerData
	var uname = PlayerData.username if PlayerData.username.length() > 0 else "Adventurer"
	var welcome_lbl = Label.new()
	welcome_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	welcome_lbl.text = "Welcome,  %s  —  choose your class" % uname
	welcome_lbl.add_theme_font_size_override("font_size", 15)
	welcome_lbl.add_theme_color_override("font_color", Color(0.60, 0.85, 1.00))
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
	sty.bg_color   = Color(0.06, 0.07, 0.16, 0.92) if not is_locked else Color(0.08, 0.08, 0.10, 0.80)
	sty.border_color = cls.color if not is_locked else Color(0.30, 0.30, 0.35, 0.60)
	sty.set_border_width_all(2); sty.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sty)
	_select_layer.add_child(panel)

	if is_locked:
		# Big "?" in center of card
		var q_lbl = Label.new()
		q_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		q_lbl.text = "?"
		q_lbl.add_theme_font_size_override("font_size", 72)
		q_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.42, 0.50))
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.size = Vector2(sz.x, sz.y)
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(q_lbl)
		var sub = Label.new()
		sub.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		sub.text = "COMING SOON"
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.40, 0.40, 0.48, 0.50))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(sz.x, 20); sub.position = Vector2(0, sz.y - 36)
		panel.add_child(sub)
		# Return a dummy disabled button
		var dummy_btn = Button.new()
		dummy_btn.visible = false
		dummy_btn.disabled = true
		panel.add_child(dummy_btn)
		return dummy_btn

	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = cls.label
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", cls.color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(sz.x, 36); lbl.position = Vector2(0, 16)
	panel.add_child(lbl)

	var desc = Label.new()
	desc.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	desc.text = cls.desc
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.80, 0.82, 0.88))
	desc.size = Vector2(sz.x - 16, sz.y - 110); desc.position = Vector2(8, 58)
	panel.add_child(desc)

	var btn           = Button.new()
	btn.text          = "PLAY AS " + cls.label
	btn.size          = Vector2(sz.x - 16, 40)
	btn.position      = Vector2(8, sz.y - 50)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", cls.color)
	var bsty          = StyleBoxFlat.new()
	bsty.bg_color     = Color(0.08, 0.06, 0.18)
	bsty.border_color = cls.color
	bsty.set_border_width_all(1); bsty.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", bsty)
	btn.pressed.connect(_on_class_selected.bind(cls.key))
	panel.add_child(btn)
	return btn

func _on_class_selected(cls: String) -> void:
	_pending_nickname = PlayerData.nickname
	_select_layer.queue_free()
	_select_layer = null
	_spawn_player(cls)
	_spawn_shop_terminal()
	_spawn_mission_terminal()
	_spawn_bank_terminal()
	_setup_hud(cls)
	_init_social_systems()
	_spawn_aadu_herds()
	_join_spaceport()

func _init_social_systems() -> void:
	# Options panel
	var op_script   = load("res://Scripts/PlayerOptionsPanel.gd")
	_options_panel  = CanvasLayer.new()
	_options_panel.set_script(op_script)
	add_child(_options_panel)
	_options_panel.call("init")
	_options_panel.connect("duel_requested", func(pid, nick):
		if is_instance_valid(_duel_system): _duel_system.call("request_duel", pid, nick))
	_options_panel.connect("invite_requested", func(pid, nick):
		if is_instance_valid(_party_system): _party_system.call("send_invite", pid, nick))
	_options_panel.connect("trade_requested", func(pid, _nick2):
		# Send request; recipient's show_request panel will accept/decline
		Relay.send_game_data({"cmd": "trade_request", "nick": PlayerData.nickname}, pid))

	# Duel system
	var ds_script  = load("res://Scripts/DuelSystem.gd")
	_duel_system   = Node.new()
	_duel_system.set_script(ds_script)
	add_child(_duel_system)
	_duel_system.call("init", self)

	# Party system (attaches its frame to the existing HUD)
	var ps_script   = load("res://Scripts/PartySystem.gd")
	_party_system   = Node.new()
	_party_system.set_script(ps_script)
	add_child(_party_system)
	_party_system.call("init", self, _hud, 110.0)   # 10 + 100 = 110 px below player frame

	# Trade window
	var tw_script   = load("res://Scripts/TradeWindow.gd")
	_trade_system   = CanvasLayer.new()
	_trade_system.set_script(tw_script)
	add_child(_trade_system)
	_trade_system.call("init", self)

# ── PLAYER SPAWN ──────────────────────────────────────────────
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
		sprite.scale  = Vector2(0.088, 0.088)
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

	if cls == "brawler":
		_attach_split_body_shaders(sprite, _build_frames(cls))

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12.0; shape.height = 20.0
	col.shape = shape
	_player.add_child(col)

	# Spawn inside the spaceport near the south gate
	_player.position = Vector2(PORT_X + PORT_W * 0.5, PORT_Y + PORT_H * 0.88)
	add_child(_player)
	if _pending_nickname.length() > 0:
		_player.set("character_name", _pending_nickname)

func _spawn_shop_terminal() -> void:
	var script   = load("res://Scripts/BossShopTerminal.gd")
	var terminal = Node2D.new()
	terminal.set_script(script)
	# In front of SHOP building entrance (center of front door)
	terminal.position = Vector2(PORT_X + PORT_W * 0.36 + 150, PORT_Y + PORT_H * 0.83 + 70)
	add_child(terminal)

# ── TELEPORTERS ───────────────────────────────────────────────
const SPAWN_POS : Vector2 = Vector2(PORT_X + PORT_W * 0.5, PORT_Y + PORT_H * 0.88)

func _spawn_teleporter_at_player() -> void:
	if not is_instance_valid(_player): return
	var tp_script = load("res://Scripts/SpaceportTeleporter.gd")
	var tp        = Node2D.new()
	tp.set_script(tp_script)
	tp.position   = _player.global_position
	add_child(tp)
	tp.call("init", _player, "tp_player_%d" % randi(), [
		{ "label": "Coronet Spaceport — Main Gate", "pos": SPAWN_POS },
	])

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

# ── SPRITE FRAMES (identical to BossArenaScene) ───────────────
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
		"brawler":
			var bnbase = "res://Characters/NEWFOUNDMETHOD/Brawler/"
			var cw = 768; var ch = 448
			for dir in ["n","e","w","se","sw","nw"]:
				_add_grid(frames,"idle_"+dir, bnbase+"idle/idle_"+dir+".png", cw,ch,4,29,10.0)
			_add_grid(frames,"idle_s", bnbase+"idle/idle_sw.png", cw,ch,4,29,10.0)
			_add_grid(frames,"idle_ne", bnbase+"idle/idle_ne.png", cw,ch,4,28,10.0)
			for dir in ["n","e","ne","se","sw"]:
				_add_grid(frames,"run_"+dir, bnbase+"run/run_"+dir+".png", cw,ch,4,17,20.0)
			for dir in ["w","nw"]:
				_add_grid(frames,"run_"+dir, bnbase+"run/run_"+dir+".png", cw,ch,4,17,18.0,true,true)
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
		push_warning("SpaceportScene: could not load "+path)
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
		push_warning("SpaceportScene: could not load "+path)
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

func _build_cyberlord_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"): frames.remove_animation("default")
	var base = "res://Characters/minimmo/Old/melee2/"
	for dir in ["s","n","e","w"]:
		_add_strip(frames,"idle_"+dir,  base+"idle/idle_"+dir+".png",   144,144,8,7.0)
		_add_strip(frames,"run_"+dir,   base+"run/run_"+dir+".png",    144,144,8,10.0)
		_add_strip(frames,"attack_"+dir,base+"attack/attack_"+dir+".png",144,144,7,12.0,false)
	return frames

func _build_aadu_frames() -> SpriteFrames:
	# All anims are PNG horizontal sprite strips, 160×160 per frame.
	#   idle:          5 frames → 800×160
	#   run/attack/eat/die: 8 frames → 1280×160
	# (Godot 4 has no GIF loader — convert GIFs to PNG strips before importing)
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

# ── AADU HERDS ────────────────────────────────────────────────
func _spawn_aadu_herds() -> void:
	# 1) Editor-placed markers (add AaduHerdMarker nodes as children of spaceport.tscn)
	for child in get_children():
		if child.is_in_group("aadu_herd_marker"):
			var count = randi_range(int(child.get("herd_min")), int(child.get("herd_max")))
			_spawn_aadu_herd(child.global_position,
				count,
				float(child.get("wander_radius")),
				float(child.get("baby_chance")))
	# 2) Procedural fallback herds spread across the open wilderness
	var rng = RandomNumberGenerator.new()
	rng.seed = 77331
	for _i in 14:
		var hx = rng.randf_range(PORT_X + PORT_W + 600.0, WORLD_W - 600.0)
		var hy = rng.randf_range(600.0, WORLD_H - 600.0)
		var count = rng.randi_range(2, 8)
		_spawn_aadu_herd(Vector2(hx, hy), count, rng.randf_range(140.0, 280.0), 0.25)

func _spawn_aadu_herd(center: Vector2, count: int,
		wander_r: float, baby_chance_p: float) -> void:
	var frames = _build_aadu_frames()
	for i in count:
		var angle  = float(i) / float(count) * TAU + randf() * 0.6
		var offset = randf_range(20.0, minf(wander_r * 0.5, 120.0))
		var pos    = center + Vector2(cos(angle), sin(angle)) * offset
		var baby   = (randf() < baby_chance_p)
		_spawn_single_aadu(pos, center, wander_r, baby, frames)

func _spawn_single_aadu(pos: Vector2, herd_center: Vector2,
		wander_r: float, is_baby: bool, frames: SpriteFrames,
		mission_mob: bool = false) -> void:
	var script = load("res://Scripts/Aadu.gd")
	var mob    = CharacterBody2D.new()
	mob.set_script(script)
	mob.set("is_baby",       is_baby)
	mob.set("wander_radius", wander_r)

	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = frames
	var sc = 0.55 if is_baby else 1.0
	sprite.scale  = Vector2(sc, sc)
	sprite.offset = Vector2(0, -48)
	sprite.animation = "idle_s"
	mob.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 18.0 if is_baby else 28.0
	shape.height = 32.0 if is_baby else 52.0
	col.shape    = shape
	mob.add_child(col)

	mob.position        = pos
	mob.collision_layer = 2
	mob.collision_mask  = 2
	add_child(mob)
	# spawn_pos must be set AFTER add_child so global_position is valid
	mob.set("spawn_pos",   herd_center)
	if mission_mob:
		mob.add_to_group("mission_mob")
	mob.tree_exiting.connect(_on_targetable_removed.bind(mob))

func on_aadu_died(xp: float, world_pos: Vector2) -> void:
	if is_instance_valid(_player):
		_player.call("add_exp", xp)
	_share_xp_with_party(xp)
	_check_mission_complete()
	spawn_damage_number(world_pos, 0.0, Color(0.75, 0.90, 0.35))

func _share_xp_with_party(xp: float) -> void:
	if not is_instance_valid(_party_system): return
	if not bool(_party_system.get("in_party")): return
	var members : Array = _party_system.get("members")
	for m in members:
		var pid = int(m.get("peer_id", -1))
		if pid == Relay.my_peer_id or pid == -1: continue
		Relay.send_game_data({"cmd": "party_xp", "amount": xp}, pid)

# ── HUD (Dreadmyst dark-fantasy MMO style) ────────────────────
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
	const PORT  : float = 64.0   # portrait size
	const BAR_X : float = 78.0   # bars start after portrait
	const BAR_W : float = 200.0

	_player_frame          = Panel.new()
	_player_frame.size     = Vector2(PF_W, PF_H)
	_player_frame.position = Vector2(10, 10)
	var pf_sty             = StyleBoxFlat.new()
	pf_sty.bg_color        = Color(0.06, 0.05, 0.04, 0.92)
	pf_sty.border_color    = Color(0.22, 0.18, 0.12, 0.95)
	pf_sty.set_border_width_all(2)
	pf_sty.border_color    = Color(0.35, 0.28, 0.18, 0.90)
	pf_sty.shadow_color    = Color(0.0, 0.0, 0.0, 0.50)
	pf_sty.shadow_size     = 4
	_player_frame.add_theme_stylebox_override("panel", pf_sty)
	_hud.add_child(_player_frame)
	_player_frame.gui_input.connect(_on_frame_drag)

	# Portrait background (dark circle area)
	var port_bg       = ColorRect.new()
	port_bg.color     = Color(0.03, 0.03, 0.03, 1.0)
	port_bg.size      = Vector2(PORT + 4, PORT + 4)
	port_bg.position  = Vector2(5, 5)
	port_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(port_bg)

	# Portrait placeholder (class icon drawn procedurally)
	_portrait_rect          = TextureRect.new()
	_portrait_rect.size     = Vector2(PORT, PORT)
	_portrait_rect.position = Vector2(7, 7)
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_portrait_rect)
	# We'll overlay a class letter on the portrait
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

	# Level badge (bottom-left of portrait)
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
	# Badge background
	var lvl_bg        = ColorRect.new()
	lvl_bg.color      = Color(0.10, 0.08, 0.04, 0.95)
	lvl_bg.size       = Vector2(22, 16)
	lvl_bg.position   = Vector2(7, PORT - 6)
	lvl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(lvl_bg)
	_player_frame.move_child(lvl_bg, _player_frame.get_child_count() - 2)

	# Player name
	_player_name_lbl = Label.new()
	_player_name_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Archivo_Black/ArchivoBlack-Regular.ttf"))
	_player_name_lbl.add_theme_font_size_override("font_size", 13)
	_player_name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
	_player_name_lbl.position = Vector2(BAR_X, 6)
	_player_name_lbl.size     = Vector2(BAR_W, 18)
	_player_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(_player_name_lbl)

	# HP bar (dark red)
	_hp_bar = _make_bar(Color(0.72, 0.14, 0.10), Vector2(BAR_X, 26), Vector2(BAR_W, 18))
	_player_frame.add_child(_hp_bar)
	_hp_bar_lbl = _make_bar_label(Vector2(BAR_X, 26), Vector2(BAR_W, 18))
	_player_frame.add_child(_hp_bar_lbl)

	# MP bar (dark blue)
	_mp_bar = _make_bar(Color(0.15, 0.30, 0.72), Vector2(BAR_X, 48), Vector2(BAR_W, 16))
	_player_frame.add_child(_mp_bar)
	_mp_bar_lbl = _make_bar_label(Vector2(BAR_X, 48), Vector2(BAR_W, 16))
	_player_frame.add_child(_mp_bar_lbl)

	# XP bar (thin gold bar at bottom)
	_xp_bar = _make_bar(Color(0.82, 0.68, 0.15), Vector2(BAR_X, 68), Vector2(BAR_W, 8))
	_player_frame.add_child(_xp_bar)
	_xp_bar_lbl = _make_bar_label(Vector2(BAR_X, 67), Vector2(BAR_W, 10))
	_xp_bar_lbl.add_theme_font_size_override("font_size", 8)
	_player_frame.add_child(_xp_bar_lbl)

	# Percentage overlay on HP bar (right-aligned)
	var hp_pct = Label.new()
	hp_pct.name = "HPPct"
	hp_pct.add_theme_font_override("font", font)
	hp_pct.add_theme_font_size_override("font_size", 10)
	hp_pct.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	hp_pct.size     = Vector2(40, 18)
	hp_pct.position = Vector2(BAR_X + BAR_W - 42, 26)
	hp_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(hp_pct)

	# Top gold accent line on player frame
	var pf_accent        = ColorRect.new()
	pf_accent.color      = Color(0.55, 0.42, 0.18, 0.70)
	pf_accent.size       = Vector2(PF_W - 4, 1)
	pf_accent.position   = Vector2(2, 2)
	pf_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_child(pf_accent)

	# ── Target panel (top-center, Dreadmyst style) ─────────────
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

	# Target red accent line
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

	# ── Minimap (top-right, Dreadmyst style) ───────────────────
	const MMAP_W : float = 180.0
	const MMAP_H : float = 180.0
	const MMAP_X : float = -196.0   # relative to vp.x

	# Location label above minimap
	_mm_location_lbl = Label.new()
	_mm_location_lbl.add_theme_font_override("font", bold)
	_mm_location_lbl.add_theme_font_size_override("font_size", 12)
	_mm_location_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.65))
	_mm_location_lbl.text = "CORONET SPACEPORT"
	_mm_location_lbl.size = Vector2(MMAP_W, 18)
	_mm_location_lbl.position = Vector2(vp.x + MMAP_X, 10)
	_mm_location_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mm_location_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_mm_location_lbl)

	var mm_panel          = Panel.new()
	mm_panel.size         = Vector2(MMAP_W, MMAP_H)
	mm_panel.position     = Vector2(vp.x + MMAP_X, 28)
	var mm_sty            = StyleBoxFlat.new()
	mm_sty.bg_color       = Color(0.02, 0.02, 0.03, 1.0)
	mm_sty.border_color   = Color(0.0, 0.0, 0.0, 1.0)
	mm_sty.set_border_width_all(3)
	mm_sty.set_corner_radius_all(1)
	mm_sty.shadow_color   = Color(0.0, 0.0, 0.0, 0.65)
	mm_sty.shadow_size    = 8
	mm_panel.add_theme_stylebox_override("panel", mm_sty)
	mm_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(mm_panel)

	var mm_script = load("res://Scripts/MinimapDraw.gd")
	_minimap_draw             = mm_script.new()
	_minimap_draw.set("scene_ref", self)
	_minimap_draw.size        = Vector2(MMAP_W, MMAP_H)
	_minimap_draw.position    = Vector2.ZERO
	mm_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mm_panel.add_child(_minimap_draw)

	# Channel label below minimap
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

	# ── Settings & Help windows + buttons below minimap ────────
	var btn_y    : float = 28 + MMAP_H + 22
	var btn_half : float = (MMAP_W - 4) * 0.5

	var help_script = load("res://Scripts/HelpWindow.gd")
	var help_win    = CanvasLayer.new()
	help_win.set_script(help_script)
	add_child(help_win)
	help_win.call("init")
	help_win.call("set_btn_pos", Vector2(vp.x + MMAP_X + btn_half + 4, btn_y))
	help_win.get("_btn").size = Vector2(btn_half, 24)

	var settings_script = load("res://Scripts/SettingsWindow.gd")
	var settings_win    = CanvasLayer.new()
	settings_win.set_script(settings_script)
	add_child(settings_win)
	settings_win.call("init", self)
	settings_win.call("set_btn_pos",  Vector2(vp.x + MMAP_X, btn_y))
	settings_win.call("set_fps_pos",  Vector2(vp.x + MMAP_X, btn_y + 28))
	settings_win.get("_btn").size     = Vector2(btn_half, 24)

	# Mission compass widget (full-viewport overlay, hidden until mission active)
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
	l.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
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
	# Update HP percentage label
	var pct_node = _player_frame.get_node_or_null("HPPct")
	if pct_node: pct_node.text = "%d%%" % hp_pct
	# Target — mob target takes priority; player target shown as fallback
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
			var ptgt_name = ptgt.get("character_name")
			_tgt_name_lbl.text = str(ptgt_name) if ptgt_name != null else "Player_%d" % _player_target_peer
			var php  = float(ptgt.get("hp") if ptgt.get("hp") != null else 100.0)
			var pmhp = float(ptgt.get("max_hp") if ptgt.get("max_hp") != null else 100.0)
			_tgt_hp_bar.max_value = pmhp; _tgt_hp_bar.value = php
			if _tgt_hp_lbl: _tgt_hp_lbl.text = "%d / %d" % [int(php), int(pmhp)]
			var pmp  = float(ptgt.get("mp") if ptgt.get("mp") != null else 100.0)
			var pmmq = float(ptgt.get("max_mp") if ptgt.get("max_mp") != null else 100.0)
			if _tgt_mp_bar: _tgt_mp_bar.visible = true; _tgt_mp_bar.max_value = pmmq; _tgt_mp_bar.value = pmp
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
		var vp = get_viewport().get_visible_rect().size
		np.x   = clampf(np.x, 0.0, vp.x - _player_frame.size.x)
		np.y   = clampf(np.y, 0.0, vp.y - _player_frame.size.y)
		_player_frame.position = np

# ── Damage / effect spawners (called by BossArenaPlayer) ──────
func is_targeted(node: Node) -> bool:
	if not is_instance_valid(_player): return false
	var tgt = _player.get("_current_target")
	return is_instance_valid(tgt) and tgt == node

func spawn_damage_number(world_pos: Vector2, amount: float, col: Color) -> void:
	if amount <= 0.0: return   # skip ghost-projectile hits
	var script = load("res://Scripts/DamageNumber.gd")
	var node   = Node2D.new()
	node.set_script(script)
	node.position = world_pos
	add_child(node)
	node.call("init", amount, col)

func spawn_fireball(spawn_pos: Vector2, target: Node, dmg: float, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/Fireball.gd")
	var fb     = Node2D.new()
	fb.set_script(script)
	fb.position = spawn_pos
	add_child(fb)
	fb.call("init", target, dmg)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({
			"cmd": "fireball",
			"sx": spawn_pos.x, "sy": spawn_pos.y,
			"tx": target.global_position.x, "ty": target.global_position.y,
		})

func spawn_bullet(spawn_pos: Vector2, target: Node, dmg: float, _broadcast: bool = true) -> Node:
	var script = load("res://Scripts/Bullet.gd")
	var b      = Node2D.new()
	b.set_script(script)
	b.position = spawn_pos
	add_child(b)
	b.call("init", target, dmg)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({
			"cmd": "bullet",
			"sx": spawn_pos.x, "sy": spawn_pos.y,
			"tx": target.global_position.x, "ty": target.global_position.y,
		})
	return b

func spawn_canister(spawn_pos: Vector2, target: Node, dmg: float, is_heal: bool, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/MedicCanister.gd")
	var c      = Node2D.new()
	c.set_script(script)
	c.position = spawn_pos
	add_child(c)
	c.call("init", target, dmg, is_heal)
	if _broadcast and Relay.connected and is_instance_valid(target):
		Relay.send_game_data({
			"cmd": "canister",
			"sx": spawn_pos.x, "sy": spawn_pos.y,
			"tx": target.global_position.x, "ty": target.global_position.y,
			"heal": is_heal,
		})

func spawn_melee_hit(world_pos: Vector2, col: Color, _broadcast: bool = true) -> void:
	var script = load("res://Scripts/MeleeHit.gd")
	var hit    = Node2D.new()
	hit.set_script(script)
	hit.position = world_pos
	add_child(hit)
	hit.call("init", col)
	if _broadcast and Relay.connected:
		Relay.send_game_data({
			"cmd": "melee_hit",
			"x": world_pos.x, "y": world_pos.y,
			"r": col.r, "g": col.g, "b": col.b,
		})

func _on_targetable_removed(_node: Node) -> void:
	pass   # clean up target ref if needed

# ── MISSION SYSTEM ─────────────────────────────────────────────
func _spawn_mission_terminal() -> void:
	var script   = load("res://Scripts/MissionTerminal.gd")
	var terminal = Node2D.new()
	terminal.set_script(script)
	# In front of JOBS building entrance (center of front door)
	terminal.position = Vector2(PORT_X + PORT_W * 0.22 + 130, PORT_Y + PORT_H * 0.58 + 65)
	_mission_terminal_pos = terminal.position
	add_child(terminal)

func _spawn_bank_terminal() -> void:
	var script   = load("res://Scripts/BankTerminal.gd")
	var terminal = Node2D.new()
	terminal.set_script(script)
	# In front of BANK (Palace) entrance — py = PORT_H*0.55+100, front face bottom = py+300
	terminal.position = Vector2(PORT_X + PORT_W * 0.58 + 270, PORT_Y + PORT_H * 0.55 + 420)
	add_child(terminal)

func start_mission(data: Dictionary) -> void:
	_mission_active  = true
	_mission_name    = data.get("name", "Zerg Extermination")
	_mission_payout  = data.get("payout", 10)
	_mission_type    = data.get("type",   "zerg")
	# Pick a spawn point far from the terminal
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var spawn_pos = Vector2.ZERO
	for _attempt in 30:
		var tx = rng.randf_range(PORT_X + 200, PORT_X + PORT_W - 200)
		var ty = rng.randf_range(PORT_Y + 200, PORT_Y + PORT_H - 200)
		var candidate = Vector2(tx, ty)
		if candidate.distance_to(_mission_terminal_pos) >= 2000.0:
			spawn_pos = candidate; break
	if spawn_pos == Vector2.ZERO:
		spawn_pos = Vector2(PORT_X + PORT_W * 0.5, PORT_Y + PORT_H * 0.3)
	_mission_target_pos = spawn_pos
	if _mission_type == "aadu":
		# Spawn 8–12 Aadu as mission targets, no lair
		var count = randi_range(8, 12)
		var frames = _build_aadu_frames()
		for i in count:
			var angle = float(i) / float(count) * TAU + randf() * 0.5
			var dist  = randf_range(60.0, 180.0)
			var pos   = spawn_pos + Vector2(cos(angle), sin(angle)) * dist
			_spawn_single_aadu(pos, spawn_pos, 150.0, false, frames, true)
	else:
		# Zerg: 10 mobs + 1 lair
		for i in 10:
			var angle = float(i) / 10.0 * TAU + randf() * 0.4
			var dist  = randf_range(80.0, 200.0)
			_spawn_mission_zerg_mob(spawn_pos + Vector2(cos(angle), sin(angle)) * dist)
		_spawn_mission_lair(spawn_pos)
	# Show compass
	if _mission_compass:
		_mission_compass.set("_target_world", _mission_target_pos)
		_mission_compass.set("_player", _player)
		_mission_compass.visible = true

func on_mob_died(world_pos: Vector2) -> void:
	spawn_damage_number(world_pos, 0.0, Color(1, 0.3, 0.3))
	_check_mission_complete()

func on_mob_dropped_loot(world_pos: Vector2) -> void:
	var script = load("res://Scripts/LootBag.gd")
	var bag    = Node2D.new()
	bag.set_script(script)
	bag.position = world_pos
	add_child(bag)

func share_loot_with_party(item: Dictionary, credits: int) -> void:
	if not is_instance_valid(_party_system): return
	if not bool(_party_system.get("in_party")): return
	var members : Array = _party_system.get("members")
	for m in members:
		var pid = int(m.get("peer_id", -1))
		if pid == Relay.my_peer_id or pid == -1: continue
		Relay.send_game_data({"cmd": "party_loot", "item": item, "credits": credits}, pid)

func on_lair_died(lair_pos: Vector2) -> void:
	spawn_damage_number(lair_pos, 0.0, Color(1, 0.6, 0.1))
	_check_mission_complete()

func _spawn_mission_zerg_mob(world_pos: Vector2) -> void:
	var script = load("res://Scripts/ZergMob.gd")
	var mob    = CharacterBody2D.new()
	mob.set_script(script)

	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_boss_frames()
	sprite.scale         = Vector2(1.0, 1.0)
	sprite.offset        = Vector2(0, -33)
	mob.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 26.0; shape.height = 45.0
	col.shape    = shape
	mob.add_child(col)

	mob.position        = world_pos
	mob.collision_layer = 2
	mob.collision_mask  = 2
	add_child(mob)
	mob.add_to_group("mission_mob")
	mob.tree_exiting.connect(_on_targetable_removed.bind(mob))

func _spawn_mission_lair(world_pos: Vector2) -> void:
	var script = load("res://Scripts/ZergLair.gd")
	var lair   = Node2D.new()
	lair.set_script(script)
	lair.position = world_pos
	add_child(lair)

func _check_mission_complete() -> void:
	if not _mission_active: return
	if get_tree().get_nodes_in_group("mission_mob").size() > 0: return
	if get_tree().get_nodes_in_group("mission_lair").size() > 0: return
	_mission_active = false
	if _mission_compass:
		_mission_compass.visible = false
	# Award credits and XP
	if is_instance_valid(_player):
		var cur_credits = int(_player.get("credits")) if _player.get("credits") != null else 0
		_player.set("credits", cur_credits + _mission_payout)
		_player.call("add_exp", 250.0)
	_share_xp_with_party(250.0)
	_show_mission_complete()

func _show_mission_complete() -> void:
	var cl = CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.set_script(_mission_complete_label_script(_mission_payout))
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.15))
	var vp = get_viewport().get_visible_rect().size
	lbl.size     = Vector2(vp.x, 60)
	lbl.position = Vector2(0, vp.y * 0.38)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(lbl)

func _update_mission_compass() -> void:
	if not _mission_compass or not is_instance_valid(_mission_compass): return
	if not _mission_active:
		_mission_compass.visible = false
		return
	if is_instance_valid(_player):
		_mission_compass.set("_target_world", _mission_target_pos)
		_mission_compass.set("_player", _player)

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
	# compute target screen position manually (Camera2D has no unproject_position)
	var zoom    = cam.zoom
	var cam_pos = cam.global_position
	var rel     = (_target_world - cam_pos) * zoom + vp * 0.5
	var dist_m  = int(_player.global_position.distance_to(_target_world) / 10.0)
	var angle   = pscreen.direction_to(rel).angle()
	# Edge clamp — position arrow on screen edge
	var margin  = 48.0
	var edge    = Vector2(
		clampf(rel.x, margin, vp.x - margin),
		clampf(rel.y, margin, vp.y - margin)
	)
	if rel.x >= margin and rel.x <= vp.x - margin and rel.y >= margin and rel.y <= vp.y - margin:
		# Target is on-screen — no arrow needed
		return
	# Draw arrow
	var pulse = 0.75 + sin(_t * 4.0) * 0.25
	draw_set_transform(edge, angle + PI * 0.5, Vector2.ONE)
	var tip = Vector2(0, -14)
	var bl  = Vector2(-8,  6)
	var br  = Vector2( 8,  6)
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), Color(0.95, 0.82, 0.10, pulse))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Label
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

# ── Ellipse helper ─────────────────────────────────────────────
func _ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts   = PackedVector2Array()
	var cos_r = cos(rot); var sin_r = sin(rot)
	for i in n:
		var a  = float(i) / float(n) * TAU
		var lx = cos(a) * rx; var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cos_r - ly * sin_r, lx * sin_r + ly * cos_r))
	return pts

# Zoom-compensated text — rasterizes at screen-pixel resolution so labels stay crisp
func _draw_label(font: Font, pos: Vector2, text: String, sz: int, col: Color) -> void:
	var ct_sc = get_canvas_transform().get_scale()
	var inv = Vector2(1.0 / ct_sc.x, 1.0 / ct_sc.y)
	var rend_sz = maxi(1, int(round(sz * ct_sc.x)))
	draw_set_transform(pos, 0.0, inv)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, rend_sz, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ============================================================
#  MULTIPLAYER
# ============================================================
func _join_spaceport() -> void:
	if not Relay.connected: return
	if not Relay.server_list_received.is_connected(_on_server_list):
		Relay.server_list_received.connect(_on_server_list)
	if not Relay.relay_error.is_connected(_on_spaceport_relay_error):
		Relay.relay_error.connect(_on_spaceport_relay_error)
	Relay.fetch_server_list()

func _on_server_list(rooms: Array) -> void:
	if Relay.server_list_received.is_connected(_on_server_list):
		Relay.server_list_received.disconnect(_on_server_list)
	for room in rooms:
		if str(room.get("name", "")) == "MINISWG-SPACEPORT":
			# Relay server may return "id" or "roomId"
			var rid = str(room.get("id", room.get("roomId", "")))
			if rid != "":
				Relay.join_room(rid)
				return
	# No room found — host one so others can join
	Relay.host_game("MINISWG-SPACEPORT", 64)

func _on_spaceport_relay_error(msg: String) -> void:
	if msg == "Room not found":
		Relay.host_game("MINISWG-SPACEPORT", 64)
	elif msg == "Room full":
		_join_spaceport()

func _on_relay_data(from_peer: int, data: Dictionary) -> void:
	if from_peer == Relay.my_peer_id: return
	match data.get("cmd", ""):
		"move":
			var x           = float(data.get("x",    0.0))
			var y           = float(data.get("y",    0.0))
			var cls         = str(data.get("class",  "melee"))
			var nick        = str(data.get("nick",   "Player_%d" % from_peer))
			var mounted     = bool(data.get("mounted",      false))
			var mount_angle = float(data.get("mount_angle", 0.0))
			var mount_type  = str(data.get("mount_type",    "fighter"))
			if not _remote_players.has(from_peer):
				_add_remote_player(from_peer, cls, Vector2(x, y), nick)
			else:
				# Sync hp/max_hp on existing proxy
				var rp_mv = _remote_players[from_peer]
				if is_instance_valid(rp_mv):
					var rhp = data.get("hp");     if rhp != null: rp_mv.set("hp",     float(rhp))
					var rmhp = data.get("max_hp"); if rmhp != null: rp_mv.set("max_hp", float(rmhp))
			_update_remote_player(from_peer, Vector2(x, y), mounted, mount_angle, mount_type)
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
		"swing":
			var rp2 = _remote_players.get(from_peer)
			if not is_instance_valid(rp2): return
			var sw_script = load("res://Scripts/BossWeaponSwing.gd")
			var sw = Node2D.new(); sw.set_script(sw_script)
			sw.position = Vector2(0, -15)
			rp2.add_child(sw)
			var sw_item = {"type": str(data.get("itype", "knife")), "rarity": str(data.get("rarity", "white"))}
			sw.call("init", sw_item, str(data.get("facing", "s")))
		"death":
			_remove_remote_player(from_peer)
		"chat":
			var nick = str(data.get("nick", "Player_%d" % from_peer))
			var msg  = str(data.get("msg",  ""))
			if msg.length() == 0: return
			var rp = _remote_players.get(from_peer)
			if is_instance_valid(rp):
				_show_remote_bubble(rp, nick, msg)
			_add_to_chat_log(nick, msg)
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
					var tn = rp3.get("character_name")
					if tn != null: tnick = str(tn)
				_trade_system.call("open_trade", from_peer, tnick)
		"trade_decline":
			pass   # TradeWindow handles its own cancel flow
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
		# ── Creature sync ────────────────────────────────────────
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

func _on_peer_left(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	if is_instance_valid(_party_system):
		_party_system.call("on_peer_disconnected", peer_id)
	if _player_target_peer == peer_id:
		_player_target_peer = -1

func _add_remote_player(peer_id: int, cls: String, pos: Vector2, nick: String) -> void:
	var proxy_script = load("res://Scripts/RemotePlayerProxy.gd")
	var rp           = Node2D.new()
	rp.set_script(proxy_script)
	rp.position = pos
	rp.set_meta("target_pos", pos)
	rp.set_meta("last_dir", "s")
	rp.set_meta("mounted", false)
	rp.set("character_name", nick)
	rp.set("hp",     100.0)
	rp.set("max_hp", 100.0)

	var valid_cls = cls if ["melee", "ranged", "mage", "brawler", "medic"].has(cls) else "melee"
	rp.set_meta("cls", valid_cls)
	var sprite    = AnimatedSprite2D.new()
	sprite.name   = "Sprite"
	sprite.sprite_frames = _build_frames(valid_cls)
	if valid_cls == "melee":
		sprite.scale  = Vector2(44.0 / 160.0, 44.0 / 160.0)
		sprite.offset = Vector2(0, -80)
	elif valid_cls == "brawler":
		sprite.scale  = Vector2(0.088, 0.088)
		sprite.offset = Vector2(0, -121)
	elif valid_cls == "medic":
		sprite.scale  = Vector2(44.0 / 144.0, 44.0 / 144.0)
		sprite.offset = Vector2(0, -72)
	elif valid_cls == "ranged":
		sprite.offset = Vector2(0, -16)
	else:
		sprite.offset = Vector2(0, -12)
	sprite.animation = "idle_s"
	sprite.play()
	rp.add_child(sprite)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = nick
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.92, 1.00))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size         = Vector2(120, 16)
	lbl.position     = Vector2(-60, -52)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.add_child(lbl)

	add_child(rp)
	_remote_players[peer_id] = rp

func _update_remote_player(peer_id: int, pos: Vector2,
		mounted: bool = false, mount_angle: float = 0.0, mount_type: String = "fighter") -> void:
	var rp = _remote_players.get(peer_id)
	if not is_instance_valid(rp): return
	var old_target = rp.get_meta("target_pos") as Vector2
	rp.set_meta("target_pos", pos)

	# ── Mount state ───────────────────────────────────────────
	var was_mounted = rp.get_meta("mounted", false) as bool
	if mounted != was_mounted:
		rp.set_meta("mounted", mounted)
		var sp = rp.get_node_or_null("Sprite") as AnimatedSprite2D
		if sp: sp.visible = not mounted
		var old_veh = rp.get_node_or_null("VehicleVis")
		if old_veh: old_veh.queue_free()
		if mounted:
			_spawn_remote_vehicle(rp, mount_type, mount_angle)
	elif mounted:
		var veh = rp.get_node_or_null("VehicleVis")
		if veh: veh.set("angle", mount_angle)

	# ── Walk/run animation (only when not mounted) ────────────
	if mounted: return
	var sprite = rp.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null: return
	var diff   = pos - old_target
	var moving = diff.length() > 3.0
	var dir    = rp.get_meta("last_dir", "s") as String
	var remote_cls = rp.get_meta("cls", "melee") as String
	if moving:
		if remote_cls in ["melee", "brawler", "medic"]:
			# 8-directional
			var angle = diff.angle()
			var deg   = fmod(rad_to_deg(angle) + 360.0 + 22.5, 360.0)
			match int(deg / 45.0):
				0: dir = "e"
				1: dir = "se"
				2: dir = "s"
				3: dir = "sw"
				4: dir = "w"
				5: dir = "nw"
				6: dir = "n"
				7: dir = "ne"
				_: dir = "s"
		else:
			if abs(diff.x) > abs(diff.y):
				dir = "e" if diff.x > 0 else "w"
			else:
				dir = "s" if diff.y > 0 else "n"
		rp.set_meta("last_dir", dir)
	var anim = ("run_" if moving else "idle_") + dir
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.animation = anim
		sprite.play()
	# Brawler lean — 10° forward tilt when running east/west
	if remote_cls == "brawler" and moving and dir in ["e", "w"]:
		sprite.rotation = deg_to_rad(10.0) if dir == "e" else deg_to_rad(-10.0)
	else:
		sprite.rotation = 0.0

func _show_remote_bubble(parent: Node2D, nick: String, msg: String) -> void:
	var old = parent.get_node_or_null("ChatBubble")
	if old: old.queue_free()
	var bubble = Node2D.new()
	bubble.name = "ChatBubble"
	parent.add_child(bubble)
	var full_msg  = "%s: %s" % [nick, msg]
	var max_chars = 28
	var font_sz   = 12
	var char_w    = font_sz * 0.62
	var line_h    = font_sz + 4
	var pad_x = 8; var pad_y = 6
	var words = full_msg.split(" ")
	var lines : Array = []; var cur = ""
	for word in words:
		var candidate = (cur + " " + word).strip_edges()
		if candidate.length() > max_chars and cur.length() > 0:
			lines.append(cur); cur = word
		else:
			cur = candidate
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
		lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
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

func _spawn_remote_vehicle(parent: Node2D, mount_type: String, mount_angle: float) -> void:
	var veh = Node2D.new()
	veh.name = "VehicleVis"
	veh.set_script(load("res://Scripts/RemoteVehicle.gd"))
	veh.set("variant", mount_type)
	veh.set("angle",   mount_angle)
	parent.add_child(veh)

func _remove_remote_player(peer_id: int) -> void:
	if _remote_players.has(peer_id):
		var rp = _remote_players[peer_id]
		if is_instance_valid(rp):
			rp.queue_free()
		_remote_players.erase(peer_id)
