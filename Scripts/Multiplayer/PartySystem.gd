extends Node

# ============================================================
#  PartySystem.gd — Dreadmyst-style party frame
#  Dark fantasy party widget below the player status bars.
#  Leader can invite / kick. All members can leave.
# ============================================================

var scene_ref    : Node   = null
var members      : Array  = []   # Array of {peer_id, nick, hp, max_hp, mp, max_mp}
var leader_peer  : int    = -1
var in_party     : bool   = false

var _hud         : CanvasLayer = null
var _frame_panel : Panel       = null
var _member_rows : Array       = []
var _pending_invite_from : int    = -1
var _invite_panel        : Panel  = null
var _invite_peer_nick    : String = ""

const MAX_MEMBERS : int = 8

func init(scene: Node, hud: CanvasLayer, frame_bottom_y: float) -> void:
	scene_ref = scene
	_hud      = hud
	_build_frame(frame_bottom_y)

func _build_frame(y: float) -> void:
	_frame_panel          = Panel.new()
	_frame_panel.size     = Vector2(200, 0)
	_frame_panel.position = Vector2(10, y + 6)
	_frame_panel.visible  = false
	var sty               = StyleBoxFlat.new()
	sty.bg_color          = Color(0.05, 0.05, 0.04, 0.88)
	sty.border_color      = Color(0.30, 0.25, 0.15, 0.75)
	sty.set_border_width_all(1)
	sty.set_corner_radius_all(2)
	sty.shadow_color      = Color(0.0, 0.0, 0.0, 0.30)
	sty.shadow_size       = 3
	_frame_panel.add_theme_stylebox_override("panel", sty)
	_frame_panel.gui_input.connect(_on_frame_right_click)
	_hud.add_child(_frame_panel)

func _on_frame_right_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if in_party:
			_show_leave_menu(event.global_position)

func _show_leave_menu(screen_pos: Vector2) -> void:
	var vp = scene_ref.get_viewport().get_visible_rect().size
	var popup = Panel.new()
	popup.size = Vector2(120, 36); popup.position = screen_pos
	popup.position.x = clampf(popup.position.x, 0, vp.x - 124)
	popup.position.y = clampf(popup.position.y, 0, vp.y - 40)
	var sty = StyleBoxFlat.new()
	sty.bg_color = Color(0.05, 0.05, 0.04, 0.97)
	sty.border_color = Color(0.35, 0.28, 0.18, 0.80)
	sty.set_border_width_all(1); sty.set_corner_radius_all(2)
	popup.add_theme_stylebox_override("panel", sty)
	_hud.add_child(popup)

	var btn = Button.new()
	btn.text = "Leave Party"
	btn.size = Vector2(108, 28); btn.position = Vector2(6, 4)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.90, 0.40, 0.30))
	popup.add_child(btn)
	btn.pressed.connect(func():
		popup.queue_free()
		leave_party())
	get_tree().create_timer(5.0).timeout.connect(
		func(): if is_instance_valid(popup): popup.queue_free())

func send_invite(peer_id: int, _nick: String) -> void:
	if not in_party:
		in_party     = true
		leader_peer  = Relay.my_peer_id
		members.clear()
		members.append(_make_self_member())
	if members.size() >= MAX_MEMBERS: return
	Relay.send_game_data({
		"cmd":    "party_invite",
		"leader": Relay.my_peer_id,
		"nick":   PlayerData.nickname,
		"members": _members_to_array(),
	}, peer_id)

func on_party_invite(from_peer: int, from_nick: String, _member_list: Array) -> void:
	if in_party: return
	_pending_invite_from = from_peer
	_invite_peer_nick    = from_nick
	_show_invite_panel(from_nick)

func on_party_accept(from_peer: int) -> void:
	if leader_peer != Relay.my_peer_id: return
	if members.size() >= MAX_MEMBERS: return
	var rp = scene_ref.get("_remote_players").get(from_peer)
	var nick = "Player"
	if is_instance_valid(rp):
		var nn = rp.get("character_name")
		if nn != null: nick = str(nn)
	members.append({"peer_id": from_peer, "nick": nick, "hp": 100, "max_hp": 100, "mp": 100, "max_mp": 100})
	_broadcast_party_update()

func on_party_decline(from_peer: int) -> void:
	var rp = scene_ref.get("_remote_players").get(from_peer)
	var nick = "Player_%d" % from_peer
	if is_instance_valid(rp):
		var nn = rp.get("character_name")
		if nn != null: nick = str(nn)
	print("PartySystem: %s declined the invite." % nick)

func on_party_update(ldr: int, member_list: Array) -> void:
	leader_peer = ldr
	in_party    = true
	members     = member_list.duplicate(true)
	var found = false
	for m in members:
		if m.get("peer_id", -1) == Relay.my_peer_id:
			found = true; break
	if not found:
		members.append(_make_self_member())
	_refresh_frame()

func on_party_kick(kicked_peer: int) -> void:
	if kicked_peer == Relay.my_peer_id:
		_disband()
	else:
		members = members.filter(func(m): return m.get("peer_id", -1) != kicked_peer)
		_refresh_frame()

func on_party_leave(leaving_peer: int) -> void:
	if leaving_peer == Relay.my_peer_id:
		_disband()
	else:
		members = members.filter(func(m): return m.get("peer_id", -1) != leaving_peer)
		if leader_peer == leaving_peer and members.size() > 0:
			leader_peer = members[0].get("peer_id", -1)
		_refresh_frame()
		if leader_peer == Relay.my_peer_id:
			_broadcast_party_update()

func on_peer_disconnected(peer_id: int) -> void:
	on_party_leave(peer_id)

func leave_party() -> void:
	if not in_party: return
	Relay.send_game_data({"cmd": "party_leave", "peer_id": Relay.my_peer_id})
	_disband()

func kick_member(peer_id: int) -> void:
	if leader_peer != Relay.my_peer_id: return
	Relay.send_game_data({"cmd": "party_kick", "peer_id": peer_id}, peer_id)
	on_party_kick(peer_id)
	_broadcast_party_update()

func update_member_hp(peer_id: int, hp_val: float, max_hp_val: float, mp_val: float, max_mp_val: float) -> void:
	for m in members:
		if m.get("peer_id", -1) == peer_id:
			m["hp"] = hp_val; m["max_hp"] = max_hp_val
			m["mp"] = mp_val; m["max_mp"] = max_mp_val
			break
	_refresh_frame()

func _broadcast_party_update() -> void:
	var arr = _members_to_array()
	var pl = scene_ref.get("_player")
	if is_instance_valid(pl):
		for m in arr:
			if m.get("peer_id", -1) == Relay.my_peer_id:
				m["hp"]     = float(pl.get("hp"))
				m["max_hp"] = float(pl.get("max_hp"))
				m["mp"]     = float(pl.get("mp"))
				m["max_mp"] = float(pl.get("max_mp"))
	for m in members:
		var pid = m.get("peer_id", -1)
		if pid != Relay.my_peer_id and pid != -1:
			Relay.send_game_data({"cmd": "party_update", "leader": leader_peer, "members": arr}, pid)
	_refresh_frame()

func _show_invite_panel(from_nick: String) -> void:
	if is_instance_valid(_invite_panel): _invite_panel.queue_free()
	var vp  = scene_ref.get_viewport().get_visible_rect().size
	const W : float = 290.0; const H : float = 100.0
	_invite_panel          = Panel.new()
	_invite_panel.size     = Vector2(W, H)
	_invite_panel.position = Vector2(vp.x * 0.5 - W * 0.5, vp.y * 0.44)
	var sty = StyleBoxFlat.new()
	sty.bg_color    = Color(0.05, 0.05, 0.04, 0.97)
	sty.border_color = Color(0.40, 0.65, 0.30, 0.88)
	sty.set_border_width_all(2); sty.set_corner_radius_all(4)
	_invite_panel.add_theme_stylebox_override("panel", sty)
	if _hud: _hud.add_child(_invite_panel)
	else: scene_ref.add_child(_invite_panel)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = "%s invites you to join their party!" % from_nick
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.72))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(W, 28); lbl.position = Vector2(0, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_invite_panel.add_child(lbl)

	for i in 2:
		var texts = ["Accept", "Decline"]
		var cols  = [Color(0.30, 0.80, 0.35), Color(0.80, 0.30, 0.25)]
		var btn   = Button.new()
		btn.text  = texts[i]
		btn.size  = Vector2(100, 30); btn.position = Vector2(24 + i * 142, 58)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", cols[i])
		_invite_panel.add_child(btn)
		var accept = (i == 0)
		var peer   = _pending_invite_from
		btn.pressed.connect(func():
			if is_instance_valid(_invite_panel):
				_invite_panel.queue_free(); _invite_panel = null
			if accept:
				in_party    = true
				leader_peer = peer
				members.clear()
				members.append(_make_self_member())
				Relay.send_game_data({"cmd": "party_accept"}, peer)
				_refresh_frame()
			else:
				Relay.send_game_data({"cmd": "party_decline"}, peer))

func _disband() -> void:
	in_party    = false
	leader_peer = -1
	members.clear()
	_refresh_frame()

func _make_self_member() -> Dictionary:
	var pl = scene_ref.get("_player")
	return {
		"peer_id": Relay.my_peer_id,
		"nick":    PlayerData.nickname,
		"hp":      float(pl.get("hp")) if is_instance_valid(pl) else 100.0,
		"max_hp":  float(pl.get("max_hp")) if is_instance_valid(pl) else 100.0,
		"mp":      float(pl.get("mp")) if is_instance_valid(pl) else 100.0,
		"max_mp":  float(pl.get("max_mp")) if is_instance_valid(pl) else 100.0,
	}

func _members_to_array() -> Array:
	return members.duplicate(true)

func _refresh_frame() -> void:
	if not is_instance_valid(_frame_panel): return
	for row in _member_rows:
		if is_instance_valid(row): row.queue_free()
	_member_rows.clear()

	var others = members.filter(func(m): return m.get("peer_id", -1) != Relay.my_peer_id)
	if others.is_empty() or not in_party:
		_frame_panel.visible = false
		return

	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	const ROW_H  : float = 48.0
	const PAD    : float = 4.0
	const PW     : float = 200.0
	const HDR_H  : float = 20.0
	_frame_panel.size    = Vector2(PW, HDR_H + PAD + others.size() * ROW_H + PAD)
	_frame_panel.visible = true

	# Header
	var hdr = Control.new()
	hdr.size = Vector2(PW, HDR_H); hdr.position = Vector2(0, 0)
	_frame_panel.add_child(hdr)
	_member_rows.append(hdr)

	var hdr_lbl = Label.new()
	hdr_lbl.add_theme_font_override("font", font)
	hdr_lbl.text = "Party"
	hdr_lbl.add_theme_font_size_override("font_size", 10)
	hdr_lbl.add_theme_color_override("font_color", Color(0.80, 0.75, 0.55))
	hdr_lbl.size = Vector2(100, HDR_H); hdr_lbl.position = Vector2(6, 2)
	hdr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_lbl)

	# Header accent line
	var accent = ColorRect.new()
	accent.color = Color(0.40, 0.32, 0.18, 0.50)
	accent.size  = Vector2(PW - 8, 1)
	accent.position = Vector2(4, HDR_H - 1)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(accent)

	var leave_btn = Button.new()
	leave_btn.text = "Leave"
	leave_btn.size = Vector2(48, 14); leave_btn.position = Vector2(PW - 54, 3)
	leave_btn.add_theme_font_size_override("font_size", 9)
	leave_btn.add_theme_color_override("font_color", Color(0.90, 0.40, 0.30))
	hdr.add_child(leave_btn)
	leave_btn.pressed.connect(func(): leave_party())

	for i in others.size():
		var m    = others[i]
		var row  = Control.new()
		row.size     = Vector2(PW - 8, ROW_H - 2)
		row.position = Vector2(4, HDR_H + PAD + i * ROW_H)
		_frame_panel.add_child(row)
		_member_rows.append(row)

		# Name
		var nl = Label.new()
		nl.add_theme_font_override("font", font)
		nl.text = m.get("nick", "?")
		nl.add_theme_font_size_override("font_size", 11)
		nl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.70))
		nl.size = Vector2(140, 14); nl.position = Vector2(2, 2)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nl)

		# Leader crown
		if m.get("peer_id", -1) == leader_peer:
			var cl = Label.new()
			cl.add_theme_font_override("font", font)
			cl.text = "★"; cl.add_theme_font_size_override("font_size", 10)
			cl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
			cl.position = Vector2(144, 2); cl.size = Vector2(16, 14)
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cl)

		# HP bar (red, matching player widget)
		var hp_pct = clampf(float(m.get("hp", 100)) / maxf(1, float(m.get("max_hp", 100))), 0.0, 1.0)
		var hp_bg  = ColorRect.new()
		hp_bg.size = Vector2(PW - 12, 10); hp_bg.position = Vector2(2, 18)
		hp_bg.color = Color(0.04, 0.04, 0.06)
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hp_bg)
		var hp_fill = ColorRect.new()
		hp_fill.size = Vector2((PW - 12) * hp_pct, 10); hp_fill.position = Vector2(2, 18)
		hp_fill.color = Color(0.72, 0.14, 0.10)
		hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hp_fill)
		# HP border
		var hp_border = ColorRect.new()
		hp_border.size = Vector2(PW - 12, 1); hp_border.position = Vector2(2, 18)
		hp_border.color = Color(0.50, 0.12, 0.08, 0.60)
		hp_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hp_border)

		# MP bar (blue)
		var mp_pct = clampf(float(m.get("mp", 100)) / maxf(1, float(m.get("max_mp", 100))), 0.0, 1.0)
		var mp_bg  = ColorRect.new()
		mp_bg.size = Vector2(PW - 12, 7); mp_bg.position = Vector2(2, 30)
		mp_bg.color = Color(0.04, 0.04, 0.06)
		mp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mp_bg)
		var mp_fill = ColorRect.new()
		mp_fill.size = Vector2((PW - 12) * mp_pct, 7); mp_fill.position = Vector2(2, 30)
		mp_fill.color = Color(0.15, 0.30, 0.72)
		mp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mp_fill)

		# Kick button (leader only)
		if leader_peer == Relay.my_peer_id:
			var kick_btn = Button.new()
			kick_btn.text = "✕"; kick_btn.size = Vector2(14, 14)
			kick_btn.position = Vector2(PW - 20, 2)
			kick_btn.add_theme_font_size_override("font_size", 9)
			kick_btn.add_theme_color_override("font_color", Color(0.80, 0.28, 0.22))
			row.add_child(kick_btn)
			var kpeer = m.get("peer_id", -1)
			kick_btn.pressed.connect(func(): kick_member(kpeer))
