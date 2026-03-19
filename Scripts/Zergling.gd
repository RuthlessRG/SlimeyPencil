extends Node2D

# ============================================================
#  Zergling.gd — Beyond the Veil | Insectoid Swarm Enemy
#  Drawn entirely in code. No sprites needed.
#
#  Inspired by StarCraft zerglings and Starship Troopers bugs:
#  fast, clawing, pack hunters. Designed for LARGE hordes.
#
#  Drop into scene OR spawn from a ZerglingSpawner node.
#  Joins "enemy" and "targetable" groups automatically.
#
#  State machine:
#    IDLE    — skittering in place, antennae twitching
#    AGGRO   — spotted player, rapid scuttle toward them
#    ATTACK  — slashing with foreclaws
#    STUNNED — flinching after a hit
#    RETURN  — lost player, scurrying back to spawn point
#    LEAP    — pounce lunge toward player (special)
# ============================================================

# ── TUNING ──────────────────────────────────────────────────
const MAX_HP            = 32.0    # dies in ~3 hits — meant for large packs
const MOVE_SPEED        = 115.0   # faster than player — swarms overwhelm
const AGGRO_RANGE       = 560.0   # px — big range, hunts players from across the room
const ATTACK_RANGE      = 36.0    # px — very close, clawing distance
const DISENGAGE_RANGE   = 700.0   # px — must be > AGGRO_RANGE or they never close in
const ATTACK_DAMAGE_MIN = 5
const ATTACK_DAMAGE_MAX = 11
const ATTACK_CD         = 0.75    # fast attack cadence for a swarm feel
const STUN_DURATION     = 0.18    # brief stun — these things are relentless
const KNOCKBACK_FRICTION = 340.0

# Leap pounce
const LEAP_RANGE        = 130.0   # px — triggers leap from this range
const LEAP_COOLDOWN     = 4.0     # seconds between leaps
const LEAP_SPEED        = 420.0   # fast lunge
const LEAP_DURATION     = 0.22    # seconds of leap flight

# Pack behaviour: zerglings get angrier when near other zerglings
const PACK_RANGE        = 80.0    # px — counts nearby friendlies
const PACK_SPEED_BONUS  = 0.22    # +22% speed per nearby zergling (max 2 counted)

# ── TARGET-FRAME FIELDS (read by UI.gd) ─────────────────────
var hp              : float  = MAX_HP
var max_hp          : float  = MAX_HP
var mp              : float  = 0.0
var max_mp          : float  = 0.0
var character_name  : String = "Zergling"
var character_class : String = "Zerg Swarm"
var level           : int    = 1

# ── INTERNAL STATE ───────────────────────────────────────────
enum State { IDLE, AGGRO, ATTACK, STUNNED, RETURN, LEAP }
var _state            : State   = State.IDLE
var _spawn_pos        : Vector2 = Vector2.ZERO
var _attack_timer     : float   = 0.0
var _stun_timer       : float   = 0.0
var _hit_flash        : float   = 0.0
var _hitlag_timer     : float   = 0.0
var _is_dead          : bool    = false
var _death_timer      : float   = 0.0
var _knockback_vel    : Vector2 = Vector2.ZERO
var _facing_right     : bool    = true

# Leap state
var _leap_timer       : float   = 0.0   # counts down during leap flight
var _leap_cd          : float   = 0.0   # cooldown between leaps
var _leap_vel         : Vector2 = Vector2.ZERO

# Smooth movement — AI sets direction at 20 Hz, _process applies it every frame
var _move_vel         : Vector2 = Vector2.ZERO

# Animation counters
var _leg_phase        : float   = 0.0   # scurrying legs cycle
var _idle_twitch      : float   = 0.0   # antenna/body micro-twitch
var _claw_swing       : float   = 0.0   # attack claw animation

# ── PERFORMANCE CACHE ─────────────────────────────────────────
# Avoid scanning groups every frame — huge cost with many enemies
var _player_cache     : Node  = null   # cached player ref
var _pack_bonus_cache : float = 1.0    # cached pack speed multiplier
var _pack_bonus_timer : float = 0.0    # countdown to next pack scan
var _ai_accum         : float = 0.0   # accumulated delta for throttled AI
const PACK_SCAN_INTERVAL = 0.50       # recalc pack bonus twice per second
const AI_TICK_INTERVAL   = 0.05       # AI runs at 20 Hz instead of 60 Hz

# Blood/gore splat on death
var _splat_pts        : Array   = []    # pre-randomized gore splatter

const HIT_FLASH_TIME  = 0.10
const DEATH_TIME      = 0.85   # dies and fades fast — these are cannon fodder

# ── COLORS ───────────────────────────────────────────────────
# Chitin exoskeleton: deep purple-black with iridescent edges
const C_CHITIN        = Color(0.07, 0.04, 0.10)    # near-black carapace
const C_CHITIN_EDGE   = Color(0.30, 0.08, 0.45)    # purple iridescence
const C_CHITIN_SHINE  = Color(0.60, 0.25, 0.80, 0.5) # specular highlight
const C_FLESH         = Color(0.44, 0.10, 0.08)    # dark meat red where plates meet
const C_CLAW          = Color(0.75, 0.65, 0.40)    # bone-yellow claws
const C_CLAW_TIP      = Color(0.98, 0.92, 0.70)    # bright tip
const C_EYE_GLOW      = Color(0.90, 0.12, 0.02)    # red compound eyes
const C_EYE_INNER     = Color(1.00, 0.55, 0.10)    # orange iris
const C_SPIT          = Color(0.35, 0.88, 0.10, 0.8) # acid green spittle
const C_ACID_TRAIL    = Color(0.20, 0.70, 0.02, 0.45)
const C_SHADOW        = Color(0.00, 0.00, 0.00, 0.18)
const C_HP_FULL       = Color(0.18, 0.72, 0.26)
const C_HP_LOW        = Color(0.82, 0.16, 0.14)
const C_HP_BG         = Color(0.04, 0.02, 0.04)
const C_BLOOD         = Color(0.50, 0.04, 0.04, 0.80)
const C_BLOOD2        = Color(0.72, 0.10, 0.02, 0.60)

# ============================================================
#  READY
# ============================================================

func _ready() -> void:
	_spawn_pos = global_position
	add_to_group("enemy")
	add_to_group("targetable")
	z_index = 2
	_leap_cd = randf_range(0.0, LEAP_COOLDOWN * 0.5)
	# Stagger pack-scan timers so a swarm of zerglings doesn't all scan on the same frame
	_pack_bonus_timer = randf_range(0.0, PACK_SCAN_INTERVAL)
	# Cache player immediately so the first AI tick doesn't need a group scan
	var pl = get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		_player_cache = pl[0]
	# Pre-randomize gore splat for death
	for i in 14:
		_splat_pts.append({
			"offset": Vector2(randf_range(-22.0, 22.0), randf_range(-18.0, 18.0)),
			"radius": randf_range(1.5, 5.0),
			"col":    C_BLOOD if randf() < 0.6 else C_BLOOD2,
		})

func get_display_name() -> String:
	return character_name

# ============================================================
#  PUBLIC — DAMAGE
# ============================================================

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash  = 1.0
	_stun_timer = STUN_DURATION
	_state      = State.STUNNED
	if hp <= 0.0:
		_die()

func apply_knockback(dir: Vector2) -> void:
	if _is_dead:
		return
	_knockback_vel = dir
	_stun_timer    = maxf(_stun_timer, STUN_DURATION * 1.8)
	# Cancel leap if mid-air
	if _state == State.LEAP:
		_state     = State.STUNNED
		_leap_timer = 0.0

func apply_knockdown_state(duration: float) -> void:
	if _is_dead:
		return
	_stun_timer = maxf(_stun_timer, duration)
	_state      = State.STUNNED
	_knockback_vel = Vector2.ZERO

func start_hitlag(duration: float) -> void:
	_hitlag_timer = maxf(_hitlag_timer, duration)

func _award_kill_reward() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var killer : Node = null
	for p in players:
		if not is_instance_valid(p): continue
		if p.get("_current_target") == self:
			killer = p; break
		if killer == null or global_position.distance_to(p.global_position) < global_position.distance_to(killer.global_position):
			killer = p
	if killer != null and killer.has_method("add_exp"):
		killer.call("add_exp", 5.0)
	if randf() < 0.30:
		var loot_script = load("res://Scripts/GroundLoot.gd")
		if loot_script:
			var loot = Node2D.new(); loot.set_script(loot_script)
			get_tree().current_scene.add_child(loot)
			loot.global_position = global_position
			loot.call("init", randi_range(1, 5), 0.0)
	# Gear drop
	var item_script = load("res://Scripts/LootTable.gd")
	if item_script and killer != null and killer.has_method("add_item_to_inventory"):
		var item = item_script.roll_drop("zergling")
		if not item.is_empty():
			killer.call("add_item_to_inventory", item)

func _die() -> void:
	_award_kill_reward()
	_is_dead       = true
	_death_timer   = 0.0
	_knockback_vel = Vector2.ZERO

# ============================================================
#  PROCESS
# ============================================================

func _process(delta: float) -> void:
	if _is_dead:
		_death_timer += delta
		if _death_timer >= DEATH_TIME:
			queue_free()
		queue_redraw()
		return

	if _hitlag_timer > 0.0:
		_hitlag_timer -= delta
	else:
		_leg_phase   += delta * (if_moving() * 18.0 + 4.0)
		_idle_twitch += delta * 2.2

	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta / HIT_FLASH_TIME)

	if _knockback_vel.length_squared() > 1.0:
		position      += _knockback_vel * delta
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	# Per-frame smooth movement — direction set by 20 Hz AI, applied at full FPS
	if _state == State.LEAP:
		position += _leap_vel * delta
	elif _state == State.AGGRO or _state == State.RETURN:
		position += _move_vel * delta

	if _leap_cd > 0.0:
		_leap_cd -= delta

	# Throttle pack scan — runs at 2 Hz instead of 60 Hz
	_pack_bonus_timer -= delta
	if _pack_bonus_timer <= 0.0:
		_pack_bonus_timer = PACK_SCAN_INTERVAL
		_recalc_pack_bonus()

	# Throttle AI — runs at 20 Hz, accumulating real delta so movement stays accurate
	_ai_accum += delta
	if _ai_accum >= AI_TICK_INTERVAL:
		_tick_ai(_ai_accum)
		_ai_accum = 0.0

	# Only redraw when close enough to the player to be on screen.
	# Skipping queue_redraw() for distant zerglings avoids running ~80
	# GDScript draw calls per zergling per frame for ones you can't see.
	var _draw_dist_sq = 900.0 * 900.0   # ~900px radius around player
	if _player_cache != null and is_instance_valid(_player_cache):
		if global_position.distance_squared_to(_player_cache.global_position) < _draw_dist_sq:
			queue_redraw()
	else:
		queue_redraw()

func if_moving() -> float:
	return 1.0 if _state in [State.AGGRO, State.RETURN, State.LEAP] else 0.0

# ============================================================
#  AI
# ============================================================

func _recalc_pack_bonus() -> void:
	var count = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		if e.get("character_class") == "Zerg Swarm":
			if global_position.distance_to(e.global_position) < PACK_RANGE:
				count += 1
				if count >= 2:
					break
	_pack_bonus_cache = 1.0 + count * PACK_SPEED_BONUS

func _tick_ai(delta: float) -> void:
	var player = _find_player()
	var pack_bonus = _pack_bonus_cache

	match _state:
		State.IDLE:
			if player:
				if global_position.distance_to(player.global_position) < AGGRO_RANGE:
					_state = State.AGGRO

		State.AGGRO:
			if player:
				var dist = global_position.distance_to(player.global_position)
				if dist > DISENGAGE_RANGE:
					_state = State.RETURN
				elif dist <= ATTACK_RANGE:
					_state = State.ATTACK
					_claw_swing = 0.0
				elif dist <= LEAP_RANGE and _leap_cd <= 0.0:
					_start_leap(player)
				else:
					_move_toward(player.global_position, pack_bonus)
			else:
				_state = State.RETURN

		State.ATTACK:
			if player:
				var dist = global_position.distance_to(player.global_position)
				_facing_right = player.global_position.x > global_position.x
				_claw_swing   += delta * 8.0
				if dist > ATTACK_RANGE * 1.8:
					_state = State.AGGRO
				else:
					_attack_timer -= delta
					if _attack_timer <= 0.0:
						_do_attack(player)
						_attack_timer = ATTACK_CD
			else:
				_state = State.RETURN

		State.STUNNED:
			_stun_timer -= delta
			if _stun_timer <= 0.0:
				_state = State.AGGRO if _find_player() != null else State.RETURN

		State.RETURN:
			var dist_home = global_position.distance_to(_spawn_pos)
			if dist_home < 8.0:
				position = _spawn_pos
				_state   = State.IDLE
			else:
				_move_toward(_spawn_pos, 1.0)

		State.LEAP:
			_leap_timer -= delta
			if _leap_timer <= 0.0:
				_state = State.ATTACK if player and global_position.distance_to(player.global_position) < ATTACK_RANGE * 2.5 else State.AGGRO
				if _state == State.ATTACK and player:
					_do_attack(player)

func _move_toward(target_pos: Vector2, speed_mult: float = 1.0) -> void:
	var dir       = (target_pos - global_position).normalized()
	_move_vel     = dir * MOVE_SPEED * speed_mult
	_facing_right = dir.x >= 0.0

func _start_leap(player: Node) -> void:
	_state      = State.LEAP
	_leap_timer = LEAP_DURATION
	_leap_cd    = LEAP_COOLDOWN
	var dir     = (player.global_position - global_position).normalized()
	_facing_right = dir.x >= 0.0
	_leap_vel   = dir * LEAP_SPEED

func _do_attack(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	_facing_right = player.global_position.x > global_position.x
	var dmg       = randi_range(ATTACK_DAMAGE_MIN, ATTACK_DAMAGE_MAX)
	if player.get("stats") != null:
		player.stats.take_damage(float(dmg))
	elif player.has_method("take_damage"):
		player.take_damage(float(dmg))
	if player.has_method("start_hitlag"):
		player.start_hitlag(0.15)

func _find_player() -> Node:
	if _player_cache != null and is_instance_valid(_player_cache):
		return _player_cache
	# Cache miss — scan once and store
	var players = get_tree().get_nodes_in_group("player")
	_player_cache = players[0] if players.size() > 0 else null
	return _player_cache

# ============================================================
#  DRAW — detailed insectoid creature
# ============================================================

func _draw() -> void:
	var flash = _hit_flash
	var t_ms  = Time.get_ticks_msec() * 0.001
	var flip  = -1.0 if not _facing_right else 1.0

	# Scale all body drawing to 60% — zerglings are small and fast
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.6, 0.6))

	# ── Death: splat and fade ────────────────────────────────
	if _is_dead:
		var dt = clampf(_death_timer / DEATH_TIME, 0.0, 1.0)
		var alpha = 1.0 - dt
		# Body crumples and flattens
		var squash = 1.0 - dt * 0.75
		var splat  = dt
		_draw_death_splat(flash, alpha, squash, splat)
		return

	# Animation values
	var leg_t     = _leg_phase
	var twitch    = sin(_idle_twitch * 3.1) * (1.2 if _state == State.IDLE else 0.3)
	var is_moving = _state in [State.AGGRO, State.RETURN, State.LEAP]
	var bob       = absf(sin(leg_t)) * (3.5 if is_moving else 0.8)
	var lean      = (0.0 if not is_moving else flip * deg_to_rad(12.0))  # lean forward when running

	# Leap: dramatic arc pose
	var leap_stretch = 0.0
	if _state == State.LEAP:
		var lp = clampf(1.0 - _leap_timer / LEAP_DURATION, 0.0, 1.0)
		leap_stretch = sin(lp * PI) * 8.0

	var base = Vector2(0.0, 2.0 + bob)

	# ── Ground shadow ────────────────────────────────────────
	var shadow_w = 14.0 + leap_stretch * 0.5
	_draw_ellipse(Vector2(0, 20), shadow_w, 4.5, Color(0, 0, 0, 0.18 - leap_stretch * 0.01))

	# ── 6 Scurrying legs (3 per side, classic insect) ────────
	_draw_legs(base, flip, leg_t, is_moving, flash, leap_stretch)

	# ── Abdomen (rear segment, bulbous) ──────────────────────
	_draw_abdomen(base, flip, lean, flash, twitch)

	# ── Thorax (middle, hunched) ─────────────────────────────
	_draw_thorax(base, flip, lean, flash, bob, leap_stretch)

	# ── Foreclaws (raptorial killing limbs) ──────────────────
	_draw_foreclaws(base, flip, flash, leap_stretch)

	# ── Head + mandibles ─────────────────────────────────────
	_draw_head(base, flip, lean, flash, twitch, bob)

	# ── Compound eyes ────────────────────────────────────────
	_draw_eyes(base, flip, lean, flash)

	# ── Antennae ─────────────────────────────────────────────
	_draw_antennae(base, flip, lean, twitch, flash)

	# ── Acid spittle trail during leap ───────────────────────
	if _state == State.LEAP:
		for i in 5:
			var off = Vector2(-flip * i * 7.0, randf_range(-2.0, 2.0))
			var a   = 0.5 - i * 0.08
			draw_circle(base + off, 1.5 - i * 0.2, Color(C_SPIT.r, C_SPIT.g, C_SPIT.b, a))

	# Reset scale — HP bar and indicators drawn at natural size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── HP bar ───────────────────────────────────────────────
	var bar_alpha = clampf(1.0 - hp / MAX_HP + 0.25, 0.0, 1.0)
	if bar_alpha > 0.02:
		var bw = 30.0
		var bh = 3.5
		var bx = -bw * 0.5
		var by = -44.0
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, bh + 2), Color(C_HP_BG.r, C_HP_BG.g, C_HP_BG.b, bar_alpha))
		var ratio   = maxf(0.0, hp / MAX_HP)
		var bar_col = Color(C_HP_FULL.lerp(C_HP_LOW, 1.0 - ratio))
		bar_col.a   = bar_alpha
		draw_rect(Rect2(bx, by, bw * ratio, bh), bar_col)

	# ── Aggro indicator — glowing outline ────────────────────
	if _state in [State.AGGRO, State.ATTACK, State.LEAP]:
		var pulse = 0.5 + sin(t_ms * 6.0) * 0.5
		draw_arc(base + Vector2(0, -12), 18.0, 0, TAU, 20,
			Color(0.9, 0.1, 0.0, pulse * 0.35), 5.0)

	# ── Stun sparks ─────────────────────────────────────────
	if _state == State.STUNNED:
		var st = t_ms * 7.0
		for si in 3:
			var a = st + si * TAU / 3.0
			var sp = base + Vector2(0, -22) + Vector2(cos(a) * 12.0, sin(a) * 7.0)
			draw_circle(sp, 2.0, Color(0.8, 0.9, 0.1, 0.9))

	# ── Target ring ──────────────────────────────────────────
	if _is_targeted():
		var pulse = 0.7 + sin(t_ms * 6.0) * 0.3
		draw_arc(base + Vector2(0, -8), 20.0, 0, TAU, 28,
			Color(1.0, 0.10, 0.10, pulse * 0.35), 7.0)
		draw_arc(base + Vector2(0, -8), 20.0, 0, TAU, 28,
			Color(1.0, 0.10, 0.10, pulse), 2.0)

# ── Sub-draw functions ───────────────────────────────────────

func _draw_legs(base: Vector2, flip: float, leg_t: float, moving: bool, flash: float, stretch: float) -> void:
	var leg_col   = _flash_col(C_CHITIN, flash)
	var claw_col  = _flash_col(C_CLAW,   flash)
	# 3 legs per side, alternating gait
	for side in [-1.0, 1.0]:
		for i in 3:
			var phase   = leg_t + i * (PI / 3.0) + (0.0 if side > 0 else PI)
			var attach_y = base.y - 2.0 + i * 4.5
			var attach_x = side * flip * (5.0 + i * 0.5)
			var attach   = Vector2(attach_x, attach_y)

			# Knee
			var knee_x   = side * flip * (12.0 + i * 1.5)
			var knee_y   = attach_y + 4.0 + (sin(phase) * 4.0 if moving else 0.5)
			var knee     = Vector2(knee_x, knee_y)

			# Foot
			var foot_x   = side * flip * (16.0 + i * 0.5)
			var foot_y   = base.y + 16.0 + (sin(phase + 0.8) * 5.0 if moving else 0.0) + stretch * 0.3
			var foot     = Vector2(foot_x + stretch * side * flip * 0.3, foot_y)

			draw_line(attach, knee, leg_col, 2.5)
			draw_line(knee, foot, leg_col, 2.0)
			# Claw tip
			draw_circle(foot, 1.8, claw_col)

func _draw_abdomen(base: Vector2, flip: float, _lean: float, flash: float, twitch: float) -> void:
	var ab = Vector2(-flip * 5.0, base.y + 6.0 + twitch * 0.3)
	var c1 = _flash_col(C_CHITIN.darkened(0.2), flash)
	var c2 = _flash_col(C_CHITIN_EDGE, flash)
	# Jagged elongated abdomen — sharp spines and angular cuts
	var pts := PackedVector2Array()
	pts.append(ab + Vector2(flip * 9.0,   0.0))    # front narrow tip
	pts.append(ab + Vector2(flip * 4.0,  -6.0))    # upper-front
	pts.append(ab + Vector2(-flip * 1.0, -8.5))    # upper-mid
	pts.append(ab + Vector2(-flip * 5.0, -5.0))    # upper-rear notch
	pts.append(ab + Vector2(-flip * 8.5, -9.5))    # dorsal spine tip ← spike
	pts.append(ab + Vector2(-flip * 10.0, -3.0))   # upper-rear
	pts.append(ab + Vector2(-flip * 11.5,  0.0))   # rear point
	pts.append(ab + Vector2(-flip * 10.0,  4.0))   # lower-rear
	pts.append(ab + Vector2(-flip * 6.0,   8.0))   # lower-mid
	pts.append(ab + Vector2(-flip * 0.5,   7.5))   # lower-front
	pts.append(ab + Vector2(flip * 4.0,    5.0))   # lower-front near
	draw_colored_polygon(pts, c1)
	draw_polyline(pts, c2, 1.5, true)
	# Sharp segmentation cuts
	for s in 3:
		var sx = -flip * (1.5 + s * 3.2)
		draw_line(ab + Vector2(sx, -5.5 + s * 0.8),
				  ab + Vector2(sx - flip * 1.5, 5.0 - s * 0.5), c2, 1.0)
	draw_circle(ab + Vector2(-flip * 3.0, -3.0), 2.0,
		Color(C_CHITIN_SHINE.r, C_CHITIN_SHINE.g, C_CHITIN_SHINE.b, C_CHITIN_SHINE.a * (1.0 - flash * 0.5)))

func _draw_thorax(base: Vector2, flip: float, _lean: float, flash: float, _bob: float, stretch: float) -> void:
	var th = Vector2(flip * 1.0, base.y - 6.0)
	var c1 = _flash_col(C_CHITIN, flash)
	var c2 = _flash_col(C_CHITIN_EDGE, flash)
	var w = 9.0 + stretch * 0.2
	var h = 11.0 + stretch * 0.4
	# Angular hunched thorax — wide bottom, sharp dorsal peak
	var pts := PackedVector2Array()
	pts.append(th + Vector2(flip * 1.5,        -h))          # dorsal peak ← sharp tip
	pts.append(th + Vector2(flip * (w - 1.0),  -h * 0.55))   # top-front shoulder
	pts.append(th + Vector2(flip * w,           h * 0.1))     # front mid
	pts.append(th + Vector2(flip * (w + 1.0),   h * 0.5))    # front-lower bulge
	pts.append(th + Vector2(flip * (w - 2.0),   h))           # front-bottom
	pts.append(th + Vector2(-flip * (w * 0.25), h))           # bottom
	pts.append(th + Vector2(-flip * (w * 0.65), h * 0.4))    # back-lower
	pts.append(th + Vector2(-flip * (w * 0.6),  -h * 0.5))   # back-upper notch
	pts.append(th + Vector2(-flip * (w * 0.2),  -h * 0.88))  # back-top
	draw_colored_polygon(pts, c1)
	draw_polyline(pts, c2, 1.8, true)
	# Sharp pointed dorsal spines
	for si in 4:
		var sx = flip * (-0.5 + si * 0.9)
		var sy  = -h + si * 2.2
		draw_line(th + Vector2(sx - flip * 0.5, sy + 2.0),
				  th + Vector2(sx, sy - 3.5 - si * 0.4), c2, 2.0)
	# Neck connector flesh
	draw_line(th + Vector2(flip * 1.0, -h + 2.0),
			  th + Vector2(flip * 2.0, -h - 2.0),
			  _flash_col(C_FLESH, flash), 3.5)

func _draw_foreclaws(base: Vector2, flip: float, flash: float, stretch: float) -> void:
	var attack_raise = 0.0
	if _state == State.ATTACK:
		attack_raise = sin(_claw_swing) * 10.0
	if _state == State.LEAP:
		attack_raise = -12.0 + stretch * 0.4

	var claw_col  = _flash_col(C_CLAW, flash)
	var tip_col   = _flash_col(C_CLAW_TIP, flash)
	var joint_col = _flash_col(C_CHITIN_EDGE, flash)

	# Two raptorial foreclaws
	for side in [-1.0, 1.0]:
		var sh = Vector2(flip * 7.0, base.y - 8.0)       # shoulder
		var el = Vector2(flip * (14.0 + side * 2.0),
						 base.y - 4.0 + side * 2.0 + attack_raise)  # elbow
		var wrist = Vector2(flip * (20.0 + side * 1.5),
							base.y + 1.0 + side * 1.0 + attack_raise)

		# Upper arm
		draw_line(sh, el, _flash_col(C_CHITIN, flash), 4.0)
		draw_circle(el, 2.5, joint_col)

		# Forearm
		draw_line(el, wrist, _flash_col(C_FLESH, flash), 3.0)

		# Two blade claws from wrist
		for c in 2:
			var blade_len = 9.0 - c * 2.5
			var angle     = deg_to_rad(-30.0 + c * 25.0 + (attack_raise * 1.5))
			var tip = wrist + Vector2(
				cos(angle) * flip * blade_len,
				sin(angle) * blade_len - 1.0
			)
			draw_line(wrist, tip, claw_col, 2.2 - c * 0.4)
			draw_circle(tip, 1.2, tip_col)

func _draw_head(base: Vector2, flip: float, _lean: float, flash: float, twitch: float, _bob: float) -> void:
	var hc = Vector2(flip * 3.0, base.y - 18.0 + twitch * 0.4)
	var c1 = _flash_col(C_CHITIN, flash)
	var c2 = _flash_col(C_CHITIN_EDGE, flash)
	# Aggressive angular head — wedge that tapers to a sharp snout
	var pts := PackedVector2Array()
	pts.append(hc + Vector2(flip * 11.0,   1.0))   # snout tip ← forward point
	pts.append(hc + Vector2(flip * 7.0,   -7.0))   # brow-ridge front
	pts.append(hc + Vector2(flip * 1.0,   -9.0))   # top-skull front
	pts.append(hc + Vector2(-flip * 4.0,  -7.5))   # skull top-rear
	pts.append(hc + Vector2(-flip * 7.5,  -5.0))   # rear-skull notch
	pts.append(hc + Vector2(-flip * 8.0,   0.0))   # rear-skull
	pts.append(hc + Vector2(-flip * 6.5,   5.0))   # jaw rear
	pts.append(hc + Vector2(-flip * 1.0,   7.0))   # jaw back
	pts.append(hc + Vector2(flip * 6.0,    5.0))   # jaw front-lower
	draw_colored_polygon(pts, c1)
	draw_polyline(pts, c2, 1.2, true)
	# Three pointed cranial spines
	for fi in 3:
		var fx = flip * (-3.0 + fi * 2.0)
		draw_line(hc + Vector2(fx, -7.0),
				  hc + Vector2(fx + flip * 0.5, -11.5 - fi), c2, 1.8)
	# Mandibles (open during attack/leap)
	var mandible_open = 0.0
	if _state == State.ATTACK:
		mandible_open = absf(sin(_claw_swing * 1.5)) * 6.0
	if _state == State.LEAP:
		mandible_open = 8.0
	var mand_col = c1
	# Upper mandible
	var mr = hc + Vector2(flip * 9.0, 1.5)
	var mt = hc + Vector2(flip * 13.0, -1.5 - mandible_open * 0.4)
	draw_line(mr, mt, mand_col, 4.0)
	draw_circle(mt, 1.5, _flash_col(C_CLAW, flash))
	# Lower mandible
	var mb = hc + Vector2(flip * 13.0, 2.0 + mandible_open)
	draw_line(mr, mb, mand_col, 3.5)
	draw_circle(mb, 1.5, _flash_col(C_CLAW_TIP, flash))
	draw_circle(mt + Vector2(flip * 0.5, -0.5), 0.8, Color(1.0, 1.0, 0.9, 0.7))

func _draw_eyes(base: Vector2, flip: float, _lean: float, flash: float) -> void:
	var hc = Vector2(flip * 3.0, base.y - 18.0)
	# Compound eyes: 3 facets each side
	for side in [-1.0, 1.0]:
		for fi in 3:
			var ex = hc.x + side * flip * (3.5 + fi * 1.8)
			var ey = hc.y - 1.5 + fi * 1.5
			var e_rad = 2.0 - fi * 0.3
			# Outer glow
			draw_circle(Vector2(ex, ey), e_rad + 1.0,
				Color(C_EYE_GLOW.r, C_EYE_GLOW.g, C_EYE_GLOW.b,
					  (0.4 if _state in [State.AGGRO, State.ATTACK, State.LEAP] else 0.15) * (1.0 - flash * 0.5)))
			# Main eye
			draw_circle(Vector2(ex, ey), e_rad, _flash_col(C_EYE_GLOW, flash))
			# Inner facet
			draw_circle(Vector2(ex, ey), e_rad * 0.55, _flash_col(C_EYE_INNER, flash))

func _draw_antennae(base: Vector2, flip: float, _lean: float, twitch: float, flash: float) -> void:
	var hc     = Vector2(flip * 3.0, base.y - 18.0)
	var ant_col = _flash_col(C_CHITIN_EDGE, flash)
	# Two long segmented antennae
	for side in [-1.0, 1.0]:
		var root = hc + Vector2(side * flip * 5.0, -4.0)
		var t_ms = Time.get_ticks_msec() * 0.001
		var wave = sin(t_ms * 3.5 + side * 1.2) * 4.0 + twitch * 2.0
		var mid  = root + Vector2(side * flip * 7.0, -9.0 + wave * 0.3)
		var tip  = root + Vector2(side * flip * 12.0, -18.0 + wave)
		# Draw as polyline with segments
		draw_line(root, mid, ant_col, 1.5)
		draw_line(mid,  tip, ant_col, 1.0)
		# Sensory bulb at tip
		draw_circle(tip, 2.0, _flash_col(C_EYE_GLOW, flash))
		draw_circle(tip, 1.0, Color(1.0, 0.8, 0.8, 0.7))

func _draw_death_splat(_flash: float, alpha: float, squash: float, splat: float) -> void:
	# Chitin crunch death: body flattens and bleeds
	var s = squash
	# Crushed body blob
	var pts := PackedVector2Array()
	for i in 12:
		var a = float(i) / 12.0 * TAU
		pts.append(Vector2(cos(a) * 14.0 / s, sin(a) * 8.0 * s))
	draw_colored_polygon(pts, Color(C_CHITIN.r, C_CHITIN.g, C_CHITIN.b, alpha))

	# Legs splayed out flat
	for i in 6:
		var a    = (float(i) / 6.0) * TAU
		var tip  = Vector2(cos(a) * (15.0 + splat * 5.0), sin(a) * (10.0 + splat * 3.0))
		draw_line(Vector2.ZERO, tip, Color(C_CHITIN_EDGE.r, C_CHITIN_EDGE.g, C_CHITIN_EDGE.b, alpha), 2.0)
		draw_circle(tip, 1.5, Color(C_CLAW.r, C_CLAW.g, C_CLAW.b, alpha))

	# Blood splat
	for sp in _splat_pts:
		var sc = Color(sp["col"].r, sp["col"].g, sp["col"].b, sp["col"].a * alpha * splat)
		draw_circle(sp["offset"] * splat, sp["radius"] * (0.5 + splat * 0.8), sc)

# ============================================================
#  DRAW HELPERS
# ============================================================

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

func _flash_col(col: Color, flash: float) -> Color:
	return col.lerp(Color(1, 1, 1), flash * 0.60)

func _is_targeted() -> bool:
	var ui_nodes = get_tree().get_nodes_in_group("ui_layer")
	if ui_nodes.size() > 0:
		var ui = ui_nodes[0]
		if ui.has_method("is_targeted"):
			return ui.is_targeted(self)
	return false
