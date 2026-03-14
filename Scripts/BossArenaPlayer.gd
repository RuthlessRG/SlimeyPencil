extends CharacterBody2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  BossArenaPlayer.gd — Beyond the Veil | Boss Arena
# ============================================================

const SPEED = 55.0

# ── CLASS & STATS ─────────────────────────────────────────────
var character_class : String = "melee"
var character_name  : String = "Player"
var level           : int    = 1
var hp              : float  = 200.0
var max_hp          : float  = 200.0
var mp              : float  = 100.0
var max_mp          : float  = 100.0

# Base stats before attribute bonuses
var _base_max_hp : float = 200.0
var _base_max_mp : float = 100.0

# ── ATTRIBUTES ────────────────────────────────────────────────
# STR: +25 HP, +5 melee dmg, +5% dmg reduction per point
# AGI: +5% attack speed, +2% crit chance per point
# INT: +5% spell dmg, +2% spell crit per point
# SPI: +25 MP, +5 spell dmg per point
var attr_str       : int = 0
var attr_agi       : int = 0
var attr_int       : int = 0
var attr_spi       : int = 0
var unspent_points : int = 0

# ── INVENTORY ─────────────────────────────────────────────────
# Each entry is a dict: {id, name, type, rarity, cost,
#   attr_str, attr_agi, attr_int, attr_spi, desc, equipped}
var inventory : Array = []

# Item bonus totals — recomputed in _recalc_stats from equipped items
var _item_str : int = 0
var _item_agi : int = 0
var _item_int : int = 0
var _item_spi : int = 0

# ── CREDITS & EXPERIENCE ──────────────────────────────────────
var credits       : int = 0
var _float_stack  : int = 0   # tracks stacked floating texts
var exp_points : float = 0.0
var exp_needed : float = 100.0   # scales: 100 * level

# ── FACING & ANIMATION ────────────────────────────────────────
var _facing      : String = "s"
var _is_attacking: bool   = false
var _moving      : bool   = false

# ── AUTO-ATTACK ───────────────────────────────────────────────
var _attack_timer   : float = 0.0
var _move_lock_timer: float = 0.0
var _one_shot_kill  : bool  = false

# ── DEATH ─────────────────────────────────────────────────────
const DEATH_DURATION : float = 2.0
var _dying       : bool  = false
var _death_timer : float = 0.0
var _aura_t      : float = 0.0   # drives gold aura animation

# ── SKILL STATE ───────────────────────────────────────────────
var _sprint_active    : bool  = false
var _sprint_timer     : float = 0.0
const SPRINT_DURATION : float = 15.0

# ── MOUNT STATE ───────────────────────────────────────────────
var _mounted          : bool    = false
var _mount_item       : Dictionary = {}
var _mount_speed      : float   = 0.0      # current throttle speed
var _mount_angle      : float   = 0.0      # facing angle (radians, points toward mouse)
# Parked vehicle (left behind when player presses F to exit)
var _has_parked       : bool    = false
var _parked_pos       : Vector2 = Vector2.ZERO
var _parked_item      : Dictionary = {}
var _parked_angle     : float   = 0.0
var _fade_t           : float   = 1.0      # 0=invisible 1=fully visible
var _fading_in        : bool    = false
var _fading_out       : bool    = false
var _fade_target_mount: bool    = false    # true=fading into mount, false=fading into player

var _sensu_active     : bool  = false
var _sensu_timer      : float = 0.0
const SENSU_DURATION  : float = 10.0

var _triple_active    : bool  = false
var _triple_hits_left : int   = 0

# ── TARGET SYSTEM ─────────────────────────────────────────────
var _current_target    : Node  = null
var _target_candidates : Array = []
var _target_idx        : int   = -1
var _target_scan_timer : float = 0.0

const TARGET_SCAN_RATE    = 0.10
const TARGET_CONE_RANGE   = 700.0
const TARGET_CIRCLE_RANGE = 800.0
const TARGET_CONE_ANGLE   = 60.0

# ── SOUNDS ─────────────────────────────────────────────────────
var _snd_step_port  : AudioStreamPlayer = null
var _snd_step_grass : AudioStreamPlayer = null
var _snd_melee_hits : Array = []   # knife slash sound variants
var _snd_rifle_shot : AudioStreamPlayer = null
var _snd_hum        : AudioStreamPlayer = null   # vehicle engine hum
var _footstep_timer : float = 0.0
const FOOTSTEP_INTERVAL : float = 0.37

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_setup_stats()
	_spawn_chat()
	_setup_sounds()

func _spawn_chat() -> void:
	var script = load("res://Scripts/BossChatWindow.gd")
	# Action bar — always present
	var bar_script = load("res://Scripts/BossActionBar.gd")
	var bar        = CanvasLayer.new()
	bar.name       = "ActionBar"
	bar.set_script(bar_script)
	add_child(bar)
	bar.call("init", self)

	# Buff/debuff bar — sits below HUD bars
	var buff_script = load("res://Scripts/BossBuffBar.gd")
	var buff_bar    = CanvasLayer.new()
	buff_bar.name   = "BuffBar"
	buff_bar.set_script(buff_script)
	add_child(buff_bar)
	buff_bar.call("init", self)

	var chat   = CanvasLayer.new()
	chat.name  = "ChatWindow"
	chat.set_script(script)
	add_child(chat)
	chat.call("init", self)

	# Tooltip manager — watches inventory slots and action bar slots
	var tip_script = load("res://Scripts/TooltipManager.gd")
	var tip        = CanvasLayer.new()
	tip.name       = "TooltipManager"
	tip.set_script(tip_script)
	add_child(tip)
	tip.call("init")

func _setup_sounds() -> void:
	_snd_step_port  = _make_sfx("res://Sounds/singlefootstep.mp3", -10.5)
	_snd_step_grass = _make_sfx("res://Sounds/footstepgrass.mp3",  -4.0)
	for _ks in ["res://Sounds/knife_slash.mp3", "res://Sounds/knife_slash1.mp3",
			"res://Sounds/knife_slash2.mp3", "res://Sounds/knife_slash3.mp3"]:
		var _kp = _make_sfx(_ks, -4.0)
		if _kp != null: _snd_melee_hits.append(_kp)
	_snd_rifle_shot = _make_sfx("res://Sounds/rifle_shot.mp3",     -22.0)
	var _hum_stream = load("res://Sounds/hum.wav") as AudioStream
	if _hum_stream != null:
		_snd_hum = AudioStreamPlayer.new()
		_snd_hum.stream    = _hum_stream
		_snd_hum.volume_db = -80.0
		_snd_hum.bus       = "Master"
		add_child(_snd_hum)
		_snd_hum.finished.connect(_on_hum_finished)
		_snd_hum.play()

func _on_hum_finished() -> void:
	if _snd_hum != null and (_mounted or _has_parked):
		_snd_hum.play()

func _make_sfx(path: String, vol_db: float) -> AudioStreamPlayer:
	var stream = load(path) as AudioStream
	if stream == null: return null
	var p = AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = vol_db
	p.bus       = "Master"
	add_child(p)
	return p

func _on_grass() -> bool:
	# Returns true when the player is outside the spaceport complex (on grass terrain)
	const PX = 80.0; const PY = 80.0; const PW = 2600.0; const PH = 2400.0
	return (global_position.x < PX or global_position.x > PX + PW or
			global_position.y < PY or global_position.y > PY + PH)

func _setup_stats() -> void:
	match character_class:
		"melee":
			character_name = "Melee Fighter"
			_base_max_hp   = 300.0
			_base_max_mp   = 60.0
		"ranged":
			character_name = "Marksman"
			_base_max_hp   = 180.0
			_base_max_mp   = 100.0
		"mage":
			character_name = "Mage"
			_base_max_hp   = 150.0
			_base_max_mp   = 200.0
		"brawler":
			character_name = "Brawler"
			_base_max_hp   = 350.0
			_base_max_mp   = 60.0
		"medic":
			character_name = "Medic"
			_base_max_hp   = 220.0
			_base_max_mp   = 150.0
	_recalc_stats()
	hp = max_hp
	mp = max_mp

func _draw_mount_vehicle(alpha: float) -> void:
	var variant = _mount_item.get("mount_variant", "fighter")
	var t       = Time.get_ticks_msec() / 1000.0
	var fwd     = Vector2(cos(_mount_angle), sin(_mount_angle))
	var side    = Vector2(-sin(_mount_angle), cos(_mount_angle))

	# Engine glow pulse
	var eng_glow = Color(0.30, 0.65, 1.00, (0.55 + sin(t*8.0)*0.30) * alpha)

	if variant == "fighter":
		# ── Fighter speeder (LandSpeeder MK1) ────────────────
		# Shadow
		draw_colored_polygon(
			_mount_ellipse(Vector2(6,8), 55, 14, _mount_angle, 16),
			Color(0,0,0, 0.22 * alpha))
		# Hull
		var hull = PackedVector2Array()
		for i in 21:
			var tv = float(i)/20.0
			var px: float; var py: float
			if tv <= 0.5:
				px = lerpf(-42, 50, tv*2.0)
				py = sin(tv*2.0*PI) * 16.0
			else:
				px = lerpf(50, -42, (tv-0.5)*2.0)
				py = -sin((tv-0.5)*2.0*PI) * 16.0
			hull.append(fwd*px + side*py)
		draw_colored_polygon(hull, Color(0.88, 0.92, 0.96, alpha))
		# Cockpit
		draw_colored_polygon(
			_mount_ellipse(fwd*15, 13, 7, _mount_angle, 12),
			Color(0.35, 0.70, 1.00, 0.80 * alpha))
		draw_colored_polygon(
			_mount_ellipse(fwd*16 + side*(-3), 5, 2.5, _mount_angle, 8),
			Color(1.0, 1.0, 1.0, 0.50 * alpha))
		# Engine nacelles
		for sm in [-1.0, 1.0]:
			var ep = fwd*(-30) + side*sm*13
			draw_colored_polygon(_mount_ellipse(ep, 9, 5, _mount_angle, 10),
				Color(0.45, 0.52, 0.62, alpha))
			draw_colored_polygon(_mount_ellipse(ep - fwd*9, 5, 4.5, _mount_angle, 10), eng_glow)
		# Accent stripes
		draw_line(fwd*(-40)+side*4,  fwd*40+side*4,  Color(0.25,0.60,1.00,0.70*alpha), 2.0)
		draw_line(fwd*(-40)-side*4,  fwd*40-side*4,  Color(0.25,0.60,1.00,0.70*alpha), 2.0)
		# Speed lines (scale with speed)
		var sp_ratio = abs(_mount_speed) / (SPEED * _mount_item.get("speed_mult", 5.0))
		if sp_ratio > 0.15:
			for i in 4:
				var soff = side * (float(i-2) * 5.0)
				var slen = 18.0 + sp_ratio * 22.0
				var sa   = (0.20 + sp_ratio*0.35) * alpha
				draw_line(fwd*(-42)+soff, fwd*(-42)-fwd*slen+soff,
					Color(0.50, 0.80, 1.00, sa), 1.5)
	else:
		# ── Transport speeder (LandSpeeder MK2) ──────────────
		# Shadow
		draw_colored_polygon(
			_mount_ellipse(Vector2(8,10), 48, 24, _mount_angle, 16),
			Color(0,0,0, 0.22 * alpha))
		# Wide hull
		var hull = PackedVector2Array([
			fwd*(-45) - side*22,
			fwd*35    - side*15,
			fwd*45,
			fwd*35    + side*15,
			fwd*(-45) + side*22,
		])
		draw_colored_polygon(hull, Color(0.86, 0.88, 0.92, alpha))
		# Superstructure
		var sup = PackedVector2Array([
			fwd*(-25) - side*10,
			fwd*20    - side*7,
			fwd*20    + side*7,
			fwd*(-25) + side*10,
		])
		draw_colored_polygon(sup, Color(0.76, 0.80, 0.86, alpha))
		# Bridge windows
		for wi in 4:
			var wp = fwd*(5+wi*5) + side*(-6+wi)
			draw_circle(wp, 2.2, Color(0.35,0.70,1.00, 0.85*alpha))
		# Cargo dome
		draw_colored_polygon(_mount_ellipse(fwd*(-10), 15, 9, _mount_angle, 14),
			Color(0.70, 0.75, 0.82, alpha))
		draw_colored_polygon(_mount_ellipse(fwd*(-9) - side*2, 7, 4, _mount_angle, 10),
			Color(0.92, 0.96, 1.0, 0.65*alpha))
		# Engine pods
		for sm in [-1.0, 1.0]:
			var ep = fwd*(-40) + side*sm*16
			draw_colored_polygon(_mount_ellipse(ep, 8,4, _mount_angle, 10),
				Color(0.38,0.42,0.50, alpha))
			draw_colored_polygon(_mount_ellipse(ep-fwd*8, 5,4, _mount_angle, 10), eng_glow)
		# Accent
		draw_line(fwd*(-44), fwd*44, Color(1.00,0.82,0.10, 0.70*alpha), 2.0)
		# Speed lines
		var sp_ratio = abs(_mount_speed) / (SPEED * _mount_item.get("speed_mult", 7.0))
		if sp_ratio > 0.15:
			for i in 4:
				var soff = side * (float(i-2) * 6.0)
				var slen = 20.0 + sp_ratio * 26.0
				var sa   = (0.20 + sp_ratio*0.35) * alpha
				draw_line(fwd*(-46)+soff, fwd*(-46)-fwd*slen+soff,
					Color(1.00, 0.88, 0.30, sa), 1.5)

func _draw_parked_vehicle() -> void:
	# Draw the parked vehicle at its saved world position.
	# Uses draw_set_transform to offset draw calls from the player's local origin.
	var offset : Vector2 = _parked_pos - global_position
	var save_item  = _mount_item
	var save_angle = _mount_angle
	var save_mnt   = _mounted
	_mount_item  = _parked_item
	_mount_angle = _parked_angle
	_mounted     = true
	draw_set_transform(offset, 0.0, Vector2.ONE)
	_draw_mount_vehicle(0.88)   # slightly dimmed = parked/idle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_mount_item  = save_item
	_mount_angle = save_angle
	_mounted     = save_mnt
	# "Press F" hint when player is close enough
	var dist : float = global_position.distance_to(_parked_pos)
	if dist < 130.0:
		var font = _roboto
		draw_set_transform(offset + Vector2(-38, -52), 0.0, Vector2.ONE)
		draw_string(font, Vector2.ZERO, "[F] Enter Vehicle", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(1.0, 0.95, 0.55, 0.90))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _mount_ellipse(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var cr  = cos(rot); var sr = sin(rot)
	for i in n:
		var a  = float(i)/float(n)*TAU
		var lx = cos(a)*rx; var ly = sin(a)*ry
		pts.append(center + Vector2(lx*cr - ly*sr, lx*sr + ly*cr))
	return pts


func _recalc_stats() -> void:
	# Recompute item bonuses from currently equipped items
	_item_str = 0; _item_agi = 0; _item_int = 0; _item_spi = 0
	for item in inventory:
		if item.get("equipped", false):
			_item_str += item.get("attr_str", 0)
			_item_agi += item.get("attr_agi", 0)
			_item_int += item.get("attr_int", 0)
			_item_spi += item.get("attr_spi", 0)
	max_hp = _base_max_hp + (attr_str + _item_str) * 25.0
	max_mp = _base_max_mp + (attr_spi + _item_spi) * 25.0
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)

# ── CREDITS & PROGRESSION ─────────────────────────────────────
func add_credits(amount: int) -> void:
	credits += amount
	_spawn_floating_text("+%d ¢" % amount, Color(1.0, 0.85, 0.20))

func add_exp(amount: float) -> void:
	exp_points += amount
	_spawn_floating_text("+%d XP" % int(amount), Color(0.75, 0.25, 1.0))
	while exp_points >= exp_needed:
		exp_points -= exp_needed
		_level_up()

func _spawn_floating_text(text: String, color: Color) -> void:
	var script = load("res://Scripts/BossFloatingText.gd")
	var node   = Node2D.new()
	node.set_script(script)
	var scene  = get_tree().current_scene
	if scene == null:
		return
	node.global_position = global_position + Vector2(randf_range(-8, 8), -40 - _float_stack * 20)
	_float_stack += 1
	scene.add_child(node)
	node.call("init", text, color)
	get_tree().create_timer(1.4).timeout.connect(func(): _float_stack = max(0, _float_stack - 1))

func _level_up() -> void:
	level         += 1
	unspent_points += 3
	exp_needed     = 100.0 * level
	_recalc_stats()
	hp = max_hp   # full heal on level up
	mp = max_mp
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("trigger_level_up"):
		arena.call("trigger_level_up", level)

func spend_point(attr: String) -> void:
	if unspent_points <= 0:
		return
	match attr:
		"str": attr_str += 1
		"agi": attr_agi += 1
		"int": attr_int += 1
		"spi": attr_spi += 1
		_: return
	unspent_points -= 1
	_recalc_stats()

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		queue_redraw()
		return

	_target_scan_timer -= delta
	if _target_scan_timer <= 0.0:
		_target_scan_timer = TARGET_SCAN_RATE
		_refresh_target_candidates()

	if _move_lock_timer > 0.0:
		_move_lock_timer -= delta

	_aura_t += delta
	# ── Vehicle hum volume ────────────────────────────────────
	if _snd_hum != null:
		if _mounted:
			_snd_hum.volume_db = -9.5
			if not _snd_hum.playing: _snd_hum.play()
		elif _has_parked:
			var _hd : float = global_position.distance_to(_parked_pos)
			var _hv : float = clampf(1.0 - _hd / 360.0, 0.0, 1.0)
			_snd_hum.volume_db = linear_to_db(maxf(_hv * 0.638, 0.0001))
			if not _snd_hum.playing: _snd_hum.play()
		else:
			_snd_hum.volume_db = -80.0
	queue_redraw()
	_tick_skills(delta)
	_tick_auto_attack(delta)
	_update_animation()
	queue_redraw()

func _tick_death(delta: float) -> void:
	_death_timer += delta
	var blink = absf(sin(_death_timer * 14.0))
	var fade  = 1.0 - clampf((_death_timer - 1.4) / 0.6, 0.0, 1.0)
	modulate.a = blink * fade
	if _death_timer >= DEATH_DURATION:
		queue_free()

func _physics_process(_delta: float) -> void:
	_tick_fade(_delta)

	if _dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Mount mode — spaceship controls take over entirely
	if _mounted:
		_tick_mount_physics(_delta)
		return

	if _move_lock_timer > 0.0:
		velocity = Vector2.ZERO
		_moving  = false
		move_and_slide()
		return

	var input = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0

	_moving = input != Vector2.ZERO
	if _moving:
		var _sprint_mult = 1.65 if _sprint_active else 1.0
		velocity = input.normalized() * SPEED * _sprint_mult
		if character_class == "melee" or character_class == "medic" or character_class == "brawler":
			_facing = _facing_8dir(input)
		elif input.y < 0.0:
			_facing = "n"
		elif input.y > 0.0:
			_facing = "s"
		elif input.x > 0.0:
			_facing = "e"
		else:
			_facing = "w"
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	# Footstep sounds — tick timer while moving
	if _moving:
		_footstep_timer -= _delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			if _on_grass():
				if _snd_step_grass != null: _snd_step_grass.play()
			else:
				if _snd_step_port  != null: _snd_step_port.play()
	else:
		_footstep_timer = 0.0   # reset so first step is immediate next time

func _input(event: InputEvent) -> void:
	if _dying:
		return
	# Don't fire game keys while chat input has keyboard focus
	if event is InputEventKey:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit:
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_cycle_target()
		elif event.keycode == KEY_ESCAPE:
			# Close any open window first; if none, clear target
			var window_names = ["ShopWindow", "InventoryWindow", "AttributeWindow", "MissionWindow", "SkillWindow"]
			var closed = false
			for wname in window_names:
				var win = get_node_or_null(wname)
				if win:
					win.queue_free()
					closed = true
					break
			if not closed:
				_current_target = null
				_target_idx     = -1
				_cancel_attack()
		elif event.keycode == KEY_G:
			_one_shot_kill = true
		elif event.keycode == KEY_J:
			_level_up()   # debug: instant level up
		elif event.keycode == KEY_P:
			_toggle_skills()
		elif event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_C:
			_toggle_attributes()
		elif event.keycode == KEY_F:
			if _mounted and not _fading_out and not _fading_in:
				# Exit vehicle — save it parked at current position
				_parked_pos   = global_position
				_parked_item  = _mount_item.duplicate()
				_parked_angle = _mount_angle
				_has_parked   = true
				_mount_speed  = 0.0
				_start_fade(false)
				return
			if not _mounted and _has_parked and global_position.distance_to(_parked_pos) < 130.0:
				# Re-enter the parked vehicle
				global_position = _parked_pos
				_mount_item = _parked_item
				# Mark it equipped in inventory
				for _mi2 in inventory:
					if _mi2.get("type", "") == "mount":
						_mi2["equipped"] = (_mi2.get("name", "") == _parked_item.get("name", ""))
				_has_parked = false
				_start_fade(true)
				return
			_try_open_shop()
			_try_open_mission()
			_try_open_loot()
		elif event.keycode == KEY_H:
			credits += 500   # debug: +500 credits

# ── WINDOW TOGGLES ────────────────────────────────────────────
func _toggle_inventory() -> void:
	var existing = get_node_or_null("InventoryWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossInventoryWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "InventoryWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _toggle_attributes() -> void:
	var existing = get_node_or_null("AttributeWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossAttributeWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "AttributeWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_open_shop() -> void:
	var terminals = get_tree().get_nodes_in_group("shop_terminal")
	for t in terminals:
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= 58.0:
			_toggle_shop()
			return

func _toggle_shop() -> void:
	var existing = get_node_or_null("ShopWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossShopWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "ShopWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_open_mission() -> void:
	var terminals = get_tree().get_nodes_in_group("mission_terminal")
	for t in terminals:
		if is_instance_valid(t) and global_position.distance_to(t.global_position) <= 58.0:
			_toggle_mission()
			return

func _toggle_mission() -> void:
	var existing = get_node_or_null("MissionWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/MissionWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "MissionWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

func _try_open_loot() -> void:
	for bag in get_tree().get_nodes_in_group("loot_bag"):
		if not is_instance_valid(bag): continue
		if not bag.get("_arc_done"): continue
		if global_position.distance_to(bag.global_position) <= 60.0:
			var existing = get_node_or_null("LootWindow")
			if existing: existing.queue_free()
			var script = load("res://Scripts/LootWindow.gd")
			var win    = CanvasLayer.new()
			win.name   = "LootWindow"
			win.set_script(script)
			add_child(win)
			win.call("init", self, bag)
			return

func _toggle_skills() -> void:
	var existing = get_node_or_null("SkillWindow")
	if existing:
		existing.queue_free()
		return
	var script = load("res://Scripts/BossSkillWindow.gd")
	var win    = CanvasLayer.new()
	win.name   = "SkillWindow"
	win.set_script(script)
	add_child(win)
	win.call("init", self)

# ── INVENTORY / ITEM SYSTEM ───────────────────────────────────
func add_item_to_inventory(item: Dictionary) -> void:
	var copy          = item.duplicate()
	copy["equipped"]  = false
	inventory.append(copy)

func toggle_equip(inv_index: int) -> void:
	if inv_index < 0 or inv_index >= inventory.size():
		return
	var item = inventory[inv_index]
	if item.get("type","") == "mount":
		_toggle_mount(inv_index)
		return
	item["equipped"] = not item.get("equipped", false)
	_recalc_stats()

func _toggle_mount(inv_index: int) -> void:
	var item = inventory[inv_index]
	var already_equipped = item.get("equipped", false)
	# Unequip any other mount first
	for i in inventory.size():
		if inventory[i].get("type","") == "mount" and inventory[i].get("equipped", false):
			inventory[i]["equipped"] = false
	if not already_equipped:
		item["equipped"] = true
		_mount_item = item
		_start_fade(true)   # fade player out, mount in
	else:
		_start_fade(false)  # fade mount out, player in

func _start_fade(mounting: bool) -> void:
	_fade_target_mount = mounting
	_fading_out = true
	_fading_in  = false
	_fade_t     = 1.0

func _tick_fade(delta: float) -> void:
	if _fading_out:
		_fade_t -= delta * 3.0
		if _fade_t <= 0.0:
			_fade_t     = 0.0
			_fading_out = false
			_fading_in  = true
			if _fade_target_mount:
				_mounted = true
				_mount_speed = 0.0
			else:
				_mounted = false
				_mount_item = {}
				_mount_speed = 0.0
				for i in inventory.size():
					if inventory[i].get("type","") == "mount":
						inventory[i]["equipped"] = false
				_recalc_stats()
	elif _fading_in:
		_fade_t += delta * 3.0
		if _fade_t >= 1.0:
			_fade_t    = 1.0
			_fading_in = false

# ── MOUNT PHYSICS ────────────────────────────────────────────
func _tick_mount_physics(delta: float) -> void:
	var max_speed = SPEED * _mount_item.get("speed_mult", 20.0)
	var accel     = max_speed * 1.8   # 0→max in ~0.55s
	var decel     = max_speed * 2.2

	# Throttle W = accelerate, S = brake/reverse
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		_mount_speed = move_toward(_mount_speed, max_speed, accel * delta)
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		_mount_speed = move_toward(_mount_speed, -max_speed * 0.35, decel * delta)
	# No auto-decel — ship holds speed

	# Nose tracks mouse cursor
	var vp        = get_viewport()
	var cam       = vp.get_camera_2d()
	var mouse_scr = vp.get_mouse_position()
	var mouse_world = mouse_scr
	if cam:
		var vp_size  = vp.get_visible_rect().size
		mouse_world  = (mouse_scr - vp_size * 0.5) / cam.zoom + cam.global_position
	var to_mouse  = mouse_world - global_position
	if to_mouse.length() > 5.0:
		_mount_angle = to_mouse.angle()

	var fwd = Vector2(cos(_mount_angle), sin(_mount_angle))
	velocity = fwd * _mount_speed
	move_and_slide()
	queue_redraw()

# ── ANIMATION ─────────────────────────────────────────────────
func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	# Hide character sprite while mounted; show otherwise
	sprite.visible = not _mounted
	sprite.modulate.a = _fade_t if not _mounted else (1.0 - _fade_t)
	if _mounted: return

	# Kiting: moving after firing cancels attack animation for projectile classes
	if _is_attacking and _moving and (character_class == "ranged" or character_class == "mage" or character_class == "medic"):
		_cancel_attack()

	var anim : String
	if _is_attacking:
		anim = "attack_" + _facing
	elif _moving:
		anim = "run_" + _facing
	else:
		anim = "idle_" + _facing

	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	else:
		if sprite.sprite_frames.has_animation("idle_s") and sprite.animation != "idle_s":
			sprite.play("idle_s")
	# Brawler lean — 10° forward tilt when running east/west
	if character_class == "brawler" and _moving and _facing in ["e", "w"]:
		sprite.rotation = deg_to_rad(10.0) if _facing == "e" else deg_to_rad(-10.0)
	else:
		sprite.rotation = 0.0

# ── PLACEHOLDER DRAW ──────────────────────────────────────────
func _draw() -> void:
	# Parked vehicle — drawn at its world position before mounted player draw
	if _has_parked:
		_draw_parked_vehicle()

	# ── Mount vehicle draw ────────────────────────────────────────
	if _mounted or (_fading_out and _fade_target_mount) or (_fading_in and _fade_target_mount):
		var alpha = _fade_t if (_fading_in and _fade_target_mount) else (1.0 - _fade_t if (_fading_out and _fade_target_mount) else 1.0)
		_draw_mount_vehicle(alpha)
		if _mounted and not _fading_out and not _fading_in:
			return   # skip character draw entirely

	# ── Gold aura — PD2-style soft energy cloud around body ──────
	for _aura_item in inventory:
		if _aura_item.get("equipped", false) and _aura_item.get("rarity", "") == "gold":
			var _body_cy = -20.0 if character_class == "brawler" else -12.0
			var _c       = Vector2(0.0, _body_cy)
			# Two independent slow pulses for organic breathing feel
			var _p1v = 0.55 + sin(_aura_t * 1.8) * 0.18
			var _p2v = 0.50 + sin(_aura_t * 2.5 + 1.2) * 0.14
			# ── Filled cloud polygons (size reduced 15%) ──────────────
			const _N : int = 28
			var _outer_pts = PackedVector2Array()
			var _mid_pts   = PackedVector2Array()
			var _inner_pts = PackedVector2Array()
			for _i in _N:
				var _a      = float(_i) / float(_N) * TAU
				var _wobble = sin(_a * 3.0 + _aura_t * 2.2) * 2.1 + sin(_a * 5.0 - _aura_t * 1.4) * 1.3
				var _orx    = 17.0 + _wobble   # was 20
				var _ory    = 22.0 + _wobble   # was 26
				_outer_pts.append(_c + Vector2(cos(_a) * _orx,  sin(_a) * _ory))
				_mid_pts.append(_c   + Vector2(cos(_a) * 12.8,  sin(_a) * 16.2))  # was 15/19
				_inner_pts.append(_c + Vector2(cos(_a) * 7.7,   sin(_a) * 9.4))   # was 9/11
			draw_colored_polygon(_outer_pts, Color(0.90, 0.62, 0.04, _p1v * 0.18))
			draw_colored_polygon(_mid_pts,   Color(1.00, 0.80, 0.10, _p2v * 0.32))
			draw_colored_polygon(_inner_pts, Color(1.00, 0.95, 0.55, _p1v * 0.28))
			draw_circle(_c, 4.3, Color(1.00, 0.98, 0.75, _p2v * 0.22))
			# ── Tendrils: burst from center outward, fade fast ────────
			# Each tendril has its own staggered period so they fire at different times.
			# _life goes 0→1 over the period; tendril shoots out and fades before 1.0.
			const _T_COUNT  : int   = 16   # doubled from 8
			const _T_PERIOD : float = 0.55  # seconds per burst cycle per tendril
			const _T_FADE   : float = 0.65  # fraction of period where it's still visible
			const _T_REACH  : float = 18.0  # max outward distance (px)
			for _ti in _T_COUNT:
				# Stagger start times so they don't all fire at once
				var _offset  = float(_ti) / float(_T_COUNT) * _T_PERIOD
				var _life    = fmod(_aura_t + _offset, _T_PERIOD) / _T_PERIOD  # 0→1
				if _life > _T_FADE:
					continue   # dead — skip drawing
				var _norm    = _life / _T_FADE            # 0→1 normalized within visible window
				var _talpha  = (1.0 - _norm) * 0.80      # bright at birth, gone by end
				# Each tendril fires in a fixed direction (spread evenly + small hash offset)
				var _tangle  = float(_ti) / float(_T_COUNT) * TAU + float(_ti) * 0.37
				var _tdir    = Vector2(cos(_tangle), sin(_tangle))
				# Shoot from near the cloud edge outward
				var _tstart  = _norm * 8.0               # base moves out too (not stuck at center)
				var _tend    = _tstart + _norm * _T_REACH
				var _tp0     = _c + _tdir * _tstart
				var _tp1     = _c + _tdir * _tend
				draw_line(_tp0, _tp1, Color(1.00, 0.88, 0.25, _talpha), 1.4)
			# ── Sparkles: burst from center, scatter outward, vanish ──
			const _S_COUNT  : int   = 10   # doubled from 5
			const _S_PERIOD : float = 0.40  # faster cycle than tendrils
			const _S_FADE   : float = 0.70
			const _S_REACH  : float = 22.0
			for _si in _S_COUNT:
				var _soffset = float(_si) / float(_S_COUNT) * _S_PERIOD
				var _slife   = fmod(_aura_t * 1.3 + _soffset, _S_PERIOD) / _S_PERIOD
				if _slife > _S_FADE:
					continue
				var _snorm   = _slife / _S_FADE
				var _salpha  = (1.0 - _snorm) * 0.95
				var _sangle  = float(_si) / float(_S_COUNT) * TAU + float(_si) * 0.61
				var _sdir    = Vector2(cos(_sangle), sin(_sangle))
				var _sdist   = _snorm * _S_REACH
				var _sp2     = _c + _sdir * _sdist
				var _ssz     = lerpf(2.2, 0.4, _snorm)   # large at birth, tiny at death
				draw_circle(_sp2, _ssz, Color(1.00, 0.97, 0.60, _salpha))
				# Tiny bright hot-white core on young sparkles
				if _snorm < 0.35:
					draw_circle(_sp2, _ssz * 0.45, Color(1.00, 1.00, 1.00, _salpha * 0.80))
			break

	# Nameplate — always visible above head (zoom-compensated for crisp rendering)
	if character_name.length() > 0:
		var font    = load("res://Assets/Fonts/Archivo_Black/ArchivoBlack-Regular.ttf")
		var font_sz = 7
		var name_y  = -46.0 if character_class == "brawler" else -28.0
		# Counter-scale so text rasterizes at exact screen-pixel size
		var ct_sc   = get_canvas_transform().get_scale()
		var inv     = Vector2(1.0 / ct_sc.x, 1.0 / ct_sc.y)
		var rend_sz = maxi(1, int(round(font_sz * ct_sc.x)))
		var text_w  = font.get_string_size(character_name, HORIZONTAL_ALIGNMENT_LEFT, -1, rend_sz).x
		draw_set_transform(Vector2(0, name_y), 0.0, inv)
		var dx = -text_w * 0.5
		# Black outline — draw at 1px offsets in 8 directions for crisp edge
		for ox in [-1, 0, 1]:
			for oy in [-1, 0, 1]:
				if ox == 0 and oy == 0: continue
				draw_string(font, Vector2(dx + ox, oy), character_name,
					HORIZONTAL_ALIGNMENT_LEFT, -1, rend_sz, Color(0.0, 0.0, 0.0, 1.0))
		draw_string(font, Vector2(dx, 0), character_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, rend_sz, Color(0.90, 0.95, 1.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		return

	var col = _get_class_color()
	draw_circle(Vector2.ZERO, 14.0, col)
	draw_circle(Vector2.ZERO, 11.0, col.lightened(0.25))
	var fwd = _facing_to_vec() * 10.0
	draw_circle(fwd, 4.0, Color.WHITE)
	var shadow_pts := PackedVector2Array()
	for i in 12:
		var a = float(i) / 12.0 * TAU
		shadow_pts.append(Vector2(cos(a) * 14.0, sin(a) * 5.0) + Vector2(0, 16))
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.22))

func _get_class_color() -> Color:
	match character_class:
		"melee":   return Color(0.9,  0.35, 0.20)
		"ranged":  return Color(0.35, 0.75, 0.90)
		"mage":    return Color(0.70, 0.40, 1.00)
		"brawler": return Color(0.40, 0.85, 0.30)
	return Color.WHITE

func _facing_8dir(v: Vector2) -> String:
	var angle = v.angle()  # -PI..PI, 0 = right
	# Divide circle into 8 sectors of 45°, offset by 22.5°
	var deg = fmod(rad_to_deg(angle) + 360.0 + 22.5, 360.0)
	var sector = int(deg / 45.0)
	match sector:
		0: return "e"
		1: return "se"
		2: return "s"
		3: return "sw"
		4: return "w"
		5: return "nw"
		6: return "n"
		7: return "ne"
	return "s"

func _facing_to_vec() -> Vector2:
	match _facing:
		"n": return Vector2(0, -1)
		"s": return Vector2(0,  1)
		"e": return Vector2(1,  0)
		"w": return Vector2(-1, 0)
	return Vector2(0, 1)

# ── AUTO-ATTACK ───────────────────────────────────────────────
func _tick_auto_attack(delta: float) -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return
	# Drop target if it left the targetable group (e.g. duel ended)
	if not _current_target.is_in_group("targetable"):
		_current_target = null
		return

	var attack_interval : float
	var attack_range    : float
	match character_class:
		"melee":
			attack_interval = 2.0
			attack_range    = 130.0
		"ranged":
			attack_interval = 2.5
			attack_range    = 700.0
		"mage":
			attack_interval = 4.0
			attack_range    = 700.0
		"brawler":
			attack_interval = 2.0
			attack_range    = 130.0
		"medic":
			attack_interval = 3.0
			attack_range    = 500.0
		_:
			attack_interval = 2.0
			attack_range    = 130.0

	# AGI (+ item AGI) gives +5% attack speed per point
	attack_interval /= (1.0 + (attr_agi + _item_agi) * 0.05)

	var dist = global_position.distance_to(_current_target.global_position)
	if dist > attack_range:
		_cancel_attack()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_do_attack()

func _do_attack() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		return

	match character_class:
		"melee":   _move_lock_timer = 0.0
		"ranged":  _move_lock_timer = 0.0
		"mage":    _move_lock_timer = 0.0
		"brawler": _move_lock_timer = 0.0
		"medic":   _move_lock_timer = 0.0

	var to_target = _current_target.global_position - global_position
	if character_class == "melee" or character_class == "medic" or character_class == "brawler":
		_facing = _facing_8dir(to_target)
	elif absf(to_target.x) >= absf(to_target.y):
		_facing = "e" if to_target.x > 0.0 else "w"
	else:
		_facing = "s" if to_target.y > 0.0 else "n"

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var anim_name = "attack_" + _facing
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
			_is_attacking = true
			if not sprite.animation_finished.is_connected(_on_attack_anim_done):
				sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)

	var dmg : float
	if _one_shot_kill:
		var target_hp = _current_target.get("hp")
		dmg = target_hp if target_hp != null else 99999.0
		_one_shot_kill = false
	else:
		dmg = _get_attack_damage()

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")

	if character_class == "medic":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		# Determine if target is friendly (party member / remote player) or enemy
		var is_heal = _current_target.is_in_group("party_member") or _current_target.is_in_group("friendly")
		if arena and arena.has_method("spawn_canister"):
			arena.spawn_canister(spawn_pos, _current_target, dmg, is_heal)
	elif character_class == "mage":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		if arena and arena.has_method("spawn_fireball"):
			arena.spawn_fireball(spawn_pos, _current_target, dmg)
	elif character_class == "ranged":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		# Check for equipped rifle — passes glow flag and spawns shoot visual
		# Pick glow color from equipped rifle rarity (zero alpha = no glow)
		var rifle_glow_col = Color(0, 0, 0, 0)
		for item in inventory:
			if item.get("equipped", false) and item.get("type", "") == "rifle":
				match item.get("rarity", ""):
					"white": rifle_glow_col = Color(0.92, 0.95, 1.00)
					"blue":  rifle_glow_col = Color(0.35, 0.72, 1.00)
					"gold":  rifle_glow_col = Color(1.00, 0.82, 0.15)
				break
		if arena and arena.has_method("spawn_bullet"):
			var bullet = arena.spawn_bullet(spawn_pos, _current_target, dmg)
			if bullet != null and rifle_glow_col.a > 0.0:
				bullet.set("rifle_glow", rifle_glow_col)
		if _snd_rifle_shot != null: _snd_rifle_shot.play()
		_try_spawn_weapon_swing()
	else:
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(dmg)
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_current_target.global_position, dmg, _get_dmg_color())
		if arena and arena.has_method("spawn_melee_hit"):
			var aim = _current_target.get_target_position() if _current_target.has_method("get_target_position") else _current_target.global_position
			var hit_pos = aim + Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, 18.0))
			arena.spawn_melee_hit(hit_pos, _get_dmg_color())
		if _snd_melee_hits.size() > 0:
			_snd_melee_hits[randi() % _snd_melee_hits.size()].play()
		# Weapon swing visual for any equipped knife
		_try_spawn_weapon_swing()

func _try_spawn_weapon_swing() -> void:
	for item in inventory:
		var t = item.get("type", "")
		if item.get("equipped", false) and (t == "knife" or t == "rifle"):
			var script = load("res://Scripts/BossWeaponSwing.gd")
			var swing  = Node2D.new()
			swing.set_script(script)
			swing.position = Vector2(0, -15)
			add_child(swing)
			swing.call("init", item, _facing)
			var _relay = get_node_or_null("/root/Relay")
			if _relay and _relay.has_method("send_game_data"):
				_relay.send_game_data({
					"cmd":    "swing",
					"facing": _facing,
					"itype":  item.get("type",   "knife"),
					"rarity": item.get("rarity", "white"),
				})
			return   # only one swing per attack

func _tick_skills(delta: float) -> void:
	# Sprint
	if _sprint_active:
		_sprint_timer -= delta
		var _bb2 = get_node_or_null("BuffBar")
		if _bb2 and _bb2.has_method("update_buff"):
			_bb2.call("update_buff", "sprint", _sprint_timer)
		if _sprint_timer <= 0.0:
			_sprint_active = false
			if _bb2 and _bb2.has_method("remove_buff"):
				_bb2.call("remove_buff", "sprint")

	# Sensu Bean healing
	if _sensu_active:
		_sensu_timer -= delta
		var heal_rate = max_hp / SENSU_DURATION
		hp = minf(hp + heal_rate * delta, max_hp)
		var mp_rate = max_mp / SENSU_DURATION
		mp = minf(mp + mp_rate * delta, max_mp)
		var _bb_st = get_node_or_null("BuffBar")
		if _bb_st and _bb_st.has_method("update_buff"):
			_bb_st.call("update_buff", "sensu_bean", _sensu_timer)
		if _sensu_timer <= 0.0:
			_sensu_active = false
			if _bb_st and _bb_st.has_method("remove_buff"):
				_bb_st.call("remove_buff", "sensu_bean")

func activate_skill(skill_id: String) -> void:
	match skill_id:
		"sprint":
			_sprint_active = true
			_sprint_timer  = SPRINT_DURATION
			var _bb = get_node_or_null("BuffBar")
			if _bb and _bb.has_method("add_buff"):
				_bb.call("add_buff", {
					"id": "sprint", "icon": "sprint",
					"label": "Sprint", "duration": SPRINT_DURATION,
					"color": Color(0.35, 0.80, 1.00)
				})
		"sensu_bean":
			_sensu_active = true
			_sensu_timer  = SENSU_DURATION
			var _bb_s = get_node_or_null("BuffBar")
			if _bb_s and _bb_s.has_method("add_buff"):
				_bb_s.call("add_buff", {
					"id": "sensu_bean", "icon": "sensu",
					"label": "Sensu Bean", "duration": SENSU_DURATION,
					"color": Color(0.25, 0.85, 0.40)
				})
		"triple_strike":
			if _current_target != null and is_instance_valid(_current_target):
				_triple_active    = true
				_triple_hits_left = 3
				_fire_triple_strike()

func _fire_triple_strike() -> void:
	if not _triple_active or _triple_hits_left <= 0:
		_triple_active = false
		return
	if _current_target == null or not is_instance_valid(_current_target):
		_triple_active = false
		return

	# Play (or restart) the attack animation for this hit.
	var ts_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if ts_sprite and ts_sprite.sprite_frames:
		var ts_anim = "attack_" + _facing
		if ts_sprite.sprite_frames.has_animation(ts_anim):
			# Disconnect any pending done-callback so it doesn't fire mid-sequence
			if ts_sprite.animation_finished.is_connected(_on_attack_anim_done):
				ts_sprite.animation_finished.disconnect(_on_attack_anim_done)
			ts_sprite.stop()
			ts_sprite.play(ts_anim)
			_is_attacking = true
			# Only hook cleanup on the last hit so _is_attacking clears correctly
			if _triple_hits_left == 1:
				ts_sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	var dmg = _get_attack_damage()
	# All classes fire their natural attack type
	if character_class == "medic":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		var is_heal = _current_target.is_in_group("party_member") or _current_target.is_in_group("friendly")
		if arena and arena.has_method("spawn_canister"):
			arena.spawn_canister(spawn_pos, _current_target, dmg, is_heal)
	elif character_class == "mage":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		if arena and arena.has_method("spawn_fireball"):
			arena.spawn_fireball(spawn_pos, _current_target, dmg)
	elif character_class == "ranged":
		var spawn_pos = global_position + _facing_to_vec() * 18.0
		if arena and arena.has_method("spawn_bullet"):
			var bullet = arena.spawn_bullet(spawn_pos, _current_target, dmg)
			var rifle_glow_col = Color(0,0,0,0)
			for item in inventory:
				if item.get("equipped", false) and item.get("type","") == "rifle":
					match item.get("rarity",""):
						"white": rifle_glow_col = Color(0.92,0.95,1.00)
						"blue":  rifle_glow_col = Color(0.35,0.72,1.00)
						"gold":  rifle_glow_col = Color(1.00,0.82,0.15)
					break
			if bullet != null and rifle_glow_col.a > 0.0:
				bullet.set("rifle_glow", rifle_glow_col)
		if _snd_rifle_shot != null: _snd_rifle_shot.play()
	else:
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(dmg)
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_current_target.global_position, dmg, _get_dmg_color())
		if arena and arena.has_method("spawn_melee_hit"):
			var aim = _current_target.get_target_position() if _current_target.has_method("get_target_position") else _current_target.global_position
			var hit_pos = aim + Vector2(randf_range(-12.0,12.0), randf_range(-18.0,18.0))
			arena.spawn_melee_hit(hit_pos, _get_dmg_color())
		if _snd_melee_hits.size() > 0:
			_snd_melee_hits[randi() % _snd_melee_hits.size()].play()
		_try_spawn_weapon_swing()
	_triple_hits_left -= 1
	if _triple_hits_left > 0:
		# Fire next hit after a short delay
		get_tree().create_timer(0.18).timeout.connect(_fire_triple_strike)
	else:
		_triple_active = false

func _get_attack_damage() -> float:
	var eff_str = attr_str + _item_str
	var eff_agi = attr_agi + _item_agi
	var eff_int = attr_int + _item_int
	var eff_spi = attr_spi + _item_spi

	var base : float
	match character_class:
		"melee":
			base = randf_range(18.0, 28.0) + eff_str * 5.0
		"ranged":
			base = randf_range(12.0, 20.0)
		"mage":
			base = randf_range(22.0, 35.0)
			base *= (1.0 + eff_int * 0.05)
			base += eff_spi * 5.0
		"brawler":
			base = randf_range(20.0, 32.0) + eff_str * 5.0
		"medic":
			base = 25.0 + eff_spi * 3.0
		_:
			base = 10.0

	# AGI crit: +2% crit chance per point, crits deal 1.5x
	if randf() < eff_agi * 0.02:
		base *= 1.5

	return base

func _get_dmg_color() -> Color:
	match character_class:
		"melee":   return Color(1.0, 0.55, 0.1)
		"ranged":  return Color(0.4, 0.95, 1.0)
		"mage":    return Color(0.9, 0.5,  1.0)
		"brawler": return Color(1.0, 0.55, 0.1)
		"medic":   return Color(0.30, 0.85, 0.95)
	return Color.WHITE

func _on_attack_anim_done() -> void:
	_is_attacking = false

func _cancel_attack() -> void:
	_is_attacking = false
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite:
		if sprite.animation_finished.is_connected(_on_attack_anim_done):
			sprite.animation_finished.disconnect(_on_attack_anim_done)

# ── TARGET SYSTEM ─────────────────────────────────────────────
func _refresh_target_candidates() -> void:
	var all_targets = get_tree().get_nodes_in_group("targetable")

	var fwd = _facing_to_vec()
	var cone_hits   : Array = []
	var circle_hits : Array = []

	for node in all_targets:
		if not is_instance_valid(node):
			continue
		if node == self:
			continue
		var to_node = node.global_position - global_position
		var dist    = to_node.length()

		if dist < TARGET_CONE_RANGE:
			var angle_diff = fwd.angle_to(to_node.normalized())
			if absf(angle_diff) < deg_to_rad(TARGET_CONE_ANGLE):
				cone_hits.append({"node": node, "dist": dist})

		if dist < TARGET_CIRCLE_RANGE:
			circle_hits.append({"node": node, "dist": dist})

	cone_hits.sort_custom(func(a, b): return a.dist < b.dist)
	circle_hits.sort_custom(func(a, b): return a.dist < b.dist)

	var new_candidates : Array = []
	for h in cone_hits:
		new_candidates.append(h.node)
	for h in circle_hits:
		if not new_candidates.has(h.node):
			new_candidates.append(h.node)

	_target_candidates = new_candidates

	if _current_target != null:
		if not is_instance_valid(_current_target) or not _target_candidates.has(_current_target):
			_current_target = null
			_target_idx = -1
		else:
			_target_idx = _target_candidates.find(_current_target)

func _cycle_target() -> void:
	if _target_candidates.is_empty():
		_current_target = null
		return
	_target_idx = (_target_idx + 1) % _target_candidates.size()
	_current_target = _target_candidates[_target_idx]
	_attack_timer = 0.5

# ── PUBLIC INTERFACE ──────────────────────────────────────────
func get_current_target() -> Node:
	return _current_target

func is_targeted(node: Node) -> bool:
	return node == _current_target

# ── DAMAGE / DEATH ────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _dying:
		return
	# STR (+ item STR): +5% damage reduction per point
	var reduction = (attr_str + _item_str) * 0.05
	amount *= maxf(0.0, 1.0 - reduction)
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	_current_target = null
	var _relay = get_node_or_null("/root/Relay")
	if _relay and _relay.has_method("send_game_data"):
		_relay.send_game_data({"cmd": "death"})
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("on_player_died"):
		arena.call("on_player_died")
