extends Node2D

# ============================================================
#  TrainingDummy.gd — Beyond the Veil
#  A wooden training dummy that takes damage from abilities.
#  Spawned by DojoScene on F1 near the player.
#
#  Add to scene as a Node2D with this script attached.
#  No child nodes required — draws itself with _draw().
# ============================================================

const MAX_HP         = 1400.0
const HIT_FLASH_TIME = 0.18
const WOBBLE_DECAY   = 4.0
const WOBBLE_AMOUNT  = 6.0   # degrees
const REGEN_DELAY    = 5.0   # seconds after last hit before HP resets
const REGEN_TIME     = 3.0   # seconds to fully regen

# Expose hp/max_hp so UI target frame can read them directly
var hp      : float = MAX_HP
var max_hp  : float = MAX_HP
var mp      : float = 0.0
var max_mp  : float = 0.0

# Minimal stats-like info for target frame
var character_name  : String = "Training Dummy"
var character_class : String = "Dummy"
var level           : int    = 1
var _hit_flash   : float = 0.0   # 0-1 white flash timer
var _wobble      : float = 0.0   # degrees rotation from impact
var _regen_timer : float = 0.0
var _is_dead     : bool  = false
var _death_timer : float = 0.0
const DEATH_TIME = 1.8  # seconds to fall over before queue_free

# Knockdown — uppercut sends dummy to the ground temporarily
var _is_knocked_down  : bool  = false
var _knockdown_timer  : float = 0.0
const KNOCKDOWN_LEAN_DEG = 68.0

# Hitlag — brief animation freeze on hit (cinematic slo-mo)
var _hitlag_timer : float = 0.0

# Knockback — applied by UI when kick finisher lands
var _knockback_vel : Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION = 320.0

# Sparks — small line bursts that fly out on hit
var _sparks : Array = []  # [{pos, vel, life, max_life, col}]
const SPARK_COUNT = 10

# HP bar tracking
var _hp_label_node : Node = null  # we'll draw the bar ourselves

# Colors — Mook Jong wood palette
const C_WOOD_MAIN  = Color(0.58, 0.38, 0.18)   # warm walnut
const C_WOOD_DARK  = Color(0.32, 0.20, 0.08)   # deep shadow grain
const C_WOOD_LITE  = Color(0.74, 0.56, 0.30)   # highlight edge
const C_WOOD_GRAIN = Color(0.44, 0.28, 0.10)   # subtle grain lines
const C_WOOD_RING  = Color(0.24, 0.14, 0.04)   # dark reinforcement rings
const C_BASE_DARK  = Color(0.20, 0.12, 0.04)   # base frame
const C_HP_FULL  = Color(0.18, 0.72, 0.26)
const C_HP_LOW   = Color(0.82, 0.16, 0.14)
const C_HP_BG    = Color(0.08, 0.04, 0.04)

func _ready() -> void:
	add_to_group("training_dummy")
	add_to_group("targetable")   # makes it findable by UI target system
	z_index = 1

func get_display_name() -> String:
	return character_name

func _process(delta: float) -> void:
	if _is_dead:
		_death_timer += delta
		if _death_timer >= DEATH_TIME:
			queue_free()
		queue_redraw()
		return

	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta / HIT_FLASH_TIME)

	# Hitlag — freeze wobble animation while active
	if _hitlag_timer > 0.0:
		_hitlag_timer -= delta
	elif _wobble != 0.0:
		_wobble = move_toward(_wobble, 0.0, WOBBLE_DECAY * delta * clampf(absf(_wobble), 1.0, WOBBLE_AMOUNT))

	# Knockdown tick
	if _is_knocked_down:
		_knockdown_timer -= delta
		if _knockdown_timer <= 0.0:
			_is_knocked_down = false
			_knockdown_timer = 0.0

	# Knockback slide
	if _knockback_vel.length_squared() > 1.0:
		position += _knockback_vel * delta
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)

	# Regen HP after delay
	if hp < MAX_HP and hp > 0.0:
		_regen_timer += delta
		if _regen_timer >= REGEN_DELAY:
			hp = minf(MAX_HP, hp + (MAX_HP / REGEN_TIME) * delta)

	# Tick sparks
	for i in range(_sparks.size() - 1, -1, -1):
		var s = _sparks[i]
		s.life -= delta
		if s.life <= 0.0:
			_sparks.remove_at(i)
		else:
			s.pos += s.vel * delta
			s.vel = s.vel.move_toward(Vector2.ZERO, 280.0 * delta)

	queue_redraw()

func _draw() -> void:
	var wobble_rad = deg_to_rad(_wobble)
	var death_lean = 0.0
	if _is_dead:
		death_lean = deg_to_rad(lerp(0.0, 100.0, clampf(_death_timer / DEATH_TIME, 0.0, 1.0)))
	elif _is_knocked_down:
		death_lean = deg_to_rad(KNOCKDOWN_LEAN_DEG)
	var total_angle = wobble_rad + death_lean
	var flash = _hit_flash
	var pivot = Vector2(0, 30)

	# Helper: get flashed version of wood color
	var wd  = C_WOOD_DARK.lerp(Color.WHITE, flash * 0.45)
	var wm  = C_WOOD_MAIN.lerp(Color.WHITE, flash * 0.45)
	var wl  = C_WOOD_LITE.lerp(Color.WHITE, flash * 0.45)
	var wr  = C_WOOD_RING.lerp(Color.WHITE, flash * 0.3)

	# 1. Ground shadow
	_draw_ellipse_shape(Vector2(0, 34), 18.0, 6.0, Color(0, 0, 0, 0.28))

	# 2. Base frame (doesn't rotate — stays on ground)
	draw_line(Vector2(-14, 28), Vector2(-8, 40), C_BASE_DARK, 7.0)
	draw_line(Vector2(-14, 28), Vector2(-8, 40), C_WOOD_DARK, 5.0)
	draw_line(Vector2(14, 28), Vector2(8, 40), C_BASE_DARK, 7.0)
	draw_line(Vector2(14, 28), Vector2(8, 40), C_WOOD_DARK, 5.0)
	draw_line(Vector2(-10, 38), Vector2(10, 38), C_BASE_DARK, 6.0)
	draw_line(Vector2(-10, 38), Vector2(10, 38), C_WOOD_DARK, 4.0)

	# 3. Main vertical post (cylindrical, rotates from pivot)
	var post_top = rotate_pt(Vector2(0, -85), pivot, total_angle)
	var post_bot = pivot
	var post_dir = (post_top - post_bot).normalized() if post_top != post_bot else Vector2(0, -1)
	var perp = Vector2(-post_dir.y, post_dir.x) * 2.5
	draw_line(post_bot, post_top, wd, 13.0)
	draw_line(post_bot, post_top, wm, 10.0)
	draw_line(post_bot + perp, post_top + perp, wl, 3.5)

	# 4. Post rings (darker bands at intervals)
	for ring_y in [-60.0, -40.0, -20.0, 0.0]:
		var rl = rotate_pt(Vector2(-6, ring_y), pivot, total_angle)
		var rr = rotate_pt(Vector2(6, ring_y), pivot, total_angle)
		draw_line(rl, rr, wr, 4.0)
		draw_line(rl, rr, C_WOOD_GRAIN, 2.0)

	# 5. Shoulder arms — two arms at y=-62, extending ±34px each
	for side in [-1.0, 1.0]:
		var arm_base = rotate_pt(Vector2(0, -62), pivot, total_angle)
		var arm_end  = rotate_pt(Vector2(side * 34, -62), pivot, total_angle)
		var arm_dir  = (arm_end - arm_base).normalized() if arm_end != arm_base else Vector2(side, 0)
		var aperp    = Vector2(-arm_dir.y, arm_dir.x) * 2.0
		draw_line(arm_base, arm_end, wd, 9.0)
		draw_line(arm_base, arm_end, wm, 7.0)
		draw_line(arm_base + aperp, arm_end + aperp, wl, 2.5)
		draw_circle(arm_end, 5.0, wd)
		draw_circle(arm_end, 4.0, wm)

	# 6. Mid chest arm — single arm extending right at y=-38
	var ma_base = rotate_pt(Vector2(0, -38), pivot, total_angle)
	var ma_end  = rotate_pt(Vector2(36, -38), pivot, total_angle)
	var ma_dir  = (ma_end - ma_base).normalized() if ma_end != ma_base else Vector2(1, 0)
	var mperp   = Vector2(-ma_dir.y, ma_dir.x) * 2.0
	draw_line(ma_base, ma_end, wd, 9.0)
	draw_line(ma_base, ma_end, wm, 7.0)
	draw_line(ma_base + mperp, ma_end + mperp, wl, 2.5)
	draw_circle(ma_end, 5.0, wd)
	draw_circle(ma_end, 4.0, wm)

	# 7. Leg arm — angled down-right from y=-8 to approx y=+18
	var la_base = rotate_pt(Vector2(0, -8), pivot, total_angle)
	var la_end  = rotate_pt(Vector2(32, 20), pivot, total_angle)
	var la_dir  = (la_end - la_base).normalized() if la_end != la_base else Vector2(0.85, 0.53)
	var lperp   = Vector2(-la_dir.y, la_dir.x) * 2.0
	draw_line(la_base, la_end, wd, 9.0)
	draw_line(la_base, la_end, wm, 7.0)
	draw_line(la_base + lperp, la_end + lperp, wl, 2.5)
	draw_circle(la_end, 5.0, wd)
	draw_circle(la_end, 4.0, wm)

	# 8. Post front face re-draw (so post visually overlaps arm bases)
	draw_line(post_bot, post_top, wd, 13.0)
	draw_line(post_bot, post_top, wm, 10.0)
	draw_line(post_bot + perp, post_top + perp, wl, 3.5)
	for ring_y2 in [-60.0, -40.0, -20.0, 0.0]:
		var rl2 = rotate_pt(Vector2(-6, ring_y2), pivot, total_angle)
		var rr2 = rotate_pt(Vector2(6, ring_y2), pivot, total_angle)
		draw_line(rl2, rr2, wr, 4.0)
		draw_line(rl2, rr2, C_WOOD_GRAIN, 2.0)

	# 9. Top cap (wooden ball at tip of post)
	var cap = rotate_pt(Vector2(0, -88), pivot, total_angle)
	draw_circle(cap, 9.0, wd)
	draw_circle(cap, 7.5, wm)
	draw_circle(cap + rotate_dir(Vector2(-2, -2), total_angle), 3.0, wl)

	# 10. Wood grain lines on post
	for gi in range(0, 8):
		var gy = -75.0 + gi * 14.0
		var gp0 = rotate_pt(Vector2(-2, gy), pivot, total_angle)
		var gp1 = rotate_pt(Vector2(-2, gy + 9.0), pivot, total_angle)
		draw_line(gp0, gp1, C_WOOD_GRAIN, 1.0)

	# 11. HP bar (always drawn upright, fades when full)
	var bar_w   = 44.0
	var bar_h   = 5.0
	var bar_x   = -bar_w * 0.5
	var bar_y   = -108.0
	var bar_alpha = clampf(1.0 - hp / MAX_HP + 0.15, 0.0, 1.0) if not _is_dead else 0.3
	if bar_alpha > 0.02:
		draw_rect(Rect2(bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(C_HP_BG.r, C_HP_BG.g, C_HP_BG.b, bar_alpha))
		var hp_ratio = maxf(0.0, hp / MAX_HP)
		var bar_col  = C_HP_FULL.lerp(C_HP_LOW, 1.0 - hp_ratio)
		bar_col.a    = bar_alpha
		draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), bar_col)

	# 12. Target outline (if targeted)
	if _is_targeted():
		var pulse  = 0.7 + sin(Time.get_ticks_msec() * 0.006) * 0.3
		var oc     = Color(1.0, 0.10, 0.10, pulse)
		var glow_c = Color(1.0, 0.15, 0.15, pulse * 0.35)
		draw_arc(cap, 12.0, 0, TAU, 32, glow_c, 7.0)
		draw_arc(cap, 12.0, 0, TAU, 32, oc, 2.5)
		var out_l = Vector2(-post_dir.y, post_dir.x) * 8.0
		draw_line(post_bot + out_l, post_top + out_l, glow_c, 5.0)
		draw_line(post_bot - out_l, post_top - out_l, glow_c, 5.0)
		draw_line(post_bot + out_l, post_top + out_l, oc, 2.0)
		draw_line(post_bot - out_l, post_top - out_l, oc, 2.0)

	# 13. Sparks (on top of everything)
	for s in _sparks:
		var alpha = s.life / s.max_life
		var col   = Color(s.col.r, s.col.g, s.col.b, alpha)
		var tip   = s.pos + s.vel.normalized() * lerpf(2.0, 8.0, alpha)
		draw_line(s.pos, tip, col, 1.5)

# ============================================================
#  PUBLIC — take_damage
#  Called by DojoScene's damage dispatch (or directly).
#  Returns true if the dummy died.
# ============================================================

func take_damage(amount: float) -> bool:
	if _is_dead:
		return false
	hp = maxf(0.0, hp - amount)
	_hit_flash   = 1.0
	_wobble      = WOBBLE_AMOUNT * sign(randf() - 0.5)
	_regen_timer = 0.0
	_spawn_sparks()
	if hp <= 0.0:
		_is_dead = true
	return _is_dead

func apply_knockback(dir: Vector2) -> void:
	if _is_dead:
		return
	_knockback_vel = dir
	_wobble = WOBBLE_AMOUNT * 1.5 * sign(dir.x if absf(dir.x) > absf(dir.y) else dir.y)

func _spawn_sparks() -> void:
	# Orange/yellow spark burst — like a fighting game hit effect
	for i in SPARK_COUNT:
		var angle = randf() * TAU
		var spd   = randf_range(80.0, 220.0)
		var life  = randf_range(0.15, 0.35)
		var warm  = randf_range(0.0, 1.0)
		var col   = Color(1.0, lerpf(0.3, 0.9, warm), 0.0, 1.0)
		_sparks.append({
			"pos": Vector2(randf_range(-6, 6), randf_range(-20, 0)),
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"life": life, "max_life": life, "col": col
		})

func _is_targeted() -> bool:
	# Ask the UI CanvasLayer if this node is the current target
	var ui_nodes = get_tree().get_nodes_in_group("ui_layer")
	if ui_nodes.size() > 0:
		var ui = ui_nodes[0]
		if ui.has_method("is_targeted"):
			return ui.is_targeted(self)
	return false

# ============================================================
#  DRAW HELPERS
# ============================================================

func rotate_pt(pt: Vector2, pivot: Vector2, angle: float) -> Vector2:
	var local = pt - pivot
	var cos_a  = cos(angle)
	var sin_a  = sin(angle)
	return pivot + Vector2(local.x * cos_a - local.y * sin_a,
						   local.x * sin_a + local.y * cos_a)

func rotate_dir(dir: Vector2, angle: float) -> Vector2:
	return Vector2(dir.x * cos(angle) - dir.y * sin(angle),
				   dir.x * sin(angle) + dir.y * cos(angle))

func rotated_rect(top_left: Vector2, bottom_right: Vector2,
		pivot: Vector2, angle: float) -> PackedVector2Array:
	var corners = [
		Vector2(top_left.x,     top_left.y),
		Vector2(bottom_right.x, top_left.y),
		Vector2(bottom_right.x, bottom_right.y),
		Vector2(top_left.x,     bottom_right.y),
	]
	var pts := PackedVector2Array()
	for c in corners:
		pts.append(rotate_pt(c, pivot, angle))
	return pts

func shrink_poly(pts: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center = Vector2.ZERO
	for p in pts: center += p
	center /= pts.size()
	var result := PackedVector2Array()
	for p in pts:
		result.append(p.move_toward(center, amount))
	return result

# ── Knockdown — called by Uppercut finisher ──────────────────
func apply_knockdown_state(duration: float) -> void:
	if _is_dead:
		return
	_is_knocked_down = true
	_knockdown_timer  = duration
	_wobble           = 0.0   # stop wobble while floored

# ── Hitlag — cinematic freeze on hit ─────────────────────────
func start_hitlag(duration: float) -> void:
	_hitlag_timer = maxf(_hitlag_timer, duration)

func _draw_ellipse_shape(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
