extends Node2D

# ============================================================
#  MedicCanister.gd — medic projectile
#  Arcs toward target like a grenade. Blue = heal, Purple = poison.
#  On impact: heal AOE (25 HP) or damage AOE (25 dmg + 3 dps poison 12s).
# ============================================================

const SPEED        : float = 200.0
const ARRIVE_DIST  : float = 18.0
const IMPACT_TIME  : float = 1.2    # how long impact VFX lasts
const POISON_DPS   : float = 3.0
const POISON_DUR   : float = 12.0
const AOE_RADIUS   : float = 80.0

var _target    : Node   = null
var _damage    : float  = 0.0
var _is_heal   : bool   = true
var _impacted  : bool   = false
var _impact_t  : float  = 0.0

# Bezier arc
var _start_pos : Vector2 = Vector2.ZERO
var _ctrl_pos  : Vector2 = Vector2.ZERO
var _end_pos   : Vector2 = Vector2.ZERO
var _arc_t     : float   = 0.0
var _arc_dur   : float   = 1.0

# Trail
var _trail : Array = []

# Impact particles
var _particles : Array = []

func init(target: Node, damage: float, is_heal: bool) -> void:
	_target    = target
	_damage    = damage
	_is_heal   = is_heal
	_start_pos = global_position

	var aim = target.global_position
	_end_pos = aim

	var dist  = _start_pos.distance_to(_end_pos)
	_arc_dur  = maxf(dist / SPEED, 0.2)

	# High arc — control point above the midpoint
	var mid   = (_start_pos + _end_pos) * 0.5
	_ctrl_pos = mid + Vector2(0, -dist * 0.55)

func _process(delta: float) -> void:
	if _impacted:
		_impact_t += delta
		# Update impact particles
		for p in _particles:
			p.life -= delta
			p.pos  += p.vel * delta
			p.vel.y += p.get("grav", 0.0) * delta
		queue_redraw()
		if _impact_t >= IMPACT_TIME:
			queue_free()
		return

	# Update target position while in flight
	if is_instance_valid(_target):
		_end_pos = _target.global_position

	_arc_t += delta / _arc_dur

	# Bezier position
	var t  = clampf(_arc_t, 0.0, 1.0)
	var p0 = _start_pos
	var p1 = _ctrl_pos
	var p2 = _end_pos
	var pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
	global_position = pos

	# Trail
	_trail.append({"pos": pos, "life": 0.15})
	var i = _trail.size() - 1
	while i >= 0:
		_trail[i].life -= delta
		if _trail[i].life <= 0.0:
			_trail.remove_at(i)
		i -= 1

	queue_redraw()

	if _arc_t >= 1.0 or global_position.distance_to(_end_pos) < ARRIVE_DIST:
		_on_impact()

func _on_impact() -> void:
	_impacted = true
	global_position = _end_pos

	var arena = get_tree().get_first_node_in_group("boss_arena_scene")

	if _is_heal:
		# Heal AOE — find nearby friendly units
		_apply_heal_aoe(arena)
		_spawn_heal_particles()
	else:
		# Damage + poison AOE
		_apply_damage_aoe(arena)
		_spawn_poison_particles()

func _apply_heal_aoe(arena: Node) -> void:
	# Heal the direct target
	if is_instance_valid(_target) and _target.has_method("heal"):
		_target.heal(_damage)
	elif is_instance_valid(_target):
		var cur_hp = _target.get("hp")
		var max_h  = _target.get("max_hp")
		if cur_hp != null and max_h != null:
			_target.set("hp", minf(cur_hp + _damage, max_h))
	# AOE heal on nearby friendlies
	for node in get_tree().get_nodes_in_group("friendly"):
		if node == _target: continue
		if not is_instance_valid(node): continue
		if node.global_position.distance_to(_end_pos) > AOE_RADIUS: continue
		if node.has_method("heal"):
			node.heal(_damage)
		else:
			var cur_hp = node.get("hp")
			var max_h  = node.get("max_hp")
			if cur_hp != null and max_h != null:
				node.set("hp", minf(cur_hp + _damage, max_h))
	if arena and arena.has_method("spawn_damage_number"):
		arena.spawn_damage_number(_end_pos, _damage, Color(0.30, 0.85, 1.0))

func _apply_damage_aoe(arena: Node) -> void:
	# Damage the direct target
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(_damage)
	if arena and arena.has_method("spawn_damage_number"):
		arena.spawn_damage_number(_end_pos, _damage, Color(0.65, 0.20, 0.85))
	# AOE damage on nearby enemies
	for node in get_tree().get_nodes_in_group("targetable"):
		if node == _target: continue
		if not is_instance_valid(node): continue
		if node.global_position.distance_to(_end_pos) > AOE_RADIUS: continue
		if node.has_method("take_damage"):
			node.take_damage(_damage)
	# Apply poison debuff to all hit targets
	var hit_nodes : Array = []
	if is_instance_valid(_target): hit_nodes.append(_target)
	for node in get_tree().get_nodes_in_group("targetable"):
		if node.global_position.distance_to(_end_pos) <= AOE_RADIUS:
			if not hit_nodes.has(node): hit_nodes.append(node)
	for node in hit_nodes:
		if not is_instance_valid(node): continue
		# Apply poison meta — ticked by the arena scene or the target itself
		node.set_meta("poison_dps", POISON_DPS)
		node.set_meta("poison_remaining", POISON_DUR)

func _spawn_heal_particles() -> void:
	for i in 14:
		_particles.append({
			"pos": _end_pos + Vector2(randf_range(-30, 30), randf_range(-10, 20)),
			"vel": Vector2(randf_range(-8, 8), randf_range(-40, -20)),
			"life": randf_range(0.6, IMPACT_TIME),
			"grav": 0.0,
			"type": "heal",
			"symbol": "+" if randf() > 0.3 else "✚",
		})

func _spawn_poison_particles() -> void:
	for i in 16:
		var angle = randf() * TAU
		var r     = randf_range(5, 35)
		_particles.append({
			"pos": _end_pos + Vector2(cos(angle), sin(angle)) * r,
			"vel": Vector2(randf_range(-12, 12), randf_range(-18, -5)),
			"life": randf_range(0.5, IMPACT_TIME),
			"grav": -5.0,
			"type": "mist",
			"size": randf_range(8, 22),
		})

func _draw() -> void:
	if _impacted:
		_draw_impact()
		return

	# Draw trail
	var base_col = Color(0.30, 0.75, 1.0, 0.6) if _is_heal else Color(0.55, 0.15, 0.75, 0.6)
	for trail_pt in _trail:
		var a = trail_pt.life / 0.15
		var local = trail_pt.pos - global_position
		draw_circle(local, 3.0 * a, Color(base_col.r, base_col.g, base_col.b, 0.3 * a))

	# Draw canister body
	var col = Color(0.25, 0.65, 1.0) if _is_heal else Color(0.55, 0.12, 0.70)
	# Outer glow
	draw_circle(Vector2.ZERO, 10.0, Color(col.r, col.g, col.b, 0.18))
	# Body — cylinder shape (two rects)
	draw_rect(Rect2(-4, -6, 8, 12), col)
	draw_rect(Rect2(-5, -4, 10, 2), Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, 1.0))
	# Cap
	draw_rect(Rect2(-3, -8, 6, 3), Color(0.85, 0.85, 0.90))
	# Core highlight
	draw_circle(Vector2(0, -1), 2.5, Color(1.0, 1.0, 1.0, 0.55))

func _draw_impact() -> void:
	var fade = 1.0 - clampf(_impact_t / IMPACT_TIME, 0.0, 1.0)

	if _is_heal:
		# AOE ring
		var ring_r = AOE_RADIUS * clampf(_impact_t / 0.3, 0.0, 1.0)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32,
			Color(0.30, 0.85, 1.0, 0.25 * fade), 2.0)
		# Healing symbols rising
		var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz = maxi(1, int(round(16 * _ct_sc.x)))
		for p in _particles:
			if p.life <= 0.0: continue
			var a = clampf(p.life / 0.6, 0.0, 1.0) * fade
			var local = p.pos - global_position
			if font:
				draw_set_transform(local, 0.0, _inv)
				draw_string(font, Vector2.ZERO, p.symbol, HORIZONTAL_ALIGNMENT_LEFT,
					-1, _rend_sz, Color(0.30, 0.90, 1.0, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# AOE ring — purple
		var ring_r = AOE_RADIUS * clampf(_impact_t / 0.3, 0.0, 1.0)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32,
			Color(0.55, 0.15, 0.70, 0.25 * fade), 2.0)
		# Poison mist clouds
		for p in _particles:
			if p.life <= 0.0: continue
			var a = clampf(p.life / 0.5, 0.0, 1.0) * fade
			var local = p.pos - global_position
			var sz = p.size
			draw_circle(local, sz, Color(0.50, 0.15, 0.65, 0.22 * a))
			draw_circle(local, sz * 0.6, Color(0.60, 0.20, 0.80, 0.30 * a))
			draw_circle(local + Vector2(sz * 0.2, -sz * 0.1), sz * 0.3,
				Color(0.70, 0.30, 0.90, 0.18 * a))
