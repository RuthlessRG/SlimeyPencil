extends Node2D

# ============================================================
#  GroundLoot.gd — SWG-style ground loot pickup
#  Spawned when mobs die. Player walks over to collect.
#  Shows animated glowing coin/credit pile. Auto-despawns.
# ============================================================

const PICKUP_RANGE : float = 38.0
const LIFETIME     : float = 28.0   # seconds before despawn
const PULSE_SPEED  : float = 3.5

var credits  : int    = 0
var xp       : float  = 0.0
var _t       : float  = 0.0
var _picked  : bool   = false
var _font    : Font   = null

func init(cred: int, exp: float) -> void:
	credits = cred
	xp      = exp
	_font   = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	# Despawn after lifetime
	if _t >= LIFETIME:
		queue_free()
		return
	# Check for player pickup
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p): continue
		if p.get("_dying") == true or p.get("_incapped") == true: continue
		if global_position.distance_to(p.global_position) <= PICKUP_RANGE:
			_collect(p)
			return

func _collect(player: Node) -> void:
	if _picked: return
	_picked = true
	if credits > 0 and player.has_method("add_credits"):
		player.call("add_credits", credits)
	if xp > 0.0 and player.has_method("add_exp"):
		player.call("add_exp", xp)
	queue_free()

func _draw() -> void:
	if _picked: return

	var pulse    = 0.65 + sin(_t * PULSE_SPEED) * 0.35
	var fade_in  = clampf(_t / 0.4, 0.0, 1.0)
	# Blink fast in last 5 seconds as warning
	var blink    = 1.0
	var time_left = LIFETIME - _t
	if time_left < 5.0:
		blink = 0.5 + absf(sin(_t * 8.0)) * 0.5

	var alpha = fade_in * blink

	# Ground shadow
	draw_ellipse_arc_polygon(Vector2(0, 2), 10.0, 3.5, Color(0, 0, 0, 0.25 * alpha))

	# Outer glow ring
	draw_circle(Vector2.ZERO, 9.0 + pulse * 3.0, Color(1.0, 0.85, 0.15, 0.18 * alpha))
	draw_circle(Vector2.ZERO, 7.0 + pulse * 2.0, Color(1.0, 0.90, 0.25, 0.28 * alpha))

	# Main coin body
	draw_circle(Vector2.ZERO, 7.0, Color(0.95, 0.78, 0.15, alpha))
	draw_circle(Vector2.ZERO, 5.5, Color(1.0,  0.90, 0.30, alpha))
	draw_circle(Vector2.ZERO, 3.5, Color(1.0,  0.95, 0.50, alpha * 0.9))

	# Credit symbol (¢) drawn as string
	if _font != null:
		var ct_sc = get_canvas_transform().get_scale()
		var inv   = Vector2(1.0 / ct_sc.x, 1.0 / ct_sc.y)
		var fsz   = maxi(1, int(round(9 * ct_sc.x)))
		draw_set_transform(Vector2(-3.5, -4.5), 0.0, inv)
		draw_string(_font, Vector2.ZERO, "¢", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz,
			Color(0.65, 0.45, 0.05, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Credit amount label above coin (fade in with coin)
	if _font != null and credits > 0:
		var ct_sc2 = get_canvas_transform().get_scale()
		var inv2   = Vector2(1.0 / ct_sc2.x, 1.0 / ct_sc2.y)
		var fsz2   = maxi(1, int(round(8 * ct_sc2.x)))
		draw_set_transform(Vector2(-8, -18), 0.0, inv2)
		draw_string(_font, Vector2.ZERO, "+%d¢" % credits, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz2,
			Color(1.0, 0.92, 0.30, alpha * 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_ellipse_arc_polygon(center: Vector2, rx: float, ry: float, color: Color, steps: int = 16) -> void:
	var pts = PackedVector2Array()
	for i in steps:
		var a = TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
