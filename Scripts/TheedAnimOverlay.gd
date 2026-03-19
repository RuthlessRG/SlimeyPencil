extends Node2D

# ============================================================
#  TheedAnimOverlay.gd — miniSWG
#  Ambient flying ships + scripted ship events over Theed.
#  Ships use sprite sheets, rotated to face travel direction.
# ============================================================

var _t : float = 0.0
var _ships : Array = []
var _events : Array = []  # scripted ship events
var _birds : Array = []

var _ship_tex : Texture2D = null
var _ship_tex_flip : Texture2D = null

const CELL_W : int = 196
const CELL_H : int = 194
const COLS   : int = 4
const ROWS   : int = 6
const TOTAL_SHIPS : int = 24

# Ship sprites face NE in the original sheet (~upper-right)
# In screen coords (Y down), NE is angle -PI/4
const BASE_ANGLE_ORIG : float = -0.785  # -PI/4, nose points NE
const BASE_ANGLE_FLIP : float = -2.356  # -3*PI/4, nose points NW (flipped)

# Map area around the city — set dynamically
var CITY_X : float = 0.0
var CITY_Y : float = 0.0
const MAP_EXTENT : float = 6000.0

func _ready() -> void:
	# Ship textures removed — ambient ships disabled for now
	z_index = 50

func set_city_center(pos: Vector2) -> void:
	CITY_X = pos.x
	CITY_Y = pos.y
	_init_birds()

# ── AMBIENT SHIPS ────────────────────────────────────────────
func _init_ships() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 88442
	_ships.clear()

	for i in 8:
		var near = i < 5
		var flipped = rng.randi() % 2 == 0

		var start_pos : Vector2
		var dest_pos : Vector2
		var speed : float

		if near:
			var a1 = rng.randf() * TAU
			var r1 = rng.randf_range(300, 1200)
			start_pos = Vector2(CITY_X + cos(a1) * r1, CITY_Y + sin(a1) * r1)
			var a2 = a1 + rng.randf_range(PI * 0.5, PI * 1.5)
			var r2 = rng.randf_range(300, 1200)
			dest_pos = Vector2(CITY_X + cos(a2) * r2, CITY_Y + sin(a2) * r2)
			speed = rng.randf_range(78, 182)
		else:
			var edge = rng.randi() % 4
			start_pos = _edge_pos(edge, rng)
			dest_pos = _edge_pos((edge + 2) % 4, rng)
			speed = rng.randf_range(104, 234)

		var vel = (dest_pos - start_pos).normalized() * speed
		# Pick flipped based on travel direction — use original for NE travel, flipped for NW
		flipped = vel.x < 0

		_ships.append({
			"pos": start_pos,
			"vel": vel,
			"dest": dest_pos,
			"ship_idx": rng.randi() % TOTAL_SHIPS,
			"flipped": flipped,
			"sc": rng.randf_range(0.25, 0.55),
			"shadow_y": rng.randf_range(20, 50),
			"alpha": rng.randf_range(0.75, 0.95),
			"near": near,
			"thruster_phase": rng.randf_range(0.0, TAU),
		})

func _edge_pos(edge: int, rng: RandomNumberGenerator) -> Vector2:
	match edge:
		0: return Vector2(rng.randf_range(CITY_X - MAP_EXTENT, CITY_X + MAP_EXTENT), CITY_Y - MAP_EXTENT)
		1: return Vector2(CITY_X + MAP_EXTENT, rng.randf_range(CITY_Y - MAP_EXTENT, CITY_Y + MAP_EXTENT))
		2: return Vector2(rng.randf_range(CITY_X - MAP_EXTENT, CITY_X + MAP_EXTENT), CITY_Y + MAP_EXTENT)
		_: return Vector2(CITY_X - MAP_EXTENT, rng.randf_range(CITY_Y - MAP_EXTENT, CITY_Y + MAP_EXTENT))

func _process(delta: float) -> void:
	_t += delta
	_tick_birds(delta)
	queue_redraw()

func _tick_ships(delta: float) -> void:
	var rng = RandomNumberGenerator.new()
	for i in _ships.size():
		var s = _ships[i]
		s["pos"] += s["vel"] * delta
		var p : Vector2 = s["pos"]
		var near : bool = s.get("near", false)
		var oob : bool

		if near:
			oob = p.distance_to(Vector2(CITY_X, CITY_Y)) > 2000
		else:
			oob = p.x < CITY_X - MAP_EXTENT - 500 or p.x > CITY_X + MAP_EXTENT + 500 \
			   or p.y < CITY_Y - MAP_EXTENT - 500 or p.y > CITY_Y + MAP_EXTENT + 500

		if oob:
			rng.seed = int(_t * 100) * 97 + i * 7919
			s["ship_idx"] = rng.randi() % TOTAL_SHIPS
			s["sc"] = rng.randf_range(0.25, 0.55)
			s["alpha"] = rng.randf_range(0.75, 0.95)
			s["thruster_phase"] = rng.randf_range(0.0, TAU)

			if near:
				var a1 = rng.randf() * TAU
				var r1 = rng.randf_range(300, 1200)
				var np2 = Vector2(CITY_X + cos(a1) * r1, CITY_Y + sin(a1) * r1)
				var a2 = a1 + rng.randf_range(PI * 0.5, PI * 1.5)
				var r2 = rng.randf_range(300, 1200)
				var nd2 = Vector2(CITY_X + cos(a2) * r2, CITY_Y + sin(a2) * r2)
				s["pos"] = np2
				s["dest"] = nd2
				s["vel"] = (nd2 - np2).normalized() * rng.randf_range(78, 182)
			else:
				var edge = rng.randi() % 4
				var np3 = _edge_pos(edge, rng)
				var nd3 = _edge_pos((edge + 2) % 4, rng)
				s["pos"] = np3
				s["vel"] = (nd3 - np3).normalized() * rng.randf_range(104, 234)
			s["flipped"] = s["vel"].x < 0

func _draw() -> void:
	_draw_birds()

	for ev in _events:
		_draw_event(ev)

func _draw_ship(s: Dictionary) -> void:
	var pos : Vector2 = s["pos"]
	var vel : Vector2 = s["vel"]
	var idx : int = s["ship_idx"]
	var sc : float = s["sc"]
	var flipped : bool = s["flipped"]
	var alpha : float = s["alpha"]
	var shy : float = s["shadow_y"]
	var phase : float = s["thruster_phase"]

	if vel.length_squared() < 0.01:
		return

	var col = idx % COLS
	var row = idx / COLS
	var src_rect = Rect2(col * CELL_W, row * CELL_H, CELL_W, CELL_H)

	var draw_w = CELL_W * sc
	var draw_h = CELL_H * sc

	# ── Shadow on ground ──
	var sh_pts = PackedVector2Array()
	for i in 10:
		var a = float(i) / 10.0 * TAU
		sh_pts.append(Vector2(
			pos.x + cos(a) * draw_w * 0.35 + shy * 0.3,
			pos.y + sin(a) * draw_h * 0.12 + shy))
	draw_colored_polygon(sh_pts, Color(0, 0, 0, 0.10))

	# ── Thruster effects (drawn BEHIND ship) ──
	var vel_angle = vel.angle()
	var tail_dir = Vector2(cos(vel_angle + PI), sin(vel_angle + PI))  # opposite of travel
	var side_dir = Vector2(-tail_dir.y, tail_dir.x)

	var thruster_len = draw_w * (0.3 + sin(_t * 8.0 + phase) * 0.12)
	var thruster_w = draw_w * 0.06
	var tail_base = pos + tail_dir * draw_w * 0.25

	# Main thruster glow
	var t_col1 = Color(0.3, 0.7, 1.0, alpha * 0.7)
	var t_col2 = Color(0.1, 0.4, 0.9, alpha * 0.4)
	var flicker = 0.7 + sin(_t * 12.0 + phase) * 0.3

	# Center thruster
	var t_tip = tail_base + tail_dir * thruster_len * flicker
	var t_pts = PackedVector2Array([
		tail_base + side_dir * thruster_w,
		tail_base - side_dir * thruster_w,
		t_tip
	])
	draw_colored_polygon(t_pts, t_col1)

	# Outer glow
	var t_tip2 = tail_base + tail_dir * thruster_len * flicker * 1.4
	var t_pts2 = PackedVector2Array([
		tail_base + side_dir * thruster_w * 2.0,
		tail_base - side_dir * thruster_w * 2.0,
		t_tip2
	])
	draw_colored_polygon(t_pts2, t_col2)

	# Hot core
	draw_circle(tail_base, thruster_w * 1.5 * flicker, Color(0.6, 0.85, 1.0, alpha * 0.6))

	# ── Rotate ship sprite to face velocity direction ──
	var base_angle = BASE_ANGLE_FLIP if flipped else BASE_ANGLE_ORIG
	var rot = vel_angle - base_angle
	var tex = _ship_tex_flip if flipped else _ship_tex

	draw_set_transform(pos, rot, Vector2(sc, sc))
	var half_w = CELL_W * 0.5
	var half_h = CELL_H * 0.5
	draw_texture_rect_region(tex, Rect2(-half_w, -half_h, CELL_W, CELL_H), src_rect, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── SCRIPTED EVENTS ──────────────────────────────────────────
# Event types: "landing", "takeoff", "flyby", "warp"
# Call spawn_event() to trigger scripted ship sequences

func spawn_event(type: String, start: Vector2, dest: Vector2, ship_idx: int = -1) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = int(_t * 1000)
	if ship_idx < 0:
		ship_idx = rng.randi() % TOTAL_SHIPS

	var ev = {
		"type": type,
		"ship_idx": ship_idx,
		"flipped": false,
		"t": 0.0,
		"duration": 0.0,
		"start": start,
		"dest": dest,
		"pos": start,
		"vel": Vector2.ZERO,
		"sc": 0.4,
		"alpha": 1.0,
		"phase": 0,
		"particles": [],
		"done": false,
	}

	match type:
		"landing":
			ev["duration"] = 4.0
			ev["vel"] = (dest - start).normalized() * 120.0
			ev["flipped"] = ev["vel"].x < 0
		"takeoff":
			ev["duration"] = 3.5
			ev["pos"] = start
			ev["vel"] = Vector2.ZERO
			ev["flipped"] = (dest - start).x < 0
		"warp":
			ev["duration"] = 2.5
			ev["vel"] = (dest - start).normalized() * 80.0
			ev["flipped"] = ev["vel"].x < 0
		"flyby":
			ev["duration"] = 5.0
			ev["vel"] = (dest - start).normalized() * 200.0
			ev["flipped"] = ev["vel"].x < 0

	_events.append(ev)

func _tick_events(delta: float) -> void:
	var to_remove = []
	for i in _events.size():
		var ev = _events[i]
		ev["t"] += delta
		var t : float = ev["t"]
		var dur : float = ev["duration"]
		var frac : float = clampf(t / dur, 0.0, 1.0)

		match ev["type"]:
			"landing":
				# Approach: decelerate toward landing pad
				var speed = lerpf(120.0, 5.0, frac * frac)
				var dir = (ev["dest"] - ev["pos"]).normalized()
				ev["vel"] = dir * speed
				ev["pos"] += ev["vel"] * delta
				ev["sc"] = lerpf(0.45, 0.3, frac)  # ship gets "closer" (lower altitude)
				# Spawn dust particles near landing
				if frac > 0.7:
					_spawn_dust(ev)

			"takeoff":
				if frac < 0.3:
					# Engines warming up — shake slightly
					ev["pos"] = ev["start"] + Vector2(randf_range(-1, 1), randf_range(-1, 1))
					ev["sc"] = 0.3
				else:
					# Lift off and accelerate
					var lift_frac = (frac - 0.3) / 0.7
					var dir = (ev["dest"] - ev["start"]).normalized()
					var speed = lerpf(10.0, 300.0, lift_frac * lift_frac)
					ev["vel"] = dir * speed
					ev["pos"] += ev["vel"] * delta
					ev["sc"] = lerpf(0.3, 0.5, lift_frac)
					ev["flipped"] = ev["vel"].x < 0
				# Dust during early takeoff
				if frac < 0.5:
					_spawn_dust(ev)

			"warp":
				if frac < 0.5:
					# Normal flight
					ev["pos"] += ev["vel"] * delta
				else:
					# Warp! Exponential acceleration + stretch
					var warp_frac = (frac - 0.5) / 0.5
					var speed = lerpf(80.0, 2000.0, warp_frac * warp_frac * warp_frac)
					var dir = ev["vel"].normalized()
					ev["vel"] = dir * speed
					ev["pos"] += ev["vel"] * delta
					ev["alpha"] = lerpf(1.0, 0.0, warp_frac)
					# Sonic boom ring at warp start
					if warp_frac < 0.15 and ev.get("boom_spawned", false) == false:
						ev["boom_spawned"] = true
						ev["boom_pos"] = ev["pos"]
						ev["boom_t"] = 0.0

			"flyby":
				ev["pos"] += ev["vel"] * delta

		# Update particles
		_tick_particles(ev, delta)

		if t >= dur:
			ev["done"] = true
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		_events.remove_at(to_remove[i])

func _spawn_dust(ev: Dictionary) -> void:
	var ground_pos : Vector2 = ev.get("dest", ev["pos"])
	if ev["type"] == "takeoff":
		ground_pos = ev["start"]
	var parts : Array = ev.get("particles", [])
	if parts.size() > 40:
		return
	for _i in 2:
		var angle = randf() * TAU
		var speed = randf_range(15, 45)
		parts.append({
			"pos": ground_pos + Vector2(randf_range(-8, 8), randf_range(-4, 4)),
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed * 0.4 - randf_range(5, 15)),
			"life": 0.0,
			"max_life": randf_range(0.6, 1.2),
			"size": randf_range(2.0, 5.0),
		})
	ev["particles"] = parts

func _tick_particles(ev: Dictionary, delta: float) -> void:
	var parts : Array = ev.get("particles", [])
	var alive = []
	for p in parts:
		p["life"] += delta
		if p["life"] < p["max_life"]:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 0.96  # drag
			alive.append(p)
	ev["particles"] = alive

func _draw_event(ev: Dictionary) -> void:
	# Draw particles (dust, exhaust)
	var parts : Array = ev.get("particles", [])
	for p in parts:
		var frac2 = p["life"] / p["max_life"]
		var a = (1.0 - frac2) * 0.5
		var sz = p["size"] * (1.0 + frac2 * 2.0)
		draw_circle(p["pos"], sz, Color(0.7, 0.6, 0.45, a))

	# Draw the ship
	var ship_data = {
		"pos": ev["pos"],
		"vel": ev["vel"],
		"ship_idx": ev["ship_idx"],
		"sc": ev["sc"],
		"flipped": ev["flipped"],
		"alpha": ev["alpha"],
		"shadow_y": 25.0,
		"thruster_phase": ev.get("phase", 0.0),
	}
	if ev["vel"].length_squared() > 1.0:
		_draw_ship(ship_data)

	# Sonic boom ring (for warp events)
	if ev.has("boom_pos"):
		ev["boom_t"] = ev.get("boom_t", 0.0) + get_process_delta_time()
		var bt : float = ev["boom_t"]
		var ring_r = bt * 300.0
		var ring_a = clampf(1.0 - bt * 1.5, 0.0, 0.7)
		if ring_a > 0.0:
			var ring_pts = PackedVector2Array()
			for i in 24:
				var ang = float(i) / 24.0 * TAU
				ring_pts.append(ev["boom_pos"] + Vector2(cos(ang) * ring_r, sin(ang) * ring_r * 0.4))
			for i in ring_pts.size():
				var p1 = ring_pts[i]
				var p2 = ring_pts[(i + 1) % ring_pts.size()]
				draw_line(p1, p2, Color(0.8, 0.9, 1.0, ring_a), 2.0)

# ── BIRDS ────────────────────────────────────────────────────
func _init_birds() -> void:
	_birds.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 77234
	for i in 40:
		var near = i < 25  # most birds near city
		var bx : float
		var by : float
		if near:
			bx = CITY_X + rng.randf_range(-1200, 1200)
			by = CITY_Y + rng.randf_range(-800, 800)
		else:
			bx = CITY_X + rng.randf_range(-4000, 4000)
			by = CITY_Y + rng.randf_range(-3000, 3000)
		_birds.append({
			"pos": Vector2(bx, by),
			"vel": Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(20, 55),
			"phase": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(4.0, 10.0),
			"near": near,
		})

func _tick_birds(delta: float) -> void:
	for b in _birds:
		b["pos"] += b["vel"] * delta
		# Wrap around
		if b["pos"].x < CITY_X - 5000: b["pos"].x += 10000
		if b["pos"].x > CITY_X + 5000: b["pos"].x -= 10000
		if b["pos"].y < CITY_Y - 5000: b["pos"].y += 10000
		if b["pos"].y > CITY_Y + 5000: b["pos"].y -= 10000
		# Gentle steer
		var steer = 1.0 if b.get("near", false) else 0.4
		b["vel"] = (b["vel"] as Vector2).rotated(sin(_t * 0.3 + b["phase"]) * steer * delta)
		# Near birds drift back toward city
		if b.get("near", false):
			var dist = (b["pos"] as Vector2).distance_to(Vector2(CITY_X, CITY_Y))
			if dist > 1800:
				b["vel"] = (b["vel"] as Vector2).lerp(
					(Vector2(CITY_X, CITY_Y) - b["pos"]).normalized() * 40.0, 0.02)

func _draw_birds() -> void:
	for b in _birds:
		var pos : Vector2 = b["pos"]
		var vel : Vector2 = b["vel"]
		var sz : float = b["size"]
		var flap = sin(_t * 6.5 + b["phase"]) * sz * 0.55
		var ang = vel.angle()
		var fwd = Vector2(cos(ang), sin(ang))
		var side = Vector2(-sin(ang), cos(ang))
		draw_line(pos, pos - fwd * sz * 0.4 - side * (sz + flap),
			Color(0.12, 0.10, 0.06, 0.70), 1.6)
		draw_line(pos, pos - fwd * sz * 0.4 + side * (sz + flap),
			Color(0.12, 0.10, 0.06, 0.70), 1.6)
		draw_circle(pos, sz * 0.2, Color(0.10, 0.08, 0.04, 0.75))
