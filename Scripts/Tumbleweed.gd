extends Node2D

# ============================================================
#  Tumbleweed.gd — realistic branchy desert tumbleweed
#  Rolls across the map, fades after a while.
# ============================================================

const ROLL_SPEED    = 60.0
const SPIN_RATE     = 3.8   # radians/second
const FADE_AFTER    = 6.0
const FADE_DURATION = 1.2

var _velocity : Vector2 = Vector2.ZERO
var _spin     : float   = 0.0
var _radius   : float   = 0.0
var _life     : float   = 0.0

# Pre-computed branch layout (set once in init, drawn every frame)
# Each branch: [angle, length_frac, width, color_idx]
var _branches_outer  : Array = []
var _branches_mid    : Array = []
var _branches_inner  : Array = []

# Palette — sun-bleached desert tumbleweed colours
const C_SHADOW   = Color(0.00, 0.00, 0.00, 0.28)
const C_BODY     = Color(0.68, 0.53, 0.30, 0.55)   # warm tan silhouette
const C_BRANCH_A = Color(0.76, 0.61, 0.35, 0.92)   # light straw
const C_BRANCH_B = Color(0.58, 0.43, 0.22, 0.88)   # mid brown
const C_BRANCH_C = Color(0.42, 0.29, 0.12, 0.80)   # dark inner shadow
const C_TWIG     = Color(0.82, 0.70, 0.48, 0.70)   # pale tips

func _ready() -> void:
	add_to_group("tumbleweed")

func init(start_pos: Vector2, direction: Vector2, radius: float) -> void:
	global_position = start_pos
	_velocity = direction.normalized() * ROLL_SPEED
	_radius   = radius
	_build_branches()

func _build_branches() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7 + global_position.y * 13)

	# Outer structural arms — 11 main branches, irregular lengths
	var outer_count = 11
	for i in outer_count:
		var base_angle = float(i) / float(outer_count) * TAU
		var jitter     = rng.randf_range(-0.18, 0.18)
		var angle      = base_angle + jitter
		# Sphere effect: shorter near top/bottom of circle
		var sphere_factor = 0.55 + 0.45 * abs(sin(angle + rng.randf_range(-0.3, 0.3)))
		_branches_outer.append({
			"angle":  angle,
			"len":    sphere_factor * rng.randf_range(0.78, 1.0),
			"width":  rng.randf_range(1.4, 2.4),
			"color":  C_BRANCH_A if rng.randf() > 0.4 else C_BRANCH_B,
		})

	# Mid crossing branches — diagonal grid inside
	var mid_count = 16
	for i in mid_count:
		var angle = float(i) / float(mid_count) * TAU + rng.randf_range(-0.25, 0.25)
		var t     = rng.randf_range(0.25, 0.55)   # inner radial start
		_branches_mid.append({
			"angle": angle,
			"start": t,
			"len":   rng.randf_range(0.28, 0.55),
			"width": rng.randf_range(0.9, 1.6),
			"color": C_BRANCH_B if rng.randf() > 0.35 else C_BRANCH_C,
		})

	# Inner shadow web — short strokes near center
	var inner_count = 9
	for i in inner_count:
		var angle = float(i) / float(inner_count) * TAU + rng.randf_range(-0.4, 0.4)
		_branches_inner.append({
			"angle": angle,
			"len":   rng.randf_range(0.20, 0.38),
			"width": rng.randf_range(0.7, 1.1),
			"color": C_BRANCH_C,
		})

func _process(delta: float) -> void:
	_life           += delta
	global_position += _velocity * delta
	_spin           += SPIN_RATE * delta

	if _life >= FADE_AFTER:
		modulate.a = 1.0 - clampf((_life - FADE_AFTER) / FADE_DURATION, 0.0, 1.0)
		if _life >= FADE_AFTER + FADE_DURATION:
			queue_free()
			return

	queue_redraw()

	# Out-of-world cleanup
	var margin = _radius + 200.0
	if (global_position.x < -margin or global_position.x > 3840.0 + margin or
		global_position.y < -margin or global_position.y > 2160.0 + margin):
		queue_free()

func _draw() -> void:
	var r = _radius

	# ── Ground shadow ────────────────────────────────────────────
	var sh_pts = PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		sh_pts.append(Vector2(cos(a) * r * 1.1, sin(a) * r * 0.35) + Vector2(1.5, r * 0.85))
	draw_colored_polygon(sh_pts, C_SHADOW)

	# ── Soft body silhouette ─────────────────────────────────────
	var body_pts = PackedVector2Array()
	for i in 24:
		var a = float(i) / 24.0 * TAU
		body_pts.append(Vector2(cos(a) * r, sin(a) * r))
	draw_colored_polygon(body_pts, C_BODY)

	# ── Everything below rotates with the tumble ──────────────────
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)

	# Inner shadow web (darkest, drawn first / underneath)
	for b in _branches_inner:
		var tip = Vector2(cos(b.angle), sin(b.angle)) * r * b.len
		draw_line(Vector2.ZERO, tip, b.color, b.width)

	# Mid diagonal crosses
	for b in _branches_mid:
		var origin = Vector2(cos(b.angle), sin(b.angle)) * r * b.start
		var end    = Vector2(cos(b.angle), sin(b.angle)) * r * (b.start + b.len)
		# Clamp inside sphere
		if end.length() > r * 0.95:
			end = end.normalized() * r * 0.95
		draw_line(origin, end, b.color, b.width)

	# Outer structural arms (on top — brightest)
	for b in _branches_outer:
		var tip = Vector2(cos(b.angle), sin(b.angle)) * r * b.len
		draw_line(Vector2.ZERO, tip, b.color, b.width)
		# Pale twig extension past the main branch tip
		var ext = Vector2(cos(b.angle), sin(b.angle)) * r * (b.len + 0.12)
		draw_line(tip, ext, C_TWIG, 0.8)

	# Reset transform for any subsequent draws
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
