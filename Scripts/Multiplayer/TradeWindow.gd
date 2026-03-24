extends CanvasLayer

# ============================================================
#  TradeWindow.gd — miniSWG
#  Both players open a trade window.
#  Each puts in items/credits, both confirm → items swap.
#
#  Call init(scene_ref) after add_child.
#  Call open_trade(peer_id, nick) to begin a trade session.
# ============================================================

signal trade_completed
signal trade_cancelled

var scene_ref      : Node   = null
var partner_peer   : int    = -1
var partner_nick   : String = ""
var _open          : bool   = false

# Local offer
var _my_items      : Array  = []   # indices into player inventory
var _my_credits    : int    = 0
var _my_confirmed  : bool   = false

# Remote offer (received via relay)
var _their_items   : Array  = []   # item dicts (copies)
var _their_credits : int    = 0
var _their_confirmed : bool = false

# UI nodes
var _panel         : Panel  = null
var _my_slots      : Array  = []
var _their_slots   : Array  = []
var _my_cr_field   : LineEdit = null
var _their_cr_lbl  : Label   = null
var _confirm_btn   : Button  = null
var _status_lbl    : Label   = null
var _request_panel : Panel   = null

const SLOT_COUNT : int = 6

func init(scene: Node) -> void:
	layer     = 25
	scene_ref = scene

func open_trade(peer_id: int, nick: String) -> void:
	if _open: return
	partner_peer  = peer_id
	partner_nick  = nick
	_open         = true
	_my_items.clear(); _my_credits = 0; _my_confirmed = false
	_their_items.clear(); _their_credits = 0; _their_confirmed = false
	_build_window()

func show_request(from_peer: int, from_nick: String) -> void:
	if _open: return
	_build_request_panel(from_peer, from_nick)

func on_trade_offer(items: Array, credits: int) -> void:
	_their_items   = items
	_their_credits = credits
	_their_confirmed = false
	_refresh_their_side()

func on_trade_confirm() -> void:
	_their_confirmed = true
	_update_confirm_visual()

func on_trade_cancel() -> void:
	_close("Trade cancelled.")

func on_trade_complete(items_from: Array, creds_from: int, items_to: Array, creds_to: int) -> void:
	# items_from = what WE receive (from partner)
	# items_to   = what THEY receive (from us) — already removed by us
	var pl = scene_ref.get("_player")
	if is_instance_valid(pl):
		var inv : Array = pl.get("inventory")
		# Remove our offered items (by id matching)
		for item in items_to:
			for i in range(inv.size() - 1, -1, -1):
				if inv[i].get("id") == item.get("id"):
					inv.remove_at(i); break
		# Add received items
		for item in items_from:
			inv.append(item)
		# Adjust credits
		var cr = int(pl.get("credits"))
		pl.set("credits", cr - creds_to + creds_from)
	_close("Trade complete!")
	emit_signal("trade_completed")

func _build_request_panel(from_peer: int, from_nick: String) -> void:
	if is_instance_valid(_request_panel): _request_panel.queue_free()
	var vp = scene_ref.get_viewport().get_visible_rect().size
	const W : float = 280.0; const H : float = 98.0
	_request_panel          = Panel.new()
	_request_panel.size     = Vector2(W, H)
	_request_panel.position = Vector2(vp.x * 0.5 - W * 0.5, vp.y * 0.50)
	var sty = StyleBoxFlat.new()
	sty.bg_color    = Color(0.04, 0.04, 0.09, 0.97)
	sty.border_color = Color(0.30, 0.72, 1.00, 0.90)
	sty.set_border_width_all(2); sty.set_corner_radius_all(8)
	_request_panel.add_theme_stylebox_override("panel", sty)
	add_child(_request_panel)

	var lbl = Label.new()
	lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	lbl.text = "%s wants to trade with you!" % from_nick
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.88, 1.00))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(W, 28); lbl.position = Vector2(0, 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_request_panel.add_child(lbl)

	for i in 2:
		var texts = ["Accept", "Decline"]
		var cols  = [Color(0.25, 0.88, 0.40), Color(0.88, 0.30, 0.25)]
		var btn   = Button.new()
		btn.text  = texts[i]; btn.size = Vector2(100, 30)
		btn.position = Vector2(24 + i * 132, 56)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", cols[i])
		_request_panel.add_child(btn)
		var accept = (i == 0); var peer = from_peer; var nick = from_nick
		btn.pressed.connect(func():
			if is_instance_valid(_request_panel):
				_request_panel.queue_free(); _request_panel = null
			if accept:
				Relay.send_game_data({"cmd": "trade_accept"}, peer)
				open_trade(peer, nick)
			else:
				Relay.send_game_data({"cmd": "trade_decline"}, peer))

func _build_window() -> void:
	if is_instance_valid(_panel): _panel.queue_free()
	var vp = scene_ref.get_viewport().get_visible_rect().size
	const W : float = 500.0; const H : float = 340.0
	_panel          = Panel.new()
	_panel.size     = Vector2(W, H)
	_panel.position = Vector2(vp.x * 0.5 - W * 0.5, vp.y * 0.5 - H * 0.5)
	var sty         = StyleBoxFlat.new()
	sty.bg_color    = Color(0.04, 0.04, 0.09, 0.97)
	sty.border_color = Color(0.30, 0.72, 1.00, 0.85)
	sty.set_border_width_all(2); sty.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	# Header
	var hdr = Label.new()
	hdr.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	hdr.text = "Trade with  %s" % partner_nick
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.add_theme_color_override("font_color", Color(0.50, 0.88, 1.00))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.size = Vector2(W, 26); hdr.position = Vector2(0, 8)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hdr)

	# Separator
	var sep = ColorRect.new()
	sep.size = Vector2(W - 20, 1); sep.position = Vector2(10, 34)
	sep.color = Color(0.30, 0.50, 0.80, 0.5)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(sep)

	# Column headers
	for col in 2:
		var lbl = Label.new()
		lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		lbl.text = "Your Offer" if col == 0 else partner_nick + "'s Offer"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 1.00))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(220, 18); lbl.position = Vector2(10 + col * 260, 38)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(lbl)

	# Item slots (2 columns of 6)
	_my_slots.clear(); _their_slots.clear()
	for col in 2:
		for row in SLOT_COUNT:
			var slot          = Panel.new()
			slot.size         = Vector2(200, 30)
			slot.position     = Vector2(20 + col * 260, 60 + row * 34)
			var ssty          = StyleBoxFlat.new()
			ssty.bg_color     = Color(0.06, 0.07, 0.15, 0.85)
			ssty.border_color = Color(0.25, 0.35, 0.65, 0.60)
			ssty.set_border_width_all(1); ssty.set_corner_radius_all(3)
			slot.add_theme_stylebox_override("panel", ssty)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			_panel.add_child(slot)
			if col == 0:
				_my_slots.append(slot)
				var sidx = row
				slot.gui_input.connect(func(ev):
					if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
						_remove_my_item(sidx))
			else:
				_their_slots.append(slot)

	# Credits
	var my_cr_lbl = Label.new()
	my_cr_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	my_cr_lbl.text = "Credits:"; my_cr_lbl.add_theme_font_size_override("font_size", 12)
	my_cr_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	my_cr_lbl.position = Vector2(20, 270); my_cr_lbl.size = Vector2(70, 20)
	my_cr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(my_cr_lbl)

	_my_cr_field          = LineEdit.new()
	_my_cr_field.size     = Vector2(120, 22)
	_my_cr_field.position = Vector2(92, 269)
	_my_cr_field.placeholder_text = "0"
	_my_cr_field.add_theme_font_size_override("font_size", 12)
	_panel.add_child(_my_cr_field)
	_my_cr_field.text_changed.connect(func(t):
		_my_credits = int(t) if t.is_valid_int() else 0
		_send_offer())

	_their_cr_lbl = Label.new()
	_their_cr_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_their_cr_lbl.text = "Credits: 0"
	_their_cr_lbl.add_theme_font_size_override("font_size", 12)
	_their_cr_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
	_their_cr_lbl.position = Vector2(280, 270); _their_cr_lbl.size = Vector2(200, 20)
	_their_cr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_their_cr_lbl)

	# Confirm / Cancel buttons
	_confirm_btn          = Button.new()
	_confirm_btn.text     = "Confirm Trade"
	_confirm_btn.size     = Vector2(150, 32); _confirm_btn.position = Vector2(100, 298)
	_confirm_btn.add_theme_font_size_override("font_size", 13)
	_confirm_btn.add_theme_color_override("font_color", Color(0.25, 0.90, 0.40))
	_panel.add_child(_confirm_btn)
	_confirm_btn.pressed.connect(_on_confirm)

	var cancel_btn          = Button.new()
	cancel_btn.text         = "Cancel"
	cancel_btn.size         = Vector2(100, 32); cancel_btn.position = Vector2(270, 298)
	cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.add_theme_color_override("font_color", Color(0.88, 0.30, 0.25))
	_panel.add_child(cancel_btn)
	cancel_btn.pressed.connect(func():
		Relay.send_game_data({"cmd": "trade_cancel"}, partner_peer)
		_close("Trade cancelled."))

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.70, 0.80, 1.00))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.size = Vector2(W, 18); _status_lbl.position = Vector2(0, 319)
	_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_status_lbl)

	# Inventory sidebar: show player items as clickable labels to add to trade
	_build_inventory_list()
	_refresh_my_side()
	_refresh_their_side()

func _build_inventory_list() -> void:
	# Small label below the window instructing the player
	var tip = Label.new()
	tip.text = "Click item in inventory to offer • Right-click slot to remove"
	tip.add_theme_font_size_override("font_size", 10)
	tip.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.size = Vector2(500, 16); tip.position = Vector2(0, 200)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Not added – just a design note; the inventory window works independently

func add_item_to_trade(inv_idx: int) -> void:
	if _my_confirmed: return
	if _my_items.size() >= SLOT_COUNT: return
	if _my_items.has(inv_idx): return
	_my_items.append(inv_idx)
	_refresh_my_side()
	_send_offer()

func _remove_my_item(slot_idx: int) -> void:
	if slot_idx >= _my_items.size(): return
	_my_items.remove_at(slot_idx)
	_my_confirmed = false
	_refresh_my_side()
	_send_offer()

func _send_offer() -> void:
	if not _open: return
	var pl = scene_ref.get("_player")
	var offered_items : Array = []
	if is_instance_valid(pl):
		var inv : Array = pl.get("inventory")
		for idx in _my_items:
			if idx < inv.size():
				offered_items.append(inv[idx])
	Relay.send_game_data({"cmd": "trade_offer",
		"items": offered_items, "credits": _my_credits}, partner_peer)

func _on_confirm() -> void:
	if _my_confirmed: return
	_my_confirmed = true
	_update_confirm_visual()
	Relay.send_game_data({"cmd": "trade_confirm"}, partner_peer)
	if _their_confirmed:
		_execute_trade()

func _execute_trade() -> void:
	var pl = scene_ref.get("_player")
	var offered_items : Array = []
	if is_instance_valid(pl):
		var inv : Array = pl.get("inventory")
		for idx in _my_items:
			if idx < inv.size():
				offered_items.append(inv[idx])
	Relay.send_game_data({
		"cmd":        "trade_complete",
		"items_from": _their_items,
		"creds_from": _their_credits,
		"items_to":   offered_items,
		"creds_to":   _my_credits,
	}, partner_peer)
	on_trade_complete(_their_items, _their_credits, offered_items, _my_credits)

func _refresh_my_side() -> void:
	var pl  = scene_ref.get("_player")
	var inv : Array = [] if not is_instance_valid(pl) else pl.get("inventory")
	for i in _my_slots.size():
		var slot = _my_slots[i]
		for child in slot.get_children(): child.queue_free()
		if i < _my_items.size():
			var idx  = _my_items[i]
			var item = inv[idx] if idx < inv.size() else {}
			var lbl  = Label.new()
			lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
			lbl.text = item.get("name", "?") + "  [%s]" % item.get("rarity", "")
			lbl.add_theme_font_size_override("font_size", 11)
			var rc = {"grey": Color(0.7,0.7,0.7), "white": Color(1,1,1), "blue": Color(0.4,0.7,1), "gold": Color(1,0.85,0.2)}
			lbl.add_theme_color_override("font_color", rc.get(item.get("rarity","grey"), Color(0.8,0.8,0.8)))
			lbl.position = Vector2(4, 7); lbl.size = Vector2(192, 16)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(lbl)

func _refresh_their_side() -> void:
	for i in _their_slots.size():
		var slot = _their_slots[i]
		for child in slot.get_children(): child.queue_free()
		if i < _their_items.size():
			var item = _their_items[i]
			var lbl  = Label.new()
			lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
			lbl.text = item.get("name", "?") + "  [%s]" % item.get("rarity", "")
			lbl.add_theme_font_size_override("font_size", 11)
			var rc = {"grey": Color(0.7,0.7,0.7), "white": Color(1,1,1), "blue": Color(0.4,0.7,1), "gold": Color(1,0.85,0.2)}
			lbl.add_theme_color_override("font_color", rc.get(item.get("rarity","grey"), Color(0.8,0.8,0.8)))
			lbl.position = Vector2(4, 7); lbl.size = Vector2(192, 16)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(lbl)
	if is_instance_valid(_their_cr_lbl):
		_their_cr_lbl.text = "Credits: %d" % _their_credits

func _update_confirm_visual() -> void:
	if not is_instance_valid(_confirm_btn): return
	if _my_confirmed and _their_confirmed:
		_confirm_btn.text = "Both Confirmed — Executing…"
		_confirm_btn.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))
	elif _my_confirmed:
		_confirm_btn.text = "Waiting for %s…" % partner_nick
		_confirm_btn.add_theme_color_override("font_color", Color(0.80, 0.88, 0.30))
	if is_instance_valid(_status_lbl):
		_status_lbl.text = "Partner confirmed!" if _their_confirmed else ""

func _close(msg: String = "") -> void:
	_open = false
	if is_instance_valid(_panel): _panel.queue_free(); _panel = null
	if msg.length() > 0:
		print("TradeWindow: ", msg)
	emit_signal("trade_cancelled")
