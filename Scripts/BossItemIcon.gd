extends Control

# ============================================================
#  BossItemIcon.gd — draws an item icon inside a slot Control
#  Set item_data before adding to scene tree.
#  mouse_filter should be MOUSE_FILTER_IGNORE so clicks pass
#  through to the parent slot Panel.
# ============================================================

var item_data : Dictionary = {}
var _t        : float      = 0.0

func _process(delta: float) -> void:
	# Animate if gold (glow pulse) OR equipped (equip glow)
	if item_data.get("rarity", "") == "gold" or item_data.get("equipped", false):
		_t += delta
		queue_redraw()

func _draw() -> void:
	if item_data.is_empty():
		return
	match item_data.get("type", ""):
		"knife":  _draw_knife()
		"rifle":  _draw_rifle()
		"mount":  _draw_mount()

func _draw_knife() -> void:
	var cx     = size.x * 0.5
	var cy     = size.y * 0.5
	var center = Vector2(cx, cy)
	var dir    = Vector2(1.0, -1.0).normalized()   # blade points upper-right
	var perp   = Vector2(1.0,  1.0).normalized()   # perpendicular (lower-right)
	var rarity = item_data.get("rarity", "grey")

	# ── Colors ────────────────────────────────────────────────
	var blade_c  : Color
	var edge_c   : Color
	var guard_c  : Color
	var handle_c : Color

	match rarity:
		"grey":
			blade_c  = Color(0.52, 0.54, 0.58)
			edge_c   = Color(0.78, 0.80, 0.84)
			guard_c  = Color(0.38, 0.40, 0.44)
			handle_c = Color(0.32, 0.22, 0.12)
		"white":
			blade_c  = Color(0.86, 0.89, 0.96)
			edge_c   = Color(1.00, 1.00, 1.00)
			guard_c  = Color(0.58, 0.60, 0.68)
			handle_c = Color(0.42, 0.38, 0.50)
		"gold":
			blade_c  = Color(0.90, 0.70, 0.10)
			edge_c   = Color(1.00, 0.95, 0.40)
			guard_c  = Color(0.68, 0.52, 0.18)
			handle_c = Color(0.52, 0.28, 0.08)
		_:
			blade_c  = Color(0.5, 0.5, 0.5)
			edge_c   = Color(0.8, 0.8, 0.8)
			guard_c  = Color(0.4, 0.4, 0.4)
			handle_c = Color(0.3, 0.2, 0.1)

	var tip        = center + dir  * 15.0
	var guard_ctr  = center - dir  *  1.0
	var handle_end = center - dir  * 12.0

	# ── Equipped glow ─────────────────────────────────────────
	if item_data.get("equipped", false):
		var eq_a = 0.35 + sin(_t * 4.0) * 0.18
		var gc : Color
		match rarity:
			"grey":  gc = Color(0.70, 0.85, 1.00)
			"white": gc = Color(1.00, 1.00, 1.00)
			"gold":  gc = Color(1.00, 0.90, 0.20)
			_:       gc = Color(0.70, 0.85, 1.00)
		draw_circle(center, 22.0, Color(gc.r, gc.g, gc.b, eq_a * 0.18))
		draw_circle(center, 16.0, Color(gc.r, gc.g, gc.b, eq_a * 0.30))
		draw_circle(center, 10.0, Color(gc.r, gc.g, gc.b, eq_a * 0.20))

	# ── Gold inherent aura ─────────────────────────────────────
	if rarity == "gold" and not item_data.get("equipped", false):
		var ga = 0.28 + sin(_t * 3.0) * 0.10
		draw_circle(center, 19.0, Color(1.0, 0.80, 0.05, ga * 0.22))
		draw_circle(center, 13.0, Color(1.0, 0.88, 0.15, ga * 0.32))
		draw_circle(center,  8.0, Color(1.0, 0.95, 0.30, ga * 0.18))

	# ── Blade (filled triangle) ────────────────────────────────
	var blade_pts = PackedVector2Array([
		tip,
		guard_ctr + perp * 2.8,
		guard_ctr - perp * 2.8,
	])
	draw_colored_polygon(blade_pts, blade_c)
	# Edge shine along top of blade
	draw_line(tip, guard_ctr + perp * 2.5, edge_c, 1.0)

	# ── Guard ─────────────────────────────────────────────────
	draw_line(guard_ctr + perp * 6.0, guard_ctr - perp * 6.0, guard_c, 2.8)
	draw_circle(guard_ctr + perp * 6.0, 1.5, guard_c.lightened(0.2))
	draw_circle(guard_ctr - perp * 6.0, 1.5, guard_c.lightened(0.2))

	# ── Handle ────────────────────────────────────────────────
	draw_line(guard_ctr, handle_end, handle_c, 3.8)
	# Wrap bands
	for i in 3:
		var frac = 0.15 + i * 0.25
		var hp   = guard_ctr.lerp(handle_end, frac)
		draw_line(hp + perp * 2.2, hp - perp * 2.2, handle_c.lightened(0.28), 1.2)
	# Pommel
	draw_circle(handle_end, 3.0, guard_c)
	draw_circle(handle_end, 1.8, guard_c.lightened(0.3))

func _draw_rifle() -> void:
	var cx     = size.x * 0.5
	var cy     = size.y * 0.5
	var rarity = item_data.get("rarity", "white")

	# ── Palette by rarity ────────────────────────────────────
	var c_base  : Color
	var c_hi    : Color
	var c_dark  : Color
	var c_acc   : Color
	var c_grip  : Color
	match rarity:
		"blue":
			c_base = Color(0.22, 0.45, 0.82)
			c_hi   = Color(0.55, 0.80, 1.00)
			c_dark = Color(0.10, 0.20, 0.42)
			c_acc  = Color(0.65, 0.92, 1.00)
			c_grip = Color(0.08, 0.14, 0.28)
		"gold":
			c_base = Color(0.75, 0.58, 0.10)
			c_hi   = Color(1.00, 0.92, 0.45)
			c_dark = Color(0.38, 0.28, 0.05)
			c_acc  = Color(1.00, 0.82, 0.20)
			c_grip = Color(0.25, 0.18, 0.04)
		_: # white / silver
			c_base = Color(0.62, 0.65, 0.70)
			c_hi   = Color(0.88, 0.91, 0.96)
			c_dark = Color(0.30, 0.32, 0.36)
			c_acc  = Color(0.44, 0.78, 1.00)
			c_grip = Color(0.18, 0.19, 0.22)

	# ── Equipped glow — rarity-coloured ─────────────────────
	var glow_col : Color
	match rarity:
		"blue": glow_col = Color(0.35, 0.72, 1.00)
		"gold": glow_col = Color(1.00, 0.82, 0.10)
		_:      glow_col = Color(0.90, 0.92, 1.00)
	if item_data.get("equipped", false):
		var eq_a = 0.32 + sin(_t * 4.0) * 0.16
		draw_circle(Vector2(cx, cy), 23.0, Color(glow_col.r, glow_col.g, glow_col.b, eq_a * 0.16))
		draw_circle(Vector2(cx, cy), 16.0, Color(glow_col.r, glow_col.g, glow_col.b, eq_a * 0.30))

	# ── Gold inherent aura (same as gold knife) ──────────────
	if rarity == "gold" and not item_data.get("equipped", false):
		var ga = 0.28 + sin(_t * 3.0) * 0.10
		draw_circle(Vector2(cx, cy), 22.0, Color(1.0, 0.80, 0.05, ga * 0.22))
		draw_circle(Vector2(cx, cy), 14.0, Color(1.0, 0.88, 0.15, ga * 0.32))
		draw_circle(Vector2(cx, cy),  8.0, Color(1.0, 0.95, 0.30, ga * 0.18))

	# The rifle is drawn horizontally, pointing right.
	# All coords relative to (cx, cy) = icon center.
	# Icon is 52×52 so we have ~±24 px to play with.

	# ── Stock (rear left) ────────────────────────────────────
	# Thick chunky stock block
	var stock_pts = PackedVector2Array([
		Vector2(cx - 22, cy - 3),
		Vector2(cx - 13, cy - 3),
		Vector2(cx - 13, cy + 5),
		Vector2(cx - 20, cy + 7),
		Vector2(cx - 22, cy + 5),
	])
	draw_colored_polygon(stock_pts, c_grip)
	# stock top shine
	draw_line(Vector2(cx - 22, cy - 3), Vector2(cx - 13, cy - 3), c_dark, 1.0)

	# ── Receiver / main body ─────────────────────────────────
	# Wide central block
	var body_pts = PackedVector2Array([
		Vector2(cx - 14, cy - 6),
		Vector2(cx +  6, cy - 6),
		Vector2(cx +  6, cy + 5),
		Vector2(cx - 14, cy + 5),
	])
	draw_colored_polygon(body_pts, c_base)
	# top-edge highlight stripe
	draw_line(Vector2(cx - 14, cy - 6), Vector2(cx + 6, cy - 6), c_hi, 1.4)
	# bottom shadow
	draw_line(Vector2(cx - 14, cy + 5), Vector2(cx + 6, cy + 5), c_dark, 1.0)

	# ── Picatinny rail on top of receiver ────────────────────
	draw_line(Vector2(cx - 12, cy - 7), Vector2(cx + 5, cy - 7), c_dark, 1.6)
	# rail teeth (3 notches)
	for i in 3:
		var rx = cx - 10.0 + i * 5.5
		draw_line(Vector2(rx, cy - 9), Vector2(rx, cy - 7), c_dark, 1.2)

	# ── Barrel (long, thin, points right) ────────────────────
	# Main barrel tube
	draw_line(Vector2(cx + 5,  cy - 2), Vector2(cx + 23, cy - 2), c_base, 3.5)
	# Barrel top shine
	draw_line(Vector2(cx + 5,  cy - 3.5), Vector2(cx + 23, cy - 3.5), c_hi, 1.0)
	# Barrel bottom shadow
	draw_line(Vector2(cx + 5,  cy - 0.5), Vector2(cx + 23, cy - 0.5), c_dark, 1.0)
	# Muzzle brake — three rings near tip
	for i in 3:
		var mx = cx + 17.0 + i * 2.0
		draw_line(Vector2(mx, cy - 5), Vector2(mx, cy + 1), c_dark, 1.4)
	# Muzzle tip cap
	draw_rect(Rect2(cx + 22, cy - 4, 2.5, 4), c_dark)
	draw_line(Vector2(cx + 24.5, cy - 4), Vector2(cx + 24.5, cy), c_hi, 1.0)

	# ── Under-barrel tactical grip / foregrip ────────────────
	var grip_pts = PackedVector2Array([
		Vector2(cx - 2, cy + 5),
		Vector2(cx + 4, cy + 5),
		Vector2(cx + 3, cy + 11),
		Vector2(cx - 1, cy + 11),
	])
	draw_colored_polygon(grip_pts, c_grip)
	draw_line(Vector2(cx - 2, cy + 5), Vector2(cx + 4, cy + 5), c_dark, 1.0)
	# grip texture lines
	for i in 2:
		var gy = cy + 7.0 + i * 2.0
		draw_line(Vector2(cx - 1, gy), Vector2(cx + 3, gy), c_dark.lightened(0.2), 0.8)

	# ── Magazine ──────────────────────────────────────────────
	var mag_pts = PackedVector2Array([
		Vector2(cx - 9,  cy + 5),
		Vector2(cx - 4,  cy + 5),
		Vector2(cx - 5,  cy + 13),
		Vector2(cx - 10, cy + 13),
	])
	draw_colored_polygon(mag_pts, c_dark)
	# mag highlight left edge
	draw_line(Vector2(cx - 10, cy + 5), Vector2(cx - 10, cy + 13), c_base.darkened(0.1), 1.0)
	# mag base plate
	draw_line(Vector2(cx - 10, cy + 13), Vector2(cx - 5, cy + 13), c_hi, 1.0)

	# ── Scope ─────────────────────────────────────────────────
	# Scope tube
	draw_line(Vector2(cx - 8,  cy - 9), Vector2(cx + 4, cy - 9), c_base, 4.5)
	draw_line(Vector2(cx - 8,  cy - 9), Vector2(cx + 4, cy - 9), c_hi,   1.0)  # top shine
	# Scope body (wider middle)
	draw_rect(Rect2(cx - 6, cy - 12, 8, 6), c_base)
	draw_line(Vector2(cx - 6, cy - 12), Vector2(cx + 2, cy - 12), c_hi, 1.0)   # top edge
	draw_line(Vector2(cx - 6, cy - 12), Vector2(cx - 6, cy -  9), c_dark, 0.8) # left rim
	draw_line(Vector2(cx + 2, cy - 12), Vector2(cx + 2, cy -  9), c_dark, 0.8) # right rim
	# Lens — cyan glow circle
	draw_circle(Vector2(cx - 2, cy - 11), 3.2, Color(c_acc.r, c_acc.g, c_acc.b, 0.85))
	draw_circle(Vector2(cx - 2, cy - 11), 1.8, Color(1.0, 1.0, 1.0, 0.60))
	# Scope turret knob on top
	draw_rect(Rect2(cx - 3, cy - 14, 3, 2), c_dark)
	draw_line(Vector2(cx - 3, cy - 14), Vector2(cx, cy - 14), c_hi, 0.8)

	# ── Charging handle (small tab on right of receiver) ─────
	draw_rect(Rect2(cx + 3, cy - 5, 3, 2.5), c_dark)
	draw_line(Vector2(cx + 3, cy - 5), Vector2(cx + 6, cy - 5), c_hi, 0.8)

	# ── Energy accent stripe along receiver side ──────────────
	draw_line(Vector2(cx - 13, cy + 1), Vector2(cx + 5, cy + 1), Color(c_acc.r, c_acc.g, c_acc.b, 0.55), 1.0)

func _draw_mount() -> void:
	var cx      = size.x * 0.5
	var cy      = size.y * 0.5
	var variant = item_data.get("mount_variant", "fighter")
	var rarity  = item_data.get("rarity", "blue")
	var t       = _t

	# Equip glow
	if item_data.get("equipped", false):
		var eq_a = 0.35 + sin(t * 4.0) * 0.18
		var gc   = Color(0.35, 0.72, 1.00) if rarity == "blue" else Color(1.00, 0.85, 0.15)
		draw_circle(Vector2(cx,cy), 24.0, Color(gc.r,gc.g,gc.b, eq_a*0.16))
		draw_circle(Vector2(cx,cy), 16.0, Color(gc.r,gc.g,gc.b, eq_a*0.28))

	# Gold aura
	if rarity == "gold" and not item_data.get("equipped", false):
		var ga = 0.28 + sin(t * 3.0) * 0.10
		draw_circle(Vector2(cx,cy), 22.0, Color(1.0,0.80,0.05, ga*0.22))
		draw_circle(Vector2(cx,cy), 14.0, Color(1.0,0.88,0.15, ga*0.32))

	if variant == "fighter":
		# ── Fighter speeder icon ──────────────────────────────
		var hull_c  = Color(0.88, 0.92, 0.96)
		var dark_c  = Color(0.45, 0.52, 0.62)
		var acc_c   = Color(0.25, 0.60, 1.00) if rarity == "blue" else Color(1.00, 0.82, 0.10)
		var glow_c  = Color(acc_c.r, acc_c.g, acc_c.b, 0.55 + sin(t*5.0)*0.25)
		# Shadow
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx-16,cy+10), Vector2(cx+17,cy+10),
			Vector2(cx+14,cy+13), Vector2(cx-13,cy+13)]), Color(0,0,0,0.22))
		# Main hull — pointed teardrop left to right
		var hull = PackedVector2Array()
		for i in 20:
			var a  = float(i)/19.0
			var hx : float
			var hy : float
			if a <= 0.5:
				hx = cx - 14.0 + a*2.0*31.0
				hy = cy + sin(a*2.0*PI)*9.0
			else:
				hx = cx + 17.0 - (a-0.5)*2.0*31.0
				hy = cy - sin((a-0.5)*2.0*PI)*9.0
			hull.append(Vector2(hx, hy))
		draw_colored_polygon(hull, hull_c)
		# Cockpit glass
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx+4,cy-6), Vector2(cx+12,cy-2),
			Vector2(cx+12,cy+2), Vector2(cx+4,cy+6)]), Color(0.35,0.70,1.00,0.80))
		draw_line(Vector2(cx+5,cy-5), Vector2(cx+12,cy-1.5), Color(1,1,1,0.50), 1.2)
		# Engine nacelles
		for ys in [-1.0, 1.0]:
			var ep = Vector2(cx-8, cy + ys*7)
			draw_colored_polygon(PackedVector2Array([
				ep+Vector2(-5,-3), ep+Vector2(2,-3),
				ep+Vector2(2,3),   ep+Vector2(-5,3)]), dark_c)
			draw_colored_polygon(PackedVector2Array([
				ep+Vector2(-8,-2.5), ep+Vector2(-5,-2.5),
				ep+Vector2(-5,2.5),  ep+Vector2(-8,2.5)]), glow_c)
		# Accent stripes
		draw_line(Vector2(cx-12,cy-3), Vector2(cx+10,cy-3), acc_c, 1.5)
		draw_line(Vector2(cx-12,cy+3), Vector2(cx+10,cy+3), acc_c, 1.5)
		# Speed lines when equipped / gold
		if item_data.get("equipped", false) or rarity == "gold":
			for i in 3:
				var ly = cy - 5.0 + i*5.0
				var la = 0.25 + sin(t*6.0+i)*0.15
				draw_line(Vector2(cx-22, ly), Vector2(cx-15, ly), Color(acc_c.r,acc_c.g,acc_c.b,la), 1.0)
	else:
		# ── Transport speeder icon ────────────────────────────
		var hull_c  = Color(0.86, 0.88, 0.92)
		var _dark_c = Color(0.38, 0.42, 0.50)
		var acc_c   = Color(1.00, 0.82, 0.10)
		var glow_c  = Color(acc_c.r, acc_c.g, acc_c.b, 0.55 + sin(t*5.0)*0.25)
		# Shadow
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx-18,cy+9), Vector2(cx+18,cy+9),
			Vector2(cx+14,cy+13), Vector2(cx-14,cy+13)]), Color(0,0,0,0.22))
		# Wide boxy hull
		var hull = PackedVector2Array([
			Vector2(cx-17, cy-5),
			Vector2(cx+14, cy-7),
			Vector2(cx+18, cy),
			Vector2(cx+14, cy+7),
			Vector2(cx-17, cy+5),
		])
		draw_colored_polygon(hull, hull_c)
		# Superstructure top
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx-10,cy-10), Vector2(cx+8,cy-8),
			Vector2(cx+8, cy-5),  Vector2(cx-10,cy-5)]), Color(0.76,0.80,0.86))
		# Bridge windows (4 dots)
		for wi in 4:
			draw_circle(Vector2(cx-6+wi*5, cy-8), 2.2, Color(0.35,0.70,1.00,0.85))
			draw_circle(Vector2(cx-5+wi*5, cy-8), 1.0, Color(1,1,1,0.55))
		# Cargo dome
		draw_colored_polygon(_ellipse_icon(Vector2(cx-2,cy), 8, 5, 0, 12), Color(0.70,0.75,0.82))
		draw_colored_polygon(_ellipse_icon(Vector2(cx-2,cy-1), 4, 2.5, 0, 8), Color(0.92,0.96,1.0,0.70))
		# Engine glow pods
		for ys in [-1.0, 1.0]:
			var ep = Vector2(cx-15, cy+ys*4.5)
			draw_colored_polygon(PackedVector2Array([
				ep+Vector2(-4,-2.5), ep+Vector2(1,-2.5),
				ep+Vector2(1,2.5),   ep+Vector2(-4,2.5)]), glow_c)
		# Accent stripe
		draw_line(Vector2(cx-16,cy), Vector2(cx+16,cy), acc_c, 1.8)
		if item_data.get("equipped", false) or rarity == "gold":
			for i in 3:
				var ly = cy - 4.0 + i*4.0
				var la = 0.25 + sin(t*6.0+i)*0.15
				draw_line(Vector2(cx-24, ly), Vector2(cx-18, ly), Color(acc_c.r,acc_c.g,acc_c.b,la), 1.0)

func _ellipse_icon(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts   = PackedVector2Array()
	var cos_r = cos(rot); var sin_r = sin(rot)
	for i in n:
		var a  = float(i)/float(n)*TAU
		var lx = cos(a)*rx; var ly = sin(a)*ry
		pts.append(center + Vector2(lx*cos_r - ly*sin_r, lx*sin_r + ly*cos_r))
	return pts
