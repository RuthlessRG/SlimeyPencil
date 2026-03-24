extends CanvasLayer

# ============================================================
#  PlayerOptionsPanel.gd — miniSWG
#  Right-click popup for player interactions.
#  Signals: duel_requested, invite_requested, trade_requested
# ============================================================

signal duel_requested(peer_id: int, nick: String)
signal invite_requested(peer_id: int, nick: String)
signal trade_requested(peer_id: int, nick: String)

var _panel       : Panel  = null
var _target_peer : int    = -1
var _target_nick : String = ""

func init() -> void:
	layer = 30

func show_for(peer_id: int, nick: String, screen_pos: Vector2) -> void:
	_target_peer = peer_id
	_target_nick = nick
	if is_instance_valid(_panel):
		_panel.queue_free()
	_build_panel(screen_pos)

func close() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_panel): return
	if event is InputEventMouseButton and event.pressed:
		var local = _panel.get_local_mouse_position()
		if not Rect2(Vector2.ZERO, _panel.size).has_point(local):
			close()

func _build_panel(pos: Vector2) -> void:
	var vp = get_viewport().get_visible_rect().size
	const W : float = 148.0
	const H : float = 118.0
	var px = clampf(pos.x, 4.0, vp.x - W - 4.0)
	var py = clampf(pos.y, 4.0, vp.y - H - 4.0)

	_panel          = Panel.new()
	_panel.size     = Vector2(W, H)
	_panel.position = Vector2(px, py)
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.04, 0.04, 0.09, 0.97)
	sty.border_color = Color(0.52, 0.52, 0.62, 0.90)
	sty.set_border_width_all(2); sty.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sty)

	var title = Label.new()
	title.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	title.text = _target_nick
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.80, 0.92, 1.00))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(W, 22); title.position = Vector2(0, 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	var sep       = ColorRect.new()
	sep.size      = Vector2(W - 12, 1); sep.position = Vector2(6, 27)
	sep.color     = Color(0.40, 0.40, 0.52, 0.55)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	var opts  = [["Duel",   Color(1.00, 0.72, 0.20)],
				 ["Invite", Color(0.35, 0.88, 0.50)],
				 ["Trade",  Color(0.30, 0.72, 1.00)]]
	for i in opts.size():
		var btn = Button.new()
		btn.text = opts[i][0]
		btn.size = Vector2(W - 16, 24)
		btn.position = Vector2(8, 32 + i * 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", opts[i][1])
		var bs  = StyleBoxFlat.new()
		bs.bg_color = Color(0.08, 0.10, 0.22, 0.0); bs.set_border_width_all(0)
		var bsh = bs.duplicate() as StyleBoxFlat
		bsh.bg_color = Color(0.14, 0.18, 0.38, 0.85)
		btn.add_theme_stylebox_override("normal",  bs)
		btn.add_theme_stylebox_override("hover",   bsh)
		btn.add_theme_stylebox_override("pressed", bsh)
		_panel.add_child(btn)
		var idx = i
		btn.pressed.connect(func():
			close()
			match idx:
				0: emit_signal("duel_requested",   _target_peer, _target_nick)
				1: emit_signal("invite_requested", _target_peer, _target_nick)
				2: emit_signal("trade_requested",  _target_peer, _target_nick)
		)

	add_child(_panel)
