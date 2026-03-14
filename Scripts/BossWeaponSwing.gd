extends Node2D

# ============================================================
#  BossWeaponSwing.gd — animated weapon visual
#  Handles knife stab AND rifle shoot animations.
#  Spawned as a child of the attacking player.
# ============================================================

const DURATION       : float = 0.32   # knife stab duration (seconds)
const RIFLE_DURATION : float = 0.42   # rifle shoot duration (seconds)

var _item_data : Dictionary = {}
var _facing    : String     = "s"
var _t         : float      = 0.0
var _is_rifle  : bool       = false

# ── Brass casing ejection state ───────────────────────────────
var _casing_spawned  : bool    = false
var _casing_pos      : Vector2 = Vector2.ZERO
var _casing_vel      : Vector2 = Vector2.ZERO
var _casing_rot      : float   = 0.0
var _casing_rot_spd  : float   = 0.0
var _casing_life     : float   = 0.0
var _casing_alpha    : float   = 1.0

func init(item_data: Dictionary, facing: String) -> void:
	_item_data = item_data
	_facing    = facing
	_is_rifle  = (item_data.get("type", "") == "rifle")

func _process(delta: float) -> void:
	_t += delta
	var dur = RIFLE_DURATION if _is_rifle else DURATION

	if _t >= dur:
		queue_free()
		return

	# Spawn brass casing at ~20% into the shoot animation
	if _is_rifle and not _casing_spawned and _t >= dur * 0.20:
		_casing_spawned = true
		var fv   = _facing_to_vec()
		# Eject sideways + slight backward + upward arc
		var perp = Vector2(-fv.y, fv.x)
		_casing_pos     = fv * 10.0
		_casing_vel     = perp * 60.0 + fv * -12.0 + Vector2(0.0, -50.0)
		_casing_rot     = randf_range(0.0, TAU)
		_casing_rot_spd = randf_range(9.0, 16.0) * (1.0 if randf() > 0.5 else -1.0)
		_casing_life    = 0.0

	# Tick casing physics
	if _casing_spawned:
		_casing_life  += delta
		_casing_vel.y += 140.0 * delta   # gravity pull
		_casing_pos   += _casing_vel * delta
		_casing_rot   += _casing_rot_spd * delta
		_casing_alpha  = clampf(1.0 - (_casing_life / 0.38), 0.0, 1.0)

	# Alpha fade in final 40% of animation
	const FADE_START : float = 0.60
	var p = _t / dur
	if p < FADE_START:
		modulate.a = 1.0
	else:
		modulate.a = 1.0 - (p - FADE_START) / (1.0 - FADE_START)

	queue_redraw()

# ===============================================================
#  DRAW DISPATCH
# ===============================================================
func _draw() -> void:
	if _item_data.is_empty():
		return
	if _is_rifle:
		_draw_rifle_shoot()
	else:
		_draw_knife_stab()

# ===============================================================
#  RIFLE SHOOT ANIMATION
# ===============================================================
func _draw_rifle_shoot() -> void:
	var p    = _t / RIFLE_DURATION
	var fv   = _facing_to_vec()
	var perp = Vector2(-fv.y, fv.x)

	# ── Recoil: snap back fast, hold, ease forward ─────────────
	var recoil : float
	if p < 0.20:
		recoil = (p / 0.20) * 7.0
	elif p < 0.35:
		recoil = 7.0
	else:
		recoil = lerpf(7.0, 0.0, (p - 0.35) / 0.65)

	var origin = fv * (18.0 - recoil)

	# ── Palette by rarity ──────────────────────────────────────
	var rarity = _item_data.get("rarity", "white")
	var silver_dark  : Color
	var silver_mid   : Color
	var silver_light : Color
	var silver_shine : Color
	var scope_dark   : Color
	var scope_lens   : Color
	var accent       : Color
	match rarity:
		"blue":
			silver_dark  = Color(0.10, 0.20, 0.42)
			silver_mid   = Color(0.22, 0.45, 0.82)
			silver_light = Color(0.45, 0.72, 1.00)
			silver_shine = Color(0.75, 0.92, 1.00)
			scope_dark   = Color(0.08, 0.14, 0.30)
			scope_lens   = Color(0.55, 0.90, 1.00, 0.90)
			accent       = Color(0.65, 0.95, 1.00)
		"gold":
			silver_dark  = Color(0.38, 0.28, 0.05)
			silver_mid   = Color(0.75, 0.58, 0.10)
			silver_light = Color(0.92, 0.78, 0.30)
			silver_shine = Color(1.00, 0.95, 0.55)
			scope_dark   = Color(0.22, 0.16, 0.03)
			scope_lens   = Color(1.00, 0.85, 0.20, 0.90)
			accent       = Color(1.00, 0.92, 0.35)
		_: # white / silver default
			silver_dark  = Color(0.42, 0.44, 0.48)
			silver_mid   = Color(0.62, 0.64, 0.68)
			silver_light = Color(0.82, 0.84, 0.88)
			silver_shine = Color(0.96, 0.97, 1.00)
			scope_dark   = Color(0.28, 0.30, 0.34)
			scope_lens   = Color(0.30, 0.65, 0.90, 0.85)
			accent       = Color(0.55, 0.78, 1.00)

	# Key points along the rifle axis
	var stock_end    = origin - fv * 18.0
	var grip_pt      = origin - fv * 10.0
	var recv_start   = origin - fv *  2.0
	var barrel_start = origin + fv *  4.0
	var barrel_end   = origin + fv * 22.0

	# Downward direction (for grip/mag hanging below body)
	var down = perp * -1.0

	# ── Muzzle flash (first 30%) ───────────────────────────────
	if p < 0.30:
		var flash_a = 1.0 - (p / 0.30)
		var muzzle  = barrel_end
		draw_circle(muzzle, 10.0 * flash_a, Color(accent.r, accent.g, accent.b, flash_a * 0.35))
		draw_circle(muzzle,  6.0 * flash_a, Color(silver_shine.r, silver_shine.g, silver_shine.b, flash_a * 0.60))
		draw_circle(muzzle,  3.0,            Color(1.00, 1.00, 1.00, flash_a * 0.95))
		for i in 4:
			var angle     = float(i) / 4.0 * TAU + 0.3
			var spike_tip = muzzle + Vector2(cos(angle), sin(angle)) * (4.0 + flash_a * 8.0)
			draw_line(muzzle, spike_tip, Color(accent.r, accent.g, accent.b, flash_a * 0.80), 1.2)

	# ── Stock ──────────────────────────────────────────────────
	var stock_pts = PackedVector2Array([
		stock_end + perp * 1.5,
		stock_end - perp * 1.5,
		grip_pt   - perp * 4.0,
		grip_pt   + perp * 4.0,
	])
	draw_colored_polygon(stock_pts, silver_dark)
	draw_line(stock_end + perp * 1.5, grip_pt + perp * 4.0, silver_mid, 1.0)

	# ── Receiver body ──────────────────────────────────────────
	var recv_pts = PackedVector2Array([
		grip_pt      + perp * 4.0,
		barrel_start + perp * 4.0,
		barrel_start - perp * 4.0,
		grip_pt      - perp * 4.0,
	])
	draw_colored_polygon(recv_pts, silver_mid)
	draw_line(grip_pt + perp * 4.0, barrel_start + perp * 4.0, silver_shine, 1.5)
	for i in 4:
		var npt = grip_pt.lerp(barrel_start, 0.15 + i * 0.20)
		draw_line(npt + perp * 3.0, npt + perp * 5.0, silver_dark, 0.8)
	draw_line(grip_pt + fv * 2.0, barrel_start - fv * 1.0, silver_dark, 0.8)

	# ── Pistol grip ────────────────────────────────────────────
	var grip_cx  = grip_pt + fv * 3.0
	var grip_pts = PackedVector2Array([
		grip_cx + perp * 2.0,
		grip_cx - perp * 2.0,
		grip_cx - perp * 2.0 + down * 7.0,
		grip_cx + perp * 2.0 + down * 7.0,
	])
	draw_colored_polygon(grip_pts, silver_dark)
	for i in 3:
		var gp = grip_cx + down * (2.0 + i * 2.0)
		draw_line(gp + perp * 1.5, gp - perp * 1.5, silver_mid, 0.7)

	# ── Magazine ───────────────────────────────────────────────
	var mag_cx   = recv_start - fv * 1.0
	var mag_pts  = PackedVector2Array([
		mag_cx + perp * 2.5,
		mag_cx - perp * 2.5,
		mag_cx - perp * 2.0 + down * 9.0,
		mag_cx + perp * 2.0 + down * 9.0,
	])
	draw_colored_polygon(mag_pts, silver_dark)
	draw_line(mag_cx - perp * 2.0 + down * 9.0, mag_cx + perp * 2.0 + down * 9.0, silver_mid, 1.5)
	draw_line(mag_cx + perp * 2.5, mag_cx + perp * 2.0 + down * 9.0, silver_mid, 0.8)

	# ── Barrel ─────────────────────────────────────────────────
	draw_line(barrel_start + perp * 1.5, barrel_end + perp * 1.5, silver_dark,  2.8)
	draw_line(barrel_start - perp * 1.0, barrel_end - perp * 1.0, silver_mid,   1.5)
	draw_line(barrel_start - perp * 2.0, barrel_end - perp * 2.0, silver_shine, 0.9)
	var mz_pts = PackedVector2Array([
		barrel_end - fv * 2.5 + perp * 3.0,
		barrel_end             + perp * 3.0,
		barrel_end             - perp * 3.0,
		barrel_end - fv * 2.5 - perp * 3.0,
	])
	draw_colored_polygon(mz_pts, silver_dark)
	draw_line(barrel_end + perp * 3.0, barrel_end - perp * 3.0, silver_mid, 1.0)

	# ── Under-barrel rail ──────────────────────────────────────
	draw_line(barrel_start + fv * 1.0 + perp * 4.0,
	          barrel_start + fv * 8.0 + perp * 4.0, silver_dark, 1.5)

	# ── Scope ──────────────────────────────────────────────────
	var sc_start = grip_pt    + fv * 2.0 - perp * 4.0
	var sc_end   = recv_start + fv * 2.0 - perp * 4.0
	var sc_h     = perp * -4.5
	var sc_pts   = PackedVector2Array([
		sc_start,
		sc_end,
		sc_end   + sc_h,
		sc_start + sc_h,
	])
	draw_colored_polygon(sc_pts, scope_dark)
	draw_line(sc_start + sc_h, sc_end + sc_h, silver_mid, 0.8)
	draw_line(sc_start, sc_start + sc_h, silver_dark, 1.2)
	draw_line(sc_end,   sc_end   + sc_h, silver_dark, 1.2)
	var scope_mid_pt = sc_h * 0.5
	draw_circle(sc_start + scope_mid_pt, 2.5, scope_dark)
	draw_circle(sc_start + scope_mid_pt, 1.5, scope_lens)
	draw_circle(sc_end   + scope_mid_pt, 2.5, scope_dark)
	draw_circle(sc_end   + scope_mid_pt, 1.5, scope_lens)
	var sc_center = sc_start.lerp(sc_end, 0.5) + scope_mid_pt
	draw_circle(sc_center, 0.9, accent)

	# ── Trigger guard ──────────────────────────────────────────
	var tg_base = grip_cx
	draw_line(tg_base + perp * 2.5, tg_base + perp * 3.5 + down * 5.0, silver_mid, 0.9)
	draw_line(tg_base - perp * 2.5, tg_base - perp * 3.5 + down * 5.0, silver_mid, 0.9)
	draw_line(tg_base + perp * 3.5 + down * 5.0,
	          tg_base - perp * 3.5 + down * 5.0, silver_mid, 0.9)

	# ── Ejection port heat glow (first 25%) ───────────────────
	if p < 0.25:
		var heat_a = (1.0 - p / 0.25) * 0.55
		var port   = recv_start + fv * 0.5 - perp * 3.5
		draw_circle(port, 3.5, Color(1.0, 0.65, 0.15, heat_a))
		draw_circle(port, 1.8, Color(1.0, 0.90, 0.55, heat_a * 0.80))

	# ── Brass casing ───────────────────────────────────────────
	if _casing_spawned and _casing_alpha > 0.01:
		var cas_outer = Color(0.85, 0.60, 0.10, _casing_alpha)
		var cas_inner = Color(1.00, 0.82, 0.35, _casing_alpha * 0.80)
		var cos_r = cos(_casing_rot)
		var sin_r = sin(_casing_rot)
		var cw : float = 1.8
		var ch : float = 4.5
		var cas_pts = PackedVector2Array([
			_casing_pos + Vector2( cos_r * cw - sin_r *  ch,  sin_r * cw + cos_r *  ch),
			_casing_pos + Vector2(-cos_r * cw - sin_r *  ch, -sin_r * cw + cos_r *  ch),
			_casing_pos + Vector2(-cos_r * cw + sin_r *  ch, -sin_r * cw - cos_r *  ch),
			_casing_pos + Vector2( cos_r * cw + sin_r *  ch,  sin_r * cw - cos_r *  ch),
		])
		draw_colored_polygon(cas_pts, cas_outer)
		draw_line(cas_pts[0], cas_pts[1], cas_inner, 0.8)


# ===============================================================
#  KNIFE STAB ANIMATION (unchanged from original)
# ===============================================================
func _draw_knife_stab() -> void:
	var p = _t / DURATION

	const CREEP_END : float = 0.40
	const BURST_END : float = 0.58
	var thrust : float
	if p < CREEP_END:
		thrust = pow(p / CREEP_END, 3.0) * 0.25
	elif p < BURST_END:
		thrust = lerpf(0.25, 1.0, (p - CREEP_END) / (BURST_END - CREEP_END))
	else:
		thrust = 1.0
	var arm = lerp(10.0, 30.0, thrust)

	var facing_vec  = _facing_to_vec()
	var facing_perp = Vector2(-facing_vec.y, facing_vec.x)
	var knife_pivot = facing_vec * arm
	var tip        = knife_pivot + facing_vec * 14.0
	var guard_ctr  = knife_pivot - facing_vec *  2.0
	var handle_end = knife_pivot - facing_vec * 11.0

	var rarity = _item_data.get("rarity", "grey")
	var blade_c  : Color
	var edge_c   : Color
	var guard_c  : Color
	var handle_c : Color
	var trail_c  : Color

	match rarity:
		"grey":
			blade_c  = Color(0.55, 0.57, 0.62)
			edge_c   = Color(0.82, 0.84, 0.88)
			guard_c  = Color(0.38, 0.40, 0.44)
			handle_c = Color(0.32, 0.22, 0.12)
			trail_c  = Color(0.70, 0.72, 0.76)
		"white":
			blade_c  = Color(0.88, 0.90, 0.96)
			edge_c   = Color(1.00, 1.00, 1.00)
			guard_c  = Color(0.56, 0.58, 0.65)
			handle_c = Color(0.42, 0.38, 0.50)
			trail_c  = Color(0.90, 0.92, 1.00)
		"gold":
			blade_c  = Color(0.90, 0.72, 0.14)
			edge_c   = Color(1.00, 0.95, 0.42)
			guard_c  = Color(0.68, 0.52, 0.18)
			handle_c = Color(0.52, 0.28, 0.08)
			trail_c  = Color(1.00, 0.88, 0.30)
		_:
			blade_c  = Color(0.5, 0.5, 0.5)
			edge_c   = Color(0.8, 0.8, 0.8)
			guard_c  = Color(0.4, 0.4, 0.4)
			handle_c = Color(0.3, 0.2, 0.1)
			trail_c  = Color(0.6, 0.6, 0.6)

	if thrust > 0.05:
		var TRAIL_STEPS = 10
		var trail_start = facing_vec * 6.0
		var trail_end   = facing_vec * (arm - 2.0)
		for ti in TRAIL_STEPS - 1:
			var fa_s  = float(ti)     / float(TRAIL_STEPS - 1)
			var fa_e  = float(ti + 1) / float(TRAIL_STEPS - 1)
			var pt_s  = trail_start.lerp(trail_end, fa_s)
			var pt_e  = trail_start.lerp(trail_end, fa_e)
			var seg_a = lerp(0.0, 0.50, (fa_s + fa_e) * 0.5) * thrust
			draw_line(pt_s, pt_e, Color(trail_c.r, trail_c.g, trail_c.b, seg_a), 2.0)

	if rarity == "gold":
		draw_circle(tip, 7.0 * thrust, Color(1.0, 0.85, 0.10, 0.30))
		draw_circle(tip, 4.0 * thrust, Color(1.0, 0.95, 0.40, 0.25))

	var blade_pts = PackedVector2Array([
		tip,
		guard_ctr + facing_perp * 2.5,
		guard_ctr - facing_perp * 2.5,
	])
	draw_colored_polygon(blade_pts, blade_c)
	draw_line(tip, guard_ctr - facing_perp * 2.2, edge_c, 1.0)
	draw_line(guard_ctr + facing_perp * 5.5, guard_ctr - facing_perp * 5.5, guard_c, 2.8)
	draw_circle(guard_ctr + facing_perp * 5.5, 1.5, guard_c.lightened(0.2))
	draw_circle(guard_ctr - facing_perp * 5.5, 1.5, guard_c.lightened(0.2))
	draw_line(guard_ctr, handle_end, handle_c, 3.8)
	for i in 3:
		var frac = 0.15 + i * 0.25
		var hp   = guard_ctr.lerp(handle_end, frac)
		draw_line(hp + facing_perp * 2.2, hp - facing_perp * 2.2, handle_c.lightened(0.28), 1.2)
	draw_circle(handle_end, 2.8, guard_c)
	draw_circle(handle_end, 1.6, guard_c.lightened(0.3))


# ===============================================================
#  SHARED HELPER
# ===============================================================
func _facing_to_vec() -> Vector2:
	match _facing:
		"n": return Vector2( 0, -1)
		"s": return Vector2( 0,  1)
		"e": return Vector2( 1,  0)
		"w": return Vector2(-1,  0)
	return Vector2(0, 1)
