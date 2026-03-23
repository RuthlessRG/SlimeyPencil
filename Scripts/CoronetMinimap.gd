extends Control

## Minimap draw control for Coronet 3D scene.
## Renders player, mobs, and remote players as dots.

var scene_ref : Node = null
var _zoom : float = 0.5  # world units per pixel

func _ready() -> void:
	pass  # scene_ref is set externally by CoronetPlayer

func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom = clampf(_zoom - 0.05, 0.1, 2.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom = clampf(_zoom + 0.05, 0.1, 2.0)
			queue_redraw()
			get_viewport().set_input_as_handled()

func _process(_delta : float) -> void:
	queue_redraw()

func _draw() -> void:
	if scene_ref == null:
		# Try to find scene ref from parent chain
		var p = get_parent()
		while p:
			if p.has_method("_log_combat"):
				scene_ref = p
				break
			p = p.get_parent()
	if scene_ref == null:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.15, 0.18, 0.15, 0.95))
		return
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5

	# Background — dark terrain with grid lines
	draw_rect(Rect2(0, 0, w, h), Color(0.12, 0.14, 0.12, 0.95))
	# Grid lines for spatial reference
	var grid_step := 20.0
	for gx in range(0, int(w), int(grid_step)):
		draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.18, 0.2, 0.18, 0.5), 1.0)
	for gy in range(0, int(h), int(grid_step)):
		draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.18, 0.2, 0.18, 0.5), 1.0)

	# Get player position
	var player_pos := Vector3.ZERO
	var active = scene_ref.get("_active")
	if active and is_instance_valid(active):
		player_pos = active.global_position

	# Draw buildings as gray squares
	var skip_names := ["Ground", "WorldEnvironment", "Sun", "Moon", "MoonLight", "Camera3D"]
	for child in scene_ref.get_children():
		if child.name in skip_names:
			continue
		if child == active:
			continue
		if child.has_method("get_display_name"):  # mob
			continue
		if child.has_method("take_damage"):  # mob
			continue
		var cname := child.name.to_lower()
		if "vehicle" in cname or "iron_sentinel" in cname or "ember_guard" in cname:
			continue
		if "rain" in cname or "hud" in cname:
			continue
		# Anything else with a position is likely a building/structure
		if child is Node3D:
			var bpos : Vector3 = child.global_position
			var dx := (bpos.x - player_pos.x) / _zoom
			var dz := (bpos.z - player_pos.z) / _zoom
			var sx := cx + dx
			var sy := cy + dz
			if sx >= -20 and sx <= w + 20 and sy >= -20 and sy <= h + 20:
				draw_rect(Rect2(sx - 5, sy - 5, 10, 10), Color(0.35, 0.35, 0.4, 0.8))

	# Draw mobs as red dots
	for child in scene_ref.get_children():
		if child.has_method("get_display_name") and child.get("is_dead") != null:
			if child.get("is_dead"):
				continue
			var mpos : Vector3 = child.global_position
			var dx := (mpos.x - player_pos.x) / _zoom
			var dz := (mpos.z - player_pos.z) / _zoom
			var sx := cx + dx
			var sy := cy + dz
			if sx >= 0 and sx <= w and sy >= 0 and sy <= h:
				draw_circle(Vector2(sx, sy), 3.0, Color(0.9, 0.2, 0.2))

	# Draw remote players as blue dots
	var remotes = scene_ref.get("_remote_players")
	if remotes and remotes is Dictionary:
		for peer_id in remotes:
			var rp = remotes[peer_id]
			if is_instance_valid(rp):
				var rpos : Vector3 = rp.global_position
				var dx := (rpos.x - player_pos.x) / _zoom
				var dz := (rpos.z - player_pos.z) / _zoom
				var sx := cx + dx
				var sy := cy + dz
				if sx >= 0 and sx <= w and sy >= 0 and sy <= h:
					draw_circle(Vector2(sx, sy), 4.0, Color(0.2, 0.5, 0.9))
					draw_circle(Vector2(sx, sy), 2.0, Color(0.4, 0.7, 1.0))

	# Draw vehicle as yellow diamond
	var vehicle = scene_ref.get("_vehicle_mount")
	if vehicle and is_instance_valid(vehicle):
		var vpos : Vector3 = vehicle.global_position
		var dx := (vpos.x - player_pos.x) / _zoom
		var dz := (vpos.z - player_pos.z) / _zoom
		var sx := cx + dx
		var sy := cy + dz
		if sx >= 0 and sx <= w and sy >= 0 and sy <= h:
			# Diamond shape
			var pts := PackedVector2Array([
				Vector2(sx, sy - 4), Vector2(sx + 3, sy),
				Vector2(sx, sy + 4), Vector2(sx - 3, sy)
			])
			draw_colored_polygon(pts, Color(0.9, 0.8, 0.2))

	# Draw player as green dot (center)
	draw_circle(Vector2(cx, cy), 4.0, Color(0.2, 0.9, 0.2))
	draw_circle(Vector2(cx, cy), 2.0, Color(0.5, 1.0, 0.5))

	# Border
	draw_rect(Rect2(0, 0, w, h), Color(0.3, 0.35, 0.3), false, 2.0)
