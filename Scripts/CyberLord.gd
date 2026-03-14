extends CharacterBody2D

# ============================================================
#  CyberLord.gd — Boss Arena second boss
#  Spawned by BossArenaScene on F3.
#  Chases the nearest player, attacks on contact.
# ============================================================

const SPEED             = 55.0
const MAX_HP            = 500.0
const ATTACK_RANGE      = 35.0
const REPOSITION_RANGE  = 150.0
const REPOSITION_DELAY  = 0.9
const ATTACK_INTERVAL   = 2.2
const ATTACK_DAMAGE_MIN = 25.0
const ATTACK_DAMAGE_MAX = 45.0
const DEATH_DURATION    = 2.0   # seconds to blink + fade before freeing

# Bar drawn in world-space above the sprite
const BAR_W   = 150.0
const BAR_H   = 9.0
const BAR_Y   = -282.0
const ARROW_Y = -198.0   # above sprite head (~264px tall figure)

# ── STATE MACHINE ─────────────────────────────────────────────
enum State { CHASE, ATTACK, REPOSITION }
var _state            : State = State.CHASE
var _reposition_timer : float = 0.0

var character_name : String = "Cyber Lord"
var hp     : float = MAX_HP
var max_hp : float = MAX_HP

var _facing       : String = "s"
var _is_attacking : bool   = false
var _attack_timer : float  = 1.0
var _target       : Node   = null

# ── DEATH ─────────────────────────────────────────────────────
var _dying       : bool  = false
var _death_timer : float = 0.0

# ── TARGET INDICATOR ──────────────────────────────────────────
var _pulse_t     : float = 0.0
var _has_aggroed : bool  = false

# ── READY ─────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("targetable")
	add_to_group("boss")

# ── PROCESS ───────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return

	_pulse_t += delta
	_find_target()
	_attack_timer -= delta
	_update_animation()
	queue_redraw()

func _tick_death(delta: float) -> void:
	_death_timer += delta

	# Blink: fast sin wave flicker for the first ~1.4s
	var blink  = absf(sin(_death_timer * 14.0))
	# Fade: smooth ramp to 0 over the last 0.6s
	var fade   = 1.0 - clampf((_death_timer - 1.4) / 0.6, 0.0, 1.0)
	modulate.a = blink * fade

	queue_redraw()

	if _death_timer >= DEATH_DURATION:
		queue_free()

func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_target = _target.global_position - global_position
	var dist      = to_target.length()

	_update_facing(to_target)

	match _state:
		State.CHASE:
			velocity = to_target.normalized() * SPEED
			if dist <= ATTACK_RANGE:
				_state   = State.ATTACK
				velocity = Vector2.ZERO

		State.ATTACK:
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_do_attack()
			if dist > REPOSITION_RANGE:
				_state            = State.REPOSITION
				_reposition_timer = REPOSITION_DELAY

		State.REPOSITION:
			velocity           = Vector2.ZERO
			_reposition_timer -= delta
			if _reposition_timer <= 0.0:
				_state = State.CHASE

	move_and_slide()

# ── AI ────────────────────────────────────────────────────────
func _find_target() -> void:
	var had_target = (_target != null)
	var players    = get_tree().get_nodes_in_group("player")
	var best       : Node  = null
	var best_dist  : float = INF
	for p in players:
		if not is_instance_valid(p):
			continue
		var d = global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best      = p
	_target = best
	# First aggro — trigger cinematic once per boss instance
	if not had_target and _target != null and not _has_aggroed:
		_has_aggroed = true
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("trigger_boss_cinematic"):
			arena.call("trigger_boss_cinematic", character_name)

func _update_facing(to_target: Vector2) -> void:
	if absf(to_target.x) >= absf(to_target.y):
		_facing = "e" if to_target.x > 0.0 else "w"
	else:
		_facing = "s" if to_target.y > 0.0 else "n"

# ── ATTACK ────────────────────────────────────────────────────
func _do_attack() -> void:
	_attack_timer = ATTACK_INTERVAL
	_is_attacking = true

	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite and sprite.sprite_frames:
		var anim = "attack_" + _facing
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			if not sprite.animation_finished.is_connected(_on_attack_done):
				sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)

	if _target != null and is_instance_valid(_target):
		var dmg = randf_range(ATTACK_DAMAGE_MIN, ATTACK_DAMAGE_MAX)
		if _target.has_method("take_damage"):
			_target.take_damage(dmg)
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(_target.global_position, dmg, Color(0.2, 0.8, 1.0))

func _on_attack_done() -> void:
	_is_attacking = false

# ── ANIMATION ─────────────────────────────────────────────────
func _update_animation() -> void:
	var sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return

	var anim : String
	if _is_attacking:
		anim = "attack_" + _facing
	elif velocity != Vector2.ZERO:
		anim = "run_" + _facing
	else:
		anim = "idle_" + _facing

	if sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	else:
		if sprite.sprite_frames.has_animation("idle_s") and sprite.animation != "idle_s":
			sprite.play("idle_s")

# ── TARGET POSITION ───────────────────────────────────────────
func get_target_position() -> Vector2:
	return global_position + Vector2(0.0, -132.0)

# ── DAMAGE INTERFACE ──────────────────────────────────────────
func take_damage(amount: float) -> void:
	if _dying:
		return
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		_die()

func _die() -> void:
	_dying = true
	remove_from_group("targetable")
	remove_from_group("boss")
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("on_boss_died"):
		arena.call("on_boss_died")

# ── DRAW — world-space HP bar above sprite (hidden while dying) ──
func _draw() -> void:
	if _dying:
		return

	# ── Targeted indicator ────────────────────────────────────
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena != null and arena.has_method("is_targeted") and arena.call("is_targeted", self):
		# Bouncing downward arrow just above boss head
		var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11.0, ay),
			Vector2( 11.0, ay),
			Vector2(  0.0, ay + 15.0),
		]), Color(1.0, 0.15, 0.15, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(-11.0, ay),
			Vector2( 11.0, ay),
			Vector2(  0.0, ay + 15.0),
			Vector2(-11.0, ay),
		]), Color(1.0, 0.75, 0.75, 0.70), 1.2)

