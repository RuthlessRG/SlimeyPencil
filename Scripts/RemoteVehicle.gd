extends Node2D

# ============================================================
#  RemoteVehicle.gd
#  Draws a remote player's landspeeder, exactly matching
#  BossArenaPlayer._draw_mount_vehicle().
#  Set `angle` and `variant` from SpaceportScene each frame.
# ============================================================

var angle   : float  = 0.0
var variant : String = "fighter"

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var t    = Time.get_ticks_msec() / 1000.0
	var fwd  = Vector2(cos(angle), sin(angle))
	var side = Vector2(-sin(angle), cos(angle))
	var eng_glow = Color(0.30, 0.65, 1.00, 0.55 + sin(t * 8.0) * 0.30)
	if variant == "fighter":
		_draw_fighter(fwd, side, eng_glow)
	else:
		_draw_transport(fwd, side, eng_glow)

func _draw_fighter(fwd: Vector2, side: Vector2, eng_glow: Color) -> void:
	# Shadow
	draw_colored_polygon(_ell(Vector2(6, 68), 55, 14, angle, 16), Color(0, 0, 0, 0.22))
	# Hull (bezier-like)
	var hull = PackedVector2Array()
	for i in 21:
		var tv = float(i) / 20.0
		var px: float; var py: float
		if tv <= 0.5:
			px = lerpf(-42, 50, tv * 2.0)
			py = sin(tv * 2.0 * PI) * 16.0
		else:
			px = lerpf(50, -42, (tv - 0.5) * 2.0)
			py = -sin((tv - 0.5) * 2.0 * PI) * 16.0
		hull.append(fwd * px + side * py)
	draw_colored_polygon(hull, Color(0.88, 0.92, 0.96))
	# Cockpit
	draw_colored_polygon(_ell(fwd * 15, 13, 7, angle, 12), Color(0.35, 0.70, 1.00, 0.80))
	draw_colored_polygon(_ell(fwd * 16 + side * (-3), 5, 2.5, angle, 8), Color(1.0, 1.0, 1.0, 0.50))
	# Engine nacelles
	for sm in [-1.0, 1.0]:
		var ep = fwd * (-30) + side * sm * 13
		draw_colored_polygon(_ell(ep, 9, 5, angle, 10), Color(0.45, 0.52, 0.62))
		draw_colored_polygon(_ell(ep - fwd * 9, 5, 4.5, angle, 10), eng_glow)
	# Accent stripes
	draw_line(fwd * (-40) + side * 4, fwd * 40 + side * 4, Color(0.25, 0.60, 1.00, 0.70), 2.0)
	draw_line(fwd * (-40) - side * 4, fwd * 40 - side * 4, Color(0.25, 0.60, 1.00, 0.70), 2.0)

func _draw_transport(fwd: Vector2, side: Vector2, eng_glow: Color) -> void:
	# Shadow
	draw_colored_polygon(_ell(Vector2(8, 72), 48, 24, angle, 16), Color(0, 0, 0, 0.22))
	# Wide hull
	draw_colored_polygon(PackedVector2Array([
		fwd * (-45) - side * 22,
		fwd * 35    - side * 15,
		fwd * 45,
		fwd * 35    + side * 15,
		fwd * (-45) + side * 22,
	]), Color(0.86, 0.88, 0.92))
	# Superstructure
	draw_colored_polygon(PackedVector2Array([
		fwd * (-25) - side * 10,
		fwd * 20    - side * 7,
		fwd * 20    + side * 7,
		fwd * (-25) + side * 10,
	]), Color(0.76, 0.80, 0.86))
	# Bridge windows
	for wi in 4:
		draw_circle(fwd * (5 + wi * 5) + side * (-6 + wi), 2.2, Color(0.35, 0.70, 1.00, 0.85))
	# Cargo dome
	draw_colored_polygon(_ell(fwd * (-10), 15, 9, angle, 14), Color(0.70, 0.75, 0.82))
	draw_colored_polygon(_ell(fwd * (-9) - side * 2, 7, 4, angle, 10), Color(0.92, 0.96, 1.0, 0.65))
	# Engine pods
	for sm in [-1.0, 1.0]:
		var ep = fwd * (-40) + side * sm * 16
		draw_colored_polygon(_ell(ep, 8, 4, angle, 10), Color(0.38, 0.42, 0.50))
		draw_colored_polygon(_ell(ep - fwd * 8, 5, 4, angle, 10), eng_glow)
	# Accent stripe
	draw_line(fwd * (-44), fwd * 44, Color(1.00, 0.82, 0.10, 0.70), 2.0)

func _ell(center: Vector2, rx: float, ry: float, rot: float, n: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var cr = cos(rot); var sr = sin(rot)
	for i in n:
		var a = float(i) / float(n) * TAU
		var lx = cos(a) * rx; var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cr - ly * sr, lx * sr + ly * cr))
	return pts
