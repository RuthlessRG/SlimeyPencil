extends Node2D

# ============================================================
#  BankTerminal.gd — miniSWG
#  Drawn entirely in code. Player approaches + presses F
#  to open the bank terminal (stub — deposit/withdraw coming soon).
# ============================================================

const INTERACT_RANGE : float = 38.0

var _t           : float = 0.0
var _player_near : bool  = false
var _prompt_lbl  : Label = null
var _panel       : Control = null
var _player_ref  : Node    = null  # cached player reference
var _credit_lbl  : Label   = null  # "On Hand: X" label
var _bank_lbl    : Label   = null  # "In Bank: X" label
var _inv_container : VBoxContainer = null  # inventory items list
var _bank_container : VBoxContainer = null  # bank items list
var _roboto : Font = null

func _ready() -> void:
	_roboto = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	add_to_group("bank_terminal")

	_prompt_lbl = Label.new()
	_prompt_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
	_prompt_lbl.text = "[F]  Bank Terminal"
	_prompt_lbl.add_theme_font_size_override("font_size", 9)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.position = Vector2(-40, -58)
	_prompt_lbl.size     = Vector2(82, 14)
	_prompt_lbl.visible  = false
	_prompt_lbl.z_index  = 10
	add_child(_prompt_lbl)

func _process(delta: float) -> void:
	_t += delta
	var near = false
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) <= INTERACT_RANGE:
			near = true
			break
	if near != _player_near:
		_player_near = near
		_prompt_lbl.visible = near
		if near and _panel == null:
			pass  # panel shown on F-press via _input
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if _player_near:
			_toggle_panel()

func _get_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			_player_ref = p
			return p
	return null

func _toggle_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		_credit_lbl = null
		_bank_lbl = null
		_inv_container = null
		_bank_container = null
		return
	var player = _get_player()
	if player == null:
		return
	_panel = _build_panel(player)
	get_tree().current_scene.add_child(_panel)

func _make_label(text: String, size: int, color: Color, halign := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl = Label.new()
	if _roboto:
		lbl.add_theme_font_override("font", _roboto)
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = halign
	return lbl

func _make_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	if _roboto:
		btn.add_theme_font_override("font", _roboto)
	btn.text = text
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(80, 24)
	btn.pressed.connect(callback)
	return btn

func _build_panel(player: Node) -> Control:
	var W = 420.0
	var H = 380.0
	var p = Panel.new()
	p.size = Vector2(W, H)
	p.position = Vector2(
		get_viewport().size.x * 0.5 - W * 0.5,
		get_viewport().size.y * 0.5 - H * 0.5)
	p.z_index = 50

	# Title
	var title = _make_label("GALACTIC BANK", 16, Color(1.0, 0.85, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 8)
	title.size = Vector2(W, 24)
	p.add_child(title)

	# ── Credits section ──────────────────────────────────────
	var cred_bg = Panel.new()
	cred_bg.position = Vector2(10, 38)
	cred_bg.size = Vector2(W - 20, 60)
	p.add_child(cred_bg)

	_credit_lbl = _make_label("On Hand: %d credits" % player.credits, 11, Color(0.9, 0.85, 0.5))
	_credit_lbl.position = Vector2(10, 5)
	_credit_lbl.size = Vector2(200, 18)
	cred_bg.add_child(_credit_lbl)

	_bank_lbl = _make_label("In Bank: %d credits" % player.bank_credits, 11, Color(0.5, 0.85, 0.9))
	_bank_lbl.position = Vector2(10, 25)
	_bank_lbl.size = Vector2(200, 18)
	cred_bg.add_child(_bank_lbl)

	# Deposit/Withdraw buttons
	var dep_100 = _make_button("Deposit 100", func(): _transfer_credits(player, 100))
	dep_100.position = Vector2(220, 3)
	dep_100.custom_minimum_size = Vector2(80, 22)
	cred_bg.add_child(dep_100)

	var dep_all = _make_button("Deposit All", func(): _transfer_credits(player, player.credits))
	dep_all.position = Vector2(305, 3)
	dep_all.custom_minimum_size = Vector2(80, 22)
	cred_bg.add_child(dep_all)

	var with_100 = _make_button("Withdraw 100", func(): _transfer_credits(player, -100))
	with_100.position = Vector2(220, 28)
	with_100.custom_minimum_size = Vector2(80, 22)
	cred_bg.add_child(with_100)

	var with_all = _make_button("Withdraw All", func(): _transfer_credits(player, -player.bank_credits))
	with_all.position = Vector2(305, 28)
	with_all.custom_minimum_size = Vector2(80, 22)
	cred_bg.add_child(with_all)

	# ── Inventory items (left side) ──────────────────────────
	var inv_title = _make_label("INVENTORY", 11, Color(0.9, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	inv_title.position = Vector2(10, 102)
	inv_title.size = Vector2(195, 18)
	p.add_child(inv_title)

	var inv_scroll = ScrollContainer.new()
	inv_scroll.position = Vector2(10, 122)
	inv_scroll.size = Vector2(195, 210)
	p.add_child(inv_scroll)

	_inv_container = VBoxContainer.new()
	_inv_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(_inv_container)

	# ── Bank items (right side) ──────────────────────────────
	var bank_title = _make_label("BANK VAULT", 11, Color(0.5, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	bank_title.position = Vector2(215, 102)
	bank_title.size = Vector2(195, 18)
	p.add_child(bank_title)

	var bank_scroll = ScrollContainer.new()
	bank_scroll.position = Vector2(215, 122)
	bank_scroll.size = Vector2(195, 210)
	p.add_child(bank_scroll)

	_bank_container = VBoxContainer.new()
	_bank_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bank_scroll.add_child(_bank_container)

	_refresh_items(player)

	# Close hint
	var close = _make_label("[F] Close", 9, Color(0.5, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	close.position = Vector2(0, H - 20)
	close.size = Vector2(W, 16)
	p.add_child(close)

	return p

func _transfer_credits(player: Node, amount: int) -> void:
	if amount > 0:
		# Deposit
		var actual = mini(amount, player.credits)
		if actual <= 0:
			return
		player.credits -= actual
		player.bank_credits += actual
	else:
		# Withdraw
		var actual = mini(-amount, player.bank_credits)
		if actual <= 0:
			return
		player.bank_credits -= actual
		player.credits += actual
	_update_credit_labels(player)

func _update_credit_labels(player: Node) -> void:
	if _credit_lbl:
		_credit_lbl.text = "On Hand: %d credits" % player.credits
	if _bank_lbl:
		_bank_lbl.text = "In Bank: %d credits" % player.bank_credits

func _refresh_items(player: Node) -> void:
	# Clear existing
	if _inv_container:
		for c in _inv_container.get_children():
			c.queue_free()
	if _bank_container:
		for c in _bank_container.get_children():
			c.queue_free()

	# Populate inventory items with "Deposit" button
	for i in player.inventory.size():
		var item = player.inventory[i]
		var row = HBoxContainer.new()
		var name_lbl = _make_label(item.get("name", "???"), 9, _rarity_color(item.get("rarity", "common")))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row.add_child(name_lbl)
		var idx = i
		var dep_btn = _make_button(">", func(): _deposit_item(player, idx))
		dep_btn.custom_minimum_size = Vector2(28, 20)
		dep_btn.tooltip_text = "Deposit to bank"
		row.add_child(dep_btn)
		_inv_container.add_child(row)

	if player.inventory.size() == 0:
		_inv_container.add_child(_make_label("(empty)", 9, Color(0.5, 0.5, 0.5)))

	# Populate bank items with "Withdraw" button
	for i in player.bank_items.size():
		var item = player.bank_items[i]
		var row = HBoxContainer.new()
		var w_btn = _make_button("<", func(): _withdraw_item(player, i))
		w_btn.custom_minimum_size = Vector2(28, 20)
		w_btn.tooltip_text = "Withdraw to inventory"
		row.add_child(w_btn)
		var name_lbl = _make_label(item.get("name", "???"), 9, _rarity_color(item.get("rarity", "common")))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row.add_child(name_lbl)
		_bank_container.add_child(row)

	if player.bank_items.size() == 0:
		_bank_container.add_child(_make_label("(empty)", 9, Color(0.5, 0.5, 0.5)))

func _deposit_item(player: Node, inv_index: int) -> void:
	if inv_index < 0 or inv_index >= player.inventory.size():
		return
	var item = player.inventory[inv_index]
	if item.get("equipped", false):
		return  # can't bank equipped items
	player.inventory.remove_at(inv_index)
	player.bank_items.append(item)
	_refresh_items(player)

func _withdraw_item(player: Node, bank_index: int) -> void:
	if bank_index < 0 or bank_index >= player.bank_items.size():
		return
	var item = player.bank_items[bank_index]
	player.bank_items.remove_at(bank_index)
	player.inventory.append(item)
	_refresh_items(player)

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon": return Color(0.3, 0.9, 0.3)
		"rare": return Color(0.3, 0.5, 1.0)
		"epic": return Color(0.7, 0.3, 0.9)
		"legendary": return Color(1.0, 0.65, 0.0)
		_: return Color(0.8, 0.8, 0.8)

func _draw() -> void:
	var glow        = 0.55 + sin(_t * 2.3) * 0.30
	var screen_glow = 0.50 + sin(_t * 3.9) * 0.22

	# 2.5D isometric kiosk — 30% smaller
	const FW : float = 25.0
	const FH : float = 33.0
	const SD : float = 10.0
	const SH : float = 6.0

	var lx = -FW * 0.5
	var ty = -FH - SH

	# ── Cast shadow (sun from NW, shadow falls SE on ground) ──
	var sh_poly = PackedVector2Array([
		Vector2(lx + FW, ty + SH + FH),
		Vector2(lx + FW + SD, ty + FH),
		Vector2(lx + FW + SD + 8, ty + FH + 5),
		Vector2(lx + FW + 8, ty + SH + FH + 5),
		Vector2(lx + 4, ty + SH + FH + 3),
		Vector2(lx, ty + SH + FH),
	])
	draw_colored_polygon(sh_poly, Color(0, 0, 0, 0.25))

	# ── Proximity aura (gold) ─────────────────────────────────
	if _player_near:
		var aa = 0.10 + sin(_t * 4.5) * 0.05
		var ap = PackedVector2Array()
		for i in 20:
			var a = float(i) / 20.0 * TAU
			ap.append(Vector2(cos(a) * (FW * 0.6 + 10), sin(a) * (FH * 0.35 + 10) - FH * 0.45))
		draw_colored_polygon(ap, Color(1.0, 0.85, 0.20, aa))

	# ── Top face (parallelogram) ──────────────────────────────
	var top_poly = PackedVector2Array([
		Vector2(lx, ty + SH),
		Vector2(lx + SD, ty),
		Vector2(lx + FW + SD, ty),
		Vector2(lx + FW, ty + SH),
	])
	draw_colored_polygon(top_poly, Color(0.22, 0.17, 0.06))
	draw_line(Vector2(lx + SD, ty), Vector2(lx + FW + SD, ty), Color(1.0, 0.85, 0.20, 0.35 * glow), 1.0)
	# Glow beacon on top
	draw_circle(Vector2(lx + FW * 0.5 + SD * 0.4, ty + SH * 0.3), 3.0, Color(1.0, 0.85, 0.20, 0.18 * glow))
	draw_circle(Vector2(lx + FW * 0.5 + SD * 0.4, ty + SH * 0.3), 1.8, Color(1.0, 0.90, 0.40, glow))

	# ── Right side face (parallelogram) ───────────────────────
	var side_poly = PackedVector2Array([
		Vector2(lx + FW, ty + SH),
		Vector2(lx + FW + SD, ty),
		Vector2(lx + FW + SD, ty + FH),
		Vector2(lx + FW, ty + SH + FH),
	])
	draw_colored_polygon(side_poly, Color(0.08, 0.06, 0.02))
	# Side vent lines
	for vi in 4:
		var vy = ty + SH + 8 + vi * 8.0
		var vx0 = lx + FW + 1.5
		var vx1 = lx + FW + SD - 1.5
		var vy_off = (vy - (ty + SH)) / FH * -SH
		draw_line(Vector2(vx0, vy), Vector2(vx1, vy + vy_off * 0.3), Color(0.14, 0.10, 0.04), 0.8)

	# ── Front face ────────────────────────────────────────────
	draw_rect(Rect2(lx, ty + SH, FW, FH), Color(0.14, 0.10, 0.05))
	draw_rect(Rect2(lx + 1.5, ty + SH + 1.5, FW - 3, FH - 3), Color(0.18, 0.13, 0.06))
	# Panel seam
	draw_line(Vector2(lx + FW * 0.5, ty + SH + 2), Vector2(lx + FW * 0.5, ty + SH + FH - 2), Color(0.08, 0.06, 0.02), 0.6)

	# ── Gold trim stripe ─────────────────────────────────────
	draw_rect(Rect2(lx, ty + SH, FW, 5), Color(0.80, 0.65, 0.10))
	draw_rect(Rect2(lx, ty + SH, FW, 2.5), Color(0.95, 0.78, 0.15, 0.88))

	# ── Screen area ───────────────────────────────────────────
	var sx  = lx + 4
	var sy  = ty + SH + 7
	var sw  = FW - 8
	var sh2 = 17.0
	# Screen recess
	draw_rect(Rect2(sx - 1, sy - 1, sw + 2, sh2 + 2), Color(0.06, 0.04, 0.01))
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.24, 0.18, 0.04))
	# Screen glow
	var glow_c = Color(0.90 * screen_glow, 0.70 * screen_glow, 0.10 * screen_glow, 0.6)
	draw_rect(Rect2(sx + 1, sy + 1, sw - 2, sh2 - 2), glow_c)
	# Scanlines
	for si in 2:
		draw_rect(Rect2(sx + 1, sy + 3 + si * 6, sw - 2, 1.0), Color(1.0, 0.85, 0.20, 0.20 * screen_glow))
	draw_rect(Rect2(sx, sy, sw, sh2), Color(0.85, 0.65, 0.10, 0.55), false, 1.0)
	# Screen text — "GALACTIC BANK v1.4"
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf") as Font
	if font:
		var _ct_sc = get_canvas_transform().get_scale()
		var _inv = Vector2(1.0 / _ct_sc.x, 1.0 / _ct_sc.y)
		var _rend_sz1 = maxi(1, int(round(6 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 7), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "GALACTIC", HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz1, Color(1.0, 0.90, 0.35, screen_glow))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var _rend_sz2 = maxi(1, int(round(5 * _ct_sc.x)))
		draw_set_transform(Vector2(sx + 2, sy + 14), 0.0, _inv)
		draw_string(font, Vector2.ZERO, "BANK v1.4", HORIZONTAL_ALIGNMENT_LEFT, -1, _rend_sz2, Color(0.85, 0.70, 0.20, screen_glow * 0.75))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── Coin slot ─────────────────────────────────────────────
	draw_rect(Rect2(lx + FW * 0.5 - 7, ty + SH + 26, 14, 3), Color(0.55, 0.44, 0.10))
	draw_rect(Rect2(lx + FW * 0.5 - 5, ty + SH + 26.5, 10, 2), Color(0.35, 0.28, 0.06))

	# ── Keypad dots ───────────────────────────────────────────
	for row in 3:
		for col in 3:
			draw_circle(
				Vector2(lx + 7 + col * 6, ty + SH + 31 + row * 4.5),
				1.2,
				Color(0.70 * glow, 0.55 * glow, 0.12 * glow))

	# ── Bottom brand stripe ───────────────────────────────────
	draw_rect(Rect2(lx, ty + SH + FH - 4, FW, 4), Color(0.80, 0.65, 0.10, 0.75))

	# ── Metal bolts at corners ────────────────────────────────
	for bpos in [Vector2(lx + 3, ty + SH + 3), Vector2(lx + FW - 3, ty + SH + 3),
				 Vector2(lx + 3, ty + SH + FH - 3), Vector2(lx + FW - 3, ty + SH + FH - 3)]:
		draw_circle(bpos, 1.5, Color(0.35, 0.28, 0.10))
		draw_circle(bpos, 0.8, Color(0.50, 0.40, 0.18))

	# ── Outer glow outline ────────────────────────────────────
	draw_rect(Rect2(lx, ty + SH, FW, FH), Color(0.85, 0.65, 0.10, 0.35 * glow), false, 1.2)
	draw_line(Vector2(lx + FW, ty + SH), Vector2(lx + FW + SD, ty), Color(0.85, 0.65, 0.10, 0.25 * glow), 1.0)
