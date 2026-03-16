extends Control

# ============================================================
#  LunarMinimapDraw.gd — miniSWG | Lunar Station
#  Diamond-shaped minimap drawn inside a HUD panel.
#  Set scene_ref to the LunarStationScene node after instantiating.
# ============================================================

const GRID_SIZE   : int   = 128
const GRID_CENTER : int   = 64
const TILE_W      : int   = 128
const TILE_H      : int   = 64

var scene_ref : Node  = null
var _zoom     : float = 2.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom + 0.25, 0.5, 6.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom - 0.25, 0.5, 6.0)
			accept_event()

func _draw() -> void:
	var W := size.x
	var H := size.y

	# Dark space background
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, 1.0))

	# Player world position
	var p_world := Vector2.ZERO
	if is_instance_valid(scene_ref):
		var pl = scene_ref.get("_player")
		if pl != null and is_instance_valid(pl):
			p_world = pl.global_position

	# World extents — the isometric diamond spans roughly:
	#   center at tile (64,64), the diamond is 128 tiles wide
	#   In world coords the iso diamond is ~8192 x ~4096
	var world_w : float = GRID_SIZE * TILE_W * 0.5   # ~8192
	var world_h : float = GRID_SIZE * TILE_H * 0.5   # ~4096

	# World-to-minimap transform (centred on player)
	var sx = (W / world_w) * _zoom * 0.5
	var sy = (H / world_h) * _zoom * 0.5
	var cx = W * 0.5 - p_world.x * sx
	var cy = H * 0.5 - p_world.y * sy

	# ── Diamond ground outline ─────────────────────────────────
	# The diamond in world space has 4 corner tiles:
	#   top = (0, 0),  right = (128, 0),  bottom = (128, 128),  left = (0, 128)
	# But in iso coords those map to specific world positions.
	# Approximate the diamond as centered on the grid center tile.
	var tilemap = scene_ref.get("_tilemap") if is_instance_valid(scene_ref) else null
	if tilemap != null and is_instance_valid(tilemap):
		# Use actual tilemap mapping for diamond corners
		var top    = tilemap.map_to_local(Vector2i(GRID_CENTER, 0))
		var right  = tilemap.map_to_local(Vector2i(GRID_SIZE, GRID_CENTER))
		var bottom = tilemap.map_to_local(Vector2i(GRID_CENTER, GRID_SIZE))
		var left   = tilemap.map_to_local(Vector2i(0, GRID_CENTER))
		var pts = PackedVector2Array([
			Vector2(top.x * sx + cx, top.y * sy + cy),
			Vector2(right.x * sx + cx, right.y * sy + cy),
			Vector2(bottom.x * sx + cx, bottom.y * sy + cy),
			Vector2(left.x * sx + cx, left.y * sy + cy),
		])
		draw_colored_polygon(pts, Color(0.30, 0.28, 0.26, 0.60))
		# Diamond outline
		for i in 4:
			draw_line(pts[i], pts[(i + 1) % 4], Color(0.50, 0.48, 0.40, 0.50), 1.0)

	# ── Building markers ──────────────────────────────────────
	if is_instance_valid(scene_ref):
		var wl = scene_ref.get("_world_layer")
		if wl != null and is_instance_valid(wl):
			for child in wl.get_children():
				if not is_instance_valid(child): continue
				if child == scene_ref.get("_player"): continue
				# Skip remote players
				if child.name.begins_with("Remote_"): continue
				var lbl = child.get_meta("label", "")
				if lbl == "": continue  # rocks/craters have no label
				var wp = child.global_position
				var mx = wp.x * sx + cx
				var my = wp.y * sy + cy
				if mx < -5 or mx > W + 5 or my < -5 or my > H + 5: continue
				draw_circle(Vector2(mx, my), 3.0, Color(0.40, 0.70, 0.90, 0.70))

	# ── Remote player dots ────────────────────────────────────
	if is_instance_valid(scene_ref):
		var remotes = scene_ref.get("_remote_players")
		if remotes is Dictionary:
			for _pid in remotes:
				var rp = remotes[_pid]
				if not is_instance_valid(rp): continue
				var rm = Vector2(rp.global_position.x * sx + cx, rp.global_position.y * sy + cy)
				if rm.x < 0 or rm.x > W or rm.y < 0 or rm.y > H: continue
				draw_circle(rm, 3.5, Color(0.50, 0.50, 0.55, 0.40))
				draw_circle(rm, 2.0, Color(0.78, 0.78, 0.84, 1.00))

	# ── Local player dot (white) ──────────────────────────────
	var pd = Vector2(p_world.x * sx + cx, p_world.y * sy + cy)
	draw_circle(pd, 5.0, Color(1.0, 1.0, 1.0, 0.20))
	draw_circle(pd, 2.5, Color(1.0, 1.0, 1.0, 1.00))

	# ── Dark edge vignette ────────────────────────────────────
	var edge_w : float = 12.0
	draw_rect(Rect2(0, 0, W, edge_w), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, 0, W, edge_w * 0.5), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(Rect2(0, H - edge_w, W, edge_w), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, H - edge_w * 0.5, W, edge_w * 0.5), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(Rect2(0, 0, edge_w, H), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(0, 0, edge_w * 0.5, H), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(Rect2(W - edge_w, 0, edge_w, H), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(W - edge_w * 0.5, 0, edge_w * 0.5, H), Color(0.0, 0.0, 0.0, 0.25))

	# ── Border — solid black frame ───────────────────────────
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, 1.0), false, 2.5)
