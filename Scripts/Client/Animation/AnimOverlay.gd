extends Node2D

# ============================================================
#  AnimOverlay.gd — miniSWG
#  Dedicated animated-background layer.
#  Handles flying ships, birds, and walking NPCs using its OWN
#  _process and queue_redraw so the huge static world never redraws.
# ============================================================

const WORLD_W : float = 16384.0
const WORLD_H : float = 16384.0

# Port constants (must match SpaceportScene)
const PORT_X : float =   80.0
const PORT_Y : float =   80.0
const PORT_W : float = 2600.0
const PORT_H : float = 2400.0

var _t         : float = 0.0
var _fly_ships : Array = []
var _birds     : Array = []
var _npcs      : Array = []

# ── INIT ──────────────────────────────────────────────────────
func _ready() -> void:
	_init_birds()
	_init_fly_ships()
	_init_npcs()

func _process(delta: float) -> void:
	_t += delta
	_tick_birds(delta)
	_tick_fly_ships(delta)
	_tick_npcs(delta)
	queue_redraw()

func _draw() -> void:
	_draw_birds()
	_draw_flying_ships()
	_draw_npcs()

# ── BIRDS ─────────────────────────────────────────────────────
func _init_birds() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 99812
	# Dense flock near/over spaceport (within ~1600px of port center)
	var port_cx = 80 + 2600 * 0.5
	var port_cy = 80 + 2400 * 0.5
	for i in 55:
		var near = i < 30   # first 30 are port-area birds
		var bx : float
		var by : float
		if near:
			bx = rng.randf_range(port_cx - 1400, port_cx + 1400)
			by = rng.randf_range(port_cy - 1200, port_cy + 1200)
		else:
			bx = rng.randf_range(800, WORLD_W - 800)
			by = rng.randf_range(800, WORLD_H - 800)
		_birds.append({
			"pos":   Vector2(bx, by),
			"vel":   Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(24, 62),
			"phase": rng.randf_range(0.0, TAU),
			"size":  rng.randf_range(5.0, 12.0),
			"near":  near,
		})

func _tick_birds(delta: float) -> void:
	var port_cx = 80 + 2600 * 0.5
	var port_cy = 80 + 2400 * 0.5
	for b in _birds:
		b["pos"] += b["vel"] * delta
		# Wrap
		if b["pos"].x < 0:        b["pos"].x += WORLD_W
		if b["pos"].x > WORLD_W:  b["pos"].x -= WORLD_W
		if b["pos"].y < 0:        b["pos"].y += WORLD_H
		if b["pos"].y > WORLD_H:  b["pos"].y -= WORLD_H
		# Gentle steer — near birds orbit more tightly around spaceport
		var steer_scale = 1.2 if b.get("near", false) else 0.5
		var v : Vector2 = b["vel"]
		b["vel"] = v.rotated(sin(_t * 0.28 + b["phase"]) * steer_scale * delta)
		# Near birds drift back toward port if they wander too far
		if b.get("near", false):
			var dist = b["pos"].distance_to(Vector2(port_cx, port_cy))
			if dist > 2200:
				b["vel"] = b["vel"].lerp(
					(Vector2(port_cx, port_cy) - b["pos"]).normalized() * 45.0, 0.02)

func _draw_birds() -> void:
	for b in _birds:
		var pos : Vector2 = b["pos"]
		var vel : Vector2 = b["vel"]
		var sz  : float   = b["size"]
		var flap = sin(_t * 6.5 + b["phase"]) * sz * 0.55
		var ang  = vel.angle()
		var fwd  = Vector2(cos(ang), sin(ang))
		var side = Vector2(-sin(ang), cos(ang))
		draw_line(pos, pos - fwd * sz * 0.4 - side * (sz + flap),
			Color(0.15, 0.12, 0.08, 0.72), 1.8)
		draw_line(pos, pos - fwd * sz * 0.4 + side * (sz + flap),
			Color(0.15, 0.12, 0.08, 0.72), 1.8)
		draw_circle(pos, sz * 0.22, Color(0.12, 0.10, 0.06, 0.80))

# ── FLYING SHIPS ──────────────────────────────────────────────
func _init_fly_ships() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 44556
	var cols = [
		Color(0.90, 0.92, 0.95),   # silver-white
		Color(0.85, 0.72, 0.20),   # gold
		Color(0.80, 0.20, 0.18),   # red
		Color(0.08, 0.08, 0.10),   # black
		Color(0.30, 0.55, 0.90),   # blue
		Color(0.55, 0.82, 0.35),   # green
		Color(0.92, 0.50, 0.12),   # orange
		Color(0.70, 0.75, 0.82),   # steel-blue
		Color(0.78, 0.28, 0.88),   # purple
		Color(0.22, 0.88, 0.72),   # teal
		Color(0.95, 0.85, 0.35),   # yellow
		Color(0.55, 0.35, 0.20),   # brown-bronze
	]
	# 22 ships total: first 14 orbit near the spaceport for dense ambience,
	# remaining 8 cross the full world for distant flyby colour.
	var port_cx = 80.0 + 2600.0 * 0.5
	var port_cy = 80.0 + 2400.0 * 0.5
	for i in 22:
		var near = i < 14
		var np   : Vector2
		var nd   : Vector2
		if near:
			# Spawn at a random point around the spaceport area and fly to another
			var a1 = rng.randf() * TAU
			var r1 = rng.randf_range(400, 1800)
			np = Vector2(port_cx + cos(a1) * r1, port_cy + sin(a1) * r1)
			var a2 = a1 + rng.randf_range(PI * 0.6, PI * 1.4)
			var r2 = rng.randf_range(400, 1800)
			nd = Vector2(port_cx + cos(a2) * r2, port_cy + sin(a2) * r2)
		else:
			var edge = rng.randi() % 4
			np = _edge_pos(edge, rng)
			nd = _edge_pos((edge + 2) % 4, rng)
		_fly_ships.append({
			"pos":   np,
			"vel":   (nd - np).normalized() * rng.randf_range(45, 110),
			"dest":  nd,
			"col":   cols[i % cols.size()],
			"type":  rng.randi() % 3,
			"sc":    rng.randf_range(0.42, 0.70),
			"shy":   rng.randf_range(18, 55),
			"near":  near,
		})

func _edge_pos(edge: int, rng: RandomNumberGenerator) -> Vector2:
	match edge:
		0: return Vector2(rng.randf_range(400, WORLD_W - 400), -300)
		1: return Vector2(WORLD_W + 300, rng.randf_range(400, WORLD_H - 400))
		2: return Vector2(rng.randf_range(400, WORLD_W - 400), WORLD_H + 300)
		_: return Vector2(-300, rng.randf_range(400, WORLD_H - 400))

func _tick_fly_ships(delta: float) -> void:
	var rng = RandomNumberGenerator.new()
	var port_cx = 80.0 + 2600.0 * 0.5
	var port_cy = 80.0 + 2400.0 * 0.5
	for i in _fly_ships.size():
		var s   = _fly_ships[i]
		s["pos"] += s["vel"] * delta
		var p : Vector2 = s["pos"]
		var near : bool = s.get("near", false)
		var oob : bool
		if near:
			var dist = p.distance_to(Vector2(port_cx, port_cy))
			oob = dist > 2600
		else:
			oob = p.x < -500 or p.x > WORLD_W + 500 or p.y < -500 or p.y > WORLD_H + 500
		if oob:
			rng.seed = int(_t * 100) * 97 + i * 7919
			if near:
				var a1 = rng.randf() * TAU
				var r1 = rng.randf_range(400, 1800)
				var np2 = Vector2(port_cx + cos(a1) * r1, port_cy + sin(a1) * r1)
				var a2  = a1 + rng.randf_range(PI * 0.6, PI * 1.4)
				var r2  = rng.randf_range(400, 1800)
				var nd2 = Vector2(port_cx + cos(a2) * r2, port_cy + sin(a2) * r2)
				s["pos"]  = np2
				s["dest"] = nd2
				s["vel"]  = (nd2 - np2).normalized() * rng.randf_range(50, 120)
			else:
				var edge = rng.randi() % 4
				var np3  = _edge_pos(edge, rng)
				var nd3  = _edge_pos((edge + 2) % 4, rng)
				s["pos"] = np3
				s["vel"] = (nd3 - np3).normalized() * rng.randf_range(40, 90)

func _draw_flying_ships() -> void:
	for s in _fly_ships:
		var pos  : Vector2 = s["pos"]
		var col  : Color   = s["col"]
		var sc   : float   = s["sc"]
		var rot  : float   = s["vel"].angle()
		var shy  : float   = s["shy"]
		var fwd  = Vector2(cos(rot), sin(rot))
		var side = Vector2(-sin(rot), cos(rot))

		# Skip drawing if velocity is zero (avoid .angle() NaN / degenerate polys)
		if s["vel"].length_squared() < 0.01:
			continue

		# Shadow underneath
		draw_colored_polygon(
			_ell(pos + Vector2(shy * 0.35, shy), 60 * sc, 15 * sc, rot, 10),
			Color(0, 0, 0, 0.16))

		match int(s["type"]):
			0:  # fighter — clean arrowhead
				var L = 62.0 * sc;  var W = 20.0 * sc
				var pts = PackedVector2Array([
					pos + fwd * L,
					pos + fwd * W * 0.4 + side * W,
					pos - fwd * L * 0.45 + side * W * 0.85,
					pos - fwd * L + side * W * 0.28,
					pos - fwd * L,
					pos - fwd * L - side * W * 0.28,
					pos - fwd * L * 0.45 - side * W * 0.85,
					pos + fwd * W * 0.4 - side * W,
				])
				draw_colored_polygon(pts, col)
				# Cockpit
				if 16 * sc >= 4.0:
					draw_colored_polygon(
						_ell(pos + fwd * 20 * sc, 16 * sc, 9 * sc, rot, 8),
						Color(0.30, 0.65, 1.0, 0.80))
				# Engine glow
				if 8 * sc >= 3.5:
					for sm in [-1.0, 1.0]:
						draw_colored_polygon(
							_ell(pos - fwd * L * 0.80 + side * sm * W * 0.22,
								 8 * sc, 7 * sc, rot, 6),
							Color(0.40, 0.75, 1.0, 0.85))
			1:  # transport
				var hull = PackedVector2Array([
					pos - fwd * 72 * sc - side * 33 * sc,
					pos + fwd * 55 * sc - side * 22 * sc,
					pos + fwd * 70 * sc,
					pos + fwd * 55 * sc + side * 22 * sc,
					pos - fwd * 72 * sc + side * 33 * sc,
				])
				draw_colored_polygon(hull, col)
				draw_colored_polygon(
					_ell(pos - fwd * 14 * sc, 20 * sc, 13 * sc, rot, 10),
					col.lightened(0.28))
				# Engine glow
				if 10 * sc >= 3.5:
					draw_colored_polygon(
						_ell(pos - fwd * 65 * sc, 10 * sc, 8 * sc, rot, 8),
						Color(0.40, 0.75, 1.0, 0.85))
			2:  # freighter
				var hull = PackedVector2Array([
					pos - fwd * 90 * sc - side * 26 * sc,
					pos + fwd * 90 * sc - side * 16 * sc,
					pos + fwd * 90 * sc + side * 16 * sc,
					pos - fwd * 90 * sc + side * 26 * sc,
				])
				draw_colored_polygon(hull, col)
				for ci in 3:
					draw_colored_polygon(
						_ell(pos + fwd * (-46 + ci * 32) * sc, 14 * sc, 9 * sc, rot, 8),
						col.darkened(0.22))
				# Engine glow
				if 9 * sc >= 3.5:
					for sm in [-1.0, 0.0, 1.0]:
						draw_colored_polygon(
							_ell(pos - fwd * 85 * sc + side * sm * 16 * sc,
								 9 * sc, 8 * sc, rot, 6),
							Color(0.40, 0.75, 1.0, 0.85))

# ── NPCs ──────────────────────────────────────────────────────
# Ambient pedestrians: half the size of the original static art,
# wandering within ~100 px of their home position.
const NPC_SC : float = 0.50   # 0.5 = half scale vs original draw code

func _init_npcs() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 77331
	# Home positions (absolute world coords).
	# Types: "biz" "pol" "droid" "worker" "alien"
	var defs = [
		# near JOBS building
		{"home": Vector2(PORT_X + PORT_W * 0.22 + 220, PORT_Y + PORT_H * 0.58 + 50),  "type": "biz"},
		{"home": Vector2(PORT_X + PORT_W * 0.22 + 255, PORT_Y + PORT_H * 0.58 + 30),  "type": "biz"},
		{"home": Vector2(PORT_X + PORT_W * 0.22 + 185, PORT_Y + PORT_H * 0.58 + 70),  "type": "pol"},
		# near Grand Dome / bank
		{"home": Vector2(PORT_X + PORT_W * 0.68 + 80,  PORT_Y + PORT_H * 0.70 + 90),  "type": "pol"},
		{"home": Vector2(PORT_X + PORT_W * 0.68 + 120, PORT_Y + PORT_H * 0.70 + 100), "type": "pol"},
		{"home": Vector2(PORT_X + PORT_W * 0.68 + 100, PORT_Y + PORT_H * 0.70 + 120), "type": "droid"},
		# near docking bay
		{"home": Vector2(PORT_X + 640,  PORT_Y + 490), "type": "worker"},
		{"home": Vector2(PORT_X + 700,  PORT_Y + 510), "type": "worker"},
		{"home": Vector2(PORT_X + 760,  PORT_Y + 480), "type": "droid"},
		{"home": Vector2(PORT_X + 820,  PORT_Y + 500), "type": "worker"},
		# near CANTINA
		{"home": Vector2(PORT_X + 510,  PORT_Y + PORT_H * 0.84 + 120), "type": "biz"},
		{"home": Vector2(PORT_X + 545,  PORT_Y + PORT_H * 0.84 + 100), "type": "alien"},
		{"home": Vector2(PORT_X + 475,  PORT_Y + PORT_H * 0.84 + 140), "type": "alien"},
		# near Trade Hall (moved to PORT_X+660)
		{"home": Vector2(PORT_X + 830,  PORT_Y + PORT_H * 0.66 + 90),  "type": "biz"},
		{"home": Vector2(PORT_X + 865,  PORT_Y + PORT_H * 0.66 + 70),  "type": "pol"},
		# hangars / maintenance
		{"home": Vector2(PORT_X + 180,  PORT_Y + 500),  "type": "worker"},
		{"home": Vector2(PORT_X + 215,  PORT_Y + 525),  "type": "droid"},
		{"home": Vector2(PORT_X + 180,  PORT_Y + 1060), "type": "worker"},
		{"home": Vector2(PORT_X + 215,  PORT_Y + 1085), "type": "worker"},
	]
	for nd in defs:
		rng.seed = rng.seed * 6364136223846793005 + 1442695040888963407
		var ang = rng.randf() * TAU
		var spd = rng.randf_range(16.0, 28.0)
		_npcs.append({
			"home":  nd["home"],
			"pos":   nd["home"] + Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-15.0, 15.0)),
			"vel":   Vector2(cos(ang), sin(ang)) * spd,
			"type":  nd["type"],
			"phase": rng.randf_range(0.0, TAU),
			"hue_r": rng.randf(),
		})

func _tick_npcs(delta: float) -> void:
	for n in _npcs:
		n["pos"] += n["vel"] * delta
		var dist : float = n["pos"].distance_to(n["home"])
		if dist > 100.0:
			# Steer back toward home position
			n["vel"] = n["vel"].lerp(
				(n["home"] - n["pos"]).normalized() * 22.0, 0.05)
		else:
			# Gentle wander
			n["vel"] = n["vel"].rotated(sin(_t * 0.55 + n["phase"]) * 1.0 * delta)

func _draw_npcs() -> void:
	const SC : float = NPC_SC
	for n in _npcs:
		var p     : Vector2 = n["pos"]
		var kind  : String  = n["type"]
		var hue_r : float   = n["hue_r"]
		# Walk cycle: leg and arm swing based on time + individual phase
		var walk  : float   = sin(_t * 5.5 + n["phase"])   # -1 .. 1

		match kind:
			"biz":   # Businessman — suit, fedora, briefcase
				var sc2 = Color(0.20 + hue_r * 0.15, 0.20, 0.28 + hue_r * 0.12)
				draw_circle(p + Vector2(1.0, 3.5), 4.0, Color(0, 0, 0, 0.16))
				# Legs
				draw_line(p + Vector2(-1.5, 0.0) * SC, p + Vector2(-2.5 + walk * 2.0, 7.0) * SC, sc2.darkened(0.3), 2.0)
				draw_line(p + Vector2( 1.5, 0.0) * SC, p + Vector2( 2.5 - walk * 2.0, 7.0) * SC, sc2.darkened(0.3), 2.0)
				# Jacket body
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-3.0, -9.0) * SC, p + Vector2(3.0, -9.0) * SC,
					p + Vector2( 4.0,  0.0) * SC, p + Vector2(-4.0,  0.0) * SC,
				]), sc2)
				# White shirt strip
				draw_line(p + Vector2(0.0, -8.0) * SC, p + Vector2(0.0, -3.0) * SC, Color(0.92, 0.92, 0.92), 2.0)
				# Red tie
				draw_line(p + Vector2(0.0, -8.0) * SC, p + Vector2(0.0, -3.0) * SC, Color(0.72, 0.10, 0.12), 1.0)
				# Arms
				draw_line(p + Vector2(-3.0, -8.0) * SC, p + Vector2(-5.0 + walk,       -1.5) * SC, sc2, 1.8)
				draw_line(p + Vector2( 3.0, -8.0) * SC, p + Vector2( 7.0 - walk * 0.5, -5.0) * SC, sc2, 1.8)
				# Briefcase (on right arm side)
				draw_rect(Rect2(p.x + 5.0 * SC, p.y - 7.0 * SC, 4.5 * SC, 3.5 * SC), Color(0.55, 0.38, 0.14))
				# Head
				draw_circle(p + Vector2(0.0, -13.0) * SC, 3.5 * SC, Color(0.82 + hue_r * 0.10, 0.65, 0.48))
				# Fedora brim + crown
				draw_rect(Rect2(p.x - 5.0 * SC, p.y - 18.5 * SC, 10.0 * SC, 2.0 * SC), sc2)
				draw_rect(Rect2(p.x - 3.0 * SC, p.y - 21.5 * SC,  6.0 * SC, 3.5 * SC), sc2)

			"pol":   # Politician — flowing robe, hood, sash
				var robe_col = Color(0.65 + hue_r * 0.25, 0.60 + hue_r * 0.10, 0.30 + hue_r * 0.30)
				draw_circle(p + Vector2(1.0, 3.5), 4.5, Color(0, 0, 0, 0.16))
				# Flowing robe (no legs visible)
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-2.0, -11.0) * SC, p + Vector2(2.0, -11.0) * SC,
					p + Vector2( 7.0,   4.0) * SC, p + Vector2(-7.0,  4.0) * SC,
				]), robe_col)
				# Robe edge trim lines
				draw_line(p + Vector2(-2.0, -11.0) * SC, p + Vector2(-7.0, 4.0) * SC, robe_col.darkened(0.28), 1.2)
				draw_line(p + Vector2( 2.0, -11.0) * SC, p + Vector2( 7.0, 4.0) * SC, robe_col.darkened(0.28), 1.2)
				# Gold sash
				draw_line(p + Vector2(-0.5, -10.0) * SC, p + Vector2(3.0, 2.0) * SC, Color(0.85, 0.65, 0.10), 1.2)
				# Slow arm sway under robes (subtle)
				draw_line(p + Vector2(-1.5, -8.0) * SC, p + Vector2(-6.0 + walk * 0.5, 1.0) * SC, robe_col.darkened(0.15), 1.5)
				# Head
				draw_circle(p + Vector2(0.0, -15.0) * SC, 3.5 * SC, Color(0.80 + hue_r * 0.12, 0.64, 0.46))
				# Hood / headpiece
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-3.5, -12.0) * SC, p + Vector2(3.5, -12.0) * SC,
					p + Vector2( 4.5, -19.0) * SC, p + Vector2(-4.5, -19.0) * SC,
				]), robe_col.darkened(0.22))

			"droid":  # Droid/Robot — boxy metallic
				var d_col = Color(0.62 + hue_r * 0.15, 0.64, 0.68)
				draw_circle(p + Vector2(0.5, 3.0), 4.0, Color(0, 0, 0, 0.16))
				# Body box
				draw_rect(Rect2(p.x - 3.5 * SC, p.y - 9.0 * SC, 7.0 * SC, 9.0 * SC), d_col)
				draw_rect(Rect2(p.x - 3.5 * SC, p.y - 9.0 * SC, 7.0 * SC, 9.0 * SC), d_col.darkened(0.35), false, 1.0)
				# Chest indicator lights
				draw_circle(p + Vector2(-1.2, -5.5) * SC, 1.0 * SC, Color(0.20, 0.80, 0.35))
				draw_circle(p + Vector2( 1.5, -5.5) * SC, 0.8 * SC, Color(0.80, 0.20, 0.20))
				# Arms (rigid, slight swing)
				draw_rect(Rect2(p.x - 6.0 * SC, p.y - 8.5 * SC, 2.5 * SC, 7.0 * SC), d_col.darkened(0.18))
				draw_rect(Rect2(p.x + 3.5 * SC, p.y - 8.5 * SC, 2.5 * SC, 7.0 * SC), d_col.darkened(0.18))
				# Walking legs
				draw_line(p + Vector2(-1.0, 0.0) * SC, p + Vector2(-1.5 + walk * 1.5, 6.5) * SC, d_col.darkened(0.28), 2.0)
				draw_line(p + Vector2( 1.0, 0.0) * SC, p + Vector2( 1.5 - walk * 1.5, 6.5) * SC, d_col.darkened(0.28), 2.0)
				# Head box
				draw_rect(Rect2(p.x - 3.0 * SC, p.y - 14.0 * SC, 6.0 * SC, 5.0 * SC), d_col.lightened(0.12))
				# Eye visor strip
				draw_rect(Rect2(p.x - 2.5 * SC, p.y - 13.0 * SC, 5.0 * SC, 2.0 * SC), Color(0.20, 0.55, 0.90, 0.85))
				# Antenna
				draw_line(p + Vector2(1.5, -14.0) * SC, p + Vector2(2.0, -17.5) * SC, d_col, 1.2)
				draw_circle(p + Vector2(2.0, -17.5) * SC, 1.0 * SC, Color(1.0, 0.50, 0.10))

			"worker":  # Ground crew — hi-vis vest, hard hat
				var vest_col = Color(0.85, 0.50 + hue_r * 0.25, 0.08)
				draw_circle(p + Vector2(1.0, 3.5), 3.5, Color(0, 0, 0, 0.16))
				# Trousers
				draw_line(p + Vector2(-1.5, 0.0) * SC, p + Vector2(-2.0 + walk * 2.0, 7.0) * SC, Color(0.22, 0.24, 0.30), 2.0)
				draw_line(p + Vector2( 1.5, 0.0) * SC, p + Vector2( 2.0 - walk * 2.0, 7.0) * SC, Color(0.22, 0.24, 0.30), 2.0)
				# Hi-vis vest body
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-3.0, -9.0) * SC, p + Vector2(3.0, -9.0) * SC,
					p + Vector2( 3.5,  0.0) * SC, p + Vector2(-3.5,  0.0) * SC,
				]), vest_col)
				# Reflective stripe
				draw_line(p + Vector2(-3.5, -4.5) * SC, p + Vector2(3.5, -4.5) * SC, Color(0.95, 0.95, 0.20), 1.5)
				# Arms
				draw_line(p + Vector2(-3.0, -8.0) * SC, p + Vector2(-5.5 + walk, -1.0) * SC, vest_col, 1.8)
				draw_line(p + Vector2( 3.0, -8.0) * SC, p + Vector2( 5.5 - walk, -1.0) * SC, vest_col, 1.8)
				# Head
				draw_circle(p + Vector2(0.0, -13.0) * SC, 3.25 * SC, Color(0.75 + hue_r * 0.15, 0.60, 0.44))
				# Hard hat
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-4.5, -15.0) * SC, p + Vector2(4.5, -15.0) * SC,
					p + Vector2( 3.5, -19.5) * SC, p + Vector2(-3.5, -19.5) * SC,
				]), Color(0.90, 0.80, 0.10))
				# Hard hat brim
				draw_rect(Rect2(p.x - 5.0 * SC, p.y - 15.0 * SC, 10.0 * SC, 1.5 * SC), Color(0.80, 0.70, 0.08))

			"alien":   # Green-skinned alien patron with head ridges
				var a_col = Color(0.30 + hue_r * 0.20, 0.70 + hue_r * 0.10, 0.35)
				draw_circle(p + Vector2(1.0, 3.5), 4.0, Color(0, 0, 0, 0.16))
				# Legs
				draw_line(p + Vector2(-1.5, 0.0) * SC, p + Vector2(-2.0 + walk * 2.0, 7.0) * SC, Color(0.28, 0.22, 0.38), 2.0)
				draw_line(p + Vector2( 1.5, 0.0) * SC, p + Vector2( 2.0 - walk * 2.0, 7.0) * SC, Color(0.28, 0.22, 0.38), 2.0)
				# Alien garb (purple-ish)
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-3.0, -9.0) * SC, p + Vector2(3.0, -9.0) * SC,
					p + Vector2( 3.5,  0.0) * SC, p + Vector2(-3.5,  0.0) * SC,
				]), Color(0.38, 0.28, 0.55))
				# Arms
				draw_line(p + Vector2(-3.0, -8.0) * SC, p + Vector2(-5.0 + walk, -2.5) * SC, a_col, 1.8)
				draw_line(p + Vector2( 3.0, -8.0) * SC, p + Vector2( 5.0 - walk, -2.5) * SC, a_col, 1.8)
				# Large alien head
				draw_circle(p + Vector2(0.0, -13.5) * SC, 4.0 * SC, a_col)
				# Big eyes
				draw_circle(p + Vector2(-1.5, -14.0) * SC, 1.6 * SC, Color(0.05, 0.05, 0.10))
				draw_circle(p + Vector2( 1.5, -14.0) * SC, 1.6 * SC, Color(0.05, 0.05, 0.10))
				draw_circle(p + Vector2(-1.5, -14.0) * SC, 0.6 * SC, Color(0.80, 0.90, 0.20))
				draw_circle(p + Vector2( 1.5, -14.0) * SC, 0.6 * SC, Color(0.80, 0.90, 0.20))
				# Head ridges
				for ri2 in 3:
					draw_line(p + Vector2(-2.5 + ri2 * 2.5, -17.5) * SC,
						p + Vector2(-2.0 + ri2 * 2.5, -15.5) * SC, a_col.darkened(0.30), 1.0)

# ── UTILITY ───────────────────────────────────────────────────
func _ell(center: Vector2, rx: float, ry: float, rot: float, steps: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var cr = cos(rot); var sr = sin(rot)
	for i in steps + 1:
		var a  = float(i) / float(steps) * TAU
		var lx = cos(a) * rx
		var ly = sin(a) * ry
		pts.append(center + Vector2(lx * cr - ly * sr, lx * sr + ly * cr))
	return pts
