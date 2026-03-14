extends CanvasLayer

# ============================================================
#  BossChatWindow.gd — Dark-fantasy MMO chat (Dreadmyst style)
#  Bottom-left chat log with colored messages, "Say:" input bar
# ============================================================

const BUBBLE_DURATION : float = 5.0
const MAX_LINES       : int   = 50
const LOG_W           : float = 420.0
const LOG_H           : float = 180.0
const INPUT_H         : float = 28.0
const TOTAL_H         : float = LOG_H + INPUT_H + 4.0

var _player        : Node          = null
var _chat_open     : bool          = false
var _chat_panel    : Panel         = null   # full chat container
var _chat_input    : LineEdit      = null
var _log_scroll    : ScrollContainer = null
var _log_vbox      : VBoxContainer = null
var _log_msgs      : Array         = []
var _log_drag      : bool          = false
var _say_lbl       : Label         = null

func init(player: Node) -> void:
	layer   = 15
	_player = player
	_build_chat()

# ── Full chat panel (always visible) ─────────────────────────
func _build_chat() -> void:
	var vp   = get_viewport().get_visible_rect().size
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")

	_chat_panel = Panel.new()
	_chat_panel.position = Vector2(8.0, vp.y - TOTAL_H - 8.0)
	_chat_panel.size     = Vector2(LOG_W, TOTAL_H)
	var sty              = StyleBoxFlat.new()
	sty.bg_color         = Color(0.03, 0.03, 0.02, 0.82)
	sty.border_color     = Color(0.18, 0.16, 0.10, 0.75)
	sty.set_border_width_all(1)
	sty.shadow_color     = Color(0.0, 0.0, 0.0, 0.30)
	sty.shadow_size      = 4
	_chat_panel.add_theme_stylebox_override("panel", sty)
	_chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_chat_panel.gui_input.connect(_on_log_drag)
	add_child(_chat_panel)

	# Scroll container for messages
	_log_scroll = ScrollContainer.new()
	_log_scroll.position = Vector2(4, 4)
	_log_scroll.size     = Vector2(LOG_W - 8, LOG_H - 4)
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chat_panel.add_child(_log_scroll)

	_log_vbox               = VBoxContainer.new()
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_vbox)

	# Scroll up/down buttons (left side)
	var scroll_up = Button.new()
	scroll_up.text = "▲"; scroll_up.size = Vector2(16, 16)
	scroll_up.position = Vector2(2, 4)
	scroll_up.add_theme_font_size_override("font_size", 8)
	scroll_up.add_theme_color_override("font_color", Color(0.65, 0.62, 0.50))
	var su_sty = StyleBoxFlat.new(); su_sty.bg_color = Color(0.08, 0.07, 0.05, 0.60)
	scroll_up.add_theme_stylebox_override("normal", su_sty)
	scroll_up.pressed.connect(func(): _log_scroll.scroll_vertical -= 40)
	_chat_panel.add_child(scroll_up)

	var scroll_down = Button.new()
	scroll_down.text = "▼"; scroll_down.size = Vector2(16, 16)
	scroll_down.position = Vector2(2, LOG_H - 20)
	scroll_down.add_theme_font_size_override("font_size", 8)
	scroll_down.add_theme_color_override("font_color", Color(0.65, 0.62, 0.50))
	var sd_sty = StyleBoxFlat.new(); sd_sty.bg_color = Color(0.08, 0.07, 0.05, 0.60)
	scroll_down.add_theme_stylebox_override("normal", sd_sty)
	scroll_down.pressed.connect(func(): _log_scroll.scroll_vertical += 40)
	_chat_panel.add_child(scroll_down)

	# ── Input bar at bottom ───────────────────────────────────
	var input_y = LOG_H + 2

	# Divider line between log and input
	var div        = ColorRect.new()
	div.color      = Color(0.25, 0.22, 0.14, 0.60)
	div.size       = Vector2(LOG_W - 8, 1)
	div.position   = Vector2(4, input_y - 1)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_panel.add_child(div)

	# "Say:" label
	_say_lbl = Label.new()
	_say_lbl.add_theme_font_override("font", font)
	_say_lbl.text     = "Say:"
	_say_lbl.position = Vector2(8, input_y + 4)
	_say_lbl.size     = Vector2(36, INPUT_H)
	_say_lbl.add_theme_font_size_override("font_size", 12)
	_say_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.58))
	_say_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_panel.add_child(_say_lbl)

	# Arrow button
	var arrow_btn = Button.new()
	arrow_btn.text = "←→"
	arrow_btn.size = Vector2(32, INPUT_H - 4)
	arrow_btn.position = Vector2(42, input_y + 2)
	arrow_btn.add_theme_font_size_override("font_size", 9)
	arrow_btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.55))
	var ab_sty = StyleBoxFlat.new(); ab_sty.bg_color = Color(0.08, 0.07, 0.05, 0.70)
	ab_sty.border_color = Color(0.22, 0.20, 0.14, 0.60); ab_sty.set_border_width_all(1)
	arrow_btn.add_theme_stylebox_override("normal", ab_sty)
	_chat_panel.add_child(arrow_btn)

	# Input field
	_chat_input = LineEdit.new()
	_chat_input.name         = "ChatInput"
	_chat_input.max_length   = 120
	_chat_input.position     = Vector2(78, input_y + 1)
	_chat_input.size         = Vector2(LOG_W - 86, INPUT_H - 2)
	_chat_input.add_theme_font_override("font", font)
	_chat_input.add_theme_font_size_override("font_size", 12)
	_chat_input.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.40, 0.38, 0.30))
	_chat_input.placeholder_text = ""
	var input_sty = StyleBoxFlat.new()
	input_sty.bg_color = Color(0.04, 0.04, 0.03, 0.60)
	input_sty.border_color = Color(0.18, 0.16, 0.10, 0.50)
	input_sty.set_border_width_all(1)
	for s_name in ["normal", "focus"]:
		_chat_input.add_theme_stylebox_override(s_name, input_sty)
	_chat_input.text_submitted.connect(_on_submitted)
	_chat_panel.add_child(_chat_input)

	# System welcome messages
	_add_log_line("", "Welcome to miniSWG. Type /help for commands.", false, Color(0.30, 0.82, 0.35))

func _on_log_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_log_drag = event.pressed and event.position.y <= 16.0
	elif event is InputEventMouseMotion and _log_drag:
		var vp      = get_viewport().get_visible_rect().size
		var new_pos = _chat_panel.position + event.relative
		_chat_panel.position = Vector2(
			clampf(new_pos.x, 0.0, vp.x - LOG_W),
			clampf(new_pos.y, 0.0, vp.y - TOTAL_H)
		)

# ── Input handling ────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if not _chat_open:
			_open_chat()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _chat_open:
		_close_chat()
		get_viewport().set_input_as_handled()

func _open_chat() -> void:
	_chat_open = true
	_chat_input.text = ""
	call_deferred("_grab_focus")

func _grab_focus() -> void:
	_chat_input.grab_focus()

func _close_chat() -> void:
	_chat_open = false
	_chat_input.release_focus()
	_chat_input.clear()

func _on_submitted(text: String) -> void:
	_close_chat()
	var msg = text.strip_edges()
	if msg.length() == 0:
		return
	var nick = "Player"
	if is_instance_valid(_player):
		var cn = _player.get("character_name")
		if cn != null:
			nick = str(cn)
	_show_bubble(msg)
	_add_log_line(nick, msg, true)
	# Relay broadcast if connected
	var relay = get_node_or_null("/root/Relay")
	if relay and relay.has_method("send_game_data"):
		relay.send_game_data({"cmd": "chat", "nick": nick, "msg": msg})

# ── Chat bubble above player ──────────────────────────────────
func _show_bubble(msg: String) -> void:
	if not is_instance_valid(_player):
		return
	var old = _player.get_node_or_null("ChatBubble")
	if old:
		old.queue_free()
	var bubble = Node2D.new()
	bubble.name = "ChatBubble"
	_player.add_child(bubble)
	var max_chars = 30
	var wrapped   = _wrap_text(msg, max_chars)
	var lines     = wrapped.split("\n")
	var font_sz   = 13
	var char_w    = font_sz * 0.62
	var line_h    = font_sz + 5
	var pad_x     = 10
	var pad_y     = 8
	var bw        = 0
	for ln in lines:
		bw = max(bw, int(ln.length() * char_w))
	bw = max(bw + pad_x * 2, 60)
	var bh       = lines.size() * line_h + pad_y * 2
	var bubble_y = -80 - bh
	var bubble_x = -bw / 2
	var bg = ColorRect.new()
	bg.color    = Color(0.04, 0.04, 0.03, 0.93)
	bg.position = Vector2(bubble_x, bubble_y)
	bg.size     = Vector2(bw, bh)
	bubble.add_child(bg)
	var top_bar = ColorRect.new()
	top_bar.color    = Color(0.45, 0.38, 0.22, 0.80)
	top_bar.size     = Vector2(bw, 1)
	top_bar.position = Vector2(bubble_x, bubble_y)
	bubble.add_child(top_bar)
	for side_x in [bubble_x, bubble_x + bw - 1]:
		var br = ColorRect.new()
		br.color    = Color(0.45, 0.38, 0.22, 0.80)
		br.size     = Vector2(1, bh)
		br.position = Vector2(side_x, bubble_y)
		bubble.add_child(br)
	var tail = Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-6, bubble_y + bh),
		Vector2(6,  bubble_y + bh),
		Vector2(0,  bubble_y + bh + 12),
	])
	tail.color = Color(0.04, 0.04, 0.03, 0.93)
	bubble.add_child(tail)
	for i in range(lines.size()):
		var lbl = Label.new()
		lbl.add_theme_font_override("font", load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf"))
		lbl.text     = lines[i]
		lbl.position = Vector2(bubble_x + pad_x, bubble_y + pad_y + i * line_h)
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
		bubble.add_child(lbl)
	var tw = bubble.create_tween()
	tw.tween_interval(BUBBLE_DURATION - 0.6)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.6)
	tw.tween_callback(bubble.queue_free)

# ── Chat log ──────────────────────────────────────────────────
func _add_log_line(nick: String, msg: String, is_self: bool, custom_col: Color = Color(-1, -1, -1)) -> void:
	if _log_vbox == null:
		return
	var font = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	var lbl = Label.new()
	lbl.add_theme_font_override("font", font)
	if nick.length() > 0:
		lbl.text = "[%s] says: %s" % [nick, msg]
	else:
		lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 11)
	var col : Color
	if custom_col.r >= 0:
		col = custom_col
	elif is_self:
		col = Color(0.92, 0.90, 0.82)
	else:
		col = Color(0.72, 0.78, 0.55)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_vbox.add_child(lbl)
	_log_msgs.append({"node": lbl})
	while _log_msgs.size() > MAX_LINES:
		var oldest = _log_msgs[0]
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
		_log_msgs.remove_at(0)
	# Auto-scroll to bottom
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	if _log_scroll:
		_log_scroll.scroll_vertical = 999999

func _wrap_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	var words        = text.split(" ")
	var result_lines = []
	var cur          = ""
	for word in words:
		var candidate = (cur + " " + word).strip_edges()
		if candidate.length() > max_chars:
			if cur.length() > 0:
				result_lines.append(cur.strip_edges())
			cur = word
		else:
			cur = candidate
	if cur.length() > 0:
		result_lines.append(cur)
	return "\n".join(result_lines)
