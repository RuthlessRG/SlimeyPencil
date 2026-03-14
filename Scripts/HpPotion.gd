extends Node2D

# ============================================================
#  HpPotion.gd — HP potion dropped by bosses on death
#  Drawn entirely in code. Player walks over it to heal 100 HP.
# ============================================================

const HEAL_AMOUNT  : float = 100.0
const PICKUP_RANGE : float = 14.0
const BOB_SPEED    : float = 2.2
const BOB_AMP      : float = 4.0

var _t          : float = 0.0
var _picked_up  : bool  = false

func _process(delta: float) -> void:
	if _picked_up:
		return

	_t += delta

	# Bob up and down
	position.y += sin(_t * BOB_SPEED) * BOB_AMP * delta

	# Check proximity to any player
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		if global_position.distance_to(p.global_position) <= PICKUP_RANGE:
			var cur_hp = p.get("hp") as float
			var max_hp = p.get("max_hp") as float
			if cur_hp != null and max_hp != null and cur_hp >= max_hp:
				continue   # full HP — can't pick up
			_pickup(p)
			return

	queue_redraw()

func _pickup(player: Node) -> void:
	_picked_up = true

	# Heal the player
	if player.has_method("take_damage"):
		pass   # heal via direct HP assignment below
	var cur_hp = player.get("hp")     as float
	var max_hp = player.get("max_hp") as float
	if cur_hp != null and max_hp != null:
		player.set("hp", minf(cur_hp + HEAL_AMOUNT, max_hp))

	# Spawn a heal number (green, upward float)
	var arena = get_tree().get_first_node_in_group("boss_arena_scene")
	if arena and arena.has_method("spawn_damage_number"):
		arena.spawn_damage_number(global_position, HEAL_AMOUNT, Color(0.2, 1.0, 0.35))

	queue_free()

func _draw() -> void:
	if _picked_up:
		return

	var glow = 0.7 + sin(_t * 3.5) * 0.3

	# ── Shadow ──────────────────────────────────────────────
	draw_ellipse_approx(Vector2(0, 10), 10, 3, Color(0, 0, 0, 0.28))

	# ── Bottle body (rounded rect, dark glass) ───────────────
	# Body
	draw_rect(Rect2(-7, -2, 14, 16), Color(0.55, 0.08, 0.08, 0.88))
	draw_rect(Rect2(-6, -1, 12, 14), Color(0.72 * glow, 0.10, 0.10, 0.92))

	# Liquid fill (bright red)
	draw_rect(Rect2(-5, 3, 10, 9), Color(0.95 * glow, 0.15, 0.15, 0.95))

	# Highlight on liquid
	draw_rect(Rect2(-4, 4, 3, 5), Color(1.0, 0.55, 0.55, 0.55))

	# ── Bottle neck ──────────────────────────────────────────
	draw_rect(Rect2(-3, -8, 6, 7), Color(0.50, 0.07, 0.07, 0.88))
	draw_rect(Rect2(-2, -7, 4, 5), Color(0.65 * glow, 0.10, 0.10, 0.90))

	# ── Cork / cap ───────────────────────────────────────────
	draw_rect(Rect2(-4, -11, 8, 4), Color(0.72, 0.52, 0.22, 0.95))
	draw_rect(Rect2(-3, -10, 6, 2), Color(0.85, 0.68, 0.38, 0.90))

	# ── Outline ──────────────────────────────────────────────
	# Body outline
	draw_rect(Rect2(-7, -2, 14, 16), Color(0.2, 0.0, 0.0, 0.80), false, 1.2)
	# Neck outline
	draw_rect(Rect2(-3, -8, 6, 7),   Color(0.2, 0.0, 0.0, 0.80), false, 1.0)
	# Cork outline
	draw_rect(Rect2(-4, -11, 8, 4),  Color(0.35, 0.22, 0.05, 0.80), false, 1.0)

	# ── Cross symbol on bottle ───────────────────────────────
	draw_rect(Rect2(-1, 4, 2, 7), Color(1.0, 1.0, 1.0, 0.70))
	draw_rect(Rect2(-3, 6, 6, 2), Color(1.0, 1.0, 1.0, 0.70))

	# ── Glow ring when close to player ───────────────────────
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		var dist = global_position.distance_to(p.global_position)
		if dist < PICKUP_RANGE * 2.5:
			var ring_a = (1.0 - dist / (PICKUP_RANGE * 2.5)) * 0.6
			draw_arc(Vector2(0, 4), 14, 0, TAU, 24, Color(0.3, 1.0, 0.4, ring_a), 2.0)
		break

# Helper: approximate ellipse with polygon
func draw_ellipse_approx(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)
