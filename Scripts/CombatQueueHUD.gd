extends CanvasLayer

# ============================================================
#  CombatQueueHUD.gd — SWG Pre-CU combat queue tracker
#  Shows only while the player has a valid target (in combat).
#  Fades in/out. Displays queued abilities + countdown timer.
# ============================================================

var _player      : Node  = null
var _panel       : Panel = null
var _timer_bar   : ColorRect = null
var _timer_bg    : ColorRect = null
var _rows        : Array = []   # Array of Control (one per queue slot)
var _is_showing  : bool  = false
var _vis_tween   : Tween = null
var _font        : Font
var _font_bold   : Font

const HUD_W    : float = 190.0
const ROW_H    : float = 22.0
const ROW_PAD  : float = 2.0
const PAD      : float = 6.0
const MAX_ROWS : int   = 4

# Colours matching the dark-fantasy palette
const COL_BG         := Color(0.03, 0.03, 0.02, 0.92)
const COL_BORDER     := Color(0.32, 0.26, 0.14, 0.88)
const COL_HDR        := Color(0.68, 0.58, 0.28, 0.90)
const COL_TIMER_BG   := Color(0.10, 0.08, 0.04, 0.85)
const COL_TIMER_FILL := Color(0.80, 0.60, 0.15, 0.92)
const COL_NEXT_BG    := Color(0.22, 0.18, 0.05, 0.70)
const COL_NEXT_TEXT  := Color(1.00, 0.92, 0.35, 1.00)
const COL_NEXT_NUM   := Color(1.00, 0.85, 0.20, 1.00)
const COL_QUEUE_TEXT := Color(0.75, 0.70, 0.55, 0.82)
const COL_QUEUE_NUM  := Color(0.50, 0.48, 0.38, 0.70)
const COL_EMPTY_TEXT := Color(0.35, 0.32, 0.22, 0.40)

func init(player: Node) -> void:
	layer   = 11
	_player = player
	_font      = load("res://Assets/Fonts/Roboto/static/Roboto-Regular.ttf")
	_font_bold = load("res://Assets/Fonts/Roboto/static/Roboto-Bold.ttf")
	_build_ui()

func _build_ui() -> void:
	var vp     = get_viewport().get_visible_rect().size
	# Total panel height: header + gap + timer bar + gap + rows + padding
	var hud_h  = PAD + 14.0 + 4.0 + 6.0 + 5.0 + MAX_ROWS * (ROW_H + ROW_PAD) - ROW_PAD + PAD
	# Sit just above the action bar (action bar is ~66px from bottom)
	var hud_x  = vp.x * 0.5 - HUD_W * 0.5
	var hud_y  = vp.y - 72.0 - hud_h

	_panel          = Panel.new()
	_panel.position = Vector2(hud_x, hud_y)
	_panel.size     = Vector2(HUD_W, hud_h)
	_panel.modulate.a = 0.0  # start invisible
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sty = StyleBoxFlat.new()
	sty.bg_color = COL_BG
	sty.border_color = COL_BORDER
	sty.set_border_width_all(2)
	sty.set_corner_radius_all(3)
	sty.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sty.shadow_size  = 5
	_panel.add_theme_stylebox_override("panel", sty)
	add_child(_panel)

	# Top accent line
	var accent = ColorRect.new()
	accent.color = Color(0.48, 0.38, 0.16, 0.55)
	accent.size  = Vector2(HUD_W - 4.0, 1.0)
	accent.position = Vector2(2.0, 2.0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(accent)

	# Header
	var hdr = Label.new()
	hdr.text = "COMBAT QUEUE"
	hdr.add_theme_font_override("font", _font_bold)
	hdr.add_theme_font_size_override("font_size", 9)
	hdr.add_theme_color_override("font_color", COL_HDR)
	hdr.position = Vector2(PAD, PAD)
	hdr.size     = Vector2(HUD_W - PAD * 2.0, 14.0)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(hdr)

	# Timer bar background
	var tb_y = PAD + 14.0 + 4.0
	_timer_bg          = ColorRect.new()
	_timer_bg.position = Vector2(PAD, tb_y)
	_timer_bg.size     = Vector2(HUD_W - PAD * 2.0, 6.0)
	_timer_bg.color    = COL_TIMER_BG
	_timer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_timer_bg)

	# Timer fill (width updated each frame)
	_timer_bar          = ColorRect.new()
	_timer_bar.position = Vector2(PAD, tb_y)
	_timer_bar.size     = Vector2(0.0, 6.0)
	_timer_bar.color    = COL_TIMER_FILL
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_timer_bar)

	# Queue rows
	var rows_top = tb_y + 6.0 + 5.0
	for i in MAX_ROWS:
		var row = _make_row(i, rows_top + i * (ROW_H + ROW_PAD))
		_rows.append(row)
		_panel.add_child(row)

func _make_row(idx: int, y: float) -> Control:
	var row = Control.new()
	row.position = Vector2(PAD, y)
	row.size     = Vector2(HUD_W - PAD * 2.0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ColorRect.new()
	bg.name = "BG"
	bg.size  = Vector2(HUD_W - PAD * 2.0, ROW_H)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bg)

	var num = Label.new()
	num.name = "Num"
	num.text = str(idx + 1)
	num.add_theme_font_override("font", _font_bold)
	num.add_theme_font_size_override("font_size", 10)
	num.add_theme_color_override("font_color", COL_QUEUE_NUM)
	num.position    = Vector2(2.0, 3.0)
	num.size        = Vector2(14.0, ROW_H)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num)

	var lbl = Label.new()
	lbl.name = "Lbl"
	lbl.text = "—"
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COL_EMPTY_TEXT)
	lbl.position    = Vector2(18.0, 3.0)
	lbl.size        = Vector2(HUD_W - PAD * 2.0 - 18.0, ROW_H)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	return row

# ── Per-frame update ──────────────────────────────────────────
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player): return

	var in_combat = _check_in_combat()
	if in_combat and not _is_showing:
		_show()
	elif not in_combat and _is_showing:
		_hide()

	if not _is_showing: return

	# Timer bar fill (progress toward next execute)
	var qt       = _player.get("_queue_timer") as float
	var interval = _calc_base_interval()
	if interval > 0.0:
		var frac = clampf(1.0 - qt / interval, 0.0, 1.0)
		_timer_bar.size.x = frac * (HUD_W - PAD * 2.0)
		# Gold → bright as it nears firing
		_timer_bar.color = Color(
			0.55 + frac * 0.30,
			0.38 + frac * 0.28,
			0.10,
			0.92
		)

	# Refresh queue rows
	var queue : Array = _player.get("_combat_queue") if _player.get("_combat_queue") != null else []
	for i in MAX_ROWS:
		var row = _rows[i]
		var lbl = row.get_node_or_null("Lbl") as Label
		var bg  = row.get_node_or_null("BG")  as ColorRect
		var num = row.get_node_or_null("Num") as Label
		if i < queue.size():
			var sid : String = queue[i]
			var display = sid.replace("_", " ").to_upper()
			if lbl: lbl.text = display
			if i == 0:  # NEXT — bright gold highlight
				if lbl: lbl.add_theme_color_override("font_color", COL_NEXT_TEXT)
				if bg:  bg.color = COL_NEXT_BG
				if num: num.add_theme_color_override("font_color", COL_NEXT_NUM)
			else:
				if lbl: lbl.add_theme_color_override("font_color", COL_QUEUE_TEXT)
				if bg:  bg.color = Color(0.0, 0.0, 0.0, 0.0)
				if num: num.add_theme_color_override("font_color", COL_QUEUE_NUM)
		else:
			if lbl:
				lbl.text = "—"
				lbl.add_theme_color_override("font_color", COL_EMPTY_TEXT)
			if bg:  bg.color = Color(0.0, 0.0, 0.0, 0.0)
			if num: num.add_theme_color_override("font_color", COL_QUEUE_NUM)

# ── Helpers ───────────────────────────────────────────────────
func _check_in_combat() -> bool:
	var tgt = _player.get("_current_target")
	if tgt == null or not is_instance_valid(tgt): return false
	if tgt.get("_dying") == true: return false
	if not tgt.is_in_group("targetable"): return false
	return true

func _calc_base_interval() -> float:
	var cls : String = _player.get("character_class") if _player.get("character_class") != null else "melee"
	var agi : int    = (_player.get("attr_agi") as int) + (_player.get("_item_agi") as int)
	var base : float
	match cls:
		"melee", "scrapper": base = 2.0
		"ranged":            base = 2.5
		"mage":              base = 3.5
		"streetfighter":     base = 2.5
		"medic", "robo":     base = 3.0
		_:                   base = 2.0
	base /= (1.0 + agi * 0.05)
	return maxf(base, 1.0)

func _show() -> void:
	_is_showing = true
	if _vis_tween: _vis_tween.kill()
	_vis_tween = create_tween()
	_vis_tween.tween_property(_panel, "modulate:a", 1.0, 0.22)

func _hide() -> void:
	_is_showing = false
	if _vis_tween: _vis_tween.kill()
	_vis_tween = create_tween()
	_vis_tween.tween_property(_panel, "modulate:a", 0.0, 0.38)
