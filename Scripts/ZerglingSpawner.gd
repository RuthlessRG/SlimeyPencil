extends Node2D

var _roboto : Font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

# ============================================================
#  ZerglingSpawner.gd — Beyond the Veil
#
#  Drop into any scene. Place wherever you want swarms to
#  emerge from. Shows a glowing egg sac drawn in code.
#
#  EXPORTS — tweak in the Inspector:
#    max_alive       — cap on simultaneous live zerglings
#    spawn_interval  — seconds between each spawn
#    burst_size      — how many spawn at once per tick
#    active          — toggle spawning on/off
#    spawn_radius    — scatter radius around spawner
#
#  Also exposes:
#    activate()  / deactivate()  — for scripted triggers
#    spawn_burst(n)              — force-spawn N right now
# ============================================================

@export var max_alive      : int   = 20
@export var spawn_interval : float = 8.0
@export var burst_size     : int   = 3
@export var active         : bool  = true
@export var spawn_radius   : float = 28.0
@export var zergling_script : Script = null   # set to res://Scripts/Zergling.gd

# Visual
var _pulse              : float = 0.0
var _sac_wobble         : float = 0.0
var _spawn_timer        : float = 0.0
var _alive_count        : int   = 0
var _spawned_zerglings  : Array = []   # tracks only THIS spawner's children

# Sac crack animation
var _crack_t     : float = 0.0   # 0=sealed, 1=bursting

# ── COLOURS ─────────────────────────────────────────────────
const C_SAC_OUTER  = Color(0.22, 0.06, 0.28)   # dark purple membrane
const C_SAC_INNER  = Color(0.50, 0.10, 0.12)   # flesh red core
const C_SAC_GLOW   = Color(0.65, 0.02, 0.02, 0.5) # ominous glow
const C_CRACK      = Color(0.90, 0.50, 0.02, 0.9) # orange glow in cracks
const C_SLIME      = Color(0.25, 0.72, 0.08, 0.55) # acid-green bio-slime
const C_EGG_SAC    = Color(0.30, 0.08, 0.35)

func _ready() -> void:
	add_to_group("zergling_spawner")
	z_index = 1
	# Stagger initial timer so multiple spawners don't fire at the exact same frame
	_spawn_timer = randf_range(0.0, spawn_interval)

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false

func spawn_burst(n: int) -> void:
	for i in n:
		_spawn_one()

func _process(delta: float) -> void:
	_pulse      += delta * 2.4
	_sac_wobble += delta * 1.8

	if active:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			# Count living zerglings that belong to this spawner
			_alive_count = _count_alive()
			if _alive_count < max_alive:
				var to_spawn = mini(burst_size, max_alive - _alive_count)
				for i in to_spawn:
					_spawn_one()
				_crack_t = 1.0   # flash burst animation

	# Crack flash fades
	if _crack_t > 0.0:
		_crack_t = maxf(0.0, _crack_t - delta * 3.5)

	queue_redraw()

func _count_alive() -> int:
	_spawned_zerglings = _spawned_zerglings.filter(func(z): return is_instance_valid(z))
	return _spawned_zerglings.size()

func _spawn_one() -> void:
	var script = zergling_script
	if script == null:
		# Try loading by path if not assigned
		script = load("res://Scripts/Zergling.gd")
	if script == null:
		push_warning("ZerglingSpawner: couldn't find Zergling.gd — set zergling_script export")
		return

	var z = Node2D.new()
	z.set_script(script)

	# Scatter in a rough arc around the sac
	var angle   = randf_range(0.0, TAU)
	var dist    = randf_range(0.0, spawn_radius)
	z.position  = global_position + Vector2(cos(angle) * dist, sin(angle) * dist)

	# Add to same parent as spawner so it lives in the world
	get_parent().add_child(z)
	_spawned_zerglings.append(z)

# ============================================================
#  DRAW — egg sac / biomass spawner
# ============================================================

func _draw() -> void:
	var t_ms    = Time.get_ticks_msec() * 0.001
	var pulse   = sin(_pulse) * 0.5 + 0.5
	var wobble  = sin(_sac_wobble) * 2.0

	# ── Ground slime pool ────────────────────────────────────
	_draw_ellipse(Vector2(0, 22), 26.0, 8.0, Color(C_SLIME.r, C_SLIME.g, C_SLIME.b, 0.25 + pulse * 0.10))
	# Slime tendrils
	for ti in 6:
		var ta   = TAU * float(ti) / 6.0 + t_ms * 0.4
		var tlen = 18.0 + sin(t_ms * 2.0 + ti) * 5.0
		var tip  = Vector2(cos(ta) * tlen * 1.3, 22.0 + sin(ta) * tlen * 0.5)
		draw_line(Vector2(0, 18), tip,
			Color(C_SLIME.r, C_SLIME.g, C_SLIME.b, 0.3 + pulse * 0.15), 1.5)
		draw_circle(tip, 2.0, Color(C_SLIME.r, C_SLIME.g, C_SLIME.b, 0.4))

	# ── Outer membrane (pulsing) ─────────────────────────────
	var sac_r = 20.0 + pulse * 2.5 + wobble * 0.5
	var pts   := PackedVector2Array()
	var seg   = 20
	for i in seg:
		var a = float(i) / float(seg) * TAU
		var r = sac_r + sin(a * 3.0 + t_ms * 1.5) * 2.5
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.85 + 2.0))
	draw_colored_polygon(pts, C_SAC_OUTER)

	# Outer glow ring
	for gi in 3:
		draw_arc(Vector2(0, 2), sac_r + gi * 3.0, 0, TAU, 24,
			Color(C_SAC_GLOW.r, C_SAC_GLOW.g, C_SAC_GLOW.b, (0.25 - gi * 0.06) * (0.5 + pulse * 0.5)), 4.0)

	# ── Inner flesh (translucent squirming core) ─────────────
	var inner_pts := PackedVector2Array()
	for i in 16:
		var a = float(i) / 16.0 * TAU
		var r = (sac_r - 5.0) + sin(a * 5.0 + t_ms * 2.8) * 1.5
		inner_pts.append(Vector2(cos(a) * r * 0.75, sin(a) * r * 0.70 + 1.0))
	draw_colored_polygon(inner_pts, Color(C_SAC_INNER.r, C_SAC_INNER.g, C_SAC_INNER.b, 0.55 + pulse * 0.2))

	# ── Visible larval shapes inside ─────────────────────────
	for li in 3:
		var la    = t_ms * 0.7 + li * TAU / 3.0
		var lx    = cos(la) * 7.0
		var ly    = sin(la) * 5.0 + 1.0
		var lsize = 4.5 + sin(t_ms * 2.0 + li) * 1.0
		draw_circle(Vector2(lx, ly), lsize,
			Color(C_SAC_OUTER.r, C_SAC_OUTER.g, C_SAC_OUTER.b, 0.45))
		# Eye glints
		draw_circle(Vector2(lx + 1.5, ly - 1.0), 1.0,
			Color(0.9, 0.1, 0.0, 0.6 + pulse * 0.4))

	# ── Bio-veins ────────────────────────────────────────────
	var vein_col = Color(C_SAC_GLOW.r, C_SAC_GLOW.g, C_SAC_GLOW.b, 0.25 + pulse * 0.15)
	for vi in 5:
		var va  = float(vi) / 5.0 * TAU
		var vm  = Vector2(cos(va) * 8.0, sin(va) * 7.0)
		var ve  = Vector2(cos(va) * (sac_r - 3.0), sin(va) * (sac_r - 3.0) * 0.85)
		draw_line(vm, ve, vein_col, 1.2)

	# ── Crack flash on spawn ──────────────────────────────────
	if _crack_t > 0.0:
		var crack_alpha = _crack_t
		# Radial cracks
		for ci in 6:
			var ca  = float(ci) / 6.0 * TAU + t_ms * 0.2
			var cs  = Vector2(cos(ca) * 6.0, sin(ca) * 5.0)
			var ce  = Vector2(cos(ca) * (sac_r + 4.0), sin(ca) * (sac_r + 4.0) * 0.85)
			draw_line(cs, ce, Color(C_CRACK.r, C_CRACK.g, C_CRACK.b, crack_alpha), 2.0)
		# Burst flash circle
		draw_arc(Vector2(0, 2), sac_r + 8.0, 0, TAU, 20,
			Color(C_CRACK.r, C_CRACK.g, C_CRACK.b, crack_alpha * 0.7), 6.0)

	# ── Spawner label ─────────────────────────────────────────
	# (small indicator only visible at reasonable zoom)
	var _ct_sc = get_canvas_transform().get_scale()
	var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
	var _rend_sz = maxi(1, int(round(7 * _ct_sc.x)))
	draw_set_transform(Vector2(-16.0, -sac_r - 10.0), 0.0, _inv)
	draw_string(_roboto, Vector2.ZERO, "🐛 SPAWNER",
		HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz,
		Color(0.8, 0.2, 0.8, 0.55 + pulse * 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Helpers ──────────────────────────────────────────────────

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a = float(i) / 18.0 * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
