extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  BossArenaScene.gd — Beyond the Veil | Boss Arena
#  Attach this to a bare Node2D scene (boss_arena.tscn).
#  No child nodes needed — everything is built in code.
#
#  BACKGROUND TEXTURE:
#    When you add your tileset image to the project, drop it at
#    res://Assets/Backgrounds/sand_floor.png and uncomment the
#    texture lines in _draw(). Until then, a procedural sandy
#    desert background is drawn automatically.
#
#  CONTROLS:
#    Arrow keys / WASD  — move
#    Tab                — cycle target
#    Auto-attack fires  — when target is in range
# ============================================================

# ── WORLD ─────────────────────────────────────────────────────
const WORLD_W = 7680.0
const WORLD_H = 4320.0

# ── SANDY BACKGROUND PALETTE ──────────────────────────────────
# Matches the uploaded desert tileset aesthetic
const C_SAND_BASE   = Color(0.76, 0.52, 0.18)
const C_SAND_STRIPE = Color(0.60, 0.40, 0.12)
const C_PEBBLE      = Color(0.74, 0.74, 0.76, 0.92)
const C_PEBBLE_SHD  = Color(0.00, 0.00, 0.00, 0.18)
const PEBBLE_COUNT  = 480

var _pebbles : Array = []

# ── SCENE NODES ───────────────────────────────────────────────
var _camera       : Camera2D    = null
var _player       : Node        = null
var _boss         : Node        = null
var _select_layer : CanvasLayer = null
var _hud          : CanvasLayer = null

# ── AMBIENT EFFECT TIMERS ─────────────────────────────────────
var _tumbleweed_timer : float = 6.0    # first one appears after a short wait
var _wind_timer       : float = 2.5

# ── CAMERA ZOOM ───────────────────────────────────────────────
var _cam_zoom_base : float = 1.1   # player-controlled via scroll wheel
var _cam_zoom_target : float = 1.1

# ── BOSS CINEMATIC ────────────────────────────────────────────
const CIN_SLIDE_IN  : float = 0.35
const CIN_HOLD      : float = 1.80
const CIN_SLIDE_OUT : float = 0.35
const CIN_TOTAL     : float = CIN_SLIDE_IN + CIN_HOLD + CIN_SLIDE_OUT
var _cinematic_t    : float = -1.0   # -1 = inactive

# ── NICKNAME FILTER ───────────────────────────────────────────
const BAD_WORDS : Array = [
	"ass", "asshole", "bastard", "bitch", "cock", "cunt", "damn",
	"dick", "douche", "fuck", "homo", "jackass", "jerk", "moron",
	"nigga", "nigger", "piss", "prick", "pussy", "shit", "slut",
	"twat", "whore",
]

func _contains_bad_word(text: String) -> bool:
	for w in BAD_WORDS:
		if text.find(w) >= 0:
			return true
	return false

# ── HUD REFS ──────────────────────────────────────────────────
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
var _player_frame     : Panel       = null
var _frame_drag       : bool        = false
var _pending_nickname : String      = ""

# ── MUSIC ─────────────────────────────────────────────────────
var _music : AudioStreamPlayer = null

# ── MISSION STATE ─────────────────────────────────────────────
var _mission_active       : bool    = false
var _mission_name         : String  = ""
var _mission_payout       : int     = 0
var _mission_target_pos   : Vector2 = Vector2.ZERO
var _mission_terminal_pos : Vector2 = Vector2.ZERO
var _mission_compass      : Control = null

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("ui_layer")          # TrainingDummy checks this group for is_targeted()
	add_to_group("boss_arena_scene")  # lets BossArenaPlayer find us for damage numbers
	_gen_pebbles()
	_setup_camera()
	_start_music()
	_show_character_select()

func _start_music() -> void:
	var stream = load("res://Sounds/Music/music_battle.mp3") as AudioStream
	if stream == null:
		return
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -6.0
	_music.bus = "Master"
	add_child(_music)
	_music.play()

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	_cam_zoom_base = lerpf(_cam_zoom_base, _cam_zoom_target, 1.0 - exp(-8.0 * delta))
	_camera.zoom = Vector2.ONE * _cam_zoom_base
	if is_instance_valid(_player):
		_camera.global_position = _player.global_position
	_tick_cinematic(delta)
	_update_hud()
	_tick_ambient(delta)
	_update_mission_compass()

func _tick_cinematic(delta: float) -> void:
	if _cinematic_t < 0.0:
		_camera.zoom = Vector2.ONE * _cam_zoom_base
		return
	_cinematic_t += delta
	var zoom_extra : float = 0.0
	if _cinematic_t < CIN_SLIDE_IN:
		zoom_extra = lerpf(0.0, 0.22, _cinematic_t / CIN_SLIDE_IN)
	elif _cinematic_t < CIN_SLIDE_IN + CIN_HOLD:
		zoom_extra = 0.22
	elif _cinematic_t < CIN_TOTAL:
		zoom_extra = lerpf(0.22, 0.0, (_cinematic_t - CIN_SLIDE_IN - CIN_HOLD) / CIN_SLIDE_OUT)
	else:
		_cinematic_t = -1.0
	_camera.zoom = Vector2.ONE * (_cam_zoom_base + zoom_extra)

func _tick_ambient(delta: float) -> void:
	# Tumbleweeds — roll across the map every ~10 seconds
	_tumbleweed_timer -= delta
	if _tumbleweed_timer <= 0.0:
		_tumbleweed_timer = randf_range(20.0, 32.0)
		_spawn_tumbleweed()

	# Wind gusts — appear near the player every ~6 seconds
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_wind_timer = randf_range(4.5, 8.0)
		if is_instance_valid(_player):
			_spawn_wind()

func _spawn_tumbleweed() -> void:
	# Only one tumbleweed on screen at a time
	if get_tree().get_nodes_in_group("tumbleweed").size() > 0:
		_tumbleweed_timer = randf_range(5.0, 8.0)   # check again soon
		return

	var script = load("res://Scripts/Tumbleweed.gd")
	var tw = Node2D.new()
	tw.set_script(script)
	add_child(tw)

	var edge  = randi() % 4   # 0=left, 1=right, 2=top, 3=bottom
	var start : Vector2
	var dir   : Vector2
	match edge:
		0: start = Vector2(-60, randf_range(100, WORLD_H - 100)); dir = Vector2(1, randf_range(-0.3, 0.3))
		1: start = Vector2(WORLD_W + 60, randf_range(100, WORLD_H - 100)); dir = Vector2(-1, randf_range(-0.3, 0.3))
		2: start = Vector2(randf_range(100, WORLD_W - 100), -60); dir = Vector2(randf_range(-0.3, 0.3), 1)
		3: start = Vector2(randf_range(100, WORLD_W - 100), WORLD_H + 60); dir = Vector2(randf_range(-0.3, 0.3), -1)
	var radius = randf_range(10.0, 18.0)
	tw.call("init", start, dir, radius)

func _spawn_wind() -> void:
	var script = load("res://Scripts/WindEffect.gd")
	var we = Node2D.new()
	we.set_script(script)
	# Spawn at the left edge of the visible viewport so lines sweep across the screen
	var vp_size  = get_viewport().get_visible_rect().size
	var zoom     = _camera.zoom
	var cam_pos  = _camera.global_position
	var half_w   = (vp_size.x / zoom.x) * 0.5
	var half_h   = (vp_size.y / zoom.y) * 0.5
	var left_x   = cam_pos.x - half_w - 10.0   # just off the left edge
	var rand_y   = cam_pos.y + randf_range(-half_h * 0.80, half_h * 0.80)
	we.global_position = Vector2(left_x, rand_y)
	add_child(we)
	we.call("init")

# ── DRAW — procedural sandy desert background ─────────────────
func _draw() -> void:
	# ── Swap in your tileset texture here when ready: ──────────
	# var tex = preload("res://Assets/Backgrounds/sand_floor.png")
	# draw_texture_rect(tex, Rect2(0, 0, WORLD_W, WORLD_H), true)
	# return
	# ───────────────────────────────────────────────────────────

	# Base fill
	draw_rect(Rect2(0, 0, WORLD_W, WORLD_H), C_SAND_BASE)

	# Diagonal hatching lines (mimics the tileset texture pattern)
	var stripe_col = Color(C_SAND_STRIPE.r, C_SAND_STRIPE.g, C_SAND_STRIPE.b, 0.20)
	var step := 30.0
	var x    := 0.0
	while x < WORLD_W + WORLD_H:
		draw_line(Vector2(x, 0), Vector2(x - WORLD_H, WORLD_H), stripe_col, 1.2)
		x += step

	# Pebbles — shadow first, then stone on top
	for p in _pebbles:
		var shd = _ellipse_pts(p.pos + Vector2(1.5, 3.0), p.rx * 0.85, p.ry * 0.5, p.rot, 10)
		draw_colored_polygon(shd, C_PEBBLE_SHD)
		var pts = _ellipse_pts(p.pos, p.rx, p.ry, p.rot, 10)
		draw_colored_polygon(pts, C_PEBBLE)
		# Tiny highlight on upper-left of each pebble
		var hi = _ellipse_pts(p.pos + Vector2(-p.rx * 0.25, -p.ry * 0.25), p.rx * 0.3, p.ry * 0.3, p.rot, 8)
		draw_colored_polygon(hi, Color(1.0, 1.0, 1.0, 0.18))

func _ellipse_pts(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cos_r = cos(rot)
	var sin_r = sin(rot)
	for i in n:
		var a  = float(i) / float(n) * TAU
		var lx = cos(a) * rx
		var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cos_r - ly * sin_r, lx * sin_r + ly * cos_r))
	return pts

func _gen_pebbles() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in PEBBLE_COUNT:
		_pebbles.append({
			"pos": Vector2(rng.randf_range(30, WORLD_W - 30), rng.randf_range(30, WORLD_H - 30)),
			"rx":  rng.randf_range(5.0, 12.0),
			"ry":  rng.randf_range(3.5, 7.5),
			"rot": rng.randf() * TAU,
		})

# ── CAMERA ────────────────────────────────────────────────────
func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position    = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	_camera.zoom        = Vector2(1.1, 1.1)
	_camera.limit_left  = 0
	_camera.limit_top   = 0
	_camera.limit_right = int(WORLD_W)
	_camera.limit_bottom = int(WORLD_H)
	add_child(_camera)
	_camera.make_current()

# ============================================================
#  CHARACTER SELECT
# ============================================================
func _show_character_select() -> void:
	_select_layer = CanvasLayer.new()
	_select_layer.layer = 20
	add_child(_select_layer)

	var vp = get_viewport().get_visible_rect().size

	# Dark overlay
	var bg = ColorRect.new()
	bg.size  = vp
	bg.color = Color(0.04, 0.02, 0.07, 0.95)
	_select_layer.add_child(bg)

	# Title
	var title = Label.new()
	title.text = "CHOOSE YOUR CLASS"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(vp.x, 60)
	title.position = Vector2(0, vp.y * 0.14)
	_select_layer.add_child(title)

	var hint = Label.new()
	hint.text = "Tab to cycle targets  ·  Move with Arrow Keys / WASD  ·  Auto-attack when in range"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size     = Vector2(vp.x, 28)
	hint.position = Vector2(0, vp.y * 0.14 + 68)
	_select_layer.add_child(hint)

	# Class card data
	var classes = [
		{
			"key":   "melee",
			"label": "MELEE",
			"color": Color(0.90, 0.35, 0.20),
			"desc":  "Close-range brawler.\nGets in your face\nand hits hard.\n\nHP: 300\nAtk every: 2s\nRange: 130px",
		},
		{
			"key":   "ranged",
			"label": "RANGED",
			"color": Color(0.35, 0.80, 0.95),
			"desc":  "Long-range marksman.\nKeep your distance\nand chip away.\n\nHP: 180\nAtk every: 4s\nRange: 700px",
		},
		{
			"key":   "mage",
			"label": "MAGE",
			"color": Color(0.75, 0.42, 1.00),
			"desc":  "Arcane spellcaster.\nHigh damage, low HP.\nStay far back.\n\nHP: 150\nAtk every: 4s\nRange: 400px",
		},
		{
			"key":   "scrapper",
			"label": "BRAWLER",
			"color": Color(0.40, 0.85, 0.30),
			"desc":  "Heavyweight bruiser.\nAbsorbs punishment\nand hits harder.\n\nHP: 350\nAtk every: 2s\nRange: 130px",
		},
	]

	var card_w  = 210.0
	var card_h  = 300.0
	var gap     = 48.0
	var total_w = card_w * classes.size() + gap * (classes.size() - 1)
	var start_x = (vp.x - total_w) * 0.5
	var card_y  = vp.y * 0.33

	var select_buttons : Array = []
	for i in classes.size():
		var b = _build_class_card(classes[i], Vector2(start_x + i * (card_w + gap), card_y), Vector2(card_w, card_h))
		b.disabled = true
		select_buttons.append(b)

	# ── Nickname field ─────────────────────────────────────────
	var nick_bg = ColorRect.new()
	nick_bg.name     = "NickBg"
	nick_bg.color    = Color(0.06, 0.04, 0.10, 0.90)
	nick_bg.size     = Vector2(340, 50)
	nick_bg.position = Vector2(vp.x * 0.5 - 170, card_y + card_h + 22.0)
	_select_layer.add_child(nick_bg)

	var nick_border = ColorRect.new()
	nick_border.color    = Color(0.35, 0.55, 0.90, 0.55)
	nick_border.size     = Vector2(340, 1)
	nick_border.position = Vector2.ZERO
	nick_bg.add_child(nick_border)

	var nick_lbl = Label.new()
	nick_lbl.text = "NICKNAME:"
	nick_lbl.add_theme_font_size_override("font_size", 13)
	nick_lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 1.0))
	nick_lbl.position = Vector2(10, 13)
	nick_lbl.size     = Vector2(105, 24)
	nick_bg.add_child(nick_lbl)

	var nick_field = LineEdit.new()
	nick_field.name             = "NickField"
	nick_field.max_length       = 20
	nick_field.placeholder_text = "enter nickname..."
	nick_field.position = Vector2(118, 7)
	nick_field.size     = Vector2(212, 36)
	nick_field.add_theme_font_size_override("font_size", 14)
	nick_field.add_theme_color_override("font_color", Color(1, 1, 1))
	nick_field.add_theme_color_override("font_placeholder_color", Color(0.4, 0.4, 0.45))
	var nick_sty = StyleBoxFlat.new()
	nick_sty.bg_color     = Color(0.08, 0.06, 0.14)
	nick_sty.border_color = Color(0.35, 0.55, 0.90, 0.60)
	nick_sty.set_border_width_all(1)
	nick_field.add_theme_stylebox_override("normal", nick_sty)
	nick_field.add_theme_stylebox_override("focus",  nick_sty)
	nick_bg.add_child(nick_field)

	# Pre-fill saved nickname
	var cfg = ConfigFile.new()
	if cfg.load("user://player_prefs.cfg") == OK:
		var saved = cfg.get_value("player", "nickname", "")
		if saved.length() > 0 and not _contains_bad_word(saved.to_lower()):
			nick_field.text = saved
			for b in select_buttons: b.disabled = false

	var nick_hint = Label.new()
	nick_hint.name = "NickHint"
	nick_hint.text = "Enter a nickname to continue."
	nick_hint.add_theme_font_size_override("font_size", 11)
	nick_hint.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	nick_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_hint.size         = Vector2(vp.x, 18)
	nick_hint.position     = Vector2(0, card_y + card_h + 76.0)
	nick_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_select_layer.add_child(nick_hint)

	nick_field.text_changed.connect(func(text: String) -> void:
		var clean = text.strip_edges()
		if clean.length() == 0:
			nick_hint.text = "Enter a nickname to continue."
			for b in select_buttons: b.disabled = true
		elif _contains_bad_word(clean.to_lower()):
			nick_hint.text = "That nickname is not allowed."
			for b in select_buttons: b.disabled = true
		else:
			nick_hint.text = ""
			for b in select_buttons: b.disabled = false
	)

func _build_class_card(cls: Dictionary, pos: Vector2, sz: Vector2) -> Button:
	var panel = Panel.new()
	panel.position = pos
	panel.size     = sz

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.13)
	style.border_color = cls.color
	style.set_border_width_all(2)
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	_select_layer.add_child(panel)

	# Class name
	var name_lbl = Label.new()
	name_lbl.text = cls.label
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", cls.color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, 14)
	name_lbl.size     = Vector2(sz.x, 36)
	panel.add_child(name_lbl)

	# Divider
	var div = ColorRect.new()
	div.color    = Color(cls.color.r, cls.color.g, cls.color.b, 0.35)
	div.position = Vector2(16, 58)
	div.size     = Vector2(sz.x - 32, 1)
	panel.add_child(div)

	# Description
	var desc = Label.new()
	desc.text = cls.desc
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.position = Vector2(10, 68)
	desc.size     = Vector2(sz.x - 20, 170)
	panel.add_child(desc)

	# Select button
	var btn = Button.new()
	btn.text = "SELECT"
	btn.position = Vector2(20, sz.y - 52)
	btn.size     = Vector2(sz.x - 40, 36)
	btn.pressed.connect(_on_class_selected.bind(cls.key))
	panel.add_child(btn)
	return btn

func _on_class_selected(cls: String) -> void:
	if is_instance_valid(_select_layer):
		var nick_bg_node = _select_layer.get_node_or_null("NickBg")
		if nick_bg_node:
			var nf = nick_bg_node.get_node_or_null("NickField") as LineEdit
			if nf:
				var n = nf.text.strip_edges()
				_pending_nickname = n if n.length() > 0 else cls.capitalize()
				# Save nickname for next session
				if n.length() > 0:
					var save_cfg = ConfigFile.new()
					save_cfg.set_value("player", "nickname", n)
					save_cfg.save("user://player_prefs.cfg")
		_select_layer.queue_free()
		_select_layer = null

	_spawn_player(cls)
	_spawn_shop_terminal()
	_spawn_mission_terminal()
	_setup_hud()

# ============================================================
#  SPAWNING
# ============================================================
func _spawn_player(cls: String) -> void:
	var script = load("res://Scripts/BossArenaPlayer.gd")

	_player = CharacterBody2D.new()
	_player.set_script(script)

	# Set class BEFORE add_child so _ready() → _setup_stats() sees it
	_player.set("character_class", cls)

	# AnimatedSprite2D — frames are built from sprite sheets below
	var sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = _build_frames(cls)
	if cls == "scrapper":
		sprite.scale  = Vector2(0.38, 0.38)
		sprite.offset = Vector2(0, -121)
	elif cls == "medic":
		sprite.scale  = Vector2(44.0 / 144.0, 44.0 / 144.0)
		sprite.offset = Vector2(0, -72)
	else:
		sprite.scale  = Vector2(1.0, 1.0)
		sprite.offset = Vector2(0, -12)   # half of 24px
	_player.add_child(sprite)

	# Split-body blend sprites for brawlernew
	if cls == "scrapper":
		_attach_split_body_shaders(sprite, _build_frames(cls))

	# Collision
	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 12.0
	shape.height = 20.0
	col.shape = shape
	_player.add_child(col)

	_player.position = Vector2(WORLD_W * 0.5, WORLD_H * 0.65)
	add_child(_player)
	# Apply nickname AFTER add_child so it overwrites the class default set in _ready() → _setup_stats()
	if _pending_nickname.length() > 0:
		_player.set("character_name", _pending_nickname)

func _spawn_shop_terminal() -> void:
	var script   = load("res://Scripts/BossShopTerminal.gd")
	var terminal = Node2D.new()
	terminal.set_script(script)
	# Place it 120px to the right of the player spawn point
	terminal.position = Vector2(WORLD_W * 0.5 + 120.0, WORLD_H * 0.65)
	add_child(terminal)

# ── Split-body blend (upper/lower clip shaders for brawlernew) ──
func _attach_split_body_shaders(lower_sprite: AnimatedSprite2D, frames: SpriteFrames) -> void:
	# No shader on lower sprite at spawn — applied dynamically during blend
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

# ── Sprite frame builder ───────────────────────────────────────
# Slices each sprite sheet into individual AtlasTexture frames
# and registers them as named animations on a SpriteFrames resource.
func _build_frames(cls: String) -> SpriteFrames:
	var frames = SpriteFrames.new()
	# Remove the default "default" animation Godot adds automatically
	if frames.has_animation("default"):
		frames.remove_animation("default")

	match cls:
		"melee":
			var base = "res://Characters/minimmo/brawler/"
			# idle: 192 wide × 24 tall = 8 frames of 24×24
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "idle_" + dir, base + "idle/idle_" + dir + ".png", 24, 24, 8, 8.0)
			# run: 96 wide × 24 tall = 4 frames of 24×24
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "run_"  + dir, base + "run/run_"   + dir + ".png", 24, 24, 4, 10.0)
			# attack: 144 wide × 24 tall = 6 frames of 24×24 — no loop, plays once per hit
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "attack_" + dir, base + "attack/attack_" + dir + ".png", 24, 24, 6, 12.0, false)
		"mage":
			var mbase = "res://Characters/minimmo/mage/"
			# idle: 192 wide = 8 frames of 24×24
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "idle_" + dir, mbase + "idle/idle_" + dir + ".png", 24, 24, 8, 8.0)
			# run: 96 wide = 4 frames
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "run_"  + dir, mbase + "run/run_"   + dir + ".png", 24, 24, 4, 10.0)
			# attack: 144 wide = 6 frames — no loop
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "attack_" + dir, mbase + "attack/attack_" + dir + ".png", 24, 24, 6, 12.0, false)
		"ranged":
			var rbase = "res://Characters/minimmo/ranged/"
			# idle: 192x24 = 8 frames of 24x24
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "idle_" + dir, rbase + "idle/idle_" + dir + ".png", 24, 24, 8, 8.0)
			# run: 192x24 = 8 frames of 24x24
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "run_"  + dir, rbase + "run/run_"   + dir + ".png", 24, 24, 8, 10.0)
			# attack: 512x32 = 16 frames of 32x32 — no loop, plays once per shot
			for dir in ["s", "n", "e", "w"]:
				_add_strip(frames, "attack_" + dir, rbase + "attack/attack_" + dir + ".png", 32, 32, 16, 14.0, false)
		"medic":
			var mbase = "res://Characters/minimmo/medic/"
			for dir in ["s","n","e","w","se","sw","nw"]:
				_add_strip(frames, "idle_" + dir,   mbase + "idle/idle_" + dir + ".png",   144, 144, 8, 8.0)
				_add_strip(frames, "run_"  + dir,   mbase + "run/run_"   + dir + ".png",   144, 144, 8, 10.0)
				_add_strip(frames, "attack_" + dir, mbase + "toss/toss_" + dir + ".png",   144, 144, 7, 12.0, false)

		"scrapper":
			var bnbase = "res://Characters/NEWFOUNDMETHOD/Brawler/"
			var cw = 768; var ch = 448
			for dir in ["n","e","w","se","sw","nw"]:
				_add_grid(frames, "idle_"+dir, bnbase+"idle/idle_"+dir+".png", cw, ch, 4, 29, 10.0)
			_add_grid(frames, "idle_s", bnbase+"idle/idle_sw.png", cw, ch, 4, 29, 10.0)
			_add_grid(frames, "idle_ne", bnbase+"idle/idle_ne.png", cw, ch, 4, 28, 10.0)
			for dir in ["n","e","ne","se","sw"]:
				_add_grid(frames, "run_"+dir, bnbase+"run/run_"+dir+".png", cw, ch, 4, 17, 20.0)
			for dir in ["w","nw"]:
				_add_grid(frames, "run_"+dir, bnbase+"run/run_"+dir+".png", cw, ch, 4, 17, 18.0, true, true)
			_add_grid(frames, "run_s", bnbase+"run/run_s.png", cw, ch, 4, 17, 20.0)
			for dir in ["s","n","ne","se"]:
				_add_grid(frames, "attack_"+dir, bnbase+"attack/attack_"+dir+".png", cw, ch, 4, 29, 24.0, false)
			_add_grid(frames, "attack_e", bnbase+"attack/attack_e.png", cw, ch, 4, 24, 24.0, false)
			for dir in ["sw","nw"]:
				_add_grid(frames, "attack_"+dir, bnbase+"attack/attack_"+dir+".png", cw, ch, 4, 29, 24.0, false, true)
			_add_grid(frames, "attack_w", bnbase+"attack/attack_w.png", cw, ch, 4, 24, 24.0, false, true)
	return frames

# Loads frames from a grid-layout sprite sheet (cols × rows, left-to-right, top-to-bottom).
func _add_grid(frames: SpriteFrames, anim_name: String, path: String,
		cell_w: int, cell_h: int, cols: int, total_frames: int, fps: float,
		loop: bool = true, hflip: bool = false) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("BossArenaScene: could not load " + path)
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

# Loads one horizontal sprite sheet and adds all its frames to an animation.
# fps controls playback speed.
func _add_strip(frames: SpriteFrames, anim_name: String, path: String,
		frame_w: int, frame_h: int, frame_count: int, fps: float, loop: bool = true) -> void:
	var tex = load(path) as Texture2D
	if tex == null:
		push_warning("BossArenaScene: could not load " + path)
		return

	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loop)

	for i in frame_count:
		var atlas = AtlasTexture.new()
		atlas.atlas  = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)

func _spawn_dummy() -> void:
	var script = load("res://Scripts/TrainingDummy.gd")
	var dummy  = Node2D.new()
	dummy.set_script(script)
	dummy.scale    = Vector2(0.7, 0.7)
	# Spawn near player, each additional dummy offset 50px to the right
	var dummy_count = get_tree().get_nodes_in_group("training_dummy").size()
	var base_pos    = _player.global_position if is_instance_valid(_player) else Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	dummy.position  = base_pos + Vector2(80.0 + dummy_count * 50.0, 0.0)
	add_child(dummy)
	dummy.tree_exiting.connect(_on_targetable_removed.bind(dummy))

func _spawn_boss() -> void:
	var script = load("res://Scripts/ZergBoss.gd")
	var boss   = CharacterBody2D.new()
	boss.set_script(script)

	# Sprite — 132x132 frames at 2x scale = 264x264px — big imposing boss
	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_boss_frames()
	sprite.scale         = Vector2(2.0, 2.0)
	sprite.offset        = Vector2(0, -33)    # ~33 empty rows at frame bottom; -33 places actual feet at node origin
	boss.add_child(sprite)

	# Collision — sized to match the 2x visual footprint
	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 52.0
	shape.height = 90.0
	col.shape = shape
	boss.add_child(col)

	# Space bosses 50px apart radially — each new boss steps 50px further out
	var boss_count = get_tree().get_nodes_in_group("boss").size()
	var spawn_pos  = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	if is_instance_valid(_player):
		var angle = TAU * (float(boss_count) / 6.0)   # spread up to 6 bosses in a circle
		var dist  = 280.0 + boss_count * 50.0
		spawn_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	boss.position = spawn_pos

	# Layer 2 only — boss doesn't collide with the player (layer 1)
	boss.collision_layer = 2
	boss.collision_mask  = 2

	add_child(boss)
	boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	_boss = boss   # keep ref to most recently spawned boss (for editor convenience)

func _spawn_cyberlord() -> void:
	var script = load("res://Scripts/CyberLord.gd")
	var boss   = CharacterBody2D.new()
	boss.set_script(script)

	# melee2 sheets are 144x144 — scale to match ZergBoss visual height (264px)
	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_cyberlord_frames()
	sprite.scale         = Vector2(264.0 / 144.0, 264.0 / 144.0)
	sprite.offset        = Vector2(0, -72)   # feet at node origin
	boss.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 52.0
	shape.height = 90.0
	col.shape = shape
	boss.add_child(col)

	var boss_count = get_tree().get_nodes_in_group("boss").size()
	var spawn_pos  = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	if is_instance_valid(_player):
		var angle = TAU * (float(boss_count) / 6.0)
		var dist  = 280.0 + boss_count * 50.0
		spawn_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	boss.position = spawn_pos

	boss.collision_layer = 2
	boss.collision_mask  = 2

	add_child(boss)
	boss.tree_exiting.connect(_on_targetable_removed.bind(boss))
	_boss = boss

func _spawn_zerg_mob() -> void:
	var script = load("res://Scripts/ZergMob.gd")
	var mob    = CharacterBody2D.new()
	mob.set_script(script)

	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_boss_frames()
	sprite.scale         = Vector2(1.0, 1.0)   # half of ZergBoss's 2x scale
	sprite.offset        = Vector2(0, -33)      # feet at node origin
	mob.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 26.0
	shape.height = 45.0
	col.shape = shape
	mob.add_child(col)

	var mob_count = get_tree().get_nodes_in_group("mob").size()
	var spawn_pos = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	if is_instance_valid(_player):
		var angle = TAU * (float(mob_count) / 8.0)
		var dist  = 180.0 + mob_count * 30.0
		spawn_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	mob.position = spawn_pos

	mob.collision_layer = 2
	mob.collision_mask  = 2

	add_child(mob)
	mob.tree_exiting.connect(_on_targetable_removed.bind(mob))

func _spawn_cyber_mob() -> void:
	var script = load("res://Scripts/CyberMob.gd")
	var mob    = CharacterBody2D.new()
	mob.set_script(script)

	var sprite = AnimatedSprite2D.new()
	sprite.name          = "Sprite"
	sprite.sprite_frames = _build_cyberlord_frames()
	sprite.scale         = Vector2(264.0 / 144.0 * 0.5, 264.0 / 144.0 * 0.5)   # half of CyberLord scale
	sprite.offset        = Vector2(0, -72)   # feet at node origin
	mob.add_child(sprite)

	var col   = CollisionShape2D.new()
	var shape = CapsuleShape2D.new()
	shape.radius = 26.0
	shape.height = 45.0
	col.shape = shape
	mob.add_child(col)

	var mob_count = get_tree().get_nodes_in_group("mob").size()
	var spawn_pos = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	if is_instance_valid(_player):
		var angle = TAU * (float(mob_count) / 8.0)
		var dist  = 180.0 + mob_count * 30.0
		spawn_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
	mob.position = spawn_pos

	mob.collision_layer = 2
	mob.collision_mask  = 2

	add_child(mob)
	mob.tree_exiting.connect(_on_targetable_removed.bind(mob))

func _build_cyberlord_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var base = "res://Characters/minimmo/Old/melee2/"
	for dir in ["s", "n", "e", "w"]:
		_add_strip(frames, "idle_"   + dir, base + "idle/idle_"     + dir + ".png", 144, 144, 8, 7.0)
		_add_strip(frames, "run_"    + dir, base + "run/run_"       + dir + ".png", 144, 144, 8, 10.0)
		_add_strip(frames, "attack_" + dir, base + "attack/attack_" + dir + ".png", 144, 144, 7, 12.0, false)

	return frames

func _on_targetable_removed(node: Node) -> void:
	# Only clear the player's target if they were actually targeting this node
	if is_instance_valid(_player):
		if _player.get("_current_target") == node:
			_player.set("_current_target", null)
			_player.set("_target_idx", -1)
	if node == _boss:
		_boss = null   # clear convenience ref when the last-spawned boss dies

func _build_boss_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var base = "res://Characters/minimmo/Enemies/ZergBoss/"
	# All sheets: 1056x132 = 8 frames of 132x132
	for dir in ["s", "n", "e", "w"]:
		_add_strip(frames, "idle_"   + dir, base + "idle/idle_"     + dir + ".png", 132, 132, 8, 7.0)
		_add_strip(frames, "run_"    + dir, base + "run/run_"       + dir + ".png", 132, 132, 8, 10.0)
		_add_strip(frames, "attack_" + dir, base + "attack/attack_" + dir + ".png", 132, 132, 8, 12.0, false)

	return frames

func _input(event: InputEvent) -> void:
	# Scroll wheel zoom — works any time (even on character select screen)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_target = clampf(_cam_zoom_target + 0.15, 0.5, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_target = clampf(_cam_zoom_target - 0.15, 0.5, 4.0)

	# Only handle keys after character select is gone
	if not is_instance_valid(_player):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_spawn_dummy()
		elif event.keycode == KEY_F2:
			_spawn_boss()
		elif event.keycode == KEY_F3:
			_spawn_cyberlord()
		elif event.keycode == KEY_F4:
			_spawn_zerg_mob()
		elif event.keycode == KEY_F5:
			_spawn_cyber_mob()

# ============================================================
#  HUD
# ============================================================
func _setup_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var vp = get_viewport().get_visible_rect().size

	# ── Player panel (top-left) ─────────────────────────────────
	var pp = _make_hud_panel(Vector2(12, 12), Vector2(190, 96), Color(0.25, 0.50, 0.25))
	_player_frame = pp
	_hud.add_child(pp)
	pp.mouse_filter = Control.MOUSE_FILTER_STOP
	pp.gui_input.connect(_on_player_frame_drag)

	_player_name_lbl = Label.new()
	_player_name_lbl.add_theme_font_size_override("font_size", 12)
	_player_name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_player_name_lbl.position = Vector2(8, 6)
	_player_name_lbl.size     = Vector2(174, 20)
	pp.add_child(_player_name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP"
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	hp_lbl.position = Vector2(8, 27)
	hp_lbl.size     = Vector2(20, 14)
	pp.add_child(hp_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value       = 0.0
	_hp_bar.max_value       = 100.0
	_hp_bar.value           = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.position = Vector2(28, 27)
	_hp_bar.size     = Vector2(154, 14)
	var hp_bg = StyleBoxFlat.new(); hp_bg.bg_color = Color(0.04, 0.12, 0.04, 0.9)
	var hp_fill = StyleBoxFlat.new(); hp_fill.bg_color = Color(0.15, 0.78, 0.15, 0.95)
	_hp_bar.add_theme_stylebox_override("background", hp_bg)
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	pp.add_child(_hp_bar)
	_hp_bar_lbl = Label.new()
	_hp_bar_lbl.add_theme_font_size_override("font_size", 9)
	_hp_bar_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_hp_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_hp_bar_lbl.position = Vector2(28, 27)
	_hp_bar_lbl.size     = Vector2(154, 14)
	_hp_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_child(_hp_bar_lbl)

	var mp_lbl = Label.new()
	mp_lbl.text = "MP"
	mp_lbl.add_theme_font_size_override("font_size", 10)
	mp_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 1.0))
	mp_lbl.position = Vector2(8, 47)
	mp_lbl.size     = Vector2(20, 14)
	pp.add_child(mp_lbl)

	_mp_bar = ProgressBar.new()
	_mp_bar.min_value       = 0.0
	_mp_bar.max_value       = 100.0
	_mp_bar.value           = 100.0
	_mp_bar.show_percentage = false
	_mp_bar.position = Vector2(28, 47)
	_mp_bar.size     = Vector2(154, 14)
	var mp_bg = StyleBoxFlat.new(); mp_bg.bg_color = Color(0.04, 0.04, 0.18, 0.9)
	var mp_fill = StyleBoxFlat.new(); mp_fill.bg_color = Color(0.15, 0.35, 0.95, 0.95)
	_mp_bar.add_theme_stylebox_override("background", mp_bg)
	_mp_bar.add_theme_stylebox_override("fill", mp_fill)
	pp.add_child(_mp_bar)
	_mp_bar_lbl = Label.new()
	_mp_bar_lbl.add_theme_font_size_override("font_size", 9)
	_mp_bar_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_mp_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_bar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_mp_bar_lbl.position = Vector2(28, 47)
	_mp_bar_lbl.size     = Vector2(154, 14)
	_mp_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_child(_mp_bar_lbl)

	var xp_lbl = Label.new()
	xp_lbl.text = "XP"
	xp_lbl.add_theme_font_size_override("font_size", 10)
	xp_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	xp_lbl.position = Vector2(8, 67)
	xp_lbl.size     = Vector2(20, 14)
	pp.add_child(xp_lbl)

	_xp_bar = ProgressBar.new()
	_xp_bar.min_value       = 0.0
	_xp_bar.max_value       = 100.0
	_xp_bar.value           = 0.0
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(28, 67)
	_xp_bar.size     = Vector2(154, 14)
	var xp_bg = StyleBoxFlat.new(); xp_bg.bg_color = Color(0.08, 0.03, 0.14, 0.9)
	var xp_fill = StyleBoxFlat.new(); xp_fill.bg_color = Color(0.60, 0.15, 0.90, 0.95)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	pp.add_child(_xp_bar)
	_xp_bar_lbl = Label.new()
	_xp_bar_lbl.add_theme_font_size_override("font_size", 9)
	_xp_bar_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_xp_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_bar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_xp_bar_lbl.position = Vector2(28, 67)
	_xp_bar_lbl.size     = Vector2(154, 14)
	_xp_bar_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.add_child(_xp_bar_lbl)

	# ── Target frame (top-center) ───────────────────────────────
	_tgt_panel = _make_hud_panel(Vector2(vp.x * 0.5 - 105, 12), Vector2(210, 60), Color(0.7, 0.15, 0.15))
	_tgt_panel.visible = false
	_hud.add_child(_tgt_panel)

	_tgt_name_lbl = Label.new()
	_tgt_name_lbl.add_theme_font_size_override("font_size", 13)
	_tgt_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	_tgt_name_lbl.position = Vector2(8, 6)
	_tgt_name_lbl.size     = Vector2(194, 22)
	_tgt_panel.add_child(_tgt_name_lbl)

	var tgt_hp_lbl = Label.new()
	tgt_hp_lbl.text = "HP"
	tgt_hp_lbl.add_theme_font_size_override("font_size", 10)
	tgt_hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	tgt_hp_lbl.position = Vector2(8, 34)
	tgt_hp_lbl.size     = Vector2(20, 14)
	_tgt_panel.add_child(tgt_hp_lbl)

	_tgt_hp_bar = ProgressBar.new()
	_tgt_hp_bar.min_value       = 0.0
	_tgt_hp_bar.max_value       = 100.0
	_tgt_hp_bar.value           = 100.0
	_tgt_hp_bar.show_percentage = false
	_tgt_hp_bar.position = Vector2(28, 34)
	_tgt_hp_bar.size     = Vector2(174, 14)
	_tgt_panel.add_child(_tgt_hp_bar)

	# ── Range indicator label (bottom-center) ───────────────────
	var range_lbl = Label.new()
	range_lbl.name = "RangeHint"
	range_lbl.add_theme_font_size_override("font_size", 12)
	range_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_lbl.size     = Vector2(vp.x, 20)
	range_lbl.position = Vector2(0, vp.y - 30)
	_hud.add_child(range_lbl)

	# Mission compass — hidden until a mission is active
	var compass = Control.new()
	compass.name         = "MissionCompass"
	compass.size         = vp
	compass.position     = Vector2.ZERO
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.visible      = false
	compass.set_script(_mission_compass_script())
	_hud.add_child(compass)
	_mission_compass = compass

func _on_player_frame_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_frame_drag = event.pressed
	elif event is InputEventMouseMotion and _frame_drag:
		var vp      = get_viewport().get_visible_rect().size
		var new_pos = _player_frame.position + event.relative
		_player_frame.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - _player_frame.size.x),
			clampf(new_pos.y, 0.0, vp.y - _player_frame.size.y)
		)

func _make_hud_panel(pos: Vector2, sz: Vector2, border_col: Color) -> Panel:
	var p = Panel.new()
	p.position = pos
	p.size     = sz
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.88)
	style.border_color = border_col
	style.set_border_width_all(1)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	p.add_theme_stylebox_override("panel", style)
	return p

func _update_hud() -> void:
	if _hud == null or not is_instance_valid(_player):
		return

	# Player name
	if _player_name_lbl:
		var cname = _player.get("character_name")
		if cname != null:
			_player_name_lbl.text = str(cname)

	# Player HP / MP
	var p_hp     = _player.get("hp")     as float
	var p_max_hp = _player.get("max_hp") as float
	var p_mp     = _player.get("mp")     as float
	var p_max_mp = _player.get("max_mp") as float

	if _hp_bar and p_max_hp > 0.0:
		_hp_bar.value = (p_hp / p_max_hp) * 100.0
		if _hp_bar_lbl:
			_hp_bar_lbl.text = "%d / %d" % [int(p_hp), int(p_max_hp)]
	if _mp_bar and p_max_mp > 0.0:
		_mp_bar.value = (p_mp / p_max_mp) * 100.0
		if _mp_bar_lbl:
			_mp_bar_lbl.text = "%d / %d" % [int(p_mp), int(p_max_mp)]
	if _xp_bar:
		var p_exp   = _player.get("exp_points") as float
		var p_exp_n = _player.get("exp_needed")  as float
		if p_exp_n > 0.0:
			_xp_bar.value = (p_exp / p_exp_n) * 100.0
			if _xp_bar_lbl:
				_xp_bar_lbl.text = "%d / %d" % [int(p_exp), int(p_exp_n)]

	# Target frame
	var target : Node = null
	if _player.has_method("get_current_target"):
		target = _player.call("get_current_target")

	if target != null and is_instance_valid(target):
		_tgt_panel.visible = true
		# Re-check validity right before property access — dummy may have been freed
		if not is_instance_valid(target):
			_tgt_panel.visible = false
		else:
			if _tgt_name_lbl:
				var tname = target.get("character_name")
				_tgt_name_lbl.text = str(tname) if tname != null else "???"
			if _tgt_hp_bar:
				var t_hp  = target.get("hp")     as float
				var t_max = target.get("max_hp") as float
				if t_max > 0.0:
					_tgt_hp_bar.value = clampf((t_hp / t_max) * 100.0, 0.0, 100.0)
	else:
		if _tgt_panel:
			_tgt_panel.visible = false

	# Range hint
	var range_lbl = _hud.get_node_or_null("RangeHint") as Label
	if range_lbl and target != null and is_instance_valid(target):
		var dist = _player.global_position.distance_to(target.global_position)
		var cls  = _player.get("character_class") as String
		var rng  = 130.0 if (cls == "melee" or cls == "scrapper") else 700.0
		if dist <= rng:
			range_lbl.text = "IN RANGE — auto-attacking"
			range_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 0.9))
		else:
			range_lbl.text = "Move closer  (%.0f / %.0f px)" % [dist, rng]
			range_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3, 0.8))
	elif range_lbl:
		range_lbl.text = ""

# ============================================================
#  UI_LAYER INTERFACE
#  TrainingDummy calls is_targeted() on a node in "ui_layer".
#  We proxy the call to the player's own target tracking.
# ============================================================
func is_targeted(node: Node) -> bool:
	if is_instance_valid(_player) and _player.has_method("is_targeted"):
		return _player.call("is_targeted", node)
	return false

# ============================================================
#  DAMAGE NUMBERS
# ============================================================
func spawn_bullet(from_pos: Vector2, target: Node, damage: float) -> Node:
	var script = load("res://Scripts/Bullet.gd")
	var bullet  = Node2D.new()
	bullet.set_script(script)
	add_child(bullet)
	bullet.global_position = from_pos
	bullet.call("init", target, damage)
	return bullet

func spawn_fireball(from_pos: Vector2, target: Node, damage: float) -> void:
	var script = load("res://Scripts/Fireball.gd")
	var fb     = Node2D.new()
	fb.set_script(script)
	add_child(fb)
	fb.global_position = from_pos
	fb.call("init", target, damage)

func spawn_canister(spawn_pos: Vector2, target: Node, dmg: float, is_heal: bool) -> void:
	var script = load("res://Scripts/MedicCanister.gd")
	var c      = Node2D.new()
	c.set_script(script)
	add_child(c)
	c.global_position = spawn_pos
	c.call("init", target, dmg, is_heal)

func spawn_melee_hit(world_pos: Vector2, col: Color) -> void:
	var script = load("res://Scripts/MeleeHit.gd")
	var node   = Node2D.new()
	node.set_script(script)
	node.z_index = 100
	add_child(node)
	node.global_position = world_pos
	node.call("init", col)

func trigger_boss_cinematic(boss_name: String) -> void:
	if _cinematic_t >= 0.0:
		return   # don't stack cinematics
	_cinematic_t = 0.0
	var script = load("res://Scripts/BossCinematic.gd")
	var cin    = CanvasLayer.new()
	cin.set_script(script)
	add_child(cin)
	cin.call("init", boss_name)

func on_boss_died() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("add_credits"):
		_player.call("add_credits", 100)
	if _player.has_method("add_exp"):
		_player.call("add_exp", 100.0)
	# Drop HP potion at the player's current position
	spawn_hp_potion(_player.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)))

func on_mob_died(mob_pos: Vector2) -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("add_credits"):
		_player.call("add_credits", 10)
	if _player.has_method("add_exp"):
		_player.call("add_exp", 10.0)
	spawn_damage_number(mob_pos, 10.0, Color(0.9, 0.8, 0.2))
	_check_mission_complete()

func on_lair_died(lair_pos: Vector2) -> void:
	spawn_damage_number(lair_pos, 0.0, Color(0.9, 0.8, 0.2))
	_check_mission_complete()

# ── MISSION SYSTEM ────────────────────────────────────────────
func _spawn_mission_terminal() -> void:
	var script   = load("res://Scripts/MissionTerminal.gd")
	var terminal = Node2D.new()
	terminal.set_script(script)
	# 200px to the right of the shop terminal
	terminal.position         = Vector2(WORLD_W * 0.5 + 320.0, WORLD_H * 0.65)
	_mission_terminal_pos     = terminal.position
	add_child(terminal)

func start_mission(data: Dictionary) -> void:
	if _mission_active:
		return
	_mission_active = true
	_mission_name   = data.get("name", "Zerg Extermination")
	_mission_payout = data.get("payout", 20)

	# Pick a spawn centre at least 800 px from the mission terminal
	var centre = _mission_terminal_pos
	for _attempt in 30:
		var candidate = Vector2(
			randf_range(400.0, WORLD_W - 400.0),
			randf_range(400.0, WORLD_H - 400.0))
		if candidate.distance_to(_mission_terminal_pos) >= 2000.0:
			centre = candidate
			break
	_mission_target_pos = centre

	# Spawn 10 Zerg mobs spread around the centre
	for i in 10:
		var angle   = float(i) / 10.0 * TAU + randf() * 0.4
		var dist    = randf_range(80.0, 200.0)
		var mob_pos = centre + Vector2(cos(angle) * dist, sin(angle) * dist)
		_spawn_mission_zerg_mob(mob_pos)

	# Spawn the lair at the centre
	_spawn_mission_lair(centre)

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
	shape.radius = 26.0
	shape.height = 45.0
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
	lair.tree_exiting.connect(_on_targetable_removed.bind(lair))

func _check_mission_complete() -> void:
	if not _mission_active:
		return
	var mobs_left  = get_tree().get_nodes_in_group("mission_mob").size()
	var lairs_left = get_tree().get_nodes_in_group("mission_lair").size()
	if mobs_left > 0 or lairs_left > 0:
		return
	# All targets dead — mission complete
	_mission_active = false
	if is_instance_valid(_player):
		if _player.has_method("add_credits"):
			_player.call("add_credits", _mission_payout)
		if _player.has_method("add_exp"):
			_player.call("add_exp", float(_mission_payout))
		spawn_damage_number(
			_player.global_position + Vector2(0, -80),
			float(_mission_payout), Color(1.0, 0.85, 0.10))
	_show_mission_complete()

func _show_mission_complete() -> void:
	var vp  = get_viewport().get_visible_rect().size
	var cl  = CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var lbl = Label.new()
	lbl.set_script(_mission_complete_label_script(_mission_payout))
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(vp.x, 44)
	lbl.position = Vector2(0, vp.y * 0.5 - 70)
	cl.add_child(lbl)

func _update_mission_compass() -> void:
	if not is_instance_valid(_mission_compass):
		return
	if _mission_active and is_instance_valid(_player):
		_mission_compass.visible = true
		_mission_compass.set("_target_world", _mission_target_pos)
		_mission_compass.set("_player", _player)
	else:
		_mission_compass.visible = false

func _mission_compass_script() -> GDScript:
	var src = """extends Control
var _target_world : Vector2 = Vector2.ZERO
var _player : Node = null
var _t : float = 0.0
func _process(d): _t += d; queue_redraw()
func _draw():
\tif not is_instance_valid(_player): return
\tvar vp  = get_viewport_rect().size
\tvar ac  = Vector2(vp.x - 52, 88)
\tvar to  = _target_world - _player.global_position
\tvar dist = to.length()
\tvar dir  = to.normalized() if dist > 1.0 else Vector2(0, -1)
\tvar ang  = dir.angle()
\tvar pulse = 0.70 + sin(_t * 3.0) * 0.25
\tvar AR = 19.0
\tdraw_circle(ac, AR + 5, Color(0, 0, 0, 0.58))
\tdraw_arc(ac, AR + 5, 0, TAU, 32, Color(1.0, 0.85, 0.0, 0.50), 1.5)
\tvar tip = ac + Vector2(cos(ang), sin(ang)) * AR
\tvar lft = ac + Vector2(cos(ang + 2.35), sin(ang + 2.35)) * (AR * 0.55)
\tvar rgt = ac + Vector2(cos(ang - 2.35), sin(ang - 2.35)) * (AR * 0.55)
\tvar bck = ac - Vector2(cos(ang), sin(ang)) * (AR * 0.28)
\tdraw_colored_polygon(PackedVector2Array([tip, lft, bck, rgt]), Color(1.0, 0.88, 0.0, pulse))
\tvar font = _roboto
\tvar dt = "%dm" % int(dist / 10)
\tvar dw = font.get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
\tdraw_string(font, Vector2(ac.x - dw * 0.5, ac.y + AR + 18), dt, HORIZONTAL_ALIGNMENT_LEFT, 60, 9, Color(1.0, 0.88, 0.0, 0.90))
\tvar ww = font.get_string_size("WAYPOINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
\tdraw_string(font, Vector2(ac.x - ww * 0.5, ac.y - AR - 7), "WAYPOINT", HORIZONTAL_ALIGNMENT_LEFT, 80, 8, Color(1.0, 0.88, 0.0, 0.60))
"""
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func _mission_complete_label_script(payout: int) -> GDScript:
	var src = """extends Label
var _t : float = 0.0
func _ready():
\ttext = "MISSION COMPLETE  +%dCR"
func _process(delta):
\t_t += delta
\tposition.y -= 18.0 * delta
\tmodulate.a = clampf(1.0 - (_t - 1.5) / 1.2, 0.0, 1.0)
\tif _t >= 2.7:
\t\tget_parent().queue_free()
""" % payout
	var s = GDScript.new(); s.source_code = src; s.reload(); return s

func spawn_hp_potion(world_pos: Vector2) -> void:
	var script = load("res://Scripts/HpPotion.gd")
	var node   = Node2D.new()
	node.set_script(script)
	add_child(node)
	node.global_position = world_pos

func trigger_level_up(new_level: int) -> void:
	var script = load("res://Scripts/BossLevelUpEffect.gd")
	var node   = CanvasLayer.new()
	node.set_script(script)
	add_child(node)
	node.call("init", new_level)

func on_player_died() -> void:
	var script = load("res://Scripts/GameOverScreen.gd")
	var screen = CanvasLayer.new()
	screen.set_script(script)
	add_child(screen)

func spawn_damage_number(world_pos: Vector2, amount: float, col: Color) -> void:
	var script = load("res://Scripts/DamageNumber.gd")
	var node   = Node2D.new()
	node.set_script(script)
	add_child(node)
	# Slight horizontal scatter so stacked hits don't overlap exactly
	node.global_position = world_pos + Vector2(randf_range(-10.0, 10.0), -28.0)
	node.call("init", amount, col)
