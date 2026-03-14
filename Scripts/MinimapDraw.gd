extends Control

# ============================================================
#  MinimapDraw.gd — miniSWG
#  Standalone Control drawn inside a HUD panel.
#  Set scene_ref to the SpaceportScene node after instantiating.
#  Scroll wheel over the map zooms in/out.
# ============================================================

const MAP_WORLD_W : float = 16384.0
const MAP_WORLD_H : float = 16384.0

# Matches SpaceportScene constants
const MAP_PORT_X  : float = 80.0
const MAP_PORT_Y  : float = 80.0
const MAP_PORT_W  : float = 2600.0
const MAP_PORT_H  : float = 2400.0

var scene_ref : Node  = null
var _zoom     : float = 2.0

var _sx : float = 1.0
var _sy : float = 1.0
var _cx : float = 0.0
var _cy : float = 0.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom + 0.25, 0.5, 6.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom - 0.25, 0.5, 6.0)
			accept_event()

func _w2m(wp: Vector2) -> Vector2:
	return Vector2(wp.x * _sx + _cx, wp.y * _sy + _cy)

func _draw() -> void:
	var W := size.x
	var H := size.y

	# Player world position
	var p_world := Vector2(MAP_WORLD_W * 0.5, MAP_WORLD_H * 0.5)
	if is_instance_valid(scene_ref):
		var pl = scene_ref.get("_player")
		if pl != null and is_instance_valid(pl):
			p_world = pl.global_position

	# World-to-minimap transform (centred on player)
	_sx = (W / MAP_WORLD_W) * _zoom
	_sy = (H / MAP_WORLD_H) * _zoom
	_cx = W * 0.5 - p_world.x * _sx
	_cy = H * 0.5 - p_world.y * _sy

	# ── Background (open grassland) ───────────────────────────
	draw_rect(Rect2(0, 0, W, H), Color(0.26, 0.48, 0.16, 1.0))

	# ── Spaceport complex (tarmac) ─────────────────────────────
	var port_tl  := _w2m(Vector2(MAP_PORT_X, MAP_PORT_Y))
	var port_br  := _w2m(Vector2(MAP_PORT_X + MAP_PORT_W, MAP_PORT_Y + MAP_PORT_H))
	var port_rect = Rect2(port_tl, port_br - port_tl)
	draw_rect(port_rect, Color(0.55, 0.60, 0.66, 1.0))
	draw_rect(port_rect, Color(0.38, 0.42, 0.48, 0.9), false, 1.0)

	# Docking pads (slightly lighter tarmac)
	for pad in [
		[MAP_PORT_X + 180, MAP_PORT_Y + MAP_PORT_H * 0.22, 220, MAP_PORT_H * 0.28],
		[MAP_PORT_X + MAP_PORT_W * 0.65, MAP_PORT_Y + MAP_PORT_H * 0.20, MAP_PORT_W * 0.25, MAP_PORT_H * 0.35]
	]:
		var tl := _w2m(Vector2(pad[0], pad[1]))
		var br := _w2m(Vector2(pad[0] + pad[2], pad[1] + pad[3]))
		draw_rect(Rect2(tl, br - tl), Color(0.46, 0.52, 0.58, 1.0))

	# ── Roads ─────────────────────────────────────────────────
	var road_col := Color(0.48, 0.40, 0.26, 0.75)
	draw_line(
		_w2m(Vector2(MAP_PORT_X + MAP_PORT_W,        MAP_PORT_Y + MAP_PORT_H * 0.45)),
		_w2m(Vector2(MAP_WORLD_W,                    MAP_PORT_Y + MAP_PORT_H * 0.45)),
		road_col, 1.5)
	draw_line(
		_w2m(Vector2(MAP_PORT_X + MAP_PORT_W * 0.50, MAP_PORT_Y + MAP_PORT_H)),
		_w2m(Vector2(MAP_PORT_X + MAP_PORT_W * 0.50, MAP_WORLD_H)),
		road_col, 1.5)

	# ── Remote player dots ────────────────────────────────────
	if is_instance_valid(scene_ref):
		var remotes = scene_ref.get("_remote_players")
		if remotes is Dictionary:
			for _pid in remotes:
				var rp = remotes[_pid]
				if not is_instance_valid(rp): continue
				var rm := _w2m(rp.global_position)
				if rm.x < 0 or rm.x > W or rm.y < 0 or rm.y > H: continue
				draw_circle(rm, 3.5, Color(0.50, 0.50, 0.55, 0.40))
				draw_circle(rm, 2.0, Color(0.78, 0.78, 0.84, 1.00))

	# ── Local player dot (white) ──────────────────────────────
	var pd := _w2m(p_world)
	draw_circle(pd, 5.0, Color(1.0, 1.0, 1.0, 0.20))
	draw_circle(pd, 2.5, Color(1.0, 1.0, 1.0, 1.00))

	# ── Dark edge vignette ────────────────────────────────────
	var edge_w : float = 12.0
	# Top
	draw_rect(Rect2(0, 0, W, edge_w), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, 0, W, edge_w * 0.5), Color(0.0, 0.0, 0.0, 0.25))
	# Bottom
	draw_rect(Rect2(0, H - edge_w, W, edge_w), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, H - edge_w * 0.5, W, edge_w * 0.5), Color(0.0, 0.0, 0.0, 0.25))
	# Left
	draw_rect(Rect2(0, 0, edge_w, H), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, 0, edge_w * 0.5, H), Color(0.0, 0.0, 0.0, 0.25))
	# Right
	draw_rect(Rect2(W - edge_w, 0, edge_w, H), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(W - edge_w * 0.5, 0, edge_w * 0.5, H), Color(0.0, 0.0, 0.0, 0.25))

	# ── Border — solid black frame ───────────────────────────
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, 1.0), false, 2.5)
