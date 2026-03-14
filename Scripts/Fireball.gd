extends Node2D

# ============================================================
#  Fireball.gd — mage projectile
#  Spawned by BossArenaScene.spawn_fireball().
#  Travels along a bezier arc toward the target, explodes on arrival.
# ============================================================

const SPEED        = 220.0   # pixels per second (arc path length / duration)
const ARRIVE_DIST  = 18.0    # fallback hit trigger if close to end point
const EXPLODE_TIME = 0.45    # seconds the explosion lasts

var _target    : Node   = null
var _damage    : float  = 0.0
var _exploding : bool   = false
var _explode_t : float  = 0.0

# ── Bezier arc ────────────────────────────────────────────────
var _start_pos : Vector2 = Vector2.ZERO
var _ctrl_pos  : Vector2 = Vector2.ZERO   # quadratic control point (perpendicular peak)
var _end_pos   : Vector2 = Vector2.ZERO   # target position locked at cast time
var _arc_t     : float   = 0.0            # 0.0 → 1.0 progress along arc
var _arc_dur   : float   = 1.0            # seconds to travel the arc

# Trail — list of world positions that fade behind the ball
var _trail : Array = []   # [{pos: Vector2, life: float}]

# Explosion sparks
var _sparks : Array = []  # [{pos, vel, life, max_life, col}]

# Wobble — gives the fireball an organic feeling oscillation
var _wobble_t : float = 0.0

func init(target: Node, damage: float) -> void:
	_target    = target
	_damage    = damage
	_start_pos = global_position

	# Lock target position at cast time
	var aim = target.get_target_position() if target.has_method("get_target_position") else target.global_position
	_end_pos = aim

	var dist  = _start_pos.distance_to(_end_pos)
	_arc_dur  = dist / SPEED

	# Control point: offset perpendicular (always left of flight dir) at midpoint
	var mid   = (_start_pos + _end_pos) * 0.5
	var perp  = (_end_pos - _start_pos).normalized().rotated(-PI * 0.5)
	_ctrl_pos = mid + perp * (dist * 0.30)   # arc height = 30% of distance

func _bezier(t: float) -> Vector2:
	var it = 1.0 - t
	return it * it * _start_pos + 2.0 * it * t * _ctrl_pos + t * t * _end_pos

func _process(delta: float) -> void:
	_wobble_t += delta * 8.0

	if _exploding:
		_explode_t += delta
		_tick_sparks(delta)
		if _explode_t >= EXPLODE_TIME:
			queue_free()
			return
		queue_redraw()
		return

	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	# Track target live — update end point and reshape arc so fireball always lands on boss
	var aim = _target.get_target_position() if _target.has_method("get_target_position") else _target.global_position
	_end_pos  = aim
	var mid   = (_start_pos + _end_pos) * 0.5
	var perp  = (_end_pos - _start_pos).normalized().rotated(-PI * 0.5)
	_ctrl_pos = mid + perp * (_start_pos.distance_to(_end_pos) * 0.30)

	# Record trail point in world space
	_trail.append({"pos": Vector2(global_position), "life": 0.15})

	# Age / prune trail
	for i in range(_trail.size() - 1, -1, -1):
		_trail[i].life -= delta
		if _trail[i].life <= 0.0:
			_trail.remove_at(i)

	# Advance along bezier arc
	if _arc_dur > 0.0:
		_arc_t = minf(_arc_t + delta / _arc_dur, 1.0)
	global_position = _bezier(_arc_t)

	# Hit when arc completes or when close to current target position
	var dist_to_target = global_position.distance_to(_end_pos)
	if _arc_t >= 1.0 or dist_to_target <= ARRIVE_DIST:
		_on_hit()
		return

	queue_redraw()

func _on_hit() -> void:
	if _target != null and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(_damage)
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(global_position, _damage, Color(1.0, 0.45, 0.05))

	_exploding = true
	_trail.clear()
	_spawn_explosion_sparks()

func _tick_sparks(delta: float) -> void:
	for i in range(_sparks.size() - 1, -1, -1):
		var s = _sparks[i]
		s.life -= delta
		if s.life <= 0.0:
			_sparks.remove_at(i)
		else:
			s.pos += s.vel * delta
			s.vel  = s.vel.move_toward(Vector2.ZERO, 180.0 * delta)

func _spawn_explosion_sparks() -> void:
	for i in 24:
		var angle = randf() * TAU
		var spd   = randf_range(55.0, 220.0)
		var life  = randf_range(0.18, 0.42)
		var warm  = randf()
		_sparks.append({
			"pos":      Vector2.ZERO,
			"vel":      Vector2(cos(angle), sin(angle)) * spd,
			"life":     life,
			"max_life": life,
			"col":      Color(1.0, lerpf(0.15, 0.80, warm), 0.0),
		})

func _draw() -> void:
	if _exploding:
		_draw_explosion()
		return

	# ── Trail ──────────────────────────────────────────────────
	for t in _trail:
		var ratio = t.life / 0.15
		var r     = lerpf(2.0, 6.0, ratio)
		var alpha = ratio * 0.55
		draw_circle(to_local(t.pos), r, Color(1.0, 0.35, 0.0, alpha))

	# ── Outer glow ─────────────────────────────────────────────
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.25, 0.0, 0.18))

	# ── Wobbling flame petals (organic fire shape) ─────────────
	var petal_count = 5
	for p in petal_count:
		var a      = float(p) / float(petal_count) * TAU + _wobble_t * 0.3
		var wobble = sin(_wobble_t + p * 1.3) * 2.5
		var offset = Vector2(cos(a), sin(a)) * (4.0 + wobble)
		draw_circle(offset, 4.5, Color(1.0, 0.45, 0.05, 0.55))

	# ── Core ───────────────────────────────────────────────────
	draw_circle(Vector2.ZERO, 6.5, Color(1.0, 0.55, 0.10))

	# ── Hot center ─────────────────────────────────────────────
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.92, 0.55))

func _draw_explosion() -> void:
	var t     = _explode_t / EXPLODE_TIME
	var alpha = 1.0 - t

	# Expanding outer ring
	var ring_r = 10.0 + t * 50.0
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32,
		Color(1.0, 0.5, 0.1, alpha * 0.7), 3.5)

	# Secondary ring
	var ring2_r = 5.0 + t * 30.0
	draw_arc(Vector2.ZERO, ring2_r, 0.0, TAU, 24,
		Color(1.0, 0.8, 0.3, alpha * 0.5), 2.0)

	# Fading core
	draw_circle(Vector2.ZERO, maxf(0.0, 18.0 * (1.0 - t * 1.5)),
		Color(1.0, 0.85, 0.4, alpha * 0.65))

	# Sparks
	for s in _sparks:
		var sa  = s.life / s.max_life
		var tip = s.pos + s.vel.normalized() * lerpf(2.0, 10.0, sa)
		draw_line(s.pos, tip, Color(s.col.r, s.col.g, s.col.b, sa), 1.8)
