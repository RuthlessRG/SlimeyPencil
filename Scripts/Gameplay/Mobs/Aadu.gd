extends CharacterBody2D

# ============================================================
#  Aadu.gd — miniSWG
#  Passive plains grazing herd animal.
#  Non-hostile unless attacked. 30% chance to fight back.
#  Set is_baby = true before adding to scene for calf variant.
#  Set spawn_pos and wander_radius after creation.
# ============================================================

# ── Stats ─────────────────────────────────────────────────────
const MAX_HP_BASE        : float = 80.0
const XP_REWARD_BASE     : float = 12.0
const ATTACK_DMG_MIN     : float = 6.0
const ATTACK_DMG_MAX     : float = 14.0
const FIGHT_CHANCE       : float = 0.30  # 30% adults fight, calves always flee

# ── Movement ──────────────────────────────────────────────────
const SPEED_WANDER       : float = 38.0
const SPEED_FLEE         : float = 135.0
const SPEED_FIGHT        : float = 85.0
const ATTACK_RANGE       : float = 42.0
const ATTACK_INTERVAL    : float = 2.4
const FLEE_DURATION      : float = 6.0
const PACK_ALERT_RANGE   : float = 240.0

# ── Eat behaviour ─────────────────────────────────────────────
const EAT_CHANCE         : float = 0.30  # chance to eat per wander step
const EAT_DUR_MIN        : float = 3.0
const EAT_DUR_MAX        : float = 8.0
const WANDER_STEP_MIN    : float = 2.5
const WANDER_STEP_MAX    : float = 6.0

# ── Optimisation ──────────────────────────────────────────────
const ACTIVATION_RANGE   : float = 1000.0
const DEACT_RANGE        : float = 1300.0
const DEATH_DURATION     : float = 1.8

# ── HUD / draw ────────────────────────────────────────────────
const BAR_W : float = 70.0
const BAR_H : float = 5.0
const BAR_Y : float = -88.0
const ARROW_Y : float = -76.0

# ── State ─────────────────────────────────────────────────────
enum State { SLEEP, GRAZE, EAT, FLEE, FIGHT, DEAD }
var _state : State = State.SLEEP

# ── Instance vars ─────────────────────────────────────────────
var is_baby            : bool    = false
var character_name     : String  = "Aadu"
var hp                 : float   = MAX_HP_BASE
var max_hp             : float   = MAX_HP_BASE
var xp_reward          : float   = XP_REWARD_BASE

var spawn_pos          : Vector2 = Vector2.ZERO
var wander_radius      : float   = 200.0

var _wander_target     : Vector2 = Vector2.ZERO
var _wander_timer      : float   = 0.0
var _eat_timer         : float   = 0.0
var _flee_timer        : float   = 0.0
var _attack_timer      : float   = 1.0
var _flee_from         : Vector2 = Vector2.ZERO
var _fight_target      : Node    = null

var _dying             : bool    = false
var _death_timer       : float   = 0.0
var _sleep_timer       : float   = 0.0
var _facing            : String  = "s"
var _pulse_t           : float   = 0.0

func _ready() -> void:
	add_to_group("targetable")
	add_to_group("aadu")
	spawn_pos = global_position
	if is_baby:
		character_name = "Aadu Calf"
		max_hp         = MAX_HP_BASE * 0.5
		hp             = max_hp
		xp_reward      = XP_REWARD_BASE * 0.6
	_pick_wander_target()

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return
	_pulse_t += delta

	# Lightweight sleep check — only activates near a player
	if _state == State.SLEEP:
		_sleep_timer += delta
		if _sleep_timer >= 0.5:
			_sleep_timer = 0.0
			if _nearest_player_dist() <= ACTIVATION_RANGE:
				_state = State.GRAZE
		return

	# Deactivate again if player wanders far during calm states
	if _state == State.GRAZE or _state == State.EAT:
		_sleep_timer += delta
		if _sleep_timer >= 1.5:
			_sleep_timer = 0.0
			if _nearest_player_dist() > DEACT_RANGE:
				_state = State.SLEEP
				velocity = Vector2.ZERO
				return

	match _state:
		State.GRAZE: _tick_graze(delta)
		State.EAT:   _tick_eat(delta)
		State.FLEE:  _tick_flee(delta)
		State.FIGHT: _tick_fight(delta)

	_update_animation()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if _dying or _state == State.SLEEP or _state == State.EAT:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	move_and_slide()

# ── GRAZE ─────────────────────────────────────────────────────
func _tick_graze(delta: float) -> void:
	var dir = _wander_target - global_position
	if dir.length() > 5.0:
		velocity = dir.normalized() * SPEED_WANDER
		_facing  = _vec_to_dir(velocity)
	else:
		velocity = Vector2.ZERO
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			if randf() < EAT_CHANCE:
				_state     = State.EAT
				_eat_timer = randf_range(EAT_DUR_MIN, EAT_DUR_MAX)
			else:
				_pick_wander_target()

# ── EAT ───────────────────────────────────────────────────────
func _tick_eat(delta: float) -> void:
	_eat_timer -= delta
	if _eat_timer <= 0.0:
		_pick_wander_target()
		_state = State.GRAZE

# ── FLEE ──────────────────────────────────────────────────────
func _tick_flee(delta: float) -> void:
	_flee_timer -= delta
	var away = (global_position - _flee_from).normalized()
	velocity  = away * SPEED_FLEE
	_facing   = _vec_to_dir(velocity)
	if _flee_timer <= 0.0:
		_pick_wander_target()
		_state = State.GRAZE

# ── FIGHT ─────────────────────────────────────────────────────
func _tick_fight(delta: float) -> void:
	if not is_instance_valid(_fight_target):
		_fight_target = _nearest_player()
		if _fight_target == null:
			_state = State.GRAZE; return
	var dist = global_position.distance_to(_fight_target.global_position)
	if dist > ATTACK_RANGE * 3.0:
		velocity = (_fight_target.global_position - global_position).normalized() * SPEED_FIGHT
		_facing  = _vec_to_dir(velocity)
	else:
		velocity = Vector2.ZERO
		_attack_timer -= delta
		if _attack_timer <= 0.0 and dist <= ATTACK_RANGE:
			_attack_timer = ATTACK_INTERVAL
			if _fight_target.has_method("take_damage"):
				var dmg = randf_range(ATTACK_DMG_MIN, ATTACK_DMG_MAX)
				if is_baby: dmg *= 0.4
				_fight_target.take_damage(dmg)
			var arena = get_tree().get_first_node_in_group("boss_arena_scene")
			if arena and arena.has_method("spawn_melee_hit"):
				arena.call("spawn_melee_hit", global_position + Vector2(0,-20), Color(0.90, 0.62, 0.20))

# ── DEATH ─────────────────────────────────────────────────────
func _tick_death(delta: float) -> void:
	_death_timer += delta
	var blink = absf(sin(_death_timer * 12.0))
	var fade  = 1.0 - clampf((_death_timer - 1.2) / 0.6, 0.0, 1.0)
	modulate.a = blink * fade
	queue_redraw()
	if _death_timer >= DEATH_DURATION:
		queue_free()

# ── DAMAGE INTERFACE ──────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _dying: return
	hp = maxf(0.0, hp - amount)

	if _state == State.SLEEP or _state == State.GRAZE or _state == State.EAT:
		var attacker = _nearest_player()
		var fight = (not is_baby) and (randf() < FIGHT_CHANCE)
		if fight and attacker != null:
			_fight_target = attacker
			_state        = State.FIGHT
		else:
			_flee_from  = attacker.global_position if attacker else global_position + Vector2(1,0)
			_flee_timer = FLEE_DURATION
			_state      = State.FLEE
		# Alert pack to flee
		for a in get_tree().get_nodes_in_group("aadu"):
			if a == self or not is_instance_valid(a): continue
			if global_position.distance_to(a.global_position) <= PACK_ALERT_RANGE:
				if a.has_method("force_flee"):
					a.call("force_flee", _flee_from)

	if hp <= 0.0:
		_die()

func force_flee(from_pos: Vector2) -> void:
	if _dying or _state == State.FIGHT or _state == State.DEAD: return
	_flee_from  = from_pos
	_flee_timer = FLEE_DURATION
	_state      = State.FLEE

func get_target_position() -> Vector2:
	return global_position + Vector2(0, -30)

# ── INTERNAL HELPERS ──────────────────────────────────────────
func _die() -> void:
	_dying = true
	_state = State.DEAD
	velocity = Vector2.ZERO
	remove_from_group("targetable")
	remove_from_group("aadu")
	remove_from_group("mission_mob")
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("on_aadu_died"):
		arena.call("on_aadu_died", xp_reward, global_position)
	# 10% loot drop
	if randf() < 0.10 and arena and arena.has_method("on_mob_dropped_loot"):
		arena.call("on_mob_dropped_loot", global_position)

func _pick_wander_target() -> void:
	var angle  = randf() * TAU
	var dist   = randf_range(40.0, wander_radius)
	var target = spawn_pos + Vector2(cos(angle), sin(angle)) * dist
	_wander_target = target
	_wander_timer  = randf_range(WANDER_STEP_MIN, WANDER_STEP_MAX)

func _nearest_player() -> Node:
	var best : Node = null; var best_dist = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist: best_dist = d; best = p
	return best

func _nearest_player_dist() -> float:
	var d = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p): continue
		var pd = global_position.distance_to(p.global_position)
		if pd < d: d = pd
	return d

func _vec_to_dir(v: Vector2) -> String:
	if v.length() < 1.0: return _facing
	var deg = fmod(rad_to_deg(v.angle()) + 360.0 + 22.5, 360.0)
	match int(deg / 45.0):
		0: return "e"
		1: return "se"
		2: return "s"
		3: return "sw"
		4: return "w"
		5: return "nw"
		6: return "n"
		7: return "ne"
	return "s"

func _update_animation() -> void:
	var sp = get_node_or_null("Sprite") as AnimatedSprite2D
	if sp == null: return
	var anim : String
	if _dying:
		anim = "die_" + _facing
	else:
		match _state:
			State.GRAZE:
				anim = ("run_" if velocity.length() > 5.0 else "idle_") + _facing
			State.EAT:
				anim = "eat_" + _facing
			State.FLEE:
				anim = "run_" + _facing
			State.FIGHT:
				anim = ("attack_" if velocity.length() < 5.0 else "run_") + _facing
			_:
				anim = "idle_" + _facing
	if sp.sprite_frames and sp.sprite_frames.has_animation(anim):
		if sp.animation != anim:
			sp.play(anim)
	elif sp.sprite_frames and sp.sprite_frames.has_animation("idle_s"):
		if sp.animation != "idle_s": sp.play("idle_s")

# ── DRAW ──────────────────────────────────────────────────────
func _draw() -> void:
	if _dying: return

	# Placeholder body — only drawn when no real sprite is loaded.
	var sp2 = get_node_or_null("Sprite") as AnimatedSprite2D
	var has_sprite = sp2 != null and sp2.sprite_frames != null and sp2.sprite_frames.get_animation_names().size() > 0
	if not has_sprite:
		var body_col  = Color(0.62, 0.42, 0.20) if not is_baby else Color(0.78, 0.62, 0.36)
		var head_col  = Color(0.55, 0.36, 0.16) if not is_baby else Color(0.72, 0.56, 0.30)
		var bsc       = 1.0 if not is_baby else 0.60
		var bx        = 0.0
		var by        = -20.0 * bsc
		draw_colored_polygon(_aadu_ellipse(Vector2(bx + 3, by + 8), 28 * bsc, 10 * bsc, 18),
			Color(0, 0, 0, 0.22))
		draw_colored_polygon(_aadu_ellipse(Vector2(bx, by), 28 * bsc, 19 * bsc, 20),
			body_col.darkened(0.35))
		draw_colored_polygon(_aadu_ellipse(Vector2(bx, by), 26 * bsc, 17 * bsc, 20), body_col)
		var hx = bx + 20 * bsc;  var hy = by - 14 * bsc
		draw_colored_polygon(_aadu_ellipse(Vector2(hx, hy), 13 * bsc, 11 * bsc, 14), head_col)
		draw_circle(Vector2(hx + 5 * bsc, hy - 2 * bsc), 2.5 * bsc, Color(0.10, 0.06, 0.02))
		draw_circle(Vector2(hx + 5 * bsc, hy - 2 * bsc), 1.0 * bsc, Color(1.0, 1.0, 1.0, 0.5))
		if not is_baby:
			draw_line(Vector2(hx + 2, hy - 11), Vector2(hx - 2, hy - 22), body_col.lightened(0.3), 2.5)
			draw_line(Vector2(hx + 6, hy - 10), Vector2(hx + 11, hy - 21), body_col.lightened(0.3), 2.5)
		var leg_y_top = by + 14 * bsc
		for lx2 in [-14 * bsc, -4 * bsc, 6 * bsc, 16 * bsc]:
			draw_line(Vector2(bx + lx2, leg_y_top), Vector2(bx + lx2 + 2 * bsc, leg_y_top + 12 * bsc),
				body_col.darkened(0.25), 4.0 * bsc)
		draw_arc(Vector2(bx - 24 * bsc, by + 4 * bsc), 8 * bsc, -0.8, 0.8, 8,
			body_col.lightened(0.2), 2.5)

	# HP bar
	var pct = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0.10, 0.08, 0.08, 0.80))
	var bar_col = Color(0.22, 0.82, 0.28) if pct > 0.5 else (Color(0.90, 0.78, 0.10) if pct > 0.25 else Color(0.90, 0.22, 0.18))
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W * pct, BAR_H), bar_col)
	draw_rect(Rect2(-BAR_W * 0.5, BAR_Y, BAR_W, BAR_H), Color(0, 0, 0, 0.50), false, 0.8)

	# Target arrow
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("is_targeted") and arena.call("is_targeted", self):
		var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7.0, ay), Vector2(7.0, ay), Vector2(0.0, ay + 10.0)
		]), Color(1.0, 0.72, 0.15, 0.92))

func _aadu_ellipse(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in steps:
		var a = float(i) / float(steps) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
