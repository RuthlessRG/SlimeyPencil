extends Node2D

# ============================================================
#  WindEffect.gd — looping wind gusts that trace loop-de-loops
#  Each particle follows a trochoid (cycloid) path:
#  x(t) = forward_speed * t + loop_r * sin(omega * t + phase)
#  y(t) = y_base - loop_r * cos(omega * t + phase) + loop_r
#  When loop_r * omega > forward_speed the path loops backward.
# ============================================================

const DURATION   = 0.90
const LINE_COUNT = 5
const TRAIL_STEPS = 28       # path sample points for the trail

var _t       : float = 0.0
var _gusts   : Array = []

# Each gust: {y_base, forward_speed, loop_r, omega, phase, alpha_mul, width, start_delay}
func init() -> void:
	for i in LINE_COUNT:
		var loop_r  = randf_range(22.0, 48.0)
		var omega   = randf_range(3.8, 6.5)      # rad/s — loop spin speed
		# Forward net speed must be < loop_r * omega to actually loop
		var fwd     = randf_range(50.0, 110.0)
		_gusts.append({
			"y_base":      randf_range(-70.0, 70.0),
			"forward_speed": fwd,
			"loop_r":      loop_r,
			"omega":       omega,
			"phase":       randf_range(0.0, TAU),
			"alpha_mul":   randf_range(0.55, 1.0),
			"width":       randf_range(1.1, 2.2),
			"start_delay": randf_range(0.0, 0.18),
		})

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()

func _gust_pos(g: Dictionary, t: float) -> Vector2:
	var angle = g.omega * t + g.phase
	return Vector2(
		g.forward_speed * t + g.loop_r * sin(angle),
		g.y_base + g.loop_r - g.loop_r * cos(angle)
	)

func _draw() -> void:
	var progress = clampf(_t / DURATION, 0.0, 1.0)
	# Global fade envelope — in fast, out slow
	var fade = pow(sin(progress * PI), 0.7)

	for g in _gusts:
		var elapsed = _t - g.start_delay
		if elapsed <= 0.0:
			continue

		# Build trail: sample path over [0 .. elapsed]
		var pts   : PackedVector2Array = PackedVector2Array()
		var alphas : Array = []

		for s in TRAIL_STEPS:
			var tf = float(s) / float(TRAIL_STEPS - 1)
			var t_sample = elapsed * tf
			pts.append(_gust_pos(g, t_sample))
			# Tail fades to transparent, head is brightest
			alphas.append(tf * tf)   # quadratic ramp

		# Draw connected segments with fading alpha
		for s in TRAIL_STEPS - 1:
			var a0 = alphas[s]     * fade * g.alpha_mul
			var a1 = alphas[s + 1] * fade * g.alpha_mul

			if a0 < 0.01 and a1 < 0.01:
				continue

			var alpha_avg = (a0 + a1) * 0.5

			# Soft outer glow
			draw_line(pts[s], pts[s + 1],
				Color(0.80, 0.92, 1.0, alpha_avg * 0.40), g.width + 2.5)
			# Core bright line
			draw_line(pts[s], pts[s + 1],
				Color(0.96, 0.98, 1.0, alpha_avg * 0.85), g.width)

		# Glint at the leading tip (head)
		var tip_a = fade * g.alpha_mul * 0.80
		if tip_a > 0.05:
			draw_circle(pts[TRAIL_STEPS - 1], 1.8, Color(1.0, 1.0, 1.0, tip_a))
