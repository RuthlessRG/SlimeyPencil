extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  ZergLair.gd  — Mission lair structure
#  A mud mound den where Zerg creatures live.
#  Groups: "targetable", "mission_lair"
#  API: take_damage(amount), get_target_position() -> Vector2
#  On death: calls arena.on_lair_died(global_position)
# ============================================================

const MAX_HP  : float = 500.0
const ARROW_Y : float = -76.0

var hp             : float  = MAX_HP
var max_hp         : float  = MAX_HP
var character_name : String = "Zerg Lair"

var _t       : float = 0.0
var _pulse_t : float = 0.0
var _dying   : bool  = false
var _die_t   : float = 0.0

var _sticks         : Array = []
var _leaves         : Array = []
var _lair_aggroed   : bool  = false   # have we already alerted all mobs?

func _ready() -> void:
	add_to_group("targetable")
	add_to_group("mission_lair")
	# Seed variation from world position so every lair looks slightly different
	var rng = RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 137 + global_position.y * 31)
	for i in 7:
		var ang  = rng.randf_range(0.0, TAU)
		var base = Vector2(cos(ang) * rng.randf_range(18.0, 36.0),
		                   sin(ang) * rng.randf_range(8.0, 18.0) - 10)
		var tip  = base + Vector2(cos(ang) * rng.randf_range(14.0, 22.0),
		                          -rng.randf_range(12.0, 22.0))
		_sticks.append([base, tip])
	for i in 8:
		_leaves.append(Vector2(rng.randf_range(-30.0, 30.0),
		                       rng.randf_range(-28.0, -4.0)))

func _process(delta: float) -> void:
	_t       += delta
	_pulse_t += delta
	if _dying:
		_die_t    += delta
		modulate.a = clampf(1.0 - _die_t / 2.0, 0.0, 1.0)
		if _die_t >= 2.0:
			var arena = get_parent()
			if is_instance_valid(arena) and arena.has_method("on_lair_died"):
				arena.call("on_lair_died", global_position)
			queue_free()
			return
	queue_redraw()

func get_target_position() -> Vector2:
	return global_position + Vector2(0, -22)

func take_damage(amount: float) -> void:
	if _dying: return
	hp = maxf(0.0, hp - amount)
	# First hit: alert every mission mob to aggro the nearest player
	if not _lair_aggroed:
		_lair_aggroed = true
		var attacker : Node = null
		var best_d : float = INF
		for p in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(p): continue
			var d = global_position.distance_to(p.global_position)
			if d < best_d:
				best_d   = d
				attacker = p
		if attacker:
			for mob in get_tree().get_nodes_in_group("mission_mob"):
				if is_instance_valid(mob) and mob.has_method("force_aggro"):
					mob.call("force_aggro", attacker)
	if hp <= 0.0:
		_dying = true
		remove_from_group("targetable")
		remove_from_group("mission_lair")

func is_targeted() -> bool:
	var arena = get_parent()
	if is_instance_valid(arena) and arena.has_method("is_targeted"):
		return arena.call("is_targeted", self)
	return false

func _draw() -> void:
	_draw_lair()
	if not _dying:
		if is_targeted():
			_draw_target_arrow()
		if hp < MAX_HP:
			_draw_hp_bar()

func _draw_lair() -> void:
	# Ground shadow
	var sh = PackedVector2Array()
	for i in 20:
		var a = float(i) / 20.0 * TAU
		sh.append(Vector2(cos(a) * 50, sin(a) * 17) + Vector2(2, 7))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.30))

	# Mound base — lumpy brown blob
	var mound = PackedVector2Array()
	for i in 26:
		var a  = float(i) / 26.0 * TAU
		var rx = 43.0 + sin(a * 3.0 + 0.6) * 8.0
		var ry = 25.0 + sin(a * 2.0 + 1.2) * 6.0
		mound.append(Vector2(cos(a) * rx, sin(a) * ry - 8))
	draw_colored_polygon(mound, Color(0.36, 0.22, 0.09))

	# Darker crest on top
	var crest = PackedVector2Array()
	for i in 16:
		var a  = float(i) / 16.0 * TAU
		var rx = 26.0 + sin(a * 2.0) * 5.0
		var ry = 15.0 + sin(a * 3.0) * 4.0
		crest.append(Vector2(cos(a) * rx, sin(a) * ry - 14))
	draw_colored_polygon(crest, Color(0.28, 0.16, 0.06))

	# Entry tunnel (dark hollow)
	draw_circle(Vector2(0, -7), 12.0, Color(0.07, 0.04, 0.02))
	draw_circle(Vector2(0, -7), 9.0,  Color(0.03, 0.01, 0.00))

	# Sticks poking out of the mound
	for s in _sticks:
		draw_line(s[0], s[1], Color(0.30, 0.18, 0.07), 2.0)
		var mid  = (s[0] + s[1]) * 0.5
		var perp = (s[1] - s[0]).rotated(1.05).normalized() * 6.0
		draw_line(mid, mid + perp, Color(0.22, 0.13, 0.05), 1.2)

	# Leaf clusters around the mound
	var greens = [Color(0.20, 0.38, 0.09), Color(0.16, 0.30, 0.07), Color(0.25, 0.44, 0.11)]
	for li in _leaves.size():
		var lp   = _leaves[li]
		var lc   = greens[li % greens.size()]
		var lpts = PackedVector2Array()
		for j in 6:
			var a = float(j) / 6.0 * TAU + float(li) * 0.9
			lpts.append(lp + Vector2(cos(a) * 6.0, sin(a) * 3.8))
		draw_colored_polygon(lpts, lc)

	# Red damage pulse when near death
	if hp < MAX_HP * 0.35 and not _dying:
		draw_circle(Vector2(0, -7), 15.0,
			Color(0.75, 0.08, 0.0, 0.22 + sin(_t * 5.0) * 0.14))

func _draw_target_arrow() -> void:
	var ay = ARROW_Y + sin(_pulse_t * 4.5) * 5.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, ay), Vector2(-7, ay + 13), Vector2(7, ay + 13)
	]), Color(1.0, 0.85, 0.10, 0.95))
	for i in 3:
		var ar  = 9.0 + i * 6.0
		var aal = 0.40 + sin(_pulse_t * 2.5 + i * 0.5) * 0.10
		var arc = PackedVector2Array()
		for j in 14:
			var ang = lerp(-PI * 0.55, PI * 0.55, float(j) / 13.0)
			arc.append(Vector2(cos(ang) * ar, ay + 18 + sin(ang) * ar * 0.3))
		for k in arc.size() - 1:
			draw_line(arc[k], arc[k + 1], Color(1.0, 0.85, 0.10, aal), 1.2)

func _draw_hp_bar() -> void:
	var bw = 72.0
	var bh = 6.0
	var bx = -bw * 0.5
	var by = ARROW_Y + 22.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.08, 0.08, 0.08, 0.88))
	var frac = hp / MAX_HP
	var col : Color
	if frac > 0.5:
		col = Color(0.2, 0.85, 0.2)
	elif frac > 0.25:
		col = Color(0.85, 0.60, 0.1)
	else:
		col = Color(0.85, 0.15, 0.1)
	draw_rect(Rect2(bx, by, bw * frac, bh), col)
	draw_rect(Rect2(bx, by, bw, bh), Color(0.4, 0.4, 0.4, 0.65), false, 1.0)
	var font = _roboto
	var _ct_sc = get_canvas_transform().get_scale()
	var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
	var _rend_sz = maxi(1, int(round(8 * _ct_sc.x)))
	draw_set_transform(Vector2(bx, by - 3), 0.0, _inv)
	draw_string(font, Vector2.ZERO, "ZERG LAIR",
		HORIZONTAL_ALIGNMENT_LEFT, bw, _rend_sz, Color(0.88, 0.88, 0.68, 0.88))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
