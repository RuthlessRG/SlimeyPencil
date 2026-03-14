extends Node2D

# ============================================================
#  BossCrumble.gd — reusable death effect for bosses.
#  Spawned at the boss's world position on death.
#  Shatters into debris chunks that scatter outward and fade.
#
#  Usage (from any boss script):
#    var crumble = Node2D.new()
#    crumble.set_script(load("res://Scripts/BossCrumble.gd"))
#    crumble.global_position = global_position
#    get_parent().add_child(crumble)
#    crumble.call("init", sprite_scale, boss_color)
# ============================================================

const DURATION     = 1.6    # total seconds before self-destruct
const CHUNK_COUNT  = 28     # number of debris pieces

var _t      : float = 0.0
var _chunks : Array = []    # [{pos, vel, rot, rot_spd, size, col, alpha}]

func init(sprite_scale: Vector2, base_color: Color) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var spread_r = 60.0 * maxf(sprite_scale.x, sprite_scale.y)

	for i in CHUNK_COUNT:
		var angle   = rng.randf() * TAU
		var speed   = rng.randf_range(30.0, spread_r * 1.4)
		var size    = rng.randf_range(4.0, 14.0) * maxf(sprite_scale.x, 1.0)
		# Slight color variation around the base color
		var hue_shift = rng.randf_range(-0.06, 0.06)
		var col = Color(
			clampf(base_color.r + hue_shift,       0.0, 1.0),
			clampf(base_color.g + hue_shift * 0.5, 0.0, 1.0),
			clampf(base_color.b + hue_shift * 0.3, 0.0, 1.0),
		)
		_chunks.append({
			"pos":     Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0)),
			"vel":     Vector2(cos(angle), sin(angle)) * speed,
			"rot":     rng.randf() * TAU,
			"rot_spd": rng.randf_range(-6.0, 6.0),
			"size":    size,
			"col":     col,
			"alpha":   1.0,
		})

func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return

	var progress = _t / DURATION

	for c in _chunks:
		# Gravity-like drag: chunks slow down over time
		c.vel  = c.vel.move_toward(Vector2.ZERO, c.vel.length() * delta * 2.2)
		c.pos += c.vel * delta
		c.rot += c.rot_spd * delta
		# Stay fully opaque for first 40%, then fade
		c.alpha = 1.0 - clampf((progress - 0.4) / 0.6, 0.0, 1.0)

	queue_redraw()

func _draw() -> void:
	for c in _chunks:
		var col = Color(c.col.r, c.col.g, c.col.b, c.alpha)
		# Each chunk is a small rotated rectangle (looks like a stone shard)
		draw_set_transform(c.pos, c.rot, Vector2.ONE)
		var half = c.size * 0.5
		var rect_pts = PackedVector2Array([
			Vector2(-half,        -half * 0.45),
			Vector2( half * 0.85, -half * 0.5),
			Vector2( half,         half * 0.4),
			Vector2(-half * 0.9,   half * 0.5),
		])
		draw_colored_polygon(rect_pts, col)
		# Dark edge for depth
		draw_polyline(rect_pts, Color(0.0, 0.0, 0.0, c.alpha * 0.45), 0.8)
		# Close the polyline back to start
		draw_line(rect_pts[3], rect_pts[0], Color(0.0, 0.0, 0.0, c.alpha * 0.45), 0.8)
