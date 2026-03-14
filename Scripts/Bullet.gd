extends Node2D

# ============================================================
#  Bullet.gd — ranged projectile
#  Spawned by BossArenaScene.spawn_bullet().
#  Travels fast toward target, hits on arrival.
#  Draws: muzzle flash at spawn point, thin tracer, impact flash.
# ============================================================

const SPEED       = 900.0   # pixels per second — feels like a real bullet
const ARRIVE_DIST = 10.0    # trigger impact when this close
const FLASH_TIME  = 0.15    # muzzle flash lasts this long (seconds)
const IMPACT_TIME = 0.10    # impact flash duration

var _target       : Node    = null
var _damage       : float   = 0.0
var _impacting    : bool    = false
var _impact_t     : float   = 0.0
var _flash_t      : float   = FLASH_TIME
var _dir          : Vector2 = Vector2.ZERO   # normalized travel direction (updated each frame)
var _muzzle_world : Vector2 = Vector2.ZERO   # world-space spawn position for muzzle flash
var rifle_glow    : Color   = Color(0,0,0,0)  # nonzero = rifle glow color (white/blue/gold)

func init(target: Node, damage: float) -> void:
	_target       = target
	_damage       = damage
	_muzzle_world = global_position
	if target != null and is_instance_valid(target):
		var aim_pos = target.get_target_position() if target.has_method("get_target_position") else target.global_position
		_dir = (aim_pos - global_position).normalized()

func _process(delta: float) -> void:
	_flash_t -= delta

	if _impacting:
		_impact_t += delta
		if _impact_t >= IMPACT_TIME:
			queue_free()
			return
		queue_redraw()
		return

	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var aim_pos   = _target.get_target_position() if _target.has_method("get_target_position") else _target.global_position
	var to_target = aim_pos - global_position
	var dist      = to_target.length()

	if dist <= ARRIVE_DIST:
		_on_hit()
		return

	# Soft-track target (bullet travels straight but corrects for target movement)
	_dir = to_target.normalized()
	global_position += _dir * SPEED * delta
	queue_redraw()

func _on_hit() -> void:
	if _target != null and is_instance_valid(_target):
		if _target.has_method("take_damage"):
			_target.take_damage(_damage)
		var arena = get_tree().get_first_node_in_group("boss_arena_scene")
		if arena and arena.has_method("spawn_damage_number"):
			arena.spawn_damage_number(global_position, _damage, Color(0.4, 0.95, 1.0))

	_impacting = true

func _draw() -> void:
	if _impacting:
		_draw_impact()
		return

	# ── Colour palette — orange/yellow default, rifle_glow Color drives rifle variants ──
	var has_rifle_glow = rifle_glow.a > 0.0
	var gc   = rifle_glow   # shorthand
	var glow_outer  : Color
	var glow_core   : Color
	var spike_col   : Color
	var tracer_soft : Color
	var tracer_hard : Color
	if has_rifle_glow:
		# Derive palette from the glow color — lighten for core, soften for trail
		glow_outer  = Color(gc.r * 0.8, gc.g * 0.8, gc.b * 0.8, 0.0)
		glow_core   = Color(gc.r * 0.6 + 0.4, gc.g * 0.6 + 0.4, gc.b * 0.6 + 0.4, 0.0)
		spike_col   = Color(gc.r * 0.7 + 0.3, gc.g * 0.7 + 0.3, gc.b * 0.7 + 0.3, 0.0)
		tracer_soft = Color(gc.r * 0.6, gc.g * 0.6, gc.b * 0.6, 0.0)
		tracer_hard = Color(gc.r * 0.4 + 0.6, gc.g * 0.4 + 0.6, gc.b * 0.4 + 0.6, 0.0)
	else:
		glow_outer  = Color(1.00, 0.85, 0.40, 0.0)
		glow_core   = Color(1.00, 1.00, 0.85, 0.0)
		spike_col   = Color(1.00, 0.95, 0.55, 0.0)
		tracer_soft = Color(1.00, 0.75, 0.30, 0.0)
		tracer_hard = Color(1.00, 0.96, 0.72, 0.0)

	# ── Muzzle flash — anchored at the spawn world position ──────
	if _flash_t > 0.0:
		var fa           = clampf(_flash_t / FLASH_TIME, 0.0, 1.0)
		var muzzle_local = to_local(_muzzle_world)
		draw_circle(muzzle_local, 9.0, Color(glow_outer.r, glow_outer.g, glow_outer.b, fa * 0.30))
		draw_circle(muzzle_local, 4.5, Color(glow_core.r,  glow_core.g,  glow_core.b,  fa * 0.90))
		for i in 4:
			var angle = float(i) / 4.0 * TAU
			var tip   = muzzle_local + Vector2(cos(angle), sin(angle)) * (5.0 + fa * 7.0)
			draw_line(muzzle_local, tip, Color(spike_col.r, spike_col.g, spike_col.b, fa * 0.75), 1.2)

	# ── Rifle glow aura — persistent halo in the glow color ──────
	if has_rifle_glow:
		draw_circle(Vector2.ZERO, 7.0, Color(gc.r, gc.g, gc.b, 0.22))
		draw_circle(Vector2.ZERO, 4.0, Color(gc.r * 0.6 + 0.4, gc.g * 0.6 + 0.4, gc.b * 0.6 + 0.4, 0.38))

	# ── Tracer — thin bright streak trailing behind bullet ───────
	var tail = -_dir * 28.0
	draw_line(Vector2.ZERO, tail * 0.55, Color(tracer_soft.r, tracer_soft.g, tracer_soft.b, 0.35), 3.5)
	draw_line(Vector2.ZERO, tail,        Color(tracer_hard.r, tracer_hard.g, tracer_hard.b, 0.92), 1.4)
	# Bullet tip
	draw_circle(Vector2.ZERO, 2.2, Color(1.0, 1.0, 1.0, 0.98))

func _draw_impact() -> void:
	var t     = _impact_t / IMPACT_TIME
	var alpha = 1.0 - t
	var _has_glow = rifle_glow.a > 0.0
	var _gc = rifle_glow
	if _has_glow:
		# Colored energy impact
		draw_circle(Vector2.ZERO, lerpf(3.0, 18.0, t), Color(_gc.r, _gc.g, _gc.b, alpha * 0.70))
		draw_circle(Vector2.ZERO, lerpf(2.0,  7.0, t), Color(_gc.r * 0.5 + 0.5, _gc.g * 0.5 + 0.5, _gc.b * 0.5 + 0.5, alpha * 0.90))
		for i in 4:
			var angle = float(i) / 4.0 * TAU + 0.4
			var tip   = Vector2(cos(angle), sin(angle)) * lerpf(12.0, 0.0, t)
			draw_line(Vector2.ZERO, tip, Color(_gc.r * 0.7 + 0.3, _gc.g * 0.7 + 0.3, _gc.b * 0.7 + 0.3, alpha), 1.4)
	else:
		# Default orange impact
		draw_circle(Vector2.ZERO, lerpf(3.0, 16.0, t), Color(1.0, 0.96, 0.7, alpha * 0.75))
		draw_circle(Vector2.ZERO, lerpf(2.0,  6.0, t), Color(1.0, 1.0,  1.0, alpha * 0.90))
		for i in 4:
			var angle = float(i) / 4.0 * TAU + 0.4
			var tip   = Vector2(cos(angle), sin(angle)) * lerpf(10.0, 0.0, t)
			draw_line(Vector2.ZERO, tip, Color(1.0, 0.85, 0.4, alpha), 1.4)
