extends Node2D

# ============================================================
#  MeleeHit.gd — impact flash for melee / brawler attacks.
#  Spawned by BossArenaScene.spawn_melee_hit().
# ============================================================

const DURATION = 0.22

var _t     : float = 0.0
var _color : Color = Color(1.0, 0.55, 0.1)
var _rot   : float = 0.0   # random per-hit rotation for slash variety

func init(col: Color) -> void:
	_color = col
	_rot   = randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t     = _t / DURATION
	var alpha = 1.0 - t

	# Bright center burst
	draw_circle(Vector2.ZERO, lerpf(9.0, 2.0, t),
		Color(_color.r, _color.g, _color.b, alpha * 0.92))

	# 3 slash streaks radiating outward at random rotation
	for i in 3:
		var angle = _rot + float(i) / 3.0 * TAU
		var tip  = Vector2(cos(angle), sin(angle)) * lerpf(6.0, 26.0, t)
		var tail = Vector2(cos(angle + PI), sin(angle + PI)) * lerpf(3.0, 10.0, t)
		draw_line(tail, tip,
			Color(_color.r, _color.g, _color.b, alpha * 0.82),
			lerpf(3.5, 1.0, t))

	# Expanding ring
	draw_arc(Vector2.ZERO, lerpf(6.0, 22.0, t), 0.0, TAU, 20,
		Color(_color.r, _color.g, _color.b, alpha * 0.45), 1.8)
