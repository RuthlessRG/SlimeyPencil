extends Control

# ============================================================
#  LunarMinimapDraw.gd — Minimap renderer
#  Square minimap with solid black border, terrain, dots.
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

	# Background
	var is_theed = scene_ref != null and scene_ref.is_in_group("boss_arena_scene") and scene_ref.get_script().resource_path.ends_with("TheedScene.gd")
	if is_theed:
		# Grass terrain base
		draw_rect(Rect2(0, 0, W, H), Color(0.18, 0.32, 0.12, 1.0))
		# Subtle terrain variation patches
		var rng = RandomNumberGenerator.new()
		rng.seed = 42
		for _i in 12:
			var px = rng.randf() * W
			var py = rng.randf() * H
			var pr = rng.randf_range(15, 40)
			draw_circle(Vector2(px, py), pr, Color(0.15, 0.28, 0.10, 0.3))
		for _i in 8:
			var px = rng.randf() * W
			var py = rng.randf() * H
			var pr = rng.randf_range(10, 25)
			draw_circle(Vector2(px, py), pr, Color(0.22, 0.38, 0.15, 0.25))
	else:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.06, 1.0))

	# Player world position
	var p_world := Vector2.ZERO
	if is_instance_valid(scene_ref):
		var pl = scene_ref.get("_player")
		if pl != null and is_instance_valid(pl):
			p_world = pl.global_position

	var world_w : float = GRID_SIZE * TILE_W * 0.5
	var world_h : float = GRID_SIZE * TILE_H * 0.5
	var sx = (W / world_w) * _zoom * 0.5
	var sy = (H / world_h) * _zoom * 0.5
	var cx = W * 0.5 - p_world.x * sx
	var cy = H * 0.5 - p_world.y * sy

	# ── City image on minimap ────────────────────────────────
	if is_theed and is_instance_valid(scene_ref):
		var city = scene_ref.get_node_or_null("City")
		if city:
			var city_spr = city.get_node_or_null("CityImage") as Sprite2D
			if city_spr and city_spr.texture:
				var cpos = city.position
				var tex2 = city_spr.texture
				var ts2 = tex2.get_size()
				var cmx = cpos.x * sx + cx
				var cmy = cpos.y * sy + cy
				draw_set_transform(Vector2(cmx, cmy), 0.0, Vector2(sx, sy))
				draw_texture(tex2, -ts2 * 0.5, Color(1, 1, 1, 0.7))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── Mob dots (red) ───────────────────────────────────────
	if is_instance_valid(scene_ref):
		var wl = scene_ref.get("_world_layer")
		if wl != null and is_instance_valid(wl):
			for child in wl.get_children():
				if not is_instance_valid(child): continue
				if child == scene_ref.get("_player"): continue
				if child.name.begins_with("Remote_"): continue
				var wp = child.global_position
				var mx2 = wp.x * sx + cx
				var my2 = wp.y * sy + cy
				if mx2 < -3 or mx2 > W + 3 or my2 < -3 or my2 > H + 3: continue
				# Mobs = red dots
				if child.is_in_group("targetable"):
					draw_circle(Vector2(mx2, my2), 2.5, Color(0.9, 0.15, 0.15, 0.8))
				# Terminals/NPCs = cyan dots
				elif child.get_meta("label", "") != "":
					draw_circle(Vector2(mx2, my2), 2.0, Color(0.3, 0.7, 0.9, 0.6))

	# ── Remote player dots (blue) ────────────────────────────
	if is_instance_valid(scene_ref):
		var remotes = scene_ref.get("_remote_players")
		if remotes is Dictionary:
			for _pid in remotes:
				var rp = remotes[_pid]
				if not is_instance_valid(rp): continue
				var rm = Vector2(rp.global_position.x * sx + cx, rp.global_position.y * sy + cy)
				if rm.x < 0 or rm.x > W or rm.y < 0 or rm.y > H: continue
				draw_circle(rm, 3.0, Color(0.25, 0.50, 0.90, 0.5))
				draw_circle(rm, 1.8, Color(0.45, 0.70, 1.00, 1.0))

	# ── Local player dot (bright green) ──────────────────────
	var pd = Vector2(p_world.x * sx + cx, p_world.y * sy + cy)
	draw_circle(pd, 4.0, Color(0.2, 1.0, 0.3, 0.3))
	draw_circle(pd, 2.5, Color(0.3, 1.0, 0.4, 1.0))

	# ── Thick solid black border ─────────────────────────────
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.0, 1.0), false, 4.0)
