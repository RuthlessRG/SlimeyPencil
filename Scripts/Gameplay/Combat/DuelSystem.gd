extends Node

# ============================================================
#  DuelSystem.gd — miniSWG
#  Manages the full duel lifecycle:
#  IDLE → REQUESTING → AWAITING → COUNTDOWN → ACTIVE → ENDING
#
#  Call init(scene_ref) after adding as child of SpaceportScene.
#  Handle relay messages by calling the appropriate public methods.
# ============================================================

# State constants (int to avoid enum type-annotation issues with dynamic loading)
const S_IDLE       = 0
const S_REQUESTING = 1
const S_AWAITING   = 2
const S_COUNTDOWN  = 3
const S_ACTIVE     = 4
const S_ENDING     = 5

signal duel_started
signal duel_ended(won: bool)

var scene_ref      : Node   = null
var state          : int    = 0   # S_IDLE
var opponent_peer  : int    = -1
var opponent_nick  : String = ""

var _countdown     : int    = 10
var _timer         : float  = 0.0
var _end_timer     : float  = 0.0

# ── HUD ───────────────────────────────────────────────────────
var _hud           : CanvasLayer = null
var _result_lbl    : Label       = null   # VICTORY / DEFEATED text
var _countdown_lbl : Label       = null
var _status_lbl    : Label       = null
var _request_panel : Panel       = null   # accept / decline panel

func init(scene: Node) -> void:
	scene_ref = scene
	_build_hud()

func _build_hud() -> void:
	_hud       = CanvasLayer.new()
	_hud.layer = 28
	scene_ref.add_child(_hud)

	var vp = scene_ref.get_viewport().get_visible_rect().size

	# Status label (e.g. "Duel request sent…")
	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.size     = Vector2(vp.x, 32)
	_status_lbl.position = Vector2(0, vp.y * 0.30)
	_status_lbl.visible  = false
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_status_lbl)

	# Countdown label
	_countdown_lbl = Label.new()
	_countdown_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_countdown_lbl.add_theme_font_size_override("font_size", 80)
	_countdown_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.10))
	_countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_lbl.size     = Vector2(vp.x, 120)
	_countdown_lbl.position = Vector2(0, vp.y * 0.38)
	_countdown_lbl.visible  = false
	_countdown_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_countdown_lbl)

	# Result label (VICTORY / DEFEATED)
	_result_lbl = Label.new()
	_result_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_result_lbl.add_theme_font_size_override("font_size", 64)
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.size     = Vector2(vp.x, 100)
	_result_lbl.position = Vector2(0, vp.y * 0.36)
	_result_lbl.visible  = false
	_result_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_result_lbl)

# ── Public API ────────────────────────────────────────────────
func request_duel(peer_id: int, nick: String) -> void:
	if state != S_IDLE: return
	state         = S_REQUESTING
	opponent_peer = peer_id
	opponent_nick = nick
	Relay.send_game_data({"cmd": "duel_request", "from_nick": PlayerData.nickname}, peer_id)
	_show_status("Duel request sent to %s…" % nick, 4.0)

func on_duel_request(from_peer: int, from_nick: String) -> void:
	if state != S_IDLE: return
	opponent_peer = from_peer
	opponent_nick = from_nick
	_show_request_panel(from_nick)

func on_duel_accepted(from_peer: int) -> void:
	if from_peer != opponent_peer: return
	if state != S_REQUESTING: return
	state      = S_COUNTDOWN
	_countdown = 10
	_timer     = 0.0
	_show_status("Duel accepted!  Starting in…", 1.5)
	_countdown_lbl.visible = true
	_countdown_lbl.text    = "10"
	# Do NOT enable combat yet — wait until countdown reaches 0

func on_duel_declined(from_peer: int) -> void:
	if from_peer != opponent_peer: return
	_reset()
	_show_status("%s declined the duel." % opponent_nick, 3.0)

# Called when we receive a duel_end message from the opponent.
# i_won = true means the SENDER won (we lost); false means sender lost (we won).
func on_duel_ended_by_peer(from_peer: int, opponent_i_won: bool) -> void:
	if from_peer != opponent_peer: return
	if state != S_ACTIVE and state != S_COUNTDOWN: return
	if opponent_i_won:
		_end_duel(false)   # opponent won → we lost
	else:
		_end_duel(true)    # opponent lost → we won

func on_duel_damage(amount: float) -> void:
	if state != S_ACTIVE: return
	var pl = scene_ref.get("_player")
	if not is_instance_valid(pl): return
	var old_hp = float(pl.get("hp"))
	pl.set("hp", maxf(0.0, old_hp - amount))
	if pl.get("hp") <= 0.0:
		_end_duel(false)

func _end_duel(won: bool) -> void:
	if state == S_ENDING or state == S_IDLE: return
	state = S_ENDING
	_enable_duel_combat(false)
	_countdown_lbl.visible = false
	_status_lbl.visible    = false
	# Stop attacking and clear target
	var pl = scene_ref.get("_player")
	if is_instance_valid(pl):
		pl.set("_current_target", null)
		pl.set("_is_attacking", false)
		if pl.has_method("_cancel_attack"):
			pl.call("_cancel_attack")
		# Heal both players
		pl.set("hp", pl.get("max_hp"))
		pl.set("mp", pl.get("max_mp"))
	# Show result
	if won:
		_result_lbl.text = "VICTORY!"
		_result_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.10))
		_show_status("You won the duel!", 5.0)
	else:
		_result_lbl.text = "DEFEATED"
		_result_lbl.add_theme_color_override("font_color", Color(0.78, 0.20, 0.15))
		_show_status("Defeated…  Better luck next time.", 5.0)
	_result_lbl.visible = true
	_end_timer = 5.0
	emit_signal("duel_ended", won)
	Relay.send_game_data({"cmd": "duel_end", "i_won": won}, opponent_peer)

func _process(delta: float) -> void:
	match state:
		S_COUNTDOWN:
			_timer += delta
			if _timer >= 1.0:
				_timer -= 1.0
				_countdown -= 1
				if _countdown <= 0:
					state = S_ACTIVE
					_enable_duel_combat(true)   # only now can combat begin
					_countdown_lbl.visible = false
					_show_status("FIGHT!", 1.5)
					emit_signal("duel_started")
				else:
					_countdown_lbl.text = str(_countdown)
		S_ACTIVE:
			# Check if we dealt damage to opponent proxy
			var rps = scene_ref.get("_remote_players")
			if rps is Dictionary:
				var opponent_node = rps.get(opponent_peer)
				if is_instance_valid(opponent_node):
					var cur_hp = float(opponent_node.get("hp"))
					var prv_hp = float(opponent_node.get_meta("duel_hp_prev", cur_hp))
					if prv_hp - cur_hp > 0.01:
						var dmg = prv_hp - cur_hp
						Relay.send_game_data({"cmd": "duel_damage", "amount": dmg}, opponent_peer)
						if cur_hp <= 0.0:
							opponent_node.set("hp", float(opponent_node.get("max_hp")))
							_end_duel(true)
					opponent_node.set_meta("duel_hp_prev", cur_hp)
		S_ENDING:
			_end_timer -= delta
			if _end_timer <= 0.0:
				_result_lbl.visible = false
				_reset()

# ── Helpers ───────────────────────────────────────────────────
func _reset() -> void:
	state         = S_IDLE
	opponent_peer = -1
	opponent_nick = ""
	_countdown_lbl.visible = false
	_status_lbl.visible    = false
	_result_lbl.visible    = false
	_enable_duel_combat(false)

func _enable_duel_combat(on: bool) -> void:
	if scene_ref == null: return
	var rps = scene_ref.get("_remote_players")
	if not rps is Dictionary: return
	var rp = rps.get(opponent_peer)
	if not is_instance_valid(rp): return
	if on:
		if not rp.is_in_group("targetable"):
			rp.add_to_group("targetable")
		# Do NOT pre-set duel_hp_prev here — let the first S_ACTIVE frame
		# establish the baseline via the get_meta fallback, so delta = 0
		# on frame 1 and no spurious burst damage is sent.
		if rp.has_meta("duel_hp_prev"):
			rp.remove_meta("duel_hp_prev")
	else:
		if rp.is_in_group("targetable"):
			rp.remove_from_group("targetable")
		if rp.has_meta("duel_hp_prev"):
			rp.remove_meta("duel_hp_prev")
		rp.set("hp", rp.get("max_hp"))

func _show_status(msg: String, duration: float) -> void:
	if not is_instance_valid(_status_lbl): return
	_status_lbl.text    = msg
	_status_lbl.visible = true
	get_tree().create_timer(duration).timeout.connect(
		func(): if is_instance_valid(_status_lbl): _status_lbl.visible = false)

func _show_request_panel(from_nick: String) -> void:
	if is_instance_valid(_request_panel):
		_request_panel.queue_free()
	var vp  = scene_ref.get_viewport().get_visible_rect().size
	const W : float = 280.0
	const H : float = 100.0
	_request_panel          = Panel.new()
	_request_panel.size     = Vector2(W, H)
	_request_panel.position = Vector2(vp.x * 0.5 - W * 0.5, vp.y * 0.38)
	var sty = StyleBoxFlat.new()
	sty.bg_color    = Color(0.05, 0.05, 0.10, 0.96)
	sty.border_color = Color(0.90, 0.72, 0.10, 0.90)
	sty.set_border_width_all(2); sty.set_corner_radius_all(8)
	_request_panel.add_theme_stylebox_override("panel", sty)
	_hud.add_child(_request_panel)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = "%s challenges you to a duel!" % from_nick
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(W, 28); lbl.position = Vector2(0, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_request_panel.add_child(lbl)

	for i in 2:
		var texts  = ["Accept", "Decline"]
		var cols   = [Color(0.25, 0.88, 0.40), Color(0.88, 0.30, 0.25)]
		var btn    = Button.new()
		btn.text   = texts[i]
		btn.size   = Vector2(100, 30)
		btn.position = Vector2(24 + i * 132, 58)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", cols[i])
		_request_panel.add_child(btn)
		var accept = (i == 0)
		var peer   = opponent_peer
		btn.pressed.connect(func():
			if is_instance_valid(_request_panel):
				_request_panel.queue_free(); _request_panel = null
			if accept:
				state      = S_COUNTDOWN
				_countdown = 10
				_timer     = 0.0
				_countdown_lbl.visible = true
				_countdown_lbl.text    = "10"
				# Do NOT enable combat yet — wait for countdown to reach 0
				Relay.send_game_data({"cmd": "duel_accept"}, peer)
			else:
				Relay.send_game_data({"cmd": "duel_decline"}, peer)
				_reset())
